import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../models/oxygen_reading.dart';
import '../models/blood_pressure_reading.dart';
import '../models/heart_rate_reading.dart';
import '../models/metric_type.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  final List<Reading> readings;
  final List<OxygenReading> oxygenReadings;
  final List<BloodPressureReading> bpReadings;
  final List<HeartRateReading> hrReadings;
  final VoidCallback onChanged;

  const HistoryScreen({
    super.key,
    required this.readings,
    required this.oxygenReadings,
    required this.bpReadings,
    required this.hrReadings,
    required this.onChanged,
  });

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String _statusFilter = 'todos';
  MetricType _selectedMetric = MetricType.glucose;

  // ── Glucosa ──────────────────────────────────────────
  List<Reading> get _filtered {
    return widget.readings.where((r) {
      if (_fromDate != null) {
        final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        if (r.timestamp.isBefore(from)) return false;
      }
      if (_toDate != null) {
        final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        if (r.timestamp.isAfter(to)) return false;
      }
      switch (_statusFilter) {
        case 'bajo':    return r.glucoseValue < 70;
        case 'normal':  return r.glucoseValue >= 70 && r.glucoseValue <= 130;
        case 'alto':    return r.glucoseValue > 130 && r.glucoseValue <= 180;
        case 'muyAlto': return r.glucoseValue > 180;
        default: return true;
      }
    }).toList();
  }

  Map<String, List<Reading>> get _grouped {
    final result = <String, List<Reading>>{};
    for (final r in _filtered) {
      final key = DateFormat('yyyy-MM-dd').format(r.timestamp);
      result.putIfAbsent(key, () => []).add(r);
    }
    return Map.fromEntries(
        result.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  // ── Oxígeno ───────────────────────────────────────────
  List<OxygenReading> get _filteredOxygen {
    return widget.oxygenReadings.where((r) {
      if (_fromDate != null) {
        final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        if (r.timestamp.isBefore(from)) return false;
      }
      if (_toDate != null) {
        final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        if (r.timestamp.isAfter(to)) return false;
      }
      return true;
    }).toList();
  }

  Map<String, List<OxygenReading>> get _groupedOxygen {
    final result = <String, List<OxygenReading>>{};
    for (final r in _filteredOxygen) {
      final key = DateFormat('yyyy-MM-dd').format(r.timestamp);
      result.putIfAbsent(key, () => []).add(r);
    }
    return Map.fromEntries(
        result.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  // ── Presión arterial ──────────────────────────────────
  List<BloodPressureReading> get _filteredBP {
    return widget.bpReadings.where((r) {
      if (_fromDate != null) {
        final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        if (r.timestamp.isBefore(from)) return false;
      }
      if (_toDate != null) {
        final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        if (r.timestamp.isAfter(to)) return false;
      }
      switch (_statusFilter) {
        case 'normal':   return r.status == BPStatus.normal;
        case 'elevated': return r.status == BPStatus.elevated;
        case 'stage1':   return r.status == BPStatus.stage1;
        case 'stage2':   return r.status == BPStatus.stage2;
        case 'crisis':   return r.status == BPStatus.crisis;
        default: return true;
      }
    }).toList();
  }

  Map<String, List<BloodPressureReading>> get _groupedBP {
    final result = <String, List<BloodPressureReading>>{};
    for (final r in _filteredBP) {
      final key = DateFormat('yyyy-MM-dd').format(r.timestamp);
      result.putIfAbsent(key, () => []).add(r);
    }
    return Map.fromEntries(
        result.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  // ── Pulso / FC ────────────────────────────────────────
  List<HeartRateReading> get _filteredHR {
    return widget.hrReadings.where((r) {
      if (_fromDate != null) {
        final from = DateTime(_fromDate!.year, _fromDate!.month, _fromDate!.day);
        if (r.timestamp.isBefore(from)) return false;
      }
      if (_toDate != null) {
        final to = DateTime(_toDate!.year, _toDate!.month, _toDate!.day, 23, 59, 59);
        if (r.timestamp.isAfter(to)) return false;
      }
      switch (_statusFilter) {
        case 'bradycardia':  return r.status == HRStatus.bradycardia;
        case 'normal':       return r.status == HRStatus.normal;
        case 'tachycardia':  return r.status == HRStatus.tachycardia;
        default: return true;
      }
    }).toList();
  }

  Map<String, List<HeartRateReading>> get _groupedHR {
    final result = <String, List<HeartRateReading>>{};
    for (final r in _filteredHR) {
      final key = DateFormat('yyyy-MM-dd').format(r.timestamp);
      result.putIfAbsent(key, () => []).add(r);
    }
    return Map.fromEntries(
        result.entries.toList()..sort((a, b) => b.key.compareTo(a.key)));
  }

  // ── Helpers de fecha ─────────────────────────────────
  Future<void> _pickFromDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _fromDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _fromDate = d);
  }

  Future<void> _pickToDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _toDate ?? DateTime.now(),
      firstDate: _fromDate ?? DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (d != null) setState(() => _toDate = d);
  }

  // ── Borrado ───────────────────────────────────────────
  Future<void> _deleteGlucose(Reading r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: Text('Glucosa: ${r.glucoseValue} mg/dL — ${r.moment}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final storage = await StorageService.getInstance();
      await storage.deleteReading(r.id, widget.readings);
      widget.onChanged();
    }
  }

  Future<void> _deleteOxygen(OxygenReading r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: Text('SpO2: ${r.spo2Value} % — ${DateFormat('dd/MM/yyyy HH:mm').format(r.timestamp)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final storage = await StorageService.getInstance();
      await storage.deleteOxygenReading(r.id, widget.oxygenReadings);
      widget.onChanged();
    }
  }

  Future<void> _deleteBP(BloodPressureReading r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: Text(
            'Presión: ${r.systolic}/${r.diastolic} mmHg — ${DateFormat('dd/MM/yyyy HH:mm').format(r.timestamp)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final storage = await StorageService.getInstance();
      await storage.deleteBPReading(r.id, widget.bpReadings);
      widget.onChanged();
    }
  }

  Future<void> _deleteHR(HeartRateReading r) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('¿Eliminar registro?'),
        content: Text(
            'Pulso: ${r.bpmValue} bpm — ${DateFormat('dd/MM/yyyy HH:mm').format(r.timestamp)}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar', style: TextStyle(color: AppColors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      final storage = await StorageService.getInstance();
      await storage.deleteHRReading(r.id, widget.hrReadings);
      widget.onChanged();
    }
  }

  // ── Colores glucosa ───────────────────────────────────
  Color _glucoseColor(GlucoseStatus s) {
    switch (s) {
      case GlucoseStatus.low:     return AppColors.red;
      case GlucoseStatus.normal:  return AppColors.green;
      case GlucoseStatus.high:    return AppColors.yellow;
      case GlucoseStatus.veryHigh: return AppColors.red;
    }
  }

  Color _glucoseBg(GlucoseStatus s) {
    switch (s) {
      case GlucoseStatus.low:     return AppColors.redBg;
      case GlucoseStatus.normal:  return AppColors.greenBg;
      case GlucoseStatus.high:    return AppColors.yellowBg;
      case GlucoseStatus.veryHigh: return AppColors.redBg;
    }
  }

  // ── Label día ─────────────────────────────────────────
  String _dayLabel(String key) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final yesterday = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    if (key == today) return 'Hoy';
    if (key == yesterday) return 'Ayer';
    final d = DateTime.parse(key);
    return DateFormat('EEEE d MMM', 'es').format(d);
  }

  // ── build ─────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final hasDateFilter = _fromDate != null || _toDate != null;
    final hasStatusFilter = _statusFilter != 'todos';
    final hasFilters = hasDateFilter || hasStatusFilter;

    return Column(
      children: [
        // Selector de 4 métricas
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: MetricType.values.map((metric) {
              final isSelected = _selectedMetric == metric;
              final isFirst = metric == MetricType.values.first;
              final isLast = metric == MetricType.values.last;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() {
                    _selectedMetric = metric;
                    _statusFilter = 'todos';
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: isSelected ? metric.color : AppColors.bg,
                      borderRadius: BorderRadius.horizontal(
                        left: isFirst ? const Radius.circular(8) : Radius.zero,
                        right: isLast ? const Radius.circular(8) : Radius.zero,
                      ),
                      border: Border.all(
                        color: isSelected ? metric.color : AppColors.border,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${metric.emoji}  ${metric.label}',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 11,
                          color: isSelected ? Colors.white : AppColors.muted,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        // Filtros
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Filtros de fecha
              Row(
                children: [
                  Expanded(
                    child: _dateField(
                      label: 'Desde',
                      date: _fromDate,
                      onTap: _pickFromDate,
                      onClear: _fromDate != null ? () => setState(() => _fromDate = null) : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _dateField(
                      label: 'Hasta',
                      date: _toDate,
                      onTap: _pickToDate,
                      onClear: _toDate != null ? () => setState(() => _toDate = null) : null,
                    ),
                  ),
                ],
              ),

              // Filtro de estado según métrica activa
              if (_selectedMetric == MetricType.glucose) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Estado de glucosa',
                          prefixIcon: Icon(Icons.filter_list_outlined, size: 18, color: AppColors.muted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos los registros')),
                          DropdownMenuItem(value: 'bajo', child: Text('⬇ Bajo  (<70 mg/dL)')),
                          DropdownMenuItem(value: 'normal', child: Text('✓ Normal  (70-130 mg/dL)')),
                          DropdownMenuItem(value: 'alto', child: Text('⬆ Alto  (130-180 mg/dL)')),
                          DropdownMenuItem(value: 'muyAlto', child: Text('🔴 Muy alto  (>180 mg/dL)')),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v ?? 'todos'),
                      ),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                          _statusFilter = 'todos';
                        }),
                        child: const Text('Limpiar', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ] else if (_selectedMetric == MetricType.bloodPressure) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Estado de presión',
                          prefixIcon: Icon(Icons.filter_list_outlined, size: 18, color: AppColors.muted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos los registros')),
                          DropdownMenuItem(value: 'normal', child: Text('✓ Normal')),
                          DropdownMenuItem(value: 'elevated', child: Text('⬆ Elevada')),
                          DropdownMenuItem(value: 'stage1', child: Text('⚠ Grado 1')),
                          DropdownMenuItem(value: 'stage2', child: Text('🔴 Grado 2')),
                          DropdownMenuItem(value: 'crisis', child: Text('🚨 Crisis')),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v ?? 'todos'),
                      ),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                          _statusFilter = 'todos';
                        }),
                        child: const Text('Limpiar', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ] else if (_selectedMetric == MetricType.heartRate) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _statusFilter,
                        decoration: const InputDecoration(
                          labelText: 'Estado de pulso',
                          prefixIcon: Icon(Icons.filter_list_outlined, size: 18, color: AppColors.muted),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'todos', child: Text('Todos los registros')),
                          DropdownMenuItem(value: 'bradycardia', child: Text('⬇ Bradicardia')),
                          DropdownMenuItem(value: 'normal', child: Text('✓ Normal')),
                          DropdownMenuItem(value: 'tachycardia', child: Text('⬆ Taquicardia')),
                        ],
                        onChanged: (v) => setState(() => _statusFilter = v ?? 'todos'),
                      ),
                    ),
                    if (hasFilters) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => setState(() {
                          _fromDate = null;
                          _toDate = null;
                          _statusFilter = 'todos';
                        }),
                        child: const Text('Limpiar', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                      ),
                    ],
                  ],
                ),
              ] else if (hasDateFilter) ...[
                // Oxígeno: solo muestra limpiar si hay filtros de fecha
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() {
                      _fromDate = null;
                      _toDate = null;
                    }),
                    child: const Text('Limpiar', style: TextStyle(color: AppColors.teal, fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),

        // Lista
        Expanded(
          child: switch (_selectedMetric) {
            MetricType.glucose      => _buildGlucoseList(),
            MetricType.oxygen       => _buildOxygenList(),
            MetricType.bloodPressure => _buildBPList(),
            MetricType.heartRate    => _buildHRList(),
          },
        ),
      ],
    );
  }

  // ── Listas ────────────────────────────────────────────
  Widget _buildGlucoseList() {
    if (_filtered.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('📋', style: TextStyle(fontSize: 40)),
            SizedBox(height: 8),
            Text('Sin registros', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _grouped.length,
      itemBuilder: (ctx, i) {
        final entry = _grouped.entries.elementAt(i);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dayHeader(entry.key),
            ...entry.value.map((r) => _readingCard(r)),
          ],
        );
      },
    );
  }

  Widget _buildOxygenList() {
    if (_filteredOxygen.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🫁', style: TextStyle(fontSize: 40)),
            SizedBox(height: 8),
            Text('Sin registros de oxigenación', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _groupedOxygen.length,
      itemBuilder: (ctx, i) {
        final entry = _groupedOxygen.entries.elementAt(i);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dayHeader(entry.key),
            ...entry.value.map((r) => _oxygenCard(r)),
          ],
        );
      },
    );
  }

  Widget _buildBPList() {
    if (_filteredBP.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('💓', style: TextStyle(fontSize: 40)),
            SizedBox(height: 8),
            Text('Sin registros de presión arterial', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _groupedBP.length,
      itemBuilder: (ctx, i) {
        final entry = _groupedBP.entries.elementAt(i);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dayHeader(entry.key),
            ...entry.value.map((r) => _buildBPCard(r)),
          ],
        );
      },
    );
  }

  Widget _buildHRList() {
    if (_filteredHR.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('❤️', style: TextStyle(fontSize: 40)),
            SizedBox(height: 8),
            Text('Sin registros de pulso', style: TextStyle(color: AppColors.muted)),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: _groupedHR.length,
      itemBuilder: (ctx, i) {
        final entry = _groupedHR.entries.elementAt(i);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _dayHeader(entry.key),
            ...entry.value.map((r) => _buildHRCard(r)),
          ],
        );
      },
    );
  }

  // ── Widgets reutilizables ─────────────────────────────
  Widget _dayHeader(String key) {
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 8),
      child: Text(
        _dayLabel(key).toUpperCase(),
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: AppColors.muted,
          letterSpacing: .5,
        ),
      ),
    );
  }

  Widget _dateField({
    required String label,
    required DateTime? date,
    required VoidCallback onTap,
    VoidCallback? onClear,
  }) {
    final active = date != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: active ? AppColors.tealLight : AppColors.bg,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: active ? AppColors.teal : AppColors.border),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month_outlined,
                size: 16, color: active ? AppColors.teal : AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10, color: active ? AppColors.teal : AppColors.muted)),
                  Text(
                    date != null ? DateFormat('d MMM yyyy', 'es').format(date) : 'Seleccionar',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: active ? AppColors.teal : AppColors.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: const Icon(Icons.close, size: 14, color: AppColors.teal),
              ),
          ],
        ),
      ),
    );
  }

  // ── Cards ─────────────────────────────────────────────
  Widget _readingCard(Reading r) {
    final timeStr = DateFormat('HH:mm').format(r.timestamp);
    final dateStr = DateFormat('d MMM', 'es').format(r.timestamp);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: _glucoseBg(r.status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${r.glucoseValue}',
                  style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _glucoseColor(r.status))),
              Text('mg/dL',
                  style: TextStyle(
                      fontSize: 9,
                      color: _glucoseColor(r.status),
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        title: Text('${kMomentIcons[r.moment] ?? '⏱'} ${r.moment}',
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateStr · $timeStr  ${r.status.label}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (r.insulinDose != null)
              Text('💉 ${r.insulinDose}U ${r.insulinType ?? ''}',
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.w600)),
            if (r.recordedBy != 'Sin nombre')
              Text('👤 ${r.recordedBy}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            if (r.note != null)
              Text('📝 ${r.note}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.muted, size: 20),
          onPressed: () => _deleteGlucose(r),
        ),
      ),
    );
  }

  Widget _oxygenCard(OxygenReading r) {
    final timeStr = DateFormat('HH:mm').format(r.timestamp);
    final dateStr = DateFormat('d MMM', 'es').format(r.timestamp);
    final statusColor = r.status.color;
    final statusBg = switch (r.status) {
      SpO2Status.normal   => AppColors.oxygenNormalBg,
      SpO2Status.low      => AppColors.oxygenLowBg,
      SpO2Status.critical => AppColors.oxygenCriticalBg,
    };
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${r.spo2Value}',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: statusColor)),
              Text('%',
                  style:
                      TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        title: Text(r.status.label,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: statusColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateStr · $timeStr',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (r.recordedBy != 'Sin nombre')
              Text('👤 ${r.recordedBy}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            if (r.note != null)
              Text('📝 ${r.note}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.muted, size: 20),
          onPressed: () => _deleteOxygen(r),
        ),
      ),
    );
  }

  Widget _buildBPCard(BloodPressureReading r) {
    final timeStr = DateFormat('HH:mm').format(r.timestamp);
    final dateStr = DateFormat('d MMM', 'es').format(r.timestamp);
    final statusColor = r.status.color;
    final statusBg = r.status.bgColor;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${r.systolic}',
                  style: TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w700, color: statusColor)),
              Text('/${r.diastolic}',
                  style: TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w700, color: statusColor)),
            ],
          ),
        ),
        title: Text(r.status.label,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: statusColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateStr · $timeStr',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (r.patientName != 'Sin nombre' && r.patientName != 'Sin paciente')
              Text('👤 ${r.patientName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            if (r.note != null)
              Text('📝 ${r.note}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.muted, size: 20),
          onPressed: () => _deleteBP(r),
        ),
      ),
    );
  }

  Widget _buildHRCard(HeartRateReading r) {
    final timeStr = DateFormat('HH:mm').format(r.timestamp);
    final dateStr = DateFormat('d MMM', 'es').format(r.timestamp);
    final statusColor = r.status.color;
    final statusBg = r.status.bgColor;
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        leading: Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(12)),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${r.bpmValue}',
                  style: TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700, color: statusColor)),
              Text('bpm',
                  style:
                      TextStyle(fontSize: 9, color: statusColor, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        title: Text(r.status.label,
            style: TextStyle(
                fontWeight: FontWeight.w600, fontSize: 14, color: statusColor)),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateStr · $timeStr',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (r.patientName != 'Sin nombre' && r.patientName != 'Sin paciente')
              Text('👤 ${r.patientName}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            if (r.note != null)
              Text('📝 ${r.note}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.muted, size: 20),
          onPressed: () => _deleteHR(r),
        ),
      ),
    );
  }
}

const kMomentIcons = {
  'Ayuno': '🌅',
  'Antes comida': '🍽️',
  'Después comida': '⏱️',
  'Noche': '🌙',
};
