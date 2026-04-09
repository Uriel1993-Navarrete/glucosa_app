import 'package:flutter/material.dart';
import '../theme.dart';

enum MetricType { glucose, oxygen, bloodPressure, heartRate }

extension MetricTypeExt on MetricType {
  String get label {
    switch (this) {
      case MetricType.glucose:      return 'Glucosa';
      case MetricType.oxygen:       return 'O₂';
      case MetricType.bloodPressure: return 'Presión';
      case MetricType.heartRate:    return 'Pulso';
    }
  }

  String get emoji {
    switch (this) {
      case MetricType.glucose:      return '🩸';
      case MetricType.oxygen:       return '🫁';
      case MetricType.bloodPressure: return '💓';
      case MetricType.heartRate:    return '❤️';
    }
  }

  Color get color {
    switch (this) {
      case MetricType.glucose:      return AppColors.teal;
      case MetricType.oxygen:       return AppColors.oxygenNormal;
      case MetricType.bloodPressure: return AppColors.bpNormal;
      case MetricType.heartRate:    return AppColors.hrNormal;
    }
  }
}
