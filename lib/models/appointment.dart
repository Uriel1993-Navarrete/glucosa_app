class MedicalAppointment {
  final String id;
  final DateTime dateTime;
  final String doctorName;
  final String specialty;
  final String? location;
  final String? notes;
  final String? result;
  final String patientName;
  final bool isCompleted;

  MedicalAppointment({
    required this.id,
    required this.dateTime,
    required this.doctorName,
    required this.specialty,
    this.location,
    this.notes,
    this.result,
    required this.patientName,
    this.isCompleted = false,
  });

  MedicalAppointment copyWith({
    String? id,
    DateTime? dateTime,
    String? doctorName,
    String? specialty,
    Object? location = _sentinel,
    Object? notes = _sentinel,
    Object? result = _sentinel,
    String? patientName,
    bool? isCompleted,
  }) {
    return MedicalAppointment(
      id: id ?? this.id,
      dateTime: dateTime ?? this.dateTime,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      location: location == _sentinel ? this.location : location as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      result: result == _sentinel ? this.result : result as String?,
      patientName: patientName ?? this.patientName,
      isCompleted: isCompleted ?? this.isCompleted,
    );
  }

  // ── SharedPreferences (JSON local) ─────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'dateTime': dateTime.toIso8601String(),
        'doctorName': doctorName,
        'specialty': specialty,
        'location': location,
        'notes': notes,
        'result': result,
        'patientName': patientName,
        'isCompleted': isCompleted,
      };

  factory MedicalAppointment.fromJson(Map<String, dynamic> json) =>
      MedicalAppointment(
        id: json['id'] as String,
        dateTime: DateTime.parse(json['dateTime'] as String),
        doctorName: json['doctorName'] as String,
        specialty: json['specialty'] as String,
        location: json['location'] as String?,
        notes: json['notes'] as String?,
        result: json['result'] as String?,
        patientName: json['patientName'] as String? ?? 'Sin paciente',
        isCompleted: json['isCompleted'] as bool? ?? false,
      );

  // ── Supabase ───────────────────────────────────────
  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'appointment_date': dateTime.toUtc().toIso8601String(),
        'doctor_name': doctorName,
        'specialty': specialty,
        'location': location,
        'notes': notes,
        'result': result,
        'patient_name': patientName,
        'is_completed': isCompleted,
      };

  factory MedicalAppointment.fromSupabaseRow(Map<String, dynamic> row) =>
      MedicalAppointment(
        id: row['id'] as String,
        dateTime: DateTime.parse(row['appointment_date'] as String).toLocal(),
        doctorName: row['doctor_name'] as String,
        specialty: row['specialty'] as String,
        location: row['location'] as String?,
        notes: row['notes'] as String?,
        result: row['result'] as String?,
        patientName: row['patient_name'] as String? ?? 'Sin paciente',
        isCompleted: row['is_completed'] as bool? ?? false,
      );
}

// Sentinel para distinguir null explícito de "no proporcionado" en copyWith
const _sentinel = Object();
