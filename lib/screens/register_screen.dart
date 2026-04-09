import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/reading.dart';
import '../models/oxygen_reading.dart';
import '../models/blood_pressure_reading.dart';
import '../models/heart_rate_reading.dart';
import '../models/metric_type.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class RegisterScreen extends StatefulWidget {
  final List<Reading> readings;
  final List<OxygenReading> oxygenReadings;
  final List<BloodPressureReading> bpReadings;
  final List<HeartRateReading> hrReadings;
  final VoidCallback onSaved;
  final String currentUser;
  final String currentPatient;

  const RegisterScreen({
    super.key,
    required this.readings,
    required this.oxygenReadings,
    required this.bpReadings,
    required this.hrReadings,
    required this.onSaved,
    required this.currentUser,
    required this.currentPatient,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // Glucosa
  final _glucCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  // O2
  final _spo2Ctrl = TextEditingController();
  final _o2NoteCtrl = TextEditingController();
  // Presión arterial
  final _systolicCtrl = TextEditingController();
  final _diastolicCtrl = TextEditingController();
  final _bpNoteCtrl = TextEditingController();
  // Pulso
  final _hrCtrl = TextEditingController();
  final _hrNoteCtrl = TextEditingController();

  String? _selectedMoment;
  String? _selectedInsulinType;
  String? _selectedPatient;
  List<String> _patients = [];
  bool _saving = false;
  MetricType _selectedMetric = MetricType.glucose;
  DateTime _selectedDateTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    _selectedPatient =
        widget.currentPatient.isEmpty ? null : widget.currentPatient;
    _loadPatients();
  }

  Future<void> _loadPatients() async {
    final storage = await StorageService.getInstance();
    final cached = storage.getCachedPatients();
    if (cached.isNotEmpty && mounted) {
      setState(() => _patients = cached);
    }
    try {
      final remote = await SupabaseService().getPatients();
      await storage.cachePatientsLocally(remote);
      if (mounted) setState(() => _patients = remote);
    } catch (_) {}
  }

  // ── Glucosa ──────────────────────────────────────────────────────────────

  int? get _glucVal => int.tryParse(_glucCtrl.text);

  GlucoseStatus? get _status {
    final v = _glucVal;
    if (v == null) return null;
    if (v < 70) return GlucoseStatus.low;
    if (v <= 130) return GlucoseStatus.normal;
    if (v <= 180) return GlucoseStatus.high;
    return GlucoseStatus.veryHigh;
  }

  Color _statusColor(GlucoseStatus? s) {
    switch (s) {
      case GlucoseStatus.low:
        return AppColors.red;
      case GlucoseStatus.normal:
        return AppColors.green;
      case GlucoseStatus.high:
        return AppColors.yellow;
      case GlucoseStatus.veryHigh:
        return AppColors.red;
      default:
        return AppColors.muted;
    }
  }

  double _rangePercent() {
    final v = _glucVal;
    if (v == null) return 0.5;
    return ((v - 40) / (400 - 40)).clamp(0.0, 1.0);
  }

  Future<void> _save() async {
    final v = _glucVal;
    if (v == null || v < 20 || v > 600) {
      _showSnack('Ingresa un valor válido (20–600 mg/dL)');
      return;
    }
    if (_selectedMoment == null) {
      _showSnack('Selecciona el momento del día');
      return;
    }
    setState(() => _saving = true);
    final dose = int.tryParse(_doseCtrl.text);
    final reading = Reading(
      id: const Uuid().v4(),
      timestamp: _selectedDateTime,
      glucoseValue: v,
      moment: _selectedMoment!,
      insulinDose: dose,
      insulinType: dose != null && dose > 0 ? _selectedInsulinType : null,
      note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      recordedBy:
          widget.currentUser.isEmpty ? 'Sin nombre' : widget.currentUser,
      patientName: _selectedPatient ?? widget.currentPatient,
    );
    final storage = await StorageService.getInstance();
    await storage.addReading(reading, widget.readings);
    widget.onSaved();
    SupabaseService().pushReading(reading).catchError((_) {});
    _glucCtrl.clear();
    _doseCtrl.clear();
    _noteCtrl.clear();
    setState(() {
      _selectedMoment = null;
      _selectedInsulinType = null;
      _saving = false;
      _selectedDateTime = DateTime.now();
      _selectedPatient =
          widget.currentPatient.isEmpty ? null : widget.currentPatient;
    });
    _showSnack('✓ Registro guardado');
  }

  // ── SpO2 ─────────────────────────────────────────────────────────────────

  int? get _spo2Val => int.tryParse(_spo2Ctrl.text);

  SpO2Status? get _spo2Status {
    final v = _spo2Val;
    if (v == null) return null;
    if (v < kSpo2LowMin) return SpO2Status.critical;
    if (v < kSpo2NormalMin) return SpO2Status.low;
    return SpO2Status.normal;
  }

  Color _spo2Color(SpO2Status? s) {
    switch (s) {
      case SpO2Status.critical:
        return AppColors.oxygenCritical;
      case SpO2Status.low:
        return AppColors.oxygenLow;
      case SpO2Status.normal:
        return AppColors.oxygenNormal;
      default:
        return AppColors.muted;
    }
  }

  double _spo2RangePercent() {
    final v = _spo2Val;
    if (v == null) return 1.0;
    return ((v - 70) / (100 - 70)).clamp(0.0, 1.0);
  }

  Future<void> _saveOxygen() async {
    final v = _spo2Val;
    if (v == null || v < 70 || v > 100) {
      _showSnack('Ingresa un valor válido (70–100 %)');
      return;
    }
    setState(() => _saving = true);
    final reading = OxygenReading(
      id: const Uuid().v4(),
      timestamp: _selectedDateTime,
      spo2Value: v,
      note: _o2NoteCtrl.text.trim().isEmpty ? null : _o2NoteCtrl.text.trim(),
      recordedBy:
          widget.currentUser.isEmpty ? 'Sin nombre' : widget.currentUser,
      patientName: _selectedPatient ?? widget.currentPatient,
    );
    final storage = await StorageService.getInstance();
    await storage.addOxygenReading(reading, widget.oxygenReadings);
    widget.onSaved();
    SupabaseService().pushOxygenReading(reading).catchError((_) {});
    _spo2Ctrl.clear();
    _o2NoteCtrl.clear();
    setState(() {
      _saving = false;
      _selectedDateTime = DateTime.now();
      _selectedPatient =
          widget.currentPatient.isEmpty ? null : widget.currentPatient;
    });
    _showSnack('✓ Saturación guardada');
  }

  // ── Presión arterial ─────────────────────────────────────────────────────

  int? get _systolicVal => int.tryParse(_systolicCtrl.text);
  int? get _diastolicVal => int.tryParse(_diastolicCtrl.text);

  BPStatus? get _bpStatus {
    final s = _systolicVal;
    final d = _diastolicVal;
    if (s == null || d == null) return null;
    if (s > 180 || d > 120) return BPStatus.crisis;
    if (s >= 140 || d >= 90) return BPStatus.stage2;
    if (s >= 130 || d >= 80) return BPStatus.stage1;
    if (s >= 120 && d < 80) return BPStatus.elevated;
    return BPStatus.normal;
  }

  Future<void> _saveBP() async {
    final s = _systolicVal;
    final d = _diastolicVal;
    if (s == null || s < 60 || s > 250) {
      _showSnack('Ingresa una sistólica válida (60–250 mmHg)');
      return;
    }
    if (d == null || d < 40 || d > 150) {
      _showSnack('Ingresa una diastólica válida (40–150 mmHg)');
      return;
    }
    setState(() => _saving = true);
    final reading = BloodPressureReading(
      id: const Uuid().v4(),
      timestamp: _selectedDateTime,
      systolic: s,
      diastolic: d,
      note: _bpNoteCtrl.text.trim().isEmpty ? null : _bpNoteCtrl.text.trim(),
      recordedBy:
          widget.currentUser.isEmpty ? 'Sin nombre' : widget.currentUser,
      patientName: _selectedPatient ?? widget.currentPatient,
    );
    final storage = await StorageService.getInstance();
    await storage.addBPReading(reading, widget.bpReadings);
    widget.onSaved();
    SupabaseService().pushBPReading(reading).catchError((_) {});
    _systolicCtrl.clear();
    _diastolicCtrl.clear();
    _bpNoteCtrl.clear();
    setState(() {
      _saving = false;
      _selectedDateTime = DateTime.now();
      _selectedPatient =
          widget.currentPatient.isEmpty ? null : widget.currentPatient;
    });
    _showSnack('✓ Presión arterial guardada');
  }

  // ── Pulso ────────────────────────────────────────────────────────────────

  int? get _hrVal => int.tryParse(_hrCtrl.text);

  HRStatus? get _hrStatus {
    final v = _hrVal;
    if (v == null) return null;
    if (v < 60) return HRStatus.bradycardia;
    if (v <= 100) return HRStatus.normal;
    return HRStatus.tachycardia;
  }

  double _hrRangePercent() {
    final v = _hrVal;
    if (v == null) return 0.5;
    return ((v - 30) / (250 - 30)).clamp(0.0, 1.0);
  }

  Future<void> _saveHR() async {
    final v = _hrVal;
    if (v == null || v < 30 || v > 250) {
      _showSnack('Ingresa un valor válido (30–250 bpm)');
      return;
    }
    setState(() => _saving = true);
    final reading = HeartRateReading(
      id: const Uuid().v4(),
      timestamp: _selectedDateTime,
      bpmValue: v,
      note: _hrNoteCtrl.text.trim().isEmpty ? null : _hrNoteCtrl.text.trim(),
      recordedBy:
          widget.currentUser.isEmpty ? 'Sin nombre' : widget.currentUser,
      patientName: _selectedPatient ?? widget.currentPatient,
    );
    final storage = await StorageService.getInstance();
    await storage.addHRReading(reading, widget.hrReadings);
    widget.onSaved();
    SupabaseService().pushHRReading(reading).catchError((_) {});
    _hrCtrl.clear();
    _hrNoteCtrl.clear();
    setState(() {
      _saving = false;
      _selectedDateTime = DateTime.now();
      _selectedPatient =
          widget.currentPatient.isEmpty ? null : widget.currentPatient;
    });
    _showSnack('✓ Pulso guardado');
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDateTime,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (date == null) return;
    if (!mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_selectedDateTime),
    );
    if (time == null) return;
    setState(() {
      _selectedDateTime = DateTime(
          date.year, date.month, date.day, time.hour, time.minute);
    });
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: AppColors.navy,
      ),
    );
  }

  Widget _sectionTitle(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Text(t,
            style: const TextStyle(
                fontWeight: FontWeight.w700,
                fontSize: 13,
                color: AppColors.navy)),
      );

  Widget _statItem(String val, String lbl, Color color) => Column(
        children: [
          Text(val,
              style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w700,
                  fontSize: 15)),
          Text(lbl,
              style:
                  TextStyle(color: color.withValues(alpha: .7), fontSize: 11)),
        ],
      );

  Widget _dateTimePickerCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: GestureDetector(
          onTap: _pickDateTime,
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.bg,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined,
                    size: 18, color: AppColors.muted),
                const SizedBox(width: 10),
                Text(
                  DateFormat('dd/MM/yyyy  HH:mm').format(_selectedDateTime),
                  style: const TextStyle(fontSize: 15, color: AppColors.navy),
                ),
                const Spacer(),
                const Icon(Icons.edit_outlined,
                    size: 16, color: AppColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _patientSelector() {
    if (_patients.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('🏥 Paciente'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: DropdownButtonFormField<String>(
              value: _selectedPatient,
              decoration: const InputDecoration(
                labelText: 'Para quién es este registro',
                prefixIcon: Icon(Icons.medical_information_outlined,
                    size: 18, color: AppColors.muted),
              ),
              items: _patients
                  .map((p) => DropdownMenuItem(value: p, child: Text(p)))
                  .toList(),
              onChanged: (v) => setState(() => _selectedPatient = v),
            ),
          ),
        ),
      ],
    );
  }

  Widget _saveFooter(Color btnColor, String label, VoidCallback onPressed) {
    return Column(
      children: [
        const SizedBox(height: 4),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: btnColor),
            onPressed: _saving ? null : onPressed,
            child: _saving
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(label),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Text(
            '📝 Registrado por: ${widget.currentUser.isEmpty ? 'Sin nombre' : widget.currentUser}',
            style: const TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ),
        const SizedBox(height: 20),
      ],
    );
  }

  // ── Selector de métrica ───────────────────────────────────────────────────

  Widget _buildMetricSelector() {
    const metrics = MetricType.values;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: List.generate(metrics.length, (i) {
          final m = metrics[i];
          final selected = _selectedMetric == m;
          final isFirst = i == 0;
          final isLast = i == metrics.length - 1;
          return Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedMetric = m),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: selected ? m.color : AppColors.bg,
                  borderRadius: BorderRadius.horizontal(
                    left: isFirst ? const Radius.circular(10) : Radius.zero,
                    right: isLast ? const Radius.circular(10) : Radius.zero,
                  ),
                  border: Border.all(
                    color: selected ? m.color : AppColors.border,
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(m.emoji, style: const TextStyle(fontSize: 15)),
                    const SizedBox(height: 2),
                    Text(
                      m.label,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                        color: selected ? Colors.white : AppColors.muted,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  // ── Formulario Glucosa ────────────────────────────────────────────────────

  List<Widget> _buildGlucoseForm(BuildContext context) {
    final today = widget.readings.where((r) {
      final now = DateTime.now();
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();
    final vals = today.map((r) => r.glucoseValue).toList();
    final avg = vals.isEmpty
        ? null
        : (vals.reduce((a, b) => a + b) / vals.length).round();
    final max =
        vals.isEmpty ? null : vals.reduce((a, b) => a > b ? a : b);

    return [
      if (today.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.teal],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('${today.length}', 'Hoy', Colors.white),
              _statItem('$avg mg/dL', 'Promedio', Colors.white),
              _statItem('$max mg/dL', 'Máximo', Colors.white),
            ],
          ),
        ),

      _sectionTitle('📅 Fecha y hora'),
      _dateTimePickerCard(),

      _sectionTitle('🩸 Glucosa en sangre'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _glucCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Glucosa en sangre',
                  suffixText: 'mg/dL',
                ),
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [
                        AppColors.red,
                        AppColors.yellow,
                        AppColors.green,
                        AppColors.yellow,
                        AppColors.red,
                      ]),
                    ),
                  ),
                  Positioned(
                    left: (_rangePercent() *
                            (MediaQuery.of(context).size.width - 56))
                        .clamp(0.0,
                            MediaQuery.of(context).size.width - 70),
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _statusColor(_status),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 3)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('↓ Bajo <70',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text('Normal 70-130',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text('Alto >180 ↑',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
              if (_status != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '$_glucVal mg/dL — ${_status!.label}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _statusColor(_status),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      _sectionTitle('⏰ Momento del día'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 2.6,
            children: kMoments.map((m) {
              final sel = _selectedMoment == m;
              return GestureDetector(
                onTap: () => setState(() => _selectedMoment = m),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: sel ? AppColors.tealLight : AppColors.bg,
                    border: Border.all(
                      color: sel ? AppColors.teal : AppColors.border,
                      width: sel ? 1.8 : 1.5,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(kMomentIcons[m] ?? '⏱',
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(width: 6),
                      Text(
                        m,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color:
                              sel ? AppColors.teal : AppColors.muted,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),

      _sectionTitle('💉 Insulina (opcional)'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _doseCtrl,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration:
                      const InputDecoration(labelText: 'Dosis (U)'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _selectedInsulinType,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: kInsulinTypes
                      .map((t) => DropdownMenuItem(
                          value: t,
                          child: Text(t,
                              style: const TextStyle(fontSize: 13))))
                      .toList(),
                  onChanged: (v) =>
                      setState(() => _selectedInsulinType = v),
                ),
              ),
            ],
          ),
        ),
      ),

      _sectionTitle('📝 Notas'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _noteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: Comí pasta, me sentí mareado...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),

      _patientSelector(),
      _saveFooter(AppColors.teal, '💾  Guardar registro', _save),
    ];
  }

  // ── Formulario O₂ ─────────────────────────────────────────────────────────

  List<Widget> _buildOxygenForm(BuildContext context) {
    final today = widget.oxygenReadings.where((r) {
      final now = DateTime.now();
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();
    final vals = today.map((r) => r.spo2Value).toList();
    final avg = vals.isEmpty
        ? null
        : (vals.reduce((a, b) => a + b) / vals.length).round();
    final min =
        vals.isEmpty ? null : vals.reduce((a, b) => a < b ? a : b);

    return [
      if (today.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.oxygenNormal],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('${today.length}', 'Hoy', Colors.white),
              _statItem('$avg %', 'Promedio', Colors.white),
              _statItem('$min %', 'Mínimo', Colors.white),
            ],
          ),
        ),

      _sectionTitle('📅 Fecha y hora'),
      _dateTimePickerCard(),

      _sectionTitle('🫁 Saturación de oxígeno'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _spo2Ctrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Saturación de oxígeno',
                  suffixText: '%',
                ),
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [
                        AppColors.oxygenCritical,
                        AppColors.oxygenLow,
                        AppColors.oxygenNormal,
                      ]),
                    ),
                  ),
                  Positioned(
                    left: (_spo2RangePercent() *
                            (MediaQuery.of(context).size.width - 56))
                        .clamp(0.0,
                            MediaQuery.of(context).size.width - 70),
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _spo2Color(_spo2Status),
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 3)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('<90% Crítico',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text('90–94% Bajo',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text('≥95% Normal',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
              if (_spo2Status != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '$_spo2Val % — ${_spo2Status!.label}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _spo2Color(_spo2Status),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      _sectionTitle('📝 Notas'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _o2NoteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: En reposo, después de ejercicio...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),

      _patientSelector(),
      _saveFooter(
          AppColors.oxygenNormal, '💾  Guardar saturación', _saveOxygen),
    ];
  }

  // ── Formulario Presión Arterial ───────────────────────────────────────────

  List<Widget> _buildBPForm(BuildContext context) {
    final today = widget.bpReadings.where((r) {
      final now = DateTime.now();
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();
    final sysVals = today.map((r) => r.systolic).toList();
    final diaVals = today.map((r) => r.diastolic).toList();
    final avgSys = sysVals.isEmpty
        ? null
        : (sysVals.reduce((a, b) => a + b) / sysVals.length).round();
    final avgDia = diaVals.isEmpty
        ? null
        : (diaVals.reduce((a, b) => a + b) / diaVals.length).round();

    return [
      if (today.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.bpNormal],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('${today.length}', 'Hoy', Colors.white),
              _statItem('$avgSys mmHg', 'Avg Sist.', Colors.white),
              _statItem('$avgDia mmHg', 'Avg Diast.', Colors.white),
            ],
          ),
        ),

      _sectionTitle('📅 Fecha y hora'),
      _dateTimePickerCard(),

      _sectionTitle('💓 Presión arterial'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _systolicCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Sistólica',
                        suffixText: 'mmHg',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: _diastolicCtrl,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Diastólica',
                        suffixText: 'mmHg',
                      ),
                    ),
                  ),
                ],
              ),
              if (_bpStatus != null) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: _bpStatus!.bgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '$_systolicVal/$_diastolicVal mmHg — ${_bpStatus!.label}',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                        color: _bpStatus!.color,
                      ),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 8),
              const Center(
                child: Text(
                  'Normal: <120/80  ·  Crisis: >180/120',
                  style: TextStyle(fontSize: 11, color: AppColors.muted),
                ),
              ),
            ],
          ),
        ),
      ),

      _sectionTitle('📝 Notas'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _bpNoteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: En reposo, después de caminar...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),

      _patientSelector(),
      _saveFooter(AppColors.bpNormal, '💾  Guardar presión', _saveBP),
    ];
  }

  // ── Formulario Pulso ──────────────────────────────────────────────────────

  List<Widget> _buildHRForm(BuildContext context) {
    final today = widget.hrReadings.where((r) {
      final now = DateTime.now();
      return r.timestamp.year == now.year &&
          r.timestamp.month == now.month &&
          r.timestamp.day == now.day;
    }).toList();
    final vals = today.map((r) => r.bpmValue).toList();
    final avg = vals.isEmpty
        ? null
        : (vals.reduce((a, b) => a + b) / vals.length).round();
    final min =
        vals.isEmpty ? null : vals.reduce((a, b) => a < b ? a : b);

    return [
      if (today.isNotEmpty)
        Container(
          margin: const EdgeInsets.only(bottom: 14),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [AppColors.navy, AppColors.hrNormal],
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _statItem('${today.length}', 'Hoy', Colors.white),
              _statItem('$avg bpm', 'Promedio', Colors.white),
              _statItem('$min bpm', 'Mínimo', Colors.white),
            ],
          ),
        ),

      _sectionTitle('📅 Fecha y hora'),
      _dateTimePickerCard(),

      _sectionTitle('❤️ Frecuencia cardíaca'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: _hrCtrl,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Frecuencia cardíaca',
                  suffixText: 'bpm',
                ),
              ),
              const SizedBox(height: 10),
              Stack(
                children: [
                  Container(
                    height: 6,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(4),
                      gradient: const LinearGradient(colors: [
                        AppColors.hrAbnormal,
                        AppColors.hrNormal,
                        AppColors.hrTachy,
                      ]),
                    ),
                  ),
                  Positioned(
                    left: (_hrRangePercent() *
                            (MediaQuery.of(context).size.width - 56))
                        .clamp(0.0,
                            MediaQuery.of(context).size.width - 70),
                    top: -4,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _hrStatus?.color ?? AppColors.muted,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: const [
                          BoxShadow(color: Colors.black26, blurRadius: 3)
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Bradicardia <60',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text('Normal 60-100',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                  Text('Taquicardia >100',
                      style:
                          TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
              if (_hrStatus != null) ...[
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    '$_hrVal bpm — ${_hrStatus!.label}',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: _hrStatus!.color,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),

      _sectionTitle('📝 Notas'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: TextField(
            controller: _hrNoteCtrl,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Ej: Después de ejercicio, en reposo...',
              border: OutlineInputBorder(),
            ),
          ),
        ),
      ),

      _patientSelector(),
      _saveFooter(AppColors.hrNormal, '💾  Guardar pulso', _saveHR),
    ];
  }

  // ── dispose ───────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _glucCtrl.dispose();
    _doseCtrl.dispose();
    _noteCtrl.dispose();
    _spo2Ctrl.dispose();
    _o2NoteCtrl.dispose();
    _systolicCtrl.dispose();
    _diastolicCtrl.dispose();
    _bpNoteCtrl.dispose();
    _hrCtrl.dispose();
    _hrNoteCtrl.dispose();
    super.dispose();
  }

  // ── build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          _buildMetricSelector(),
          ..._buildFormForMetric(context),
        ],
      ),
    );
  }

  List<Widget> _buildFormForMetric(BuildContext context) {
    switch (_selectedMetric) {
      case MetricType.glucose:
        return _buildGlucoseForm(context);
      case MetricType.oxygen:
        return _buildOxygenForm(context);
      case MetricType.bloodPressure:
        return _buildBPForm(context);
      case MetricType.heartRate:
        return _buildHRForm(context);
    }
  }
}
