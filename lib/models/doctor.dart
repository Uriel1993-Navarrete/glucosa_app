class Doctor {
  final String id;
  final String name;
  final String specialty;
  final String? clinic;
  final String? phone;
  final String? notes;
  final String patientName;

  Doctor({
    required this.id,
    required this.name,
    required this.specialty,
    this.clinic,
    this.phone,
    this.notes,
    required this.patientName,
  });

  Doctor copyWith({
    String? id,
    String? name,
    String? specialty,
    Object? clinic = _sentinel,
    Object? phone = _sentinel,
    Object? notes = _sentinel,
    String? patientName,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      specialty: specialty ?? this.specialty,
      clinic: clinic == _sentinel ? this.clinic : clinic as String?,
      phone: phone == _sentinel ? this.phone : phone as String?,
      notes: notes == _sentinel ? this.notes : notes as String?,
      patientName: patientName ?? this.patientName,
    );
  }

  // ── SharedPreferences ──────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'specialty': specialty,
        'clinic': clinic,
        'phone': phone,
        'notes': notes,
        'patientName': patientName,
      };

  factory Doctor.fromJson(Map<String, dynamic> json) => Doctor(
        id: json['id'] as String,
        name: json['name'] as String,
        specialty: json['specialty'] as String,
        clinic: json['clinic'] as String?,
        phone: json['phone'] as String?,
        notes: json['notes'] as String?,
        patientName: json['patientName'] as String? ?? 'Sin paciente',
      );

  // ── Supabase ───────────────────────────────────────
  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'name': name,
        'specialty': specialty,
        'clinic': clinic,
        'phone': phone,
        'notes': notes,
        'patient_name': patientName,
      };

  factory Doctor.fromSupabaseRow(Map<String, dynamic> row) => Doctor(
        id: row['id'] as String,
        name: row['name'] as String,
        specialty: row['specialty'] as String,
        clinic: row['clinic'] as String?,
        phone: row['phone'] as String?,
        notes: row['notes'] as String?,
        patientName: row['patient_name'] as String? ?? 'Sin paciente',
      );

  /// Muestra "Dr. García · Cardiólogo"
  String get displayLabel => '$name · $specialty';
}

const _sentinel = Object();
