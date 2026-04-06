class Reading {
  final String id;
  final DateTime timestamp;
  final int glucoseValue;
  final String moment;
  final int? insulinDose;
  final String? insulinType;
  final String? note;
  final String recordedBy;
  final String patientName;

  Reading({
    required this.id,
    required this.timestamp,
    required this.glucoseValue,
    required this.moment,
    this.insulinDose,
    this.insulinType,
    this.note,
    this.recordedBy = 'Sin nombre',
    this.patientName = 'Sin paciente',
  });

  GlucoseStatus get status {
    if (glucoseValue < 70) return GlucoseStatus.low;
    if (glucoseValue <= 130) return GlucoseStatus.normal;
    if (glucoseValue <= 180) return GlucoseStatus.high;
    return GlucoseStatus.veryHigh;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'glucoseValue': glucoseValue,
        'moment': moment,
        'insulinDose': insulinDose,
        'insulinType': insulinType,
        'note': note,
        'recordedBy': recordedBy,
        'patientName': patientName,
      };

  factory Reading.fromJson(Map<String, dynamic> json) => Reading(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        glucoseValue: json['glucoseValue'] as int,
        moment: json['moment'] as String,
        insulinDose: json['insulinDose'] as int?,
        insulinType: json['insulinType'] as String?,
        note: json['note'] as String?,
        recordedBy: json['recordedBy'] as String? ?? 'Sin nombre',
        patientName: json['patientName'] as String? ?? 'Sin paciente',
      );

  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'recorded_by': recordedBy,
        'patient_name': patientName,
        'recorded_at': timestamp.toUtc().toIso8601String(),
        'glucose_value': glucoseValue,
        'moment': moment,
        'insulin_dose': insulinDose,
        'insulin_type': insulinType,
        'note': note,
      };

  factory Reading.fromSupabaseRow(Map<String, dynamic> row) => Reading(
        id: row['id'] as String,
        recordedBy: row['recorded_by'] as String? ?? 'Sin nombre',
        patientName: row['patient_name'] as String? ?? 'Sin paciente',
        timestamp: DateTime.parse(row['recorded_at'] as String).toLocal(),
        glucoseValue: row['glucose_value'] as int,
        moment: row['moment'] as String,
        insulinDose: row['insulin_dose'] as int?,
        insulinType: row['insulin_type'] as String?,
        note: row['note'] as String?,
      );
}

enum GlucoseStatus { low, normal, high, veryHigh }

extension GlucoseStatusExt on GlucoseStatus {
  String get label {
    switch (this) {
      case GlucoseStatus.low:
        return '⬇ Bajo';
      case GlucoseStatus.normal:
        return '✓ Normal';
      case GlucoseStatus.high:
        return '⬆ Alto';
      case GlucoseStatus.veryHigh:
        return '🔴 Muy alto';
    }
  }

  String get labelPlain {
    switch (this) {
      case GlucoseStatus.low:
        return 'Bajo';
      case GlucoseStatus.normal:
        return 'Normal';
      case GlucoseStatus.high:
        return 'Alto';
      case GlucoseStatus.veryHigh:
        return 'Muy alto';
    }
  }
}
