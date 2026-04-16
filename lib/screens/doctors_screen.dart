import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/doctor.dart';
import '../models/prescription.dart';
import '../models/medication.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'doctor_form_screen.dart';

class DoctorsScreen extends StatefulWidget {
  final String currentPatient;
  final String currentUser;

  const DoctorsScreen({
    super.key,
    required this.currentPatient,
    required this.currentUser,
  });

  @override
  State<DoctorsScreen> createState() => _DoctorsScreenState();
}

class _DoctorsScreenState extends State<DoctorsScreen> {
  late StorageService _storage;
  List<Doctor> _doctors = [];
  List<Prescription> _prescriptions = [];
  List<Medication> _medications = [];
  List<Doctor> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl.addListener(_filter);
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _storage = await StorageService.getInstance();
    _refresh();
  }

  void _refresh() {
    final doctors = _storage
        .loadDoctors()
        .where((d) => d.patientName == widget.currentPatient)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final prescriptions = _storage
        .loadPrescriptions()
        .where((r) => r.patientName == widget.currentPatient)
        .toList();
    final medications = _storage
        .loadMedications()
        .where((m) => m.patientName == widget.currentPatient)
        .toList();
    setState(() {
      _doctors = doctors;
      _prescriptions = prescriptions;
      _medications = medications;
      _loading = false;
    });
    _filter();
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _doctors
          : _doctors
              .where((d) =>
                  d.name.toLowerCase().contains(q) ||
                  d.specialty.toLowerCase().contains(q))
              .toList();
    });
  }

  int _medCount(String doctorId) =>
      _medications.where((m) => m.doctorId == doctorId && m.isActive).length;

  int _rxCount(String doctorId) =>
      _prescriptions.where((r) => r.doctorId == doctorId).length;

  Future<void> _delete(Doctor d) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar médico?'),
        content: Text(
            '${d.name}\n\nSus recetas y medicamentos asociados quedarán sin médico.'),
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
    await _storage.deleteDoctor(d.id, _doctors);
    try {
      await SupabaseService().deleteDoctorRemote(d.id);
    } catch (_) {}
    _refresh();
  }

  Future<void> _openForm({Doctor? doctor}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => DoctorFormScreen(
          currentPatient: widget.currentPatient,
          existing: doctor,
        ),
      ),
    );
    if (result == true) _refresh();
  }

  void _showDetail(Doctor d) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DoctorDetailSheet(
        doctor: d,
        prescriptions:
            _prescriptions.where((r) => r.doctorId == d.id).toList(),
        medications:
            _medications.where((m) => m.doctorId == d.id).toList(),
        storage: _storage,
        currentPatient: widget.currentPatient,
        onEdit: () {
          Navigator.pop(context);
          _openForm(doctor: d);
        },
        onDelete: () {
          Navigator.pop(context);
          _delete(d);
        },
        onChanged: _refresh,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _searching
            ? TextField(
                controller: _searchCtrl,
                autofocus: true,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Buscar médico...',
                  hintStyle: TextStyle(color: Colors.white70),
                  border: InputBorder.none,
                  filled: false,
                ),
              )
            : const Text('Médicos'),
        actions: [
          IconButton(
            icon: Icon(_searching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() => _searching = !_searching);
              if (!_searching) {
                _searchCtrl.clear();
                _filter();
              }
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add_outlined),
        label: const Text('Agregar médico'),
      ),
    );
  }

  Widget _buildBody() {
    if (_filtered.isEmpty && _searchCtrl.text.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('👨‍⚕️', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 12),
            const Text(
              'Sin médicos registrados',
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navy),
            ),
            const SizedBox(height: 6),
            const Text(
              'Toca + para agregar el primer médico',
              style: TextStyle(fontSize: 13, color: AppColors.muted),
            ),
          ],
        ),
      );
    }

    if (_filtered.isEmpty) {
      return Center(
        child: Text(
          'Sin resultados para "${_searchCtrl.text}"',
          style: const TextStyle(color: AppColors.muted),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
      itemCount: _filtered.length,
      itemBuilder: (_, i) => _doctorCard(_filtered[i]),
    );
  }

  Widget _doctorCard(Doctor d) {
    final medCount = _medCount(d.id);
    final rxCount = _rxCount(d.id);
    return Card(
      child: InkWell(
        onTap: () => _showDetail(d),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    d.name.split(' ').last.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d.name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(d.specialty,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.teal)),
                    if (d.clinic != null) ...[
                      const SizedBox(height: 1),
                      Text(d.clinic!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                    ],
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        _miniChip('💊 $medCount medicamento${medCount != 1 ? 's' : ''}'),
                        const SizedBox(width: 6),
                        _miniChip('📋 $rxCount receta${rxCount != 1 ? 's' : ''}'),
                      ],
                    ),
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

  Widget _miniChip(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.border),
      ),
      child: Text(label,
          style: const TextStyle(fontSize: 10, color: AppColors.muted)),
    );
  }
}

// ── Detalle del doctor en BottomSheet ─────────────────────
class _DoctorDetailSheet extends StatefulWidget {
  final Doctor doctor;
  final List<Prescription> prescriptions;
  final List<Medication> medications;
  final StorageService storage;
  final String currentPatient;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _DoctorDetailSheet({
    required this.doctor,
    required this.prescriptions,
    required this.medications,
    required this.storage,
    required this.currentPatient,
    required this.onEdit,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_DoctorDetailSheet> createState() => _DoctorDetailSheetState();
}

class _DoctorDetailSheetState extends State<_DoctorDetailSheet> {
  final _rxCtrl = TextEditingController();
  bool _addingRx = false;
  bool _savingRx = false;
  DateTime _rxDate = DateTime.now();

  @override
  void dispose() {
    _rxCtrl.dispose();
    super.dispose();
  }

  Future<void> _addPrescription() async {
    setState(() => _savingRx = true);
    final rx = Prescription(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      doctorId: widget.doctor.id,
      rxNumber: _rxCtrl.text.trim().isEmpty ? null : _rxCtrl.text.trim(),
      date: _rxDate,
      patientName: widget.currentPatient,
    );
    await widget.storage
        .addPrescription(rx, widget.storage.loadPrescriptions());
    try {
      await SupabaseService().pushPrescription(rx);
    } catch (_) {}
    setState(() {
      _addingRx = false;
      _savingRx = false;
      _rxCtrl.clear();
    });
    widget.onChanged();
    Navigator.pop(context);
  }

  Future<void> _deleteRx(Prescription rx) async {
    await widget.storage
        .deletePrescription(rx.id, widget.storage.loadPrescriptions());
    try {
      await SupabaseService().deletePrescriptionRemote(rx.id);
    } catch (_) {}
    widget.onChanged();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.doctor;
    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.92,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.navy,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(
                    d.name.split(' ').last.substring(0, 1).toUpperCase(),
                    style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.name,
                        style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.navy)),
                    Text(d.specialty,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.teal)),
                    if (d.clinic != null)
                      Text(d.clinic!,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                  ],
                ),
              ),
            ],
          ),
          if (d.phone != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.phone_outlined,
                    size: 14, color: AppColors.muted),
                const SizedBox(width: 6),
                Text(d.phone!,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ],
          const SizedBox(height: 20),
          // Recetas
          Row(
            children: [
              const Text('📋',
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w700)),
              const SizedBox(width: 6),
              const Text('Recetas',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy)),
              const Spacer(),
              TextButton.icon(
                onPressed: () => setState(() => _addingRx = !_addingRx),
                icon: Icon(
                    _addingRx ? Icons.close : Icons.add,
                    size: 16,
                    color: AppColors.teal),
                label: Text(
                    _addingRx ? 'Cancelar' : 'Nueva receta',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.teal)),
              ),
            ],
          ),
          if (_addingRx) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.tealLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.teal.withValues(alpha: .3)),
              ),
              child: Column(
                children: [
                  TextField(
                    controller: _rxCtrl,
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
                        initialDate: _rxDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (picked != null)
                        setState(() => _rxDate = picked);
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
                            'Fecha: ${_rxDate.day}/${_rxDate.month}/${_rxDate.year}',
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
                      onPressed: _savingRx ? null : _addPrescription,
                      child: _savingRx
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(
                                  color: Colors.white, strokeWidth: 2))
                          : const Text('Guardar receta'),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 8),
          if (widget.prescriptions.isEmpty && !_addingRx)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Sin recetas registradas',
                style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.muted,
                    fontStyle: FontStyle.italic),
              ),
            )
          else
            ...widget.prescriptions.map((rx) {
              final medCount = widget.medications
                  .where((m) => m.prescriptionId == rx.id)
                  .length;
              return ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.amberLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Center(
                    child: Text('📋', style: TextStyle(fontSize: 18)),
                  ),
                ),
                title: Text(rx.displayLabel,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.navy)),
                subtitle: Text(
                  '${DateFormat('d MMM yyyy', 'es').format(rx.date)} · $medCount medicamento${medCount != 1 ? 's' : ''}',
                  style:
                      const TextStyle(fontSize: 11, color: AppColors.muted),
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline,
                      color: AppColors.muted, size: 18),
                  onPressed: () => _deleteRx(rx),
                ),
              );
            }),
          const Divider(height: 24),
          // Botones
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: widget.onEdit,
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
                  onPressed: widget.onDelete,
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
}
