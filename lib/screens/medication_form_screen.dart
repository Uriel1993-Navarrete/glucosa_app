import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/doctor.dart';
import '../models/medication.dart';
import '../models/prescription.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../widgets/doctor_picker.dart';

class MedicationFormScreen extends StatefulWidget {
  final String currentPatient;
  final String currentUser;
  final Medication? existing;

  const MedicationFormScreen({
    super.key,
    required this.currentPatient,
    required this.currentUser,
    this.existing,
  });

  @override
  State<MedicationFormScreen> createState() => _MedicationFormScreenState();
}

class _MedicationFormScreenState extends State<MedicationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();
  final _instructionsCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  // Doctor y receta
  Doctor? _selectedDoctor;
  Prescription? _selectedPrescription; // null = "Sin receta"
  List<Prescription> _doctorPrescriptions = [];
  bool _showNewRxForm = false;
  final _newRxCtrl = TextEditingController();
  DateTime _newRxDate = DateTime.now();

  String _unit = 'mg';
  List<String> _scheduleTimes = [];
  DateTime _startDate = DateTime.now();
  DateTime? _endDate;
  bool _isActive = true;
  bool _saving = false;

  late StorageService _storage;
  bool _storageReady = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _initStorage();
  }

  Future<void> _initStorage() async {
    _storage = await StorageService.getInstance();
    final m = widget.existing;
    if (m != null) {
      _nameCtrl.text = m.name;
      _doseCtrl.text = m.dose;
      _unit = m.unit;
      _instructionsCtrl.text = m.instructions ?? '';
      _noteCtrl.text = m.note ?? '';
      _scheduleTimes = List.from(m.scheduleTimes);
      _startDate = m.startDate;
      _endDate = m.endDate;
      _isActive = m.isActive;
      // Cargar doctor desde catálogo si existe
      if (m.doctorId != null) {
        final doctors = _storage.loadDoctors();
        _selectedDoctor = doctors.cast<Doctor?>().firstWhere(
              (d) => d?.id == m.doctorId,
              orElse: () => null,
            );
        if (_selectedDoctor != null) _loadPrescriptionsForDoctor();
      }
      // Cargar receta si existe
      if (m.prescriptionId != null && _selectedDoctor != null) {
        final prescriptions = _storage.loadPrescriptions();
        _selectedPrescription = prescriptions.cast<Prescription?>().firstWhere(
              (r) => r?.id == m.prescriptionId,
              orElse: () => null,
            );
      }
    }
    setState(() => _storageReady = true);
  }

  void _loadPrescriptionsForDoctor() {
    if (_selectedDoctor == null) return;
    final all = _storage.loadPrescriptions();
    setState(() {
      _doctorPrescriptions = all
          .where((r) =>
              r.doctorId == _selectedDoctor!.id &&
              r.patientName == widget.currentPatient)
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
    });
  }

  void _onDoctorSelected(Doctor doctor) {
    setState(() {
      _selectedDoctor = doctor;
      _selectedPrescription = null;
      _showNewRxForm = false;
    });
    _loadPrescriptionsForDoctor();
  }

  Future<void> _saveNewPrescription() async {
    final rx = Prescription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      doctorId: _selectedDoctor!.id,
      rxNumber:
          _newRxCtrl.text.trim().isEmpty ? null : _newRxCtrl.text.trim(),
      date: _newRxDate,
      patientName: widget.currentPatient,
    );
    await _storage.addPrescription(rx, _storage.loadPrescriptions());
    try {
      await SupabaseService().pushPrescription(rx);
    } catch (_) {}
    _newRxCtrl.clear();
    setState(() {
      _showNewRxForm = false;
      _selectedPrescription = rx;
    });
    _loadPrescriptionsForDoctor();
  }

  Future<void> _pickStartDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _startDate = picked);
  }

  Future<void> _pickEndDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _endDate ?? DateTime.now(),
      firstDate: _startDate,
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _endDate = picked);
  }

  Future<void> _addTime() async {
    if (_scheduleTimes.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Máximo 4 horarios por medicamento'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      final formatted =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
      if (!_scheduleTimes.contains(formatted)) {
        setState(() {
          _scheduleTimes.add(formatted);
          _scheduleTimes.sort();
        });
      }
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDoctor == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Selecciona un médico'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.red,
        ),
      );
      return;
    }
    setState(() => _saving = true);

    try {
      final current = _storage.loadMedications();
      final med = Medication(
        id: _isEditing ? widget.existing!.id : const Uuid().v4(),
        name: _nameCtrl.text.trim(),
        dose: _doseCtrl.text.trim(),
        unit: _unit,
        doctorId: _selectedDoctor!.id,
        doctorName: _selectedDoctor!.name,
        specialty: _selectedDoctor!.specialty,
        prescriptionId: _selectedPrescription?.id,
        scheduleTimes: _scheduleTimes,
        instructions: _instructionsCtrl.text.trim().isEmpty
            ? null
            : _instructionsCtrl.text.trim(),
        startDate: _startDate,
        endDate: _endDate,
        isActive: _isActive,
        patientName: widget.currentPatient,
        note: _noteCtrl.text.trim().isEmpty ? null : _noteCtrl.text.trim(),
      );

      if (_isEditing) {
        await _storage.updateMedication(med, current);
      } else {
        await _storage.addMedication(med, current);
      }

      try {
        await SupabaseService().pushMedication(med);
      } catch (_) {}

      // Reprogramar notificaciones para este medicamento
      final allMeds = _storage.loadMedications();
      await NotificationService.instance.cancelMedication(med.id, allMeds);
      if (med.isActive) {
        await NotificationService.instance.scheduleMedication(med, allMeds);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al guardar: $e'),
            backgroundColor: AppColors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_storageReady) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEditing ? 'Editar medicamento' : 'Nuevo medicamento'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Médico ──────────────────────────────────
            _sectionTitle('Médico'),
            DoctorPickerField(
              selectedDoctor: _selectedDoctor,
              patientName: widget.currentPatient,
              onDoctorSelected: _onDoctorSelected,
            ),
            const SizedBox(height: 16),

            // ── Receta (visible solo si hay doctor) ─────
            if (_selectedDoctor != null) ...[
              _sectionTitle('Receta'),
              _prescriptionSelector(),
              const SizedBox(height: 16),
            ],

            // ── Medicamento ─────────────────────────────
            _sectionTitle('Información del medicamento'),
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre del medicamento *',
                hintText: 'Ej: Metformina, Losartán',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 3,
                  child: TextFormField(
                    controller: _doseCtrl,
                    decoration:
                        const InputDecoration(labelText: 'Dosis *'),
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    validator: (v) => v == null || v.trim().isEmpty
                        ? 'Requerido'
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 2,
                  child: DropdownButtonFormField<String>(
                    value: _unit,
                    decoration:
                        const InputDecoration(labelText: 'Unidad'),
                    items: kDoseUnits
                        .map((u) =>
                            DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) =>
                        setState(() => _unit = v ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Horarios ────────────────────────────────
            _sectionTitle('Horarios de toma'),
            if (_scheduleTimes.isNotEmpty) ...[
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: _scheduleTimes
                    .map(
                      (t) => Chip(
                        label: Text(t,
                            style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.teal)),
                        backgroundColor: AppColors.tealLight,
                        deleteIconColor: AppColors.teal,
                        onDeleted: () =>
                            setState(() => _scheduleTimes.remove(t)),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 8),
            ],
            if (_scheduleTimes.length < 4)
              OutlinedButton.icon(
                onPressed: _addTime,
                icon: const Icon(Icons.add_alarm_outlined, size: 18),
                label: const Text('Agregar horario'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.teal,
                  side: const BorderSide(color: AppColors.teal),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            const SizedBox(height: 20),

            // ── Instrucciones ───────────────────────────
            _sectionTitle('Instrucciones adicionales'),
            TextFormField(
              controller: _instructionsCtrl,
              decoration: const InputDecoration(
                labelText: 'Instrucciones',
                hintText: 'Ej: Con comida, En ayunas, Antes de dormir',
              ),
            ),
            const SizedBox(height: 20),

            // ── Vigencia ────────────────────────────────
            _sectionTitle('Vigencia del medicamento'),
            Row(
              children: [
                Expanded(
                    child: _dateField(
                        'Inicio *', _startDate, _pickStartDate)),
                const SizedBox(width: 10),
                Expanded(
                  child: _dateFieldOptional(
                    'Fin',
                    _endDate,
                    _pickEndDate,
                    _endDate != null
                        ? () => setState(() => _endDate = null)
                        : null,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // ── Notas ───────────────────────────────────
            _sectionTitle('Notas adicionales'),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas',
                hintText: 'Información adicional sobre el medicamento',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              title: const Text('Medicamento activo',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy)),
              activeColor: AppColors.teal,
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text(_isEditing
                        ? 'Guardar cambios'
                        : 'Guardar medicamento'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  // ── Selector de receta ───────────────────────────────────
  Widget _prescriptionSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Chips: Sin receta + recetas existentes del doctor
        Wrap(
          spacing: 8,
          runSpacing: 6,
          children: [
            // Opción "Sin receta"
            _rxChip(
              label: 'Sin receta',
              selected: _selectedPrescription == null && !_showNewRxForm,
              onTap: () => setState(() {
                _selectedPrescription = null;
                _showNewRxForm = false;
              }),
              color: AppColors.muted,
            ),
            // Recetas existentes
            ..._doctorPrescriptions.map((rx) => _rxChip(
                  label: rx.displayLabel,
                  sublabel:
                      DateFormat('d MMM yyyy', 'es').format(rx.date),
                  selected: _selectedPrescription?.id == rx.id &&
                      !_showNewRxForm,
                  onTap: () => setState(() {
                    _selectedPrescription = rx;
                    _showNewRxForm = false;
                  }),
                  color: AppColors.amber,
                )),
            // Botón nueva receta
            GestureDetector(
              onTap: () => setState(() {
                _showNewRxForm = !_showNewRxForm;
                if (_showNewRxForm) _selectedPrescription = null;
              }),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _showNewRxForm
                      ? AppColors.teal
                      : AppColors.tealLight,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.teal),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _showNewRxForm ? Icons.close : Icons.add,
                      size: 14,
                      color: _showNewRxForm ? Colors.white : AppColors.teal,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showNewRxForm ? 'Cancelar' : 'Nueva receta',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _showNewRxForm
                            ? Colors.white
                            : AppColors.teal,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        // Formulario inline de nueva receta
        if (_showNewRxForm) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.tealLight,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppColors.teal.withValues(alpha: .3)),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _newRxCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Número de receta',
                    hintText: 'Opcional — Ej: RX-2024-001',
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _newRxDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030),
                    );
                    if (picked != null)
                      setState(() => _newRxDate = picked);
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: AppColors.bg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_outlined,
                            size: 14, color: AppColors.muted),
                        const SizedBox(width: 8),
                        Text(
                          'Fecha: ${_newRxDate.day}/${_newRxDate.month}/${_newRxDate.year}',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.navy),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saveNewPrescription,
                    child: const Text('Guardar y seleccionar receta'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _rxChip({
    required String label,
    String? sublabel,
    required bool selected,
    required VoidCallback onTap,
    required Color color,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: .15) : AppColors.bg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : AppColors.border,
            width: selected ? 1.8 : 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : AppColors.muted,
              ),
            ),
            if (sublabel != null)
              Text(
                sublabel,
                style: const TextStyle(
                    fontSize: 10, color: AppColors.muted),
              ),
          ],
        ),
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

  Widget _dateField(String label, DateTime date, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            const Icon(Icons.calendar_today_outlined,
                size: 16, color: AppColors.muted),
            const SizedBox(width: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppColors.muted)),
                Text(
                  '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}',
                  style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.navy),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateFieldOptional(
      String label,
      DateTime? date,
      VoidCallback onTap,
      VoidCallback? onClear) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: date != null ? AppColors.tealLight : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: date != null ? AppColors.teal : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.event_outlined,
                size: 16,
                color: date != null ? AppColors.teal : AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: date != null
                              ? AppColors.teal
                              : AppColors.muted)),
                  Text(
                    date != null
                        ? '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}'
                        : 'Seleccionar',
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: date != null
                            ? AppColors.teal
                            : AppColors.muted),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close,
                    size: 14, color: AppColors.teal),
              ),
          ],
        ),
      ),
    );
  }
}
