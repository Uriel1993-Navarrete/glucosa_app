import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../services/storage_service.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  final List<Reading> readings;
  final VoidCallback onChanged;
  const HistoryScreen({super.key, required this.readings, required this.onChanged});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime? _fromDate;
  DateTime? _toDate;
  String _statusFilter = 'todos'; // 'todos' | 'bajo' | 'normal' | 'alto' | 'muyAlto'

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

  Future<void> _delete(Reading r) async {
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

  Color _statusColor(GlucoseStatus s) {
    switch (s) {
      case GlucoseStatus.low: return AppColors.red;
      case GlucoseStatus.normal: return AppColors.green;
      case GlucoseStatus.high: return AppColors.yellow;
      case GlucoseStatus.veryHigh: return AppColors.red;
    }
  }

  Color _statusBg(GlucoseStatus s) {
    switch (s) {
      case GlucoseStatus.low: return AppColors.redBg;
      case GlucoseStatus.normal: return AppColors.greenBg;
      case GlucoseStatus.high: return AppColors.yellowBg;
      case GlucoseStatus.veryHigh: return AppColors.redBg;
    }
  }

  String _dayLabel(String key) {
    final now = DateTime.now();
    final today = DateFormat('yyyy-MM-dd').format(now);
    final yesterday = DateFormat('yyyy-MM-dd').format(now.subtract(const Duration(days: 1)));
    if (key == today) return 'Hoy';
    if (key == yesterday) return 'Ayer';
    final d = DateTime.parse(key);
    return DateFormat('EEEE d MMM', 'es').format(d);
  }

  @override
  Widget build(BuildContext context) {
    final hasFilters = _fromDate != null || _toDate != null || _statusFilter != 'todos';

    return Column(
      children: [
        // Panel de filtros
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Rango de fechas
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
              const SizedBox(height: 8),
              // Fila 2: Dropdown de estado
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
            ],
          ),
        ),

        Expanded(
          child: _filtered.isEmpty
              ? const Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('📋', style: TextStyle(fontSize: 40)),
                      SizedBox(height: 8),
                      Text('Sin registros', style: TextStyle(color: AppColors.muted)),
                    ],
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: _grouped.length,
                  itemBuilder: (ctx, i) {
                    final entry = _grouped.entries.elementAt(i);
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(top: 6, bottom: 8),
                          child: Text(
                            _dayLabel(entry.key).toUpperCase(),
                            style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w700,
                              color: AppColors.muted, letterSpacing: .5,
                            ),
                          ),
                        ),
                        ...entry.value.map((r) => _readingCard(r)),
                      ],
                    );
                  },
                ),
        ),
      ],
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
            Icon(Icons.calendar_month_outlined, size: 16, color: active ? AppColors.teal : AppColors.muted),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 10,
                          color: active ? AppColors.teal : AppColors.muted)),
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

  Widget _readingCard(Reading r) {
    final timeStr = DateFormat('HH:mm').format(r.timestamp);
    final dateStr = DateFormat('d MMM', 'es').format(r.timestamp);
    return Card(
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 13, vertical: 4),
        leading: Container(
          width: 54, height: 54,
          decoration: BoxDecoration(
            color: _statusBg(r.status),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${r.glucoseValue}',
                  style: TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700,
                    color: _statusColor(r.status),
                  )),
              Text('mg/dL',
                  style: TextStyle(fontSize: 9, color: _statusColor(r.status), fontWeight: FontWeight.w600)),
            ],
          ),
        ),
        title: Text(
          '${kMomentIcons[r.moment] ?? '⏱'} ${r.moment}',
          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$dateStr · $timeStr  ${r.status.label}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            if (r.insulinDose != null)
              Text('💉 ${r.insulinDose}U ${r.insulinType ?? ''}',
                  style: const TextStyle(fontSize: 12, color: AppColors.amber, fontWeight: FontWeight.w600)),
            if (r.recordedBy != 'Sin nombre')
              Text('👤 ${r.recordedBy}',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            if (r.note != null)
              Text('📝 ${r.note}',
                  style: const TextStyle(fontSize: 12, color: AppColors.muted),
                  maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.muted, size: 20),
          onPressed: () => _delete(r),
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
