import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../models/appointment.dart';
import '../models/doctor.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import '../widgets/doctor_picker.dart';

class AppointmentFormScreen extends StatefulWidget {
  final String currentPatient;
  final String currentUser;
  final DateTime initialDate;
  final MedicalAppointment? existing;

  const AppointmentFormScreen({
    super.key,
    required this.currentPatient,
    required this.currentUser,
    required this.initialDate,
    this.existing,
  });

  @override
  State<AppointmentFormScreen> createState() => _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends State<AppointmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  final _resultCtrl = TextEditingController();

  late DateTime _selectedDate;
  late TimeOfDay _selectedTime;
  Doctor? _selectedDoctor;
  bool _isCompleted = false;
  bool _saving = false;
  bool _doctorError = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    if (a != null) {
      _locationCtrl.text = a.location ?? '';
      _notesCtrl.text = a.notes ?? '';
      _resultCtrl.text = a.result ?? '';
      _selectedDate = a.dateTime;
      _selectedTime =
          TimeOfDay(hour: a.dateTime.hour, minute: a.dateTime.minute);
      _isCompleted = a.isCompleted;
      _tryLoadDoctor(a.doctorName);
    } else {
      _selectedDate = widget.initialDate;
      _selectedTime = TimeOfDay.now();
    }
  }

  Future<void> _tryLoadDoctor(String name) async {
    final storage = await StorageService.getInstance();
    final match = storage
        .loadDoctors()
        .where((d) =>
            d.patientName == widget.currentPatient &&
            d.name.toLowerCase() == name.toLowerCase())
        .firstOrNull;
    if (match != null && mounted) {
      setState(() => _selectedDoctor = match);
    }
  }

  @override
  void dispose() {
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _resultCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  DateTime get _combinedDateTime => DateTime(
        _selectedDate.year,
        _selectedDate.month,
        _selectedDate.day,
        _selectedTime.hour,
        _selectedTime.minute,
      );

  Future<void> _save() async {
    final hasDoctor = _selectedDoctor != null;
    if (!hasDoctor) {
      setState(() => _doctorError = true);
    }
    if (!_formKey.currentState!.validate() || !hasDoctor) return;
    setState(() => _saving = true);

    final storage = await StorageService.getInstance();
    final current = storage.loadAppointments();

    final appt = MedicalAppointment(
      id: _isEditing ? widget.existing!.id : const Uuid().v4(),
      dateTime: _combinedDateTime,
      doctorName: _selectedDoctor!.name,
      specialty: _selectedDoctor!.specialty,
      location: _locationCtrl.text.trim().isEmpty
          ? null
          : _locationCtrl.text.trim(),
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      result:
          _resultCtrl.text.trim().isEmpty ? null : _resultCtrl.text.trim(),
      patientName: widget.currentPatient,
      isCompleted: _isCompleted,
    );

    if (_isEditing) {
      await storage.updateAppointment(appt, current);
    } else {
      await storage.addAppointment(appt, current);
    }

    try {
      await SupabaseService().pushAppointment(appt);
    } catch (_) {}

    // Reprogramar notificación de esta cita
    await NotificationService.instance.cancelAppointment(appt.id);
    await NotificationService.instance.scheduleAppointment(appt);

    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar cita' : 'Nueva cita'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('Fecha y hora'),
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: _pickDate,
                    child: _dateTimeBox(
                      icon: Icons.calendar_today_outlined,
                      label: 'Fecha',
                      value: DateFormat('d MMM yyyy', 'es')
                          .format(_selectedDate),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _pickTime,
                    child: _dateTimeBox(
                      icon: Icons.access_time_outlined,
                      label: 'Hora',
                      value:
                          '${_selectedTime.hour.toString().padLeft(2, '0')}:${_selectedTime.minute.toString().padLeft(2, '0')}',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            _sectionTitle('Datos del médico'),
            DoctorPickerField(
              selectedDoctor: _selectedDoctor,
              patientName: widget.currentPatient,
              onDoctorSelected: (d) =>
                  setState(() { _selectedDoctor = d; _doctorError = false; }),
            ),
            if (_doctorError)
              const Padding(
                padding: EdgeInsets.only(top: 6, left: 14),
                child: Text(
                  'Selecciona un médico',
                  style: TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            if (_selectedDoctor != null)
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 14),
                child: Text(
                  _selectedDoctor!.specialty,
                  style: const TextStyle(fontSize: 12, color: AppColors.teal),
                ),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _locationCtrl,
              decoration: const InputDecoration(
                labelText: 'Ubicación / Clínica',
                hintText: 'Ej: Hospital General, Consultorio 3',
              ),
            ),
            const SizedBox(height: 20),
            _sectionTitle('Notas de la cita'),
            TextFormField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Notas previas',
                hintText: 'Recordatorios, preguntas para el médico...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _resultCtrl,
              decoration: const InputDecoration(
                labelText: 'Resultado / Notas post-cita',
                hintText: 'Diagnóstico, indicaciones, seguimiento...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              value: _isCompleted,
              onChanged: (v) => setState(() => _isCompleted = v),
              title: const Text('Cita completada',
                  style: TextStyle(
                      fontWeight: FontWeight.w600, color: AppColors.navy)),
              subtitle: Text(
                _isCompleted
                    ? 'La cita ya se realizó'
                    : 'La cita está pendiente',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
              activeColor: AppColors.green,
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
                    : Text(_isEditing ? 'Guardar cambios' : 'Guardar cita'),
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

  Widget _dateTimeBox(
      {required IconData icon, required String label, required String value}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.muted),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style:
                      const TextStyle(fontSize: 10, color: AppColors.muted)),
              Text(
                value,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
