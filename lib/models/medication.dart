class Medication {
  final String id;
  final String name;
  final String dose;
  final String unit;
  // Doctor — referencia al catálogo (nullable para backward compat con datos viejos)
  final String? doctorId;
  final String doctorName;   // denormalizado para display rápido
  final String specialty;    // denormalizado del Doctor
  // Receta — referencia a Prescription (nullable = sin receta)
  final String? prescriptionId;
  final List<String> scheduleTimes; // ["08:00", "14:00"] — hasta 4
  final String? instructions;
  final DateTime startDate;
  final DateTime? endDate;
  final bool isActive;
  final String patientName;
  final String? note;

  Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.unit,
    this.doctorId,
    required this.doctorName,
    required this.specialty,
    this.prescriptionId,
    required this.scheduleTimes,
    this.instructions,
    required this.startDate,
    this.endDate,
    this.isActive = true,
    required this.patientName,
    this.note,
  });

  Medication copyWith({
    String? id,
    String? name,
    String? dose,
    String? unit,
    Object? doctorId = _sentinel,
    String? doctorName,
    String? specialty,
    Object? prescriptionId = _sentinel,
    List<String>? scheduleTimes,
    Object? instructions = _sentinel,
    DateTime? startDate,
    Object? endDate = _sentinel,
    bool? isActive,
    String? patientName,
    Object? note = _sentinel,
  }) {
    return Medication(
      id: id ?? this.id,
      name: name ?? this.name,
      dose: dose ?? this.dose,
      unit: unit ?? this.unit,
      doctorId: doctorId == _sentinel ? this.doctorId : doctorId as String?,
      doctorName: doctorName ?? this.doctorName,
      specialty: specialty ?? this.specialty,
      prescriptionId:
          prescriptionId == _sentinel ? this.prescriptionId : prescriptionId as String?,
      scheduleTimes: scheduleTimes ?? this.scheduleTimes,
      instructions:
          instructions == _sentinel ? this.instructions : instructions as String?,
      startDate: startDate ?? this.startDate,
      endDate: endDate == _sentinel ? this.endDate : endDate as DateTime?,
      isActive: isActive ?? this.isActive,
      patientName: patientName ?? this.patientName,
      note: note == _sentinel ? this.note : note as String?,
    );
  }

  // ── SharedPreferences (JSON local) ─────────────────
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'dose': dose,
        'unit': unit,
        'doctorId': doctorId,
        'doctorName': doctorName,
        'specialty': specialty,
        'prescriptionId': prescriptionId,
        'scheduleTimes': scheduleTimes,
        'instructions': instructions,
        'startDate': startDate.toIso8601String(),
        'endDate': endDate?.toIso8601String(),
        'isActive': isActive,
        'patientName': patientName,
        'note': note,
      };

  factory Medication.fromJson(Map<String, dynamic> json) => Medication(
        id: json['id'] as String,
        name: json['name'] as String,
        dose: json['dose'] as String,
        unit: json['unit'] as String,
        // Backward compat: doctorId puede no existir en datos viejos
        doctorId: json['doctorId'] as String?,
        // Backward compat: doctorName era "prescribedBy" en datos viejos
        doctorName: json['doctorName'] as String? ??
            json['prescribedBy'] as String? ??
            'Sin médico',
        specialty: json['specialty'] as String? ?? '',
        // Backward compat: prescriptionId era "prescriptionNumber" en datos viejos
        prescriptionId: json['prescriptionId'] as String?,
        scheduleTimes: (json['scheduleTimes'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        instructions: json['instructions'] as String?,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] != null
            ? DateTime.parse(json['endDate'] as String)
            : null,
        isActive: json['isActive'] as bool? ?? true,
        patientName: json['patientName'] as String? ?? 'Sin paciente',
        note: json['note'] as String?,
      );

  // ── Supabase ───────────────────────────────────────
  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'name': name,
        'dose': dose,
        'unit': unit,
        // Nuevas columnas del catálogo
        'doctor_id': doctorId,
        'doctor_name': doctorName,
        'prescription_id': prescriptionId,
        // Columnas heredadas (mantener para backward compat en Supabase)
        'prescribed_by': doctorName,
        'specialty': specialty,
        'prescription_number': null, // ya no se usa
        'schedule_times': scheduleTimes,
        'instructions': instructions,
        'start_date': startDate.toIso8601String().split('T').first,
        'end_date': endDate?.toIso8601String().split('T').first,
        'is_active': isActive,
        'patient_name': patientName,
        'note': note,
      };

  factory Medication.fromSupabaseRow(Map<String, dynamic> row) => Medication(
        id: row['id'] as String,
        name: row['name'] as String,
        dose: row['dose'] as String,
        unit: row['unit'] as String,
        doctorId: row['doctor_id'] as String?,
        doctorName: row['doctor_name'] as String? ??
            row['prescribed_by'] as String? ??
            'Sin médico',
        specialty: row['specialty'] as String? ?? '',
        prescriptionId: row['prescription_id'] as String?,
        scheduleTimes: (row['schedule_times'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            [],
        instructions: row['instructions'] as String?,
        startDate: DateTime.parse(row['start_date'] as String),
        endDate: row['end_date'] != null
            ? DateTime.parse(row['end_date'] as String)
            : null,
        isActive: row['is_active'] as bool? ?? true,
        patientName: row['patient_name'] as String? ?? 'Sin paciente',
        note: row['note'] as String?,
      );
}

const _sentinel = Object();
