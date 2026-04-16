import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../models/appointment.dart';
import '../services/notification_service.dart';
import '../services/storage_service.dart';
import '../services/supabase_service.dart';
import '../theme.dart';
import 'appointment_form_screen.dart';

class AppointmentsScreen extends StatefulWidget {
  final String currentPatient;
  final String currentUser;

  const AppointmentsScreen({
    super.key,
    required this.currentPatient,
    required this.currentUser,
  });

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late StorageService _storage;
  List<MedicalAppointment> _appointments = [];
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    _storage = await StorageService.getInstance();
    setState(() {
      _appointments = _storage
          .loadAppointments()
          .where((a) => a.patientName == widget.currentPatient)
          .toList();
      _loading = false;
    });
  }

  List<MedicalAppointment> _eventsForDay(DateTime day) {
    return _appointments.where((a) {
      final d = a.dateTime;
      return d.year == day.year && d.month == day.month && d.day == day.day;
    }).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  List<MedicalAppointment> get _selectedDayEvents =>
      _eventsForDay(_selectedDay);

  Future<void> _delete(MedicalAppointment appt) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar cita?'),
        content: Text(
            '${appt.doctorName} — ${DateFormat('d MMM yyyy HH:mm', 'es').format(appt.dateTime)}'),
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
    // Cancelar notificación antes de eliminar
    await NotificationService.instance.cancelAppointment(appt.id);
    await _storage.deleteAppointment(appt.id, _appointments);
    try {
      await SupabaseService().deleteAppointmentRemote(appt.id);
    } catch (_) {}
    setState(() {
      _appointments = _storage
          .loadAppointments()
          .where((a) => a.patientName == widget.currentPatient)
          .toList();
    });
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Cita eliminada'),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          backgroundColor: AppColors.navy,
        ),
      );
    }
  }

  Future<void> _openForm({MedicalAppointment? appt}) async {
    final result = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => AppointmentFormScreen(
          currentPatient: widget.currentPatient,
          currentUser: widget.currentUser,
          initialDate: _selectedDay,
          existing: appt,
        ),
      ),
    );
    if (result == true) {
      setState(() {
        _appointments = _storage
            .loadAppointments()
            .where((a) => a.patientName == widget.currentPatient)
            .toList();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Citas Médicas')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildCalendar(),
                const Divider(height: 1),
                Expanded(child: _buildDayList()),
              ],
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        backgroundColor: AppColors.navy,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nueva cita'),
      ),
    );
  }

  Widget _buildCalendar() {
    return TableCalendar<MedicalAppointment>(
      firstDay: DateTime(2024),
      lastDay: DateTime(2030),
      focusedDay: _focusedDay,
      selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
      eventLoader: _eventsForDay,
      calendarFormat: CalendarFormat.month,
      startingDayOfWeek: StartingDayOfWeek.monday,
      locale: 'es_ES',
      onDaySelected: (selected, focused) {
        setState(() {
          _selectedDay = selected;
          _focusedDay = focused;
        });
      },
      onPageChanged: (focused) => _focusedDay = focused,
      calendarStyle: CalendarStyle(
        selectedDecoration: const BoxDecoration(
          color: AppColors.navy,
          shape: BoxShape.circle,
        ),
        todayDecoration: BoxDecoration(
          color: AppColors.teal.withValues(alpha: .2),
          shape: BoxShape.circle,
        ),
        todayTextStyle: const TextStyle(
          color: AppColors.teal,
          fontWeight: FontWeight.w700,
        ),
        markerDecoration: const BoxDecoration(
          color: AppColors.amber,
          shape: BoxShape.circle,
        ),
        markerSize: 5,
        markersMaxCount: 3,
        weekendTextStyle:
            const TextStyle(color: AppColors.muted),
        outsideTextStyle:
            const TextStyle(color: AppColors.border),
      ),
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        titleTextStyle: const TextStyle(
          fontWeight: FontWeight.w700,
          fontSize: 15,
          color: AppColors.navy,
        ),
        leftChevronIcon:
            const Icon(Icons.chevron_left, color: AppColors.navy),
        rightChevronIcon:
            const Icon(Icons.chevron_right, color: AppColors.navy),
        headerPadding:
            const EdgeInsets.symmetric(vertical: 8),
      ),
      daysOfWeekStyle: const DaysOfWeekStyle(
        weekdayStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
        weekendStyle: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: AppColors.muted,
        ),
      ),
    );
  }

  Widget _buildDayList() {
    final events = _selectedDayEvents;
    final dayLabel = DateFormat('EEEE d \'de\' MMMM', 'es').format(_selectedDay);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            dayLabel[0].toUpperCase() + dayLabel.substring(1),
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.muted,
              letterSpacing: .4,
            ),
          ),
        ),
        if (events.isEmpty)
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('📅', style: TextStyle(fontSize: 36)),
                  const SizedBox(height: 10),
                  const Text(
                    'Sin citas para este día',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.navy),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Toca + para agendar una',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ),
            ),
          )
        else
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
              itemCount: events.length,
              itemBuilder: (_, i) => _appointmentCard(events[i]),
            ),
          ),
      ],
    );
  }

  Widget _appointmentCard(MedicalAppointment a) {
    final timeStr = DateFormat('HH:mm').format(a.dateTime);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: a.isCompleted ? AppColors.greenBg : AppColors.amberLight,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: a.isCompleted ? AppColors.green : AppColors.amber,
                    ),
                  ),
                ),
              ],
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
                          a.doctorName,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.navy,
                          ),
                        ),
                      ),
                      if (a.isCompleted)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.greenBg,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.green),
                          ),
                          child: const Text(
                            '✓ Completada',
                            style: TextStyle(
                                fontSize: 10,
                                color: AppColors.green,
                                fontWeight: FontWeight.w700),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    a.specialty,
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.teal),
                  ),
                  if (a.location != null && a.location!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        const Icon(Icons.location_on_outlined,
                            size: 12, color: AppColors.muted),
                        const SizedBox(width: 4),
                        Text(a.location!,
                            style: const TextStyle(
                                fontSize: 11, color: AppColors.muted)),
                      ],
                    ),
                  ],
                  if (a.notes != null && a.notes!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📝 ${a.notes}',
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.muted),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (a.result != null && a.result!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '📋 ${a.result}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.green),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: AppColors.muted),
                  onPressed: () => _openForm(appt: a),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: AppColors.muted),
                  onPressed: () => _delete(a),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
