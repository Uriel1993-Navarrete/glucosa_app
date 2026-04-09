import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/reading.dart';
import '../models/oxygen_reading.dart';
import '../theme.dart';

class ChartScreen extends StatefulWidget {
  final List<Reading> readings;
  final List<OxygenReading> oxygenReadings;
  const ChartScreen({super.key, required this.readings, required this.oxygenReadings});

  @override
  State<ChartScreen> createState() => _ChartScreenState();
}

class _ChartScreenState extends State<ChartScreen> {
  late DateTime _weekStart;
  bool _isOxygen = false;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _weekStart = now.subtract(Duration(days: now.weekday - 1));
    _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day);
  }

  DateTime get _weekEnd => _weekStart.add(const Duration(days: 7));

  // ── Glucosa ───────────────────────────────────────────
  List<Reading> get _weekReadings =>
      widget.readings.where((r) => r.timestamp.isAfter(_weekStart) && r.timestamp.isBefore(_weekEnd)).toList();

  double? _avgForDay(int dayOffset) {
    final day = _weekStart.add(Duration(days: dayOffset));
    final vals = widget.readings
        .where((r) =>
            r.timestamp.year == day.year &&
            r.timestamp.month == day.month &&
            r.timestamp.day == day.day)
        .map((r) => r.glucoseValue.toDouble())
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  static const _veryHighColor = Color(0xFF8B0000);

  Color _dotColor(double v) {
    if (v < 70) return AppColors.red;
    if (v <= 130) return AppColors.green;
    if (v <= 180) return AppColors.yellow;
    return _veryHighColor;
  }

  // ── Oxígeno ───────────────────────────────────────────
  List<OxygenReading> get _weekOxygenReadings =>
      widget.oxygenReadings.where((r) => r.timestamp.isAfter(_weekStart) && r.timestamp.isBefore(_weekEnd)).toList();

  double? _avgOxygenForDay(int dayOffset) {
    final day = _weekStart.add(Duration(days: dayOffset));
    final vals = widget.oxygenReadings
        .where((r) =>
            r.timestamp.year == day.year &&
            r.timestamp.month == day.month &&
            r.timestamp.day == day.day)
        .map((r) => r.spo2Value.toDouble())
        .toList();
    if (vals.isEmpty) return null;
    return vals.reduce((a, b) => a + b) / vals.length;
  }

  Color _dotOxygenColor(double v) {
    if (v < kSpo2LowMin) return AppColors.oxygenCritical;
    if (v < kSpo2NormalMin) return AppColors.oxygenLow;
    return AppColors.oxygenNormal;
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        // Toggle Glucosa / O₂
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isOxygen = false),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_isOxygen ? AppColors.teal : AppColors.bg,
                      borderRadius: const BorderRadius.horizontal(left: Radius.circular(10)),
                      border: Border.all(color: !_isOxygen ? AppColors.teal : AppColors.border),
                    ),
                    child: Center(
                      child: Text('🩸  Glucosa',
                          style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13,
                            color: !_isOxygen ? Colors.white : AppColors.muted,
                          )),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _isOxygen = true),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _isOxygen ? AppColors.oxygenNormal : AppColors.bg,
                      borderRadius: const BorderRadius.horizontal(right: Radius.circular(10)),
                      border: Border.all(color: _isOxygen ? AppColors.oxygenNormal : AppColors.border),
                    ),
                    child: Center(
                      child: Text('🫁  O₂',
                          style: TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13,
                            color: _isOxygen ? Colors.white : AppColors.muted,
                          )),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        if (_isOxygen) ..._buildOxygenChart() else ..._buildGlucoseChart(),
      ],
    );
  }

  List<Widget> _buildGlucoseChart() {
    final weekR = _weekReadings;
    final allVals = weekR.map((r) => r.glucoseValue).toList();
    final avg = allVals.isEmpty ? null : (allVals.reduce((a, b) => a + b) / allVals.length).round();
    final inRange = widget.readings.where((r) => r.glucoseValue >= 70 && r.glucoseValue <= 130).length;
    final pct = widget.readings.isEmpty ? 0 : (inRange / widget.readings.length * 100).round();

    final spots = <FlSpot>[];
    final colors = <int, Color>{};
    for (int i = 0; i < 7; i++) {
      final v = _avgForDay(i);
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), v));
        colors[i] = _dotColor(v);
      }
    }

    final dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return [
      _weekNav(),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          _legendItem(AppColors.red, 'Bajo <70'),
          _legendItem(AppColors.green, 'Normal 70-130'),
          _legendItem(AppColors.yellow, 'Alto 130-180'),
          _legendItem(_veryHighColor, 'Muy alto >180'),
        ],
      ),
      const SizedBox(height: 10),
      _chartContainer(
        title: '📈 Glucosa diaria promedio (mg/dL)',
        child: spots.isEmpty
            ? const Center(child: Text('Sin datos esta semana', style: TextStyle(color: AppColors.muted)))
            : LineChart(LineChartData(
                minX: 0, maxX: 6,
                minY: 40, maxY: 320,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: 50,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: _titlesData(dayLabels, 50),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(y1: 70, y2: 130, color: AppColors.green.withValues(alpha: .07)),
                  ],
                ),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(y: 70, color: AppColors.green.withValues(alpha: .35), strokeWidth: 1, dashArray: [4, 4]),
                  HorizontalLine(y: 130, color: AppColors.green.withValues(alpha: .35), strokeWidth: 1, dashArray: [4, 4]),
                ]),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.teal,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => _LabeledDotPainter(
                        color: colors[spot.x.toInt()] ?? AppColors.teal,
                        value: spot.y,
                      ),
                    ),
                    belowBarData: BarAreaData(show: true, color: AppColors.teal.withValues(alpha: .07)),
                  ),
                ],
              )),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _statCard('${avg ?? '—'} mg/dL', 'Prom. semana', AppColors.teal)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('${weekR.length}', 'Registros', AppColors.teal)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('$pct%', 'En rango global', AppColors.teal)),
        ],
      ),
    ];
  }

  List<Widget> _buildOxygenChart() {
    final weekR = _weekOxygenReadings;
    final allVals = weekR.map((r) => r.spo2Value).toList();
    final avg = allVals.isEmpty ? null : (allVals.reduce((a, b) => a + b) / allVals.length).round();
    final inRange = widget.oxygenReadings.where((r) => r.spo2Value >= kSpo2NormalMin).length;
    final pct = widget.oxygenReadings.isEmpty ? 0 : (inRange / widget.oxygenReadings.length * 100).round();

    final spots = <FlSpot>[];
    final colors = <int, Color>{};
    for (int i = 0; i < 7; i++) {
      final v = _avgOxygenForDay(i);
      if (v != null) {
        spots.add(FlSpot(i.toDouble(), v));
        colors[i] = _dotOxygenColor(v);
      }
    }

    final dayLabels = ['L', 'M', 'X', 'J', 'V', 'S', 'D'];

    return [
      _weekNav(),
      const SizedBox(height: 10),
      Wrap(
        spacing: 8,
        children: [
          _legendItem(AppColors.oxygenCritical, 'Crítico <90%'),
          _legendItem(AppColors.oxygenLow, 'Bajo 90-94%'),
          _legendItem(AppColors.oxygenNormal, 'Normal ≥95%'),
        ],
      ),
      const SizedBox(height: 10),
      _chartContainer(
        title: '📈 SpO2 diario promedio (%)',
        child: spots.isEmpty
            ? const Center(child: Text('Sin datos esta semana', style: TextStyle(color: AppColors.muted)))
            : LineChart(LineChartData(
                minX: 0, maxX: 6,
                minY: 85, maxY: 100,
                gridData: FlGridData(
                  show: true,
                  drawHorizontalLine: true,
                  drawVerticalLine: false,
                  horizontalInterval: 2,
                  getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 1),
                ),
                borderData: FlBorderData(show: false),
                titlesData: _titlesData(dayLabels, 2),
                rangeAnnotations: RangeAnnotations(
                  horizontalRangeAnnotations: [
                    HorizontalRangeAnnotation(
                        y1: kSpo2NormalMin.toDouble(),
                        y2: 100,
                        color: AppColors.oxygenNormal.withValues(alpha: .07)),
                  ],
                ),
                extraLinesData: ExtraLinesData(horizontalLines: [
                  HorizontalLine(
                      y: kSpo2NormalMin.toDouble(),
                      color: AppColors.oxygenNormal.withValues(alpha: .4),
                      strokeWidth: 1,
                      dashArray: [4, 4]),
                ]),
                lineTouchData: const LineTouchData(enabled: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    curveSmoothness: 0.3,
                    color: AppColors.oxygenNormal,
                    barWidth: 2.5,
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, _, __, ___) => _LabeledDotPainter(
                        color: colors[spot.x.toInt()] ?? AppColors.oxygenNormal,
                        value: spot.y,
                        suffix: '%',
                      ),
                    ),
                    belowBarData: BarAreaData(
                        show: true, color: AppColors.oxygenNormal.withValues(alpha: .07)),
                  ),
                ],
              )),
      ),
      const SizedBox(height: 10),
      Row(
        children: [
          Expanded(child: _statCard(avg != null ? '$avg %' : '—', 'Prom. semana', AppColors.oxygenNormal)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('${weekR.length}', 'Registros', AppColors.oxygenNormal)),
          const SizedBox(width: 8),
          Expanded(child: _statCard('$pct%', '≥95% global', AppColors.oxygenNormal)),
        ],
      ),
    ];
  }

  // ── Widgets compartidos ───────────────────────────────

  Widget _weekNav() => Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 8)],
        ),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _weekStart = _weekStart.subtract(const Duration(days: 7))),
            ),
            Expanded(
              child: Text(
                '${DateFormat('d MMM', 'es').format(_weekStart)} – ${DateFormat('d MMM', 'es').format(_weekStart.add(const Duration(days: 6)))}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.navy),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: () => setState(() => _weekStart = _weekStart.add(const Duration(days: 7))),
            ),
          ],
        ),
      );

  Widget _chartContainer({required String title, required Widget child}) => Container(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 8)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 8, bottom: 12),
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: AppColors.navy)),
            ),
            SizedBox(height: 220, child: child),
          ],
        ),
      );

  FlTitlesData _titlesData(List<String> dayLabels, double interval) => FlTitlesData(
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 34,
            interval: interval,
            getTitlesWidget: (v, _) =>
                Text(v.toInt().toString(), style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            interval: 1,
            getTitlesWidget: (v, meta) {
              if (v != v.roundToDouble()) return const SizedBox.shrink();
              return Text(
                dayLabels[v.toInt().clamp(0, 6)],
                style: const TextStyle(fontSize: 11, color: AppColors.muted, fontWeight: FontWeight.w600),
              );
            },
          ),
        ),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      );

  Widget _legendItem(Color color, String label) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
          const SizedBox(width: 4),
          Text(label, style: const TextStyle(fontSize: 11, color: AppColors.muted)),
        ],
      );

  Widget _statCard(String val, String lbl, Color color) => Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .06), blurRadius: 8)],
        ),
        child: Column(
          children: [
            Text(val, style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: color)),
            const SizedBox(height: 3),
            Text(lbl,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          ],
        ),
      );
}

class _LabeledDotPainter extends FlDotPainter {
  final Color color;
  final double value;
  final String suffix;

  const _LabeledDotPainter({required this.color, required this.value, this.suffix = ''});

  @override
  void draw(Canvas canvas, FlSpot spot, Offset center) {
    canvas.drawCircle(center, 5, Paint()..color = color);
    canvas.drawCircle(center, 5,
        Paint()
          ..color = Colors.white
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2);
    final tp = TextPainter(
      text: TextSpan(
        text: '${value.round()}$suffix',
        style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w700),
      ),
      textDirection: ui.TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height - 8));
  }

  @override
  Size getSize(FlSpot spot) => const Size(40, 30);

  @override
  Color get mainColor => color;

  @override
  Color get strokeColor => Colors.white;

  @override
  double get strokeWidth => 2;

  @override
  FlDotPainter lerp(FlDotPainter a, FlDotPainter b, double t) {
    if (a is _LabeledDotPainter && b is _LabeledDotPainter) {
      return _LabeledDotPainter(
        color: Color.lerp(a.color, b.color, t) ?? b.color,
        value: a.value + (b.value - a.value) * t,
        suffix: b.suffix,
      );
    }
    return b;
  }

  @override
  List<Object?> get props => [color, value, suffix];
}
