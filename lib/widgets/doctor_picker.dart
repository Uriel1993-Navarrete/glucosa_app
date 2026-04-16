import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

/// Campo que muestra el doctor seleccionado y abre el picker al tocar.
class DoctorPickerField extends StatelessWidget {
  final Doctor? selectedDoctor;
  final String patientName;
  final ValueChanged<Doctor> onDoctorSelected;

  const DoctorPickerField({
    super.key,
    required this.selectedDoctor,
    required this.patientName,
    required this.onDoctorSelected,
  });

  @override
  Widget build(BuildContext context) {
    final hasDoctor = selectedDoctor != null;
    return GestureDetector(
      onTap: () => _openPicker(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: hasDoctor ? AppColors.tealLight : AppColors.bg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasDoctor ? AppColors.teal : AppColors.border,
            width: hasDoctor ? 1.8 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Text(
              hasDoctor ? '👨‍⚕️' : '🔍',
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: hasDoctor
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedDoctor!.name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                        Text(
                          selectedDoctor!.specialty,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.teal),
                        ),
                      ],
                    )
                  : const Text(
                      'Seleccionar médico',
                      style: TextStyle(fontSize: 14, color: AppColors.muted),
                    ),
            ),
            Icon(
              hasDoctor ? Icons.swap_horiz : Icons.chevron_right,
              color: hasDoctor ? AppColors.teal : AppColors.muted,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final result = await showModalBottomSheet<Doctor>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DoctorPickerSheet(
        patientName: patientName,
        selectedId: selectedDoctor?.id,
      ),
    );
    if (result != null) onDoctorSelected(result);
  }
}

/// Bottom sheet con buscador y lista de doctores.
class DoctorPickerSheet extends StatefulWidget {
  final String patientName;
  final String? selectedId;

  const DoctorPickerSheet({
    super.key,
    required this.patientName,
    this.selectedId,
  });

  @override
  State<DoctorPickerSheet> createState() => _DoctorPickerSheetState();
}

class _DoctorPickerSheetState extends State<DoctorPickerSheet> {
  late StorageService _storage;
  List<Doctor> _doctors = [];
  List<Doctor> _filtered = [];
  final _searchCtrl = TextEditingController();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    _storage = await StorageService.getInstance();
    final all = _storage
        .loadDoctors()
        .where((d) => d.patientName == widget.patientName)
        .toList();
    all.sort((a, b) => a.name.compareTo(b.name));
    setState(() {
      _doctors = all;
      _filtered = all;
      _loading = false;
    });
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

  Future<void> _addNew() async {
    final newDoctor = await Navigator.push<Doctor>(
      context,
      MaterialPageRoute(
        builder: (_) => _QuickDoctorForm(patientName: widget.patientName),
      ),
    );
    if (newDoctor != null && mounted) {
      Navigator.pop(context, newDoctor);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottomPad),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // Handle
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Seleccionar médico',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.navy,
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Buscador
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _searchCtrl,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Buscar por nombre o especialidad...',
                  prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            _filter();
                          },
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            // Lista
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _filtered.isEmpty && _searchCtrl.text.isEmpty
                      ? _emptyState()
                      : _filtered.isEmpty
                          ? _noResults()
                          : ListView.builder(
                              padding: const EdgeInsets.only(bottom: 8),
                              itemCount: _filtered.length,
                              itemBuilder: (_, i) =>
                                  _doctorTile(_filtered[i]),
                            ),
            ),
            const Divider(height: 1),
            // Botón agregar nuevo
            ListTile(
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.tealLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.add, color: AppColors.teal),
              ),
              title: const Text(
                'Agregar nuevo médico',
                style: TextStyle(
                    fontWeight: FontWeight.w600, color: AppColors.teal),
              ),
              onTap: _addNew,
            ),
          ],
        ),
      ),
    );
  }

  Widget _doctorTile(Doctor d) {
    final isSelected = d.id == widget.selectedId;
    return ListTile(
      leading: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.teal : AppColors.tealLight,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Center(
          child: Text(
            d.name.substring(0, 1).toUpperCase(),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: isSelected ? Colors.white : AppColors.teal,
            ),
          ),
        ),
      ),
      title: Text(
        d.name,
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isSelected ? AppColors.teal : AppColors.navy,
        ),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(d.specialty,
              style: const TextStyle(fontSize: 12, color: AppColors.teal)),
          if (d.clinic != null)
            Text(d.clinic!,
                style:
                    const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.teal)
          : null,
      onTap: () => Navigator.pop(context, d),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('👨‍⚕️', style: TextStyle(fontSize: 40)),
          const SizedBox(height: 10),
          const Text(
            'Sin médicos en el catálogo',
            style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.navy),
          ),
          const SizedBox(height: 4),
          const Text(
            'Toca "Agregar nuevo médico" para comenzar',
            style: TextStyle(fontSize: 12, color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _noResults() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔍', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 10),
          Text(
            'Sin resultados para "${_searchCtrl.text}"',
            style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppColors.navy),
          ),
        ],
      ),
    );
  }
}

/// Formulario rápido para agregar un doctor desde el picker.
class _QuickDoctorForm extends StatefulWidget {
  final String patientName;
  const _QuickDoctorForm({required this.patientName});

  @override
  State<_QuickDoctorForm> createState() => _QuickDoctorFormState();
}

class _QuickDoctorFormState extends State<_QuickDoctorForm> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  String _specialty = kSpecialties.first;
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clinicCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final storage = await StorageService.getInstance();
    final doctor = Doctor(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      specialty: _specialty,
      clinic: _clinicCtrl.text.trim().isEmpty ? null : _clinicCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      patientName: widget.patientName,
    );

    await storage.addDoctor(doctor, storage.loadDoctors());
    try {
      await SupabaseService().pushDoctor(doctor);
    } catch (_) {}

    if (mounted) Navigator.pop(context, doctor);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo médico')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nombre completo *',
                hintText: 'Ej: Dr. García López',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Campo requerido' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _specialty,
              decoration: const InputDecoration(labelText: 'Especialidad *'),
              items: kSpecialties
                  .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                  .toList(),
              onChanged: (v) => setState(() => _specialty = v ?? _specialty),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _clinicCtrl,
              decoration: const InputDecoration(
                labelText: 'Clínica / Consultorio',
                hintText: 'Opcional',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: 'Opcional',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
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
                    : const Text('Guardar médico'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
