import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../models/medication.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'medication_form_screen.dart';

// ── Panel de diagnóstico de notificaciones ───────────────────
class _DiagnosticDialog extends StatefulWidget {
  final List<Medication> medications;
  const _DiagnosticDialog({required this.medications});

  @override
  State<_DiagnosticDialog> createState() => _DiagnosticDialogState();
}

class _DiagnosticDialogState extends State<_DiagnosticDialog> {
  Map<String, String>? _info;
  String? _testResult;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await NotificationService.instance
        .getDiagnosticInfo(widget.medications);
    if (mounted) setState(() { _info = info; _loading = false; });
  }

  Future<void> _testImmediate() async {
    try {
      await NotificationService.instance.showImmediateTest();
      if (mounted) {
        setState(() => _testResult = '✅ Notificación inmediata enviada — revisa tu bandeja');
      }
    } catch (e) {
      if (mounted) setState(() => _testResult = '❌ Error: $e');
    }
  }

  Future<void> _testScheduled() async {
    setState(() => _testResult = 'Programando...');
    final result = await NotificationService.instance.scheduleTest(seconds: 30);
    if (mounted) setState(() => _testResult = result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Diagnóstico de notificaciones',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
      content: SizedBox(
        width: double.maxFinite,
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Info técnica
                    ..._info!.entries.map((e) => Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(e.key,
                                  style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.muted,
                                      fontWeight: FontWeight.w600)),
                              Text(e.value,
                                  style: const TextStyle(
                                      fontSize: 12, color: AppColors.navy)),
                            ],
                          ),
                        )),
                    // Botón de exención de batería (solo si está activa la optimización)
                    if (_info?['bateria_optimizacion']?.contains('ACTIVA') == true) ...[
                      const SizedBox(height: 4),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () async {
                            await NotificationService.instance
                                .requestIgnoreBatteryOptimizations();
                            await Future.delayed(const Duration(seconds: 1));
                            if (mounted) {
                              setState(() { _info = null; _loading = true; _testResult = null; });
                              _load();
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.red,
                            side: const BorderSide(color: AppColors.red),
                          ),
                          child: const Text('Desactivar optimización de batería',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ),
                    ],
                    const Divider(height: 20),
                    // Pruebas
                    const Text('Pruebas',
                        style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: AppColors.navy)),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _testImmediate,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.teal,
                              side: const BorderSide(color: AppColors.teal),
                            ),
                            child: const Text('Ahora',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _testScheduled,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.navy,
                              side: const BorderSide(color: AppColors.navy),
                            ),
                            child: const Text('30 seg',
                                style: TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                    ),
                    if (_testResult != null) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.tealLight,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_testResult!,
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.navy)),
                      ),
                    ],
                  ],
                ),
              ),
      ),
      actions: [
        TextButton(
          onPressed: _info == null ? null : () {
            final buffer = StringBuffer();
            _info!.forEach((k, v) => buffer.writeln('$k: $v'));
            if (_testResult != null) buffer.writeln('test_result: $_testResult');
            Clipboard.setData(ClipboardData(text: buffer.toString()));
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Diagnóstico copiado al portapapeles')),
            );
          },
          child: const Text('Copiar'),
        ),
        TextButton(
          onPressed: () => setState(() { _info = null; _loading = true; _testResult = null; _load(); }),
          child: const Text('Actualizar'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }
}

class MedicationsScreen extends StatefulWidget {
  final String currentPatient;
  final String currentUser;

  const MedicationsScreen({
    super.key,
    required this.currentPatient,
    required this.currentUser,
  });

  @override
  State<MedicationsScreen> createState() => _MedicationsScreenState();
}

class _MedicationsScreenState extends State<MedicationsScreen> {
  late StorageService _storage;
  List<Medication> _medications = [];
  bool _showOnlyActive = true;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _storage = await StorageService.getInstance();
    setState(() {
      _medications = _storage.loadMedications()
          .where((m) => m.patientName == widget.currentPatient)
          .toList();
      _loading = false;
    });
  }

  List<Medication> get _filtered {
    if (_showOnlyActive) {
      return _medications.where((m) => m.isActive).toList();
    }
    return _medications;
  }

  // Agrupar por doctor + receta
  Map<String, List<Medication>> get _grouped {
    final result = <String, List<Medication>>{};
    for (final m in _filtered) {
      final key = '${m.doctorId ?? m.doctorName}||${m.prescriptionId ?? ''}';
      result.putIfAbsent(key, () => []).add(m);
    }
    return result;
  }

  Future<void> _delete(Medication med) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar medicamento?'),
        content: Text('${med.name} — ${med.dose} ${med.unit}'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar',
                style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    // Cancelar notificaciones ANTES de eliminar (_medications aún incluye el med)
    await NotificationService.instance.cancelMedication(med.id, _medications);
    await _storage.deleteMedication(med.id, _medications);
    try {
      await SupabaseService().deleteMedicationRemote(med.id);
    } catch (_) {}
    setState(() {
      _medications = _storage.loadMedications()
          .where((m) => m.patientName == widget.currentPatient)
          .toList();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${med.name} eliminado'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.navy,
        ),
      );
    }
  }

  Future<void> _openForm({Medication? med}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => MedicationFormScreen(
          currentPatient: widget.currentPatient,
          currentUser: widget.currentUser,
          existing: med,
        ),
      ),
    );
    if (result == true) {
      setState(() {
        _medications = _storage.loadMedications()
            .where((m) => m.patientName == widget.currentPatient)
            .toList();
      });
    }
  }

  void _showDetail(Medication med) {
    String? rxDisplay;
    if (med.prescriptionId != null) {
      final rx = _storage
          .loadPrescriptions()
          .where((r) => r.id == med.prescriptionId)
          .firstOrNull;
      if (rx != null) rxDisplay = rx.displayLabel;
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MedicationDetailSheet(
        med: med,
        rxDisplay: rxDisplay,
        onEdit: () {
          Navigator.pop(context);
          _openForm(med: med);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(med);
        },
      ),
    );
  }

  void _showDiagnostic() async {
    final meds = _medications;
    showDialog<void>(
      context: context,
      builder: (_) => _DiagnosticDialog(medications: meds),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medicamentos'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report_outlined),
            tooltip: 'Diagnóstico de notificaciones',
            onPressed: _showDiagnostic,
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                _showOnlyActive ? 'Activos' : 'Todos',
                style: TextStyle(
                  fontSize: 12,
                  color: _showOnlyActive ? AppColors.teal : AppColors.muted,
                ),
              ),
              selected: _showOnlyActive,
              onSelected: (v) => setState(() => _showOnlyActive = v),
              selectedColor: AppColors.tealLight,
              checkmarkColor: AppColors.teal,
            ),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.teal,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Agregar'),
      ),
    );
  }

  Widget _buildBody() {
    final grouped = _grouped;
    if (grouped.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('💊', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            Text(
              _showOnlyActive
                  ? 'Sin medicamentos activos'
                  : 'Sin medicamentos registrados',
              style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toca + para agregar uno',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    final allDoctors = {
      for (final d in _storage.loadDoctors()) d.id: d
    };
    final allPrescriptions = {
      for (final rx in _storage.loadPrescriptions()) rx.id: rx
    };

    final keys = grouped.keys.toList();
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: keys.length,
      itemBuilder: (_, i) {
        final key = keys[i];
        final meds = grouped[key]!;
        final firstMed = meds.first;

        // Resolve doctor info
        String doctorName = firstMed.doctorName;
        String specialty = firstMed.specialty;
        if (firstMed.doctorId != null) {
          final doc = allDoctors[firstMed.doctorId];
          if (doc != null) {
            doctorName = doc.name;
            specialty = doc.specialty;
          }
        }

        // Resolve prescription Rx#
        String? rxLabel;
        if (firstMed.prescriptionId != null) {
          final rx = allPrescriptions[firstMed.prescriptionId];
          if (rx != null) rxLabel = rx.displayLabel;
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _groupHeader(doctorName, specialty, rxLabel),
            ...meds.map((m) => _medicationCard(m)),
            const SizedBox(height: 8),
          ],
        );
      },
    );
  }

  Widget _groupHeader(String doctor, String specialty, String? rxLabel) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 6),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.navy,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              specialty,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  doctor,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.navy,
                  ),
                ),
                if (rxLabel != null)
                  Text(
                    rxLabel,
                    style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _medicationCard(Medication m) {
    return Card(
      child: InkWell(
        onTap: () => _showDetail(m),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: m.isActive ? AppColors.tealLight : AppColors.bg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '💊',
                    style: TextStyle(
                      fontSize: 22,
                      color: m.isActive ? null : AppColors.muted,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            m.name,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: m.isActive ? AppColors.navy : AppColors.muted,
                            ),
                          ),
                        ),
                        if (!m.isActive)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.bg,
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: const Text(
                              'Inactivo',
                              style: TextStyle(
                                  fontSize: 10, color: AppColors.muted),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${m.dose} ${m.unit}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted),
                    ),
                    if (m.scheduleTimes.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: m.scheduleTimes
                            .map((t) => _timeChip(t))
                            .toList(),
                      ),
                    ],
                    if (m.instructions != null && m.instructions!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        m.instructions!,
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted),
                      ),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.muted, size: 18),
            ],
          ),
        ),
      ),
    );
  }

  Widget _timeChip(String time) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.tealLight,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.teal.withValues(alpha: .3)),
      ),
      child: Text(
        time,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.teal,
        ),
      ),
    );
  }
}

// ── Detalle en BottomSheet ────────────────────────────────
class _MedicationDetailSheet extends StatelessWidget {
  final Medication med;
  final String? rxDisplay;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MedicationDetailSheet({
    required this.med,
    this.rxDisplay,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.4,
      expand: false,
      builder: (_, controller) => ListView(
        controller: controller,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Row(
            children: [
              const Text('💊', style: TextStyle(fontSize: 32)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      med.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.navy,
                      ),
                    ),
                    Text(
                      '${med.dose} ${med.unit}',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              if (!med.isActive)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: const Text('Inactivo',
                      style: TextStyle(
                          fontSize: 11,
                          color: AppColors.muted,
                          fontWeight: FontWeight.w600)),
                ),
            ],
          ),
          const SizedBox(height: 20),
          _detailRow('Médico', med.doctorName),
          _detailRow('Especialidad', med.specialty),
          if (rxDisplay != null)
            _detailRow('Receta', rxDisplay!),
          if (med.scheduleTimes.isNotEmpty)
            _detailRowWidget(
              'Horarios',
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: med.scheduleTimes
                    .map((t) => Chip(
                          label: Text(t,
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.teal,
                                  fontWeight: FontWeight.w600)),
                          backgroundColor: AppColors.tealLight,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ))
                    .toList(),
              ),
            ),
          if (med.instructions != null && med.instructions!.isNotEmpty)
            _detailRow('Instrucciones', med.instructions!),
          _detailRow('Inicio', _fmtDate(med.startDate)),
          if (med.endDate != null)
            _detailRow('Fin', _fmtDate(med.endDate!)),
          if (med.note != null && med.note!.isNotEmpty)
            _detailRow('Notas', med.note!),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 16),
                  label: const Text('Editar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.teal,
                    side: const BorderSide(color: AppColors.teal),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline, size: 16),
                  label: const Text('Eliminar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.red,
                    side: const BorderSide(color: AppColors.red),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.muted),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy),
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRowWidget(String label, Widget child) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.muted),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }
}
