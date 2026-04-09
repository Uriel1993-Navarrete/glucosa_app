import 'package:flutter/material.dart';
import '../theme.dart';

class HeartRateReading {
  final String id;
  final DateTime timestamp;
  final int bpmValue;  // bpm (30–250)
  final String? note;
  final String recordedBy;
  final String patientName;

  HeartRateReading({
    required this.id,
    required this.timestamp,
    required this.bpmValue,
    this.note,
    this.recordedBy = 'Sin nombre',
    this.patientName = 'Sin paciente',
  });

  HRStatus get status {
    if (bpmValue < 60)  return HRStatus.bradycardia;
    if (bpmValue <= 100) return HRStatus.normal;
    return HRStatus.tachycardia;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'bpmValue': bpmValue,
        'note': note,
        'recordedBy': recordedBy,
        'patientName': patientName,
      };

  factory HeartRateReading.fromJson(Map<String, dynamic> json) =>
      HeartRateReading(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        bpmValue: json['bpmValue'] as int,
        note: json['note'] as String?,
        recordedBy: json['recordedBy'] as String? ?? 'Sin nombre',
        patientName: json['patientName'] as String? ?? 'Sin paciente',
      );

  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'recorded_at': timestamp.toUtc().toIso8601String(),
        'bpm_value': bpmValue,
        'note': note,
        'recorded_by': recordedBy,
        'patient_name': patientName,
      };

  factory HeartRateReading.fromSupabaseRow(Map<String, dynamic> row) =>
      HeartRateReading(
        id: row['id'] as String,
        timestamp: DateTime.parse(row['recorded_at'] as String).toLocal(),
        bpmValue: row['bpm_value'] as int,
        note: row['note'] as String?,
        recordedBy: row['recorded_by'] as String? ?? 'Sin nombre',
        patientName: row['patient_name'] as String? ?? 'Sin paciente',
      );
}

enum HRStatus { bradycardia, normal, tachycardia }

extension HRStatusExt on HRStatus {
  String get label {
    switch (this) {
      case HRStatus.bradycardia:  return '⬇ Bradicardia';
      case HRStatus.normal:       return '✓ Normal';
      case HRStatus.tachycardia:  return '⬆ Taquicardia';
    }
  }

  String get labelPlain {
    switch (this) {
      case HRStatus.bradycardia:  return 'Bradicardia';
      case HRStatus.normal:       return 'Normal';
      case HRStatus.tachycardia:  return 'Taquicardia';
    }
  }

  Color get color {
    switch (this) {
      case HRStatus.bradycardia:  return AppColors.hrAbnormal;
      case HRStatus.normal:       return AppColors.hrNormal;
      case HRStatus.tachycardia:  return AppColors.hrTachy;
    }
  }

  Color get bgColor {
    switch (this) {
      case HRStatus.bradycardia:  return AppColors.hrAbnormalBg;
      case HRStatus.normal:       return AppColors.hrNormalBg;
      case HRStatus.tachycardia:  return AppColors.hrTachyBg;
    }
  }
}
