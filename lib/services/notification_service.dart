import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest_all.dart' as tz_data;

import '../models/appointment.dart';
import '../models/medication.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  // ── Canales Android ────────────────────────────────────────
  static const _channelMeds = AndroidNotificationChannel(
    'meds_channel',
    'Recordatorios de medicamentos',
    description: 'Alertas 15 min antes de cada toma',
    importance: Importance.high,
    playSound: true,
  );

  static const _channelAppts = AndroidNotificationChannel(
    'appts_channel',
    'Recordatorios de citas',
    description: 'Alerta 1 día antes de tu cita médica',
    importance: Importance.high,
    playSound: true,
  );

  // ── MethodChannel nativo ───────────────────────────────────
  static const _batteryChannel =
      MethodChannel('com.example.glucosa_app/battery');

  // ── Inicialización ─────────────────────────────────────────

  Future<void> initialize() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(
      const InitializationSettings(android: androidSettings),
      onDidReceiveNotificationResponse: _onResponse,
    );

    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.createNotificationChannel(_channelMeds);
    await androidPlugin?.createNotificationChannel(_channelAppts);

    _initialized = true;
  }

  void _onResponse(NotificationResponse r) =>
      debugPrint('[Notif] tap id=${r.id}');

  Future<void> requestPermissions() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await androidPlugin?.requestNotificationsPermission();
    await androidPlugin?.requestExactAlarmsPermission();
  }

  Future<bool> hasExactAlarmPermission() async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    return await androidPlugin?.canScheduleExactNotifications() ?? false;
  }

  // ── Optimización de batería ────────────────────────────────

  Future<bool> isIgnoringBatteryOptimizations() async {
    try {
      return await _batteryChannel.invokeMethod<bool>('isIgnoring') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _batteryChannel.invokeMethod('requestIgnore');
    } catch (_) {}
  }

  // ── ID helpers ─────────────────────────────────────────────

  /// ID para notificación de medicamento.
  /// allMeds: lista completa (ordenada por id para determinismo).
  /// timeIndex: 0-3 (slot de horario).
  int _medNotifId(String medId, int timeIndex, List<Medication> allMeds) {
    final sorted = [...allMeds]..sort((a, b) => a.id.compareTo(b.id));
    final idx = sorted.indexWhere((m) => m.id == medId);
    if (idx == -1) return -1;
    return idx * 4 + timeIndex + 1; // +1 para evitar ID=0 en Android
  }

  List<int> _allMedNotifIds(String medId, List<Medication> allMeds) =>
      List.generate(4, (i) => _medNotifId(medId, i, allMeds));

  /// ID para notificación de cita: FNV-1a hash → [100_000, 999_999].
  int _apptNotifId(String uuid) {
    int hash = 0x811c9dc5;
    for (final cu in uuid.codeUnits) {
      hash ^= cu;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return 100000 + (hash % 900000);
  }

  // ── Medicamentos ───────────────────────────────────────────

  /// Programa notificaciones diarias para un medicamento activo.
  Future<void> scheduleMedication(
      Medication med, List<Medication> allMeds) async {
    if (!med.isActive || med.scheduleTimes.isEmpty) return;

    for (var i = 0; i < med.scheduleTimes.length && i < 4; i++) {
      final parts = med.scheduleTimes[i].split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final scheduledTZ = _nextDailyOccurrence(hour, minute, -15);

      final id = _medNotifId(med.id, i, allMeds);
      if (id == -1) continue;

      try {
        await _batteryChannel.invokeMethod('scheduleAlarm', {
          'id': id,
          'triggerAtMillis': scheduledTZ.millisecondsSinceEpoch,
          'title': '💊 ${med.name} — ${med.dose} ${med.unit}',
          'body': 'En 15 minutos es tu hora de tomar ${med.name}',
          'channelId': 'meds_channel',
        });
      } catch (e) {
        debugPrint('[Notif] Error al programar ${med.name} slot $i: $e');
      }
    }
  }

  /// Calcula el próximo TZDateTime para hora:minuto con offset en minutos.
  /// Si el resultado ya pasó hoy, avanza al día siguiente.
  tz.TZDateTime _nextDailyOccurrence(int hour, int minute, int offsetMin) {
    final now = tz.TZDateTime.now(tz.local);
    var t = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute)
        .add(Duration(minutes: offsetMin));
    if (t.isBefore(now)) t = t.add(const Duration(days: 1));
    return t;
  }

  /// Cancela todas las notificaciones de un medicamento.
  /// allMedsBeforeDelete debe incluir aún el med (para calcular el índice).
  Future<void> cancelMedication(
      String medId, List<Medication> allMedsBeforeDelete) async {
    for (final id in _allMedNotifIds(medId, allMedsBeforeDelete)) {
      try {
        await _batteryChannel.invokeMethod('cancelAlarm', {'id': id});
      } catch (e) {
        debugPrint('[Notif] Error al cancelar notif $id: $e');
      }
    }
  }

  // ── Citas ──────────────────────────────────────────────────

  /// Programa notificación única 1 día antes de una cita.
  Future<void> scheduleAppointment(MedicalAppointment appt) async {
    if (appt.isCompleted) return;

    final notifTime = appt.dateTime.subtract(const Duration(days: 1));
    if (notifTime.isBefore(DateTime.now())) return; // ya pasó

    try {
      await _batteryChannel.invokeMethod('scheduleAlarm', {
        'id': _apptNotifId(appt.id),
        'triggerAtMillis': notifTime.millisecondsSinceEpoch,
        'title': '📅 Cita mañana',
        'body': 'Mañana tienes cita con ${appt.doctorName}',
        'channelId': 'appts_channel',
      });
    } catch (e) {
      debugPrint('[Notif] Error al programar cita ${appt.doctorName}: $e');
    }
  }

  /// Cancela la notificación de una cita.
  Future<void> cancelAppointment(String apptId) async {
    try {
      await _batteryChannel.invokeMethod('cancelAlarm', {'id': _apptNotifId(apptId)});
    } catch (e) {
      debugPrint('[Notif] Error al cancelar cita $apptId: $e');
    }
  }

  // ── Diagnóstico ────────────────────────────────────────────

  /// Muestra una notificación al instante (prueba permisos y canal).
  Future<void> showImmediateTest() async {
    if (!_initialized) return;
    try {
      await _plugin.show(
        99999,
        '✅ Prueba inmediata',
        'Si ves esto, las notificaciones básicas SÍ funcionan.',
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channelMeds.id,
            _channelMeds.name,
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (e) {
      debugPrint('[Notif] Error prueba inmediata: $e');
      rethrow;
    }
  }

  /// Programa una notificación de prueba en [seconds] segundos.
  Future<String> scheduleTest({int seconds = 30}) async {
    if (!_initialized) return 'Plugin no inicializado';
    final fireAt = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    try {
      await _batteryChannel.invokeMethod('scheduleAlarm', {
        'id': 99998,
        'triggerAtMillis': fireAt.millisecondsSinceEpoch,
        'title': '⏰ Prueba programada',
        'body':
            'Esta notificación se programó para ${fireAt.hour}:${fireAt.minute.toString().padLeft(2, '0')} (${fireAt.timeZoneName})',
        'channelId': 'meds_channel',
      });
      return 'Programada para las ${fireAt.hour}:${fireAt.minute.toString().padLeft(2, '0')}:${fireAt.second.toString().padLeft(2, '0')} (${fireAt.timeZoneName})';
    } catch (e) {
      debugPrint('[Notif] Error prueba programada: $e');
      return 'ERROR: $e';
    }
  }

  /// Retorna información de diagnóstico del sistema de notificaciones.
  Future<Map<String, String>> getDiagnosticInfo(
      List<Medication> medications) async {
    final info = <String, String>{};

    info['timezone'] = tz.local.name;
    info['hora_local_ahora'] =
        tz.TZDateTime.now(tz.local).toString().substring(0, 19);
    info['inicializado'] = _initialized ? 'Sí' : 'No';

    try {
      final count = await _batteryChannel.invokeMethod<int>('getPendingAlarmCount') ?? 0;
      info['notif_pendientes'] = '$count';
    } catch (e) {
      info['notif_pendientes'] = 'Error: $e';
    }

    try {
      final hasAlarm = await hasExactAlarmPermission();
      info['permiso_alarma_exacta'] = hasAlarm ? 'Concedido ✓' : 'DENEGADO ✗';
    } catch (_) {
      info['permiso_alarma_exacta'] = 'No se pudo verificar';
    }

    try {
      final ignoring = await isIgnoringBatteryOptimizations();
      info['bateria_optimizacion'] =
          ignoring ? 'Desactivada ✓ (correcto)' : 'ACTIVA ✗ (puede bloquear)';
    } catch (_) {
      info['bateria_optimizacion'] = 'No se pudo verificar';
    }

    // Mostrar hora calculada para cada medicamento activo
    final activeMeds = medications.where((m) => m.isActive && m.scheduleTimes.isNotEmpty);
    for (final med in activeMeds.take(3)) {
      for (var i = 0; i < med.scheduleTimes.length && i < 4; i++) {
        final parts = med.scheduleTimes[i].split(':');
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final scheduled = _nextDailyOccurrence(hour, minute, -15);
        final id = _medNotifId(med.id, i, medications);
        info['${med.name}[${med.scheduleTimes[i]}]'] =
            'Notif ID $id → ${scheduled.toString().substring(0, 19)} (${scheduled.timeZoneName})';
      }
    }

    return info;
  }

  // ── scheduleAll ────────────────────────────────────────────

  /// Cancela todo y reprograma desde cero.
  /// Llamar al iniciar la app y después de sync.
  Future<void> scheduleAll({
    required List<Medication> medications,
    required List<MedicalAppointment> appointments,
  }) async {
    if (!_initialized) return;

    // Cancelar todas las alarmas nativas
    try {
      await _batteryChannel.invokeMethod('cancelAllAlarms');
    } catch (e) {
      debugPrint('[Notif] Error cancelAllAlarms: $e');
    }

    // Medicamentos activos con horarios
    for (final med in medications) {
      if (med.isActive && med.scheduleTimes.isNotEmpty) {
        await scheduleMedication(med, medications);
      }
    }

    // Citas futuras no completadas con al menos 1 día de anticipación
    final now = DateTime.now();
    for (final appt in appointments) {
      if (!appt.isCompleted &&
          appt.dateTime.isAfter(now) &&
          appt.dateTime.subtract(const Duration(days: 1)).isAfter(now)) {
        await scheduleAppointment(appt);
      }
    }
  }
}
