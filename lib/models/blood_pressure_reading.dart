import 'package:flutter/material.dart';
import '../theme.dart';

class BloodPressureReading {
  final String id;
  final DateTime timestamp;
  final int systolic;   // mmHg (60–250)
  final int diastolic;  // mmHg (40–150)
  final String? note;
  final String recordedBy;
  final String patientName;

  BloodPressureReading({
    required this.id,
    required this.timestamp,
    required this.systolic,
    required this.diastolic,
    this.note,
    this.recordedBy = 'Sin nombre',
    this.patientName = 'Sin paciente',
  });

  BPStatus get status {
    if (systolic > 180 || diastolic > 120) return BPStatus.crisis;
    if (systolic >= 140 || diastolic >= 90) return BPStatus.stage2;
    if (systolic >= 130 || diastolic >= 80) return BPStatus.stage1;
    if (systolic >= 120 && diastolic < 80)  return BPStatus.elevated;
    return BPStatus.normal;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'systolic': systolic,
        'diastolic': diastolic,
        'note': note,
        'recordedBy': recordedBy,
        'patientName': patientName,
      };

  factory BloodPressureReading.fromJson(Map<String, dynamic> json) =>
      BloodPressureReading(
        id: json['id'] as String,
        timestamp: DateTime.parse(json['timestamp'] as String),
        systolic: json['systolic'] as int,
        diastolic: json['diastolic'] as int,
        note: json['note'] as String?,
        recordedBy: json['recordedBy'] as String? ?? 'Sin nombre',
        patientName: json['patientName'] as String? ?? 'Sin paciente',
      );

  Map<String, dynamic> toSupabaseRow() => {
        'id': id,
        'recorded_at': timestamp.toUtc().toIso8601String(),
        'systolic': systolic,
        'diastolic': diastolic,
        'note': note,
        'recorded_by': recordedBy,
        'patient_name': patientName,
      };

  factory BloodPressureReading.fromSupabaseRow(Map<String, dynamic> row) =>
      BloodPressureReading(
        id: row['id'] as String,
        timestamp: DateTime.parse(row['recorded_at'] as String).toLocal(),
        systolic: row['systolic'] as int,
        diastolic: row['diastolic'] as int,
        note: row['note'] as String?,
        recordedBy: row['recorded_by'] as String? ?? 'Sin nombre',
        patientName: row['patient_name'] as String? ?? 'Sin paciente',
      );
}

enum BPStatus { normal, elevated, stage1, stage2, crisis }

extension BPStatusExt on BPStatus {
  String get label {
    switch (this) {
      case BPStatus.normal:   return '✓ Normal';
      case BPStatus.elevated: return '⬆ Elevada';
      case BPStatus.stage1:   return '⚠ Grado 1';
      case BPStatus.stage2:   return '🔴 Grado 2';
      case BPStatus.crisis:   return '🚨 Crisis';
    }
  }

  String get labelPlain {
    switch (this) {
      case BPStatus.normal:   return 'Normal';
      case BPStatus.elevated: return 'Elevada';
      case BPStatus.stage1:   return 'Grado 1';
      case BPStatus.stage2:   return 'Grado 2';
      case BPStatus.crisis:   return 'Crisis';
    }
  }

  Color get color {
    switch (this) {
      case BPStatus.normal:   return AppColors.bpNormal;
      case BPStatus.elevated: return AppColors.bpElevated;
      case BPStatus.stage1:   return AppColors.bpStage1;
      case BPStatus.stage2:   return AppColors.bpStage2;
      case BPStatus.crisis:   return AppColors.bpCrisis;
    }
  }

  Color get bgColor {
    switch (this) {
      case BPStatus.normal:   return AppColors.bpNormalBg;
      case BPStatus.elevated: return AppColors.bpElevatedBg;
      case BPStatus.stage1:   return AppColors.bpStage1Bg;
      case BPStatus.stage2:   return AppColors.bpStage2Bg;
      case BPStatus.crisis:   return AppColors.bpCrisisBg;
    }
  }
}
