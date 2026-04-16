import 'package:flutter/material.dart';
import '../models/doctor.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';

class DoctorFormScreen extends StatefulWidget {
  final String currentPatient;
  final Doctor? existing;

  const DoctorFormScreen({
    super.key,
    required this.currentPatient,
    this.existing,
  });

  @override
  State<DoctorFormScreen> createState() => _DoctorFormScreenState();
}

class _DoctorFormScreenState extends State<DoctorFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _clinicCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _specialty = kSpecialties.first;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final d = widget.existing;
    if (d != null) {
      _nameCtrl.text = d.name;
      _specialty = d.specialty;
      _clinicCtrl.text = d.clinic ?? '';
      _phoneCtrl.text = d.phone ?? '';
      _notesCtrl.text = d.notes ?? '';
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _clinicCtrl.dispose();
    _phoneCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);

    final storage = await StorageService.getInstance();
    final current = storage.loadDoctors();

    final doctor = Doctor(
      id: _isEditing
          ? widget.existing!.id
          : DateTime.now().millisecondsSinceEpoch.toString(),
      name: _nameCtrl.text.trim(),
      specialty: _specialty,
      clinic: _clinicCtrl.text.trim().isEmpty ? null : _clinicCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      patientName: widget.currentPatient,
    );

    if (_isEditing) {
      await storage.updateDoctor(doctor, current);
    } else {
      await storage.addDoctor(doctor, current);
    }

    try {
      await SupabaseService().pushDoctor(doctor);
    } catch (_) {}

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar médico' : 'Nuevo médico'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Información del médico'),
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
            const SizedBox(height: 20),
            _sectionTitle('Datos de contacto (opcional)'),
            TextFormField(
              controller: _clinicCtrl,
              decoration: const InputDecoration(
                labelText: 'Clínica / Consultorio',
                hintText: 'Ej: Hospital General, Consultorio 308',
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _phoneCtrl,
              decoration: const InputDecoration(
                labelText: 'Teléfono',
                hintText: 'Ej: 55-1234-5678',
              ),
              keyboardType: TextInputType.phone,
            ),
            const SizedBox(height: 20),
            _sectionTitle('Notas'),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas adicionales',
                hintText: 'Horario de consulta, indicaciones, etc.',
              ),
              maxLines: 3,
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
                    : Text(_isEditing ? 'Guardar cambios' : 'Guardar médico'),
              ),
            ),
            const SizedBox(height: 24),
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
}
