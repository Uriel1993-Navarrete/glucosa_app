import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/reading.dart';
import '../models/oxygen_reading.dart';
import '../models/blood_pressure_reading.dart';
import '../models/heart_rate_reading.dart';
import '../models/medication.dart';
import '../models/appointment.dart';
import '../models/doctor.dart';
import '../models/prescription.dart';

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

  // ── Lecturas de oxígeno ───────────────────────────────
  Future<List<OxygenReading>> fetchAllOxygenReadings() async {
    final data = await _client
        .from('oxygen_readings')
        .select()
        .order('recorded_at', ascending: false);
    return (data as List)
        .map((e) => OxygenReading.fromSupabaseRow(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushOxygenReading(OxygenReading r) async {
    await _client.from('oxygen_readings').upsert(r.toSupabaseRow());
  }

  /// Sube lecturas de oxígeno locales que no existen en Supabase.
  Future<void> syncOxygenToRemote(List<OxygenReading> local) async {
    if (local.isEmpty) return;
    final remoteData = await _client.from('oxygen_readings').select('id');
    final remoteIds = (remoteData as List).map((e) => e['id'] as String).toSet();
    final toUpload = local.where((r) => !remoteIds.contains(r.id)).toList();
    if (toUpload.isEmpty) return;
    await _client
        .from('oxygen_readings')
        .upsert(toUpload.map((r) => r.toSupabaseRow()).toList());
  }

  /// Descarga oxygen_readings de Supabase y hace unión con local por ID.
  Future<List<OxygenReading>> fetchAndMergeOxygen(List<OxygenReading> local) async {
    final remote = await fetchAllOxygenReadings();
    final merged = <String, OxygenReading>{};
    for (final r in local) {
      merged[r.id] = r;
    }
    for (final r in remote) {
      merged[r.id] = r;
    }
    final list = merged.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // ── Presión arterial ──────────────────────────────────
  Future<List<BloodPressureReading>> fetchAllBPReadings() async {
    final data = await _client
        .from('blood_pressure_readings')
        .select()
        .order('recorded_at', ascending: false);
    return (data as List)
        .map((e) => BloodPressureReading.fromSupabaseRow(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushBPReading(BloodPressureReading r) async {
    await _client.from('blood_pressure_readings').upsert(r.toSupabaseRow());
  }

  Future<void> syncBPToRemote(List<BloodPressureReading> local) async {
    if (local.isEmpty) return;
    final remoteData = await _client.from('blood_pressure_readings').select('id');
    final remoteIds = (remoteData as List).map((e) => e['id'] as String).toSet();
    final toUpload = local.where((r) => !remoteIds.contains(r.id)).toList();
    if (toUpload.isEmpty) return;
    await _client.from('blood_pressure_readings')
        .upsert(toUpload.map((r) => r.toSupabaseRow()).toList());
  }

  Future<List<BloodPressureReading>> fetchAndMergeBP(List<BloodPressureReading> local) async {
    final remote = await fetchAllBPReadings();
    final merged = <String, BloodPressureReading>{};
    for (final r in local) { merged[r.id] = r; }
    for (final r in remote) { merged[r.id] = r; }
    final list = merged.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // ── Pulso / FC ────────────────────────────────────────
  Future<List<HeartRateReading>> fetchAllHRReadings() async {
    final data = await _client
        .from('heart_rate_readings')
        .select()
        .order('recorded_at', ascending: false);
    return (data as List)
        .map((e) => HeartRateReading.fromSupabaseRow(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushHRReading(HeartRateReading r) async {
    await _client.from('heart_rate_readings').upsert(r.toSupabaseRow());
  }

  Future<void> syncHRToRemote(List<HeartRateReading> local) async {
    if (local.isEmpty) return;
    final remoteData = await _client.from('heart_rate_readings').select('id');
    final remoteIds = (remoteData as List).map((e) => e['id'] as String).toSet();
    final toUpload = local.where((r) => !remoteIds.contains(r.id)).toList();
    if (toUpload.isEmpty) return;
    await _client.from('heart_rate_readings')
        .upsert(toUpload.map((r) => r.toSupabaseRow()).toList());
  }

  Future<List<HeartRateReading>> fetchAndMergeHR(List<HeartRateReading> local) async {
    final remote = await fetchAllHRReadings();
    final merged = <String, HeartRateReading>{};
    for (final r in local) { merged[r.id] = r; }
    for (final r in remote) { merged[r.id] = r; }
    final list = merged.values.toList();
    list.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return list;
  }

  // ── Medicamentos ──────────────────────────────────────
  Future<List<Medication>> fetchAllMedications() async {
    final data = await _client
        .from('medications')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Medication.fromSupabaseRow(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushMedication(Medication m) async {
    await _client.from('medications').upsert(m.toSupabaseRow());
  }

  Future<void> syncMedicationsToRemote(List<Medication> local) async {
    if (local.isEmpty) return;
    final remoteData = await _client.from('medications').select('id');
    final remoteIds =
        (remoteData as List).map((e) => e['id'] as String).toSet();
    final toUpload = local.where((m) => !remoteIds.contains(m.id)).toList();
    if (toUpload.isEmpty) return;
    await _client
        .from('medications')
        .upsert(toUpload.map((m) => m.toSupabaseRow()).toList());
  }

  Future<List<Medication>> fetchAndMergeMedications(
      List<Medication> local) async {
    final remote = await fetchAllMedications();
    final merged = <String, Medication>{};
    for (final m in local) {
      merged[m.id] = m;
    }
    for (final m in remote) {
      merged[m.id] = m;
    }
    return merged.values.toList();
  }

  Future<void> deleteMedicationRemote(String id) async {
    await _client.from('medications').delete().eq('id', id);
  }

  // ── Citas médicas ─────────────────────────────────────
  Future<List<MedicalAppointment>> fetchAllAppointments() async {
    final data = await _client
        .from('appointments')
        .select()
        .order('appointment_date', ascending: true);
    return (data as List)
        .map((e) => MedicalAppointment.fromSupabaseRow(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushAppointment(MedicalAppointment a) async {
    await _client.from('appointments').upsert(a.toSupabaseRow());
  }

  Future<void> syncAppointmentsToRemote(
      List<MedicalAppointment> local) async {
    if (local.isEmpty) return;
    final remoteData = await _client.from('appointments').select('id');
    final remoteIds =
        (remoteData as List).map((e) => e['id'] as String).toSet();
    final toUpload = local.where((a) => !remoteIds.contains(a.id)).toList();
    if (toUpload.isEmpty) return;
    await _client
        .from('appointments')
        .upsert(toUpload.map((a) => a.toSupabaseRow()).toList());
  }

  Future<List<MedicalAppointment>> fetchAndMergeAppointments(
      List<MedicalAppointment> local) async {
    final remote = await fetchAllAppointments();
    final merged = <String, MedicalAppointment>{};
    for (final a in local) {
      merged[a.id] = a;
    }
    for (final a in remote) {
      merged[a.id] = a;
    }
    return merged.values.toList();
  }

  Future<void> deleteAppointmentRemote(String id) async {
    await _client.from('appointments').delete().eq('id', id);
  }

  // ── Doctores ──────────────────────────────────────────
  Future<List<Doctor>> fetchAllDoctors() async {
    final data = await _client
        .from('doctors')
        .select()
        .order('created_at', ascending: false);
    return (data as List)
        .map((e) => Doctor.fromSupabaseRow(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushDoctor(Doctor d) async {
    await _client.from('doctors').upsert(d.toSupabaseRow());
  }

  Future<void> syncDoctorsToRemote(List<Doctor> local) async {
    if (local.isEmpty) return;
    final remoteData = await _client.from('doctors').select('id');
    final remoteIds =
        (remoteData as List).map((e) => e['id'] as String).toSet();
    final toUpload = local.where((d) => !remoteIds.contains(d.id)).toList();
    if (toUpload.isEmpty) return;
    await _client
        .from('doctors')
        .upsert(toUpload.map((d) => d.toSupabaseRow()).toList());
  }

  Future<List<Doctor>> fetchAndMergeDoctors(List<Doctor> local) async {
    final remote = await fetchAllDoctors();
    final merged = <String, Doctor>{};
    for (final d in local) merged[d.id] = d;
    for (final d in remote) merged[d.id] = d;
    return merged.values.toList();
  }

  Future<void> deleteDoctorRemote(String id) async {
    await _client.from('doctors').delete().eq('id', id);
  }

  // ── Prescripciones ────────────────────────────────────
  Future<List<Prescription>> fetchAllPrescriptions() async {
    final data = await _client
        .from('prescriptions')
        .select()
        .order('date', ascending: false);
    return (data as List)
        .map((e) => Prescription.fromSupabaseRow(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> pushPrescription(Prescription rx) async {
    await _client.from('prescriptions').upsert(rx.toSupabaseRow());
  }

  Future<void> syncPrescriptionsToRemote(List<Prescription> local) async {
    if (local.isEmpty) return;
    final remoteData = await _client.from('prescriptions').select('id');
    final remoteIds =
        (remoteData as List).map((e) => e['id'] as String).toSet();
    final toUpload = local.where((r) => !remoteIds.contains(r.id)).toList();
    if (toUpload.isEmpty) return;
    await _client
        .from('prescriptions')
        .upsert(toUpload.map((r) => r.toSupabaseRow()).toList());
  }

  Future<List<Prescription>> fetchAndMergePrescriptions(
      List<Prescription> local) async {
    final remote = await fetchAllPrescriptions();
    final merged = <String, Prescription>{};
    for (final r in local) merged[r.id] = r;
    for (final r in remote) merged[r.id] = r;
    return merged.values.toList();
  }

  Future<void> deletePrescriptionRemote(String id) async {
    await _client.from('prescriptions').delete().eq('id', id);
  }
}
