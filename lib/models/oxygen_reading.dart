import 'package:flutter/material.dart';
import '../theme.dart';

class OxygenReading {
  final String id;
  final DateTime timestamp;
  final int spo2Value; // % (70–100)
  final String? note;
  final String recordedBy;
  final String patientName;

  OxygenReading({
    required this.id,
    required this.timestamp,
    required this.spo2Value,
    this.note,
    this.recordedBy = 'Sin nombre',
    this.patientName = 'Sin paciente',
  });

  SpO2Status get status {
    if (spo2Value < 90) return SpO2Status.critical;
    if (spo2Value < 95) return SpO2Status.low;
    return SpO2Status.normal;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'spo2Value': spo2Value,
        'note': note,
        'recordedBy': recordedBy,
        'patientName': patientName,
      };

  factory OxygenReading.fromJson(Map<String, dynamic> json) => OxygenReading(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        spo2Value: json['spo2Value'] as int,
        note: json['note'] as String?,
        recordedBy: json['recordedBy'] as String? ?? 'Sin nombre',
        patientName: json['patientName'] as String? ?? 'Sin paciente',
      );

  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'recorded_at': timestamp.toUtc().toIso8601String(),
        'spo2_value': spo2Value,
        'note': note,
        'recorded_by': recordedBy,
        'patient_name': patientName,
      };

  factory OxygenReading.fromSupabaseRow(Map<String, dynamic> row) => OxygenReading(
        id: row['id'] as String,
        timestamp: DateTime.parse(row['recorded_at'] as String).toLocal(),
        spo2Value: row['spo2_value'] as int,
        note: row['note'] as String?,
        recordedBy: row['recorded_by'] as String? ?? 'Sin nombre',
        patientName: row['patient_name'] as String? ?? 'Sin paciente',
      );
}

enum SpO2Status { critical, low, normal }

extension SpO2StatusExt on SpO2Status {
  String get label {
    switch (this) {
      case SpO2Status.critical:
        return '🔴 Crítico';
      case SpO2Status.low:
        return '⬇ Bajo';
      case SpO2Status.normal:
        return '✓ Normal';
    }
  }

  String get labelPlain {
    switch (this) {
      case SpO2Status.critical:
        return 'Crítico';
      case SpO2Status.low:
        return 'Bajo';
      case SpO2Status.normal:
        return 'Normal';
    }
  }

  Color get color {
    switch (this) {
      case SpO2Status.critical:
        return AppColors.oxygenCritical;
      case SpO2Status.low:
        return AppColors.oxygenLow;
      case SpO2Status.normal:
        return AppColors.oxygenNormal;
    }
  }
}
