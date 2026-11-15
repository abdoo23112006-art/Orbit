import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../main.dart';
import '../health.dart';
import '../baseline.dart';

class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(22),
  });
  @override
  Widget build(BuildContext context) => Material(
    color: Colors.white,
    shape: RoundedRectangleBorder(
      side: const BorderSide(color: line),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Padding(padding: padding, child: child),
  );
}

class Eyebrow extends StatelessWidget {
  final String text;
  const Eyebrow(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontSize: 10,
      fontWeight: FontWeight.w600,
      letterSpacing: 1.5,
      color: muted,
    ),
  );
}

class Pill extends StatelessWidget {
  final String text;
  final bool warning;
  const Pill(this.text, {super.key, this.warning = false});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: warning ? const Color(0xFFFAF0DE) : pale,
      borderRadius: BorderRadius.circular(4),
    ),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 10,
        color: warning ? amber : green,
        fontWeight: FontWeight.w500,
      ),
    ),
  );
}

String stamp(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
String shortDate(DateTime date) => '${date.day}/${date.month}';

const metricIcons = <Metric, IconData>{
  Metric.heartRate: Icons.favorite_border,
  Metric.systolic: Icons.speed_outlined,
  Metric.diastolic: Icons.speed_outlined,
  Metric.temperature: Icons.thermostat_outlined,
  Metric.glucose: Icons.water_drop_outlined,
  Metric.sleep: Icons.bedtime_outlined,
  Metric.mood: Icons.sentiment_satisfied_alt,
};

class TrendChart extends StatelessWidget {
  final List<HealthEntry> entries;
  final Metric metric;
  final TargetRange range;
  final bool arabic;
  final double height;
  final List<BaselinePoint> baselinePoints;
  const TrendChart({
    super.key,
    required this.entries,
    required this.metric,
    required this.range,
    required this.arabic,
    this.height = 190,
    this.baselinePoints = const [],
  });
  @override
  Widget build(BuildContext context) {
    final points = entries.where((e) => e.values.containsKey(metric)).toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    if (points.isEmpty)
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            arabic
                ? 'لا توجد قراءات لهذا المؤشر بعد'
                : 'No readings for this indicator yet',
            style: const TextStyle(color: muted, fontSize: 12),
          ),
        ),
      );
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Column(
        children: [
          SizedBox(
            height: height,
            child: Semantics(
              label:
                  '${metric.en}: ${points.map((e) => '${stamp(e.time)}: ${e.values[metric]}').join(', ')}',
              child: CustomPaint(
                size: Size(double.infinity, height),
                painter: TrendPainter(
                  points: points,
                  metric: metric,
                  range: range,
                  baselinePoints: baselinePoints,
                ),
              ),
            ),
          ),
          const SizedBox(height: 9),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                shortDate(points.first.time),
                style: const TextStyle(color: muted, fontSize: 10),
              ),
              Text(
                metric.unit,
                style: const TextStyle(color: muted, fontSize: 10),
              ),
              Text(
                shortDate(points.last.time),
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 18,
            children: [
              Text(
                arabic ? '●  القراءات المسجلة' : '●  Recorded readings',
                style: const TextStyle(fontSize: 10, color: green),
              ),
              Text(
                arabic
                    ? '▬  النطاق التجريبي المحدد'
                    : '▬  Illustrative target range',
                style: const TextStyle(fontSize: 10, color: muted),
              ),
              if (baselinePoints.isNotEmpty)
                Text(
                  arabic
                      ? '━  المرجع بعد التحديث اليومي'
                      : '━  Reference after daily update',
                  style: const TextStyle(
                    fontSize: 10,
                    color: Color(0xFF3569B0),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class TrendPainter extends CustomPainter {
  final List<HealthEntry> points;
  final Metric metric;
  final TargetRange range;
  final List<BaselinePoint> baselinePoints;
  TrendPainter({
    required this.points,
    required this.metric,
    required this.range,
    this.baselinePoints = const [],
  });
  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((e) => e.values[metric]!).toList();
    final visibleBaseline = baselinePoints
        .where(
          (p) =>
              !p.time.isBefore(points.first.time) &&
              !p.time.isAfter(points.last.time),
        )
        .toList();
    final allValues = [...values, ...visibleBaseline.map((p) => p.value)];
    var low = math.min(allValues.reduce(math.min), range.low),
        high = math.max(allValues.reduce(math.max), range.high);
    final span = math.max(high - low, 1.0);
    low -= span * .18;
    high += span * .18;
    final chart = Rect.fromLTWH(37, 10, size.width - 49, size.height - 25);
    double y(double value) =>
        chart.bottom - (value - low) / (high - low) * chart.height;
    final fill = Paint()..color = const Color(0xFFF0F4EB);
    canvas.drawRect(
      Rect.fromLTRB(chart.left, y(range.high), chart.right, y(range.low)),
      fill,
    );
    for (var i = 0; i < 4; i++) {
      final value = low + (high - low) * i / 3;
      final yy = y(value);
      canvas.drawLine(
        Offset(chart.left, yy),
        Offset(chart.right, yy),
        Paint()
          ..color = line
          ..strokeWidth = .7,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: metric.format(value),
          style: const TextStyle(
            color: muted,
            fontSize: 9,
            fontFamily: "OrbitSans",
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(0, yy - 6));
    }
    final start = points.first.time.millisecondsSinceEpoch;
    final duration = math.max(
      1,
      points.last.time.millisecondsSinceEpoch - start,
    );
    Offset placeBaseline(BaselinePoint p) => Offset(
      points.length == 1
          ? chart.center.dx
          : chart.left +
                (p.time.millisecondsSinceEpoch - start) /
                    duration *
                    chart.width,
      y(p.value),
    );
    for (final p in visibleBaseline) {
      canvas.drawCircle(
        placeBaseline(p),
        2.2,
        Paint()..color = const Color(0xFF3569B0),
      );
    }
    for (var i = 1; i < visibleBaseline.length; i++) {
      if (visibleBaseline[i].time
              .difference(visibleBaseline[i - 1].time)
              .inHours >
          36)
        continue;
      canvas.drawLine(
        placeBaseline(visibleBaseline[i - 1]),
        placeBaseline(visibleBaseline[i]),
        Paint()
          ..color = const Color(0xFF3569B0)
          ..strokeWidth = 2,
      );
    }
    final positions = List.generate(
      points.length,
      (i) => Offset(
        points.length == 1
            ? chart.center.dx
            : chart.left +
                  (points[i].time.millisecondsSinceEpoch - start) /
                      duration *
                      chart.width,
        y(values[i]),
      ),
    );
    final path = Path()..moveTo(positions.first.dx, positions.first.dy);
    for (final point in positions.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = green
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round,
    );
    for (var i = 0; i < positions.length; i++) {
      canvas.drawCircle(
        positions[i],
        3.3,
        Paint()..color = range.contains(values[i]) ? green : amber,
      );
      canvas.drawCircle(positions[i], 1.2, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant TrendPainter oldDelegate) => true;
}
