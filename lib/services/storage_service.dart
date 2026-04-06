import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/reading.dart';

class StorageService {
  static const _key = 'glucosa_readings_v1';
  static const _userKey = 'current_user_name';
  static const _membersKey = 'family_members_cache';
  static const _syncDoneKey = 'initial_sync_done';
  static const _lastSyncKey = 'last_sync_ts';
  static const _patientKey = 'current_patient_name';
  static const _patientsKey = 'patients_cache';
  static StorageService? _instance;
  late SharedPreferences _prefs;

  StorageService._();

  static Future<StorageService> getInstance() async {
    if (_instance == null) {
      _instance = StorageService._();
      _instance!._prefs = await SharedPreferences.getInstance();
    }
    return _instance!;
  }

  // ── CRUD ──────────────────────────────────────────────
  List<Reading> loadReadings() {
    final raw = _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final List<dynamic> list = jsonDecode(raw) as List;
      return list.map((e) => Reading.fromJson(e as Map<String, dynamic>)).toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> saveReadings(List<Reading> readings) async {
    final encoded = jsonEncode(readings.map((r) => r.toJson()).toList());
    await _prefs.setString(_key, encoded);
    await _writeBackupFile(readings);
  }

  Future<void> addReading(Reading reading, List<Reading> current) async {
    final updated = [reading, ...current];
    await saveReadings(updated);
  }

  Future<void> deleteReading(String id, List<Reading> current) async {
    final updated = current.where((r) => r.id != id).toList();
    await saveReadings(updated);
  }

  // ── BACKUP FILE (documentos del teléfono) ─────────────
  Future<File> _backupFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File('${dir.path}/glucosa-historial.json');
  }

  Future<void> _writeBackupFile(List<Reading> readings) async {
    try {
      final file = await _backupFile();
      final payload = jsonEncode({
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'readings': readings.map((r) => r.toJson()).toList(),
      });
      await file.writeAsString(payload);
    } catch (_) {}
  }

  Future<String> backupFilePath() async {
    final f = await _backupFile();
    return f.path;
  }

  // ── EXPORT ────────────────────────────────────────────
  Future<String> exportJsonPath(List<Reading> readings) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/glucosa-historial.json');
    final payload = jsonEncode({
      'version': 1,
      'savedAt': DateTime.now().toIso8601String(),
      'readings': readings.map((r) => r.toJson()).toList(),
    });
    await file.writeAsString(payload);
    return file.path;
  }

  Future<String> exportCsvPath(List<Reading> readings) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/glucosa-historial.csv');
    final buf = StringBuffer();
    buf.writeln('Fecha,Hora,Momento,Glucosa (mg/dL),Estado,Insulina (U),Tipo insulina,Notas,Paciente,Registrado por');
    for (final r in readings.reversed) {
      final date = '${r.timestamp.day}/${r.timestamp.month}/${r.timestamp.year}';
      final time =
          '${r.timestamp.hour.toString().padLeft(2, '0')}:${r.timestamp.minute.toString().padLeft(2, '0')}';
      final cells = [
        date, time, r.moment,
        r.glucoseValue.toString(), r.status.labelPlain,
        r.insulinDose?.toString() ?? '',
        r.insulinType ?? '',
        r.note ?? '',
        r.patientName,
        r.recordedBy,
      ].map((c) => '"$c"').join(',');
      buf.writeln(cells);
    }
    await file.writeAsString('\uFEFF${buf.toString()}');
    return file.path;
  }

  // ── IMPORT ────────────────────────────────────────────
  /// Loads readings from a JSON string and persists them.
  /// Returns the loaded readings or throws on error.
  Future<List<Reading>> importFromJsonString(String content) async {
    final Map<String, dynamic> data = jsonDecode(content) as Map<String, dynamic>;
    final List<dynamic> list = data['readings'] as List;
    final readings = list.map((e) => Reading.fromJson(e as Map<String, dynamic>)).toList();
    // Sort newest first
    readings.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await saveReadings(readings);
    return readings;
  }

  // ── USUARIO ACTUAL ────────────────────────────────────
  String? getCurrentUser() => _prefs.getString(_userKey);
  Future<void> setCurrentUser(String name) => _prefs.setString(_userKey, name);

  // ── CACHÉ DE FAMILIARES ───────────────────────────────
  List<String> getCachedMembers() {
    final raw = _prefs.getString(_membersKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> cacheMembersLocally(List<String> names) async {
    await _prefs.setString(_membersKey, jsonEncode(names));
  }

  // ── PACIENTE ACTUAL ───────────────────────────────────
  String? getCurrentPatient() => _prefs.getString(_patientKey);
  Future<void> setCurrentPatient(String name) => _prefs.setString(_patientKey, name);

  List<String> getCachedPatients() {
    final raw = _prefs.getString(_patientsKey);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> cachePatientsLocally(List<String> names) async {
    await _prefs.setString(_patientsKey, jsonEncode(names));
  }

  // ── SYNC ──────────────────────────────────────────────
  bool get initialSyncDone => _prefs.getBool(_syncDoneKey) ?? false;
  Future<void> markInitialSyncDone() => _prefs.setBool(_syncDoneKey, true);

  DateTime? get lastSyncAt {
    final s = _prefs.getString(_lastSyncKey);
    return s != null ? DateTime.tryParse(s) : null;
  }

  Future<void> markSyncNow() =>
      _prefs.setString(_lastSyncKey, DateTime.now().toIso8601String());

  // ── RESET ─────────────────────────────────────────────
  Future<void> clearAll() async {
    await _prefs.remove(_key);
    try {
      final f = await _backupFile();
      if (await f.exists()) await f.delete();
    } catch (_) {}
  }
}
