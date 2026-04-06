import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading.dart';

class SupabaseService {
  static const _url = 'https://kfbfnfrwhmdoeqxyikdb.supabase.co';
  static const _anonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImtmYmZuZnJ3aG1kb2VxeHlpa2RiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzUzOTg3NjgsImV4cCI6MjA5MDk3NDc2OH0.BV9co4rZuGCNEO_m092SzMTi8qM2wkDk3z6XtS-wL7E';

  static Future<void> initialize() async {
    await Supabase.initialize(url: _url, anonKey: _anonKey);
  }

  static SupabaseClient get _client => Supabase.instance.client;

  // ── Familiares (usuarios/recorders) ──────────────────
  Future<List<String>> getFamilyMembers() async {
    final data = await _client
        .from('family_members')
        .select('name')
        .order('created_at');
    return (data as List).map((e) => e['name'] as String).toList();
  }

  Future<void> addFamilyMember(String name) async {
    await _client.from('family_members').insert({'name': name});
  }

  // ── Pacientes ─────────────────────────────────────────
  Future<List<String>> getPatients() async {
    final data = await _client
        .from('patients')
        .select('name')
        .order('created_at');
    return (data as List).map((e) => e['name'] as String).toList();
  }

  Future<void> addPatient(String name) async {
    await _client.from('patients').insert({'name': name});
  }

  // ── Lecturas ──────────────────────────────────────────
  Future<List<Reading>> fetchAllReadings() async {
    final data = await _client
        .from('readings')
        .select()
        .order('recorded_at', ascending: false);
    return (data as List)
        .map((e) => Reading.fromSupabaseRow(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushReading(Reading r) async {
    await _client.from('readings').upsert(r.toSupabaseRow());
  }

  Future<void> pushReadings(List<Reading> readings) async {
    if (readings.isEmpty) return;
    await _client
        .from('readings')
        .upsert(readings.map((r) => r.toSupabaseRow()).toList());
  }

  Future<void> deleteReading(String id) async {
    await _client.from('readings').delete().eq('id', id);
  }

  // ── Sync ──────────────────────────────────────────────
  /// Sube lecturas locales que no existen en Supabase (migración inicial).
  Future<void> syncToRemote(List<Reading> localReadings) async {
    if (localReadings.isEmpty) return;
    final remoteData = await _client.from('readings').select('id');
    final remoteIds = (remoteData as List).map((e) => e['id'] as String).toSet();
    final toUpload = localReadings.where((r) => !remoteIds.contains(r.id)).toList();
    if (toUpload.isEmpty) return;
    // Los registros sin autor se marcan como 'Importado'
    final rows = toUpload.map((r) {
      final row = r.toSupabaseRow();
      if (row['recorded_by'] == 'Sin nombre') row['recorded_by'] = 'Importado';
      return row;
    }).toList();
    await _client.from('readings').upsert(rows);
  }

  /// Descarga todo de Supabase y hace unión con local por ID.
  Future<List<Reading>> fetchAndMerge(List<Reading> localReadings) async {
    final remote = await fetchAllReadings();
    final merged = <String, Reading>{};
    for (final r in localReadings) {
      merged[r.id] = r;
    }
    for (final r in remote) {
      merged[r.id] = r;
    }
    final list = merged.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }
}
