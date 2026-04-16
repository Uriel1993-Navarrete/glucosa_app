class Prescription {
  final String id;
  final String doctorId;
  final String? rxNumber;
  final DateTime date;
  final String? notes;
  final String patientName;

  Prescription({
    required this.id,
    required this.doctorId,
    this.rxNumber,
    required this.date,
    this.notes,
    required this.patientName,
  });

  Prescription copyWith({
    String? id,
    String? doctorId,
    Object? rxNumber = _sentinel,
    DateTime? date,
    Object? notes = _sentinel,
    String? patientName,
  }) {
    return Prescription(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      rxNumber: rxNumber == _sentinel ? this.rxNumber : rxNumber as String?,
      date: date ?? this.date,
      notes: notes == _sentinel ? this.notes : notes as String?,
      patientName: patientName ?? this.patientName,
    );
  }

  // ── SharedPreferences ──────────────────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'doctorId': doctorId,
        'rxNumber': rxNumber,
        'date': date.toIso8601String(),
        'notes': notes,
        'patientName': patientName,
      };

  factory Prescription.fromJson(Map<String, dynamic> json) => Prescription(
        id: json['id'] as String,
        doctorId: json['doctorId'] as String,
        rxNumber: json['rxNumber'] as String?,
        date: DateTime.parse(json['date'] as String),
        notes: json['notes'] as String?,
        patientName: json['patientName'] as String? ?? 'Sin paciente',
      );

  // ── Supabase ───────────────────────────────────────
  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'doctor_id': doctorId,
        'rx_number': rxNumber,
        'date': date.toIso8601String().split('T').first,
        'notes': notes,
        'patient_name': patientName,
      };

  factory Prescription.fromSupabaseRow(Map<String, dynamic> row) => Prescription(
        id: row['id'] as String,
        doctorId: row['doctor_id'] as String,
        rxNumber: row['rx_number'] as String?,
        date: DateTime.parse(row['date'] as String),
        notes: row['notes'] as String?,
        patientName: row['patient_name'] as String? ?? 'Sin paciente',
      );

  /// Etiqueta de display: "RX-001" o "Sin número"
  String get displayLabel => rxNumber != null ? 'Receta #$rxNumber' : 'Sin número';
}

const _sentinel = Object();
