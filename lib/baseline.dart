import 'health.dart';

/// Descriptive prototype settings; these are not NASA/clinical thresholds.
class BaselineConfig {
  final int minimumDays;
  final int maxGapDays;
  final double alpha;
  final double maxRelativeDrift;
  const BaselineConfig({
    this.minimumDays = 7,
    this.maxGapDays = 14,
    this.alpha = 0.1,
    this.maxRelativeDrift = 0.1,
  }) : assert(minimumDays >= 2),
       assert(maxGapDays > 0),
       assert(alpha > 0 && alpha <= 1),
       assert(maxRelativeDrift > 0);
}

enum BaselineStatus {
  collecting,
  active,
  paused,
  frozen,
  stale,
  unknownContext,
}

class BaselinePoint {
  final DateTime time;
  final double value;
  const BaselinePoint(this.time, this.value);
}

class BaselineResult {
  final BaselineStatus status;
  final MissionPhase phase;
  final double? value;
  final double? initialReference;
  final double? preflightReference;
  final double? comparisonReference;
  final double? latestRestingValue;
  final DateTime? lastAcceptedAt;
  final int eligibleDays;
  final List<BaselinePoint> history;
  final String? reason;
  const BaselineResult({
    required this.status,
    required this.phase,
    required this.eligibleDays,
    required this.history,
    this.value,
    this.initialReference,
    this.preflightReference,
    this.comparisonReference,
    this.latestRestingValue,
    this.lastAcceptedAt,
    this.reason,
  });
  double? get difference =>
      comparisonReference == null || latestRestingValue == null
      ? null
      : latestRestingValue! - comparisonReference!;
  double? get driftPercent => value == null || initialReference == null
      ? null
      : 100 * (value! - initialReference!) / initialReference!;
}

double _median(List<double> numbers) {
  final sorted = [...numbers]..sort();
  final mid = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[mid]
      : (sorted[mid - 1] + sorted[mid]) / 2;
}

DateTime _day(DateTime time) => DateTime(time.year, time.month, time.day);
bool _comparable(HealthEntry e) =>
    e.context == MeasurementContext.rest &&
    e.verified &&
    (e.values[Metric.heartRate]?.isFinite ?? false);
bool _eligible(HealthEntry e, TargetRange range) =>
    _comparable(e) &&
    !e.hasSymptoms &&
    range.contains(e.values[Metric.heartRate]!);

/// Replays chronologically so today's observation never changes its own
/// comparison reference. Missing days are not filled or interpolated.
BaselineResult calculateRestingBaseline({
  required List<HealthEntry> entries,
  required TargetRange target,
  required DateTime now,
  required bool demo,
  BaselineConfig config = const BaselineConfig(),
}) {
  final ordered =
      entries.where((e) => e.demo == demo && !e.time.isAfter(now)).toList()
        ..sort((a, b) => a.time.compareTo(b.time));
  if (ordered.isEmpty || ordered.last.phase == MissionPhase.unspecified) {
    return const BaselineResult(
      status: BaselineStatus.unknownContext,
      phase: MissionPhase.unspecified,
      eligibleDays: 0,
      history: [],
      reason: 'context',
    );
  }
  final phase = ordered.last.phase;
  // A return to the same phase starts a new segment, rather than blending it
  // with measurements from before an intervening phase.
  var start = ordered.length - 1;
  while (start > 0 && ordered[start - 1].phase == phase) {
    start--;
  }
  final segment = ordered.sublist(start);
  final preflightDays = <DateTime, List<double>>{};
  // Preserve the earliest qualifying preflight segment as an immutable
  // historical reference for this single-mission prototype.
  if (phase != MissionPhase.preflight) {
    for (final e in ordered.take(start)) {
      if (e.phase == MissionPhase.preflight && _eligible(e, target)) {
        preflightDays
            .putIfAbsent(_day(e.time), () => [])
            .add(e.values[Metric.heartRate]!);
      }
    }
  }
  final preflightValues = preflightDays.values.map(_median).toList();
  final preflight = preflightValues.length >= config.minimumDays
      ? _median(preflightValues.take(config.minimumDays).toList())
      : null;
  final days = <DateTime, List<HealthEntry>>{};
  for (final e in segment) {
    days.putIfAbsent(_day(e.time), () => []).add(e);
  }
  final warmup = <double>[];
  final history = <BaselinePoint>[];
  double? baseline, initial, comparison, latestResting;
  DateTime? lastAccepted;
  bool frozen = false;
  String? reason;
  var count = 0;
  var lastPaused = false;
  final latestDay = _day(segment.last.time);
  for (final day in days.entries) {
    final current = day.value;
    if (lastAccepted != null &&
        day.key.difference(_day(lastAccepted)).inDays > config.maxGapDays &&
        !frozen) {
      // A stale estimate must gather fresh days again; keep historical anchor.
      baseline = null;
      warmup.clear();
      count = 0;
    }
    if (day.key == latestDay) {
      comparison = baseline;
      final latest = current.last;
      latestResting = _comparable(latest)
          ? latest.values[Metric.heartRate]
          : null;
    }
    final comparable = current.where(_comparable).toList();
    final blocked =
        current.any((e) => e.hasSymptoms) ||
        comparable.any((e) => !target.contains(e.values[Metric.heartRate]!));
    final accepted = current.where((e) => _eligible(e, target)).toList();
    lastPaused = blocked || accepted.isEmpty;
    if (frozen) {
      continue;
    }
    if (blocked || accepted.isEmpty) {
      continue;
    }
    final daily = _median(
      accepted.map((e) => e.values[Metric.heartRate]!).toList(),
    );
    if (baseline == null) {
      // After warmup, historical drift remains visible even after a long gap.
      if (initial != null &&
          (daily - initial).abs() / initial > config.maxRelativeDrift) {
        frozen = true;
        reason = 'drift';
        continue;
      }
      warmup.add(daily);
      count++;
      lastAccepted = accepted.last.time;
      if (warmup.length >= config.minimumDays) {
        baseline = _median(warmup.take(config.minimumDays).toList());
        initial ??= baseline;
        history.add(BaselinePoint(accepted.last.time, baseline));
      }
      continue;
    }
    // The anchor does not move with the EWMA. A persistent slow drift cannot
    // silently redefine the personal reference beyond this prototype guard.
    if ((daily - initial!).abs() / initial > config.maxRelativeDrift) {
      frozen = true;
      reason = 'drift';
      continue;
    }
    baseline += config.alpha * (daily - baseline);
    lastAccepted = accepted.last.time;
    count++;
    history.add(BaselinePoint(lastAccepted, baseline));
  }
  var status = frozen
      ? BaselineStatus.frozen
      : baseline == null
      ? BaselineStatus.collecting
      : lastPaused
      ? BaselineStatus.paused
      : BaselineStatus.active;
  if (!frozen &&
      lastAccepted != null &&
      now.difference(lastAccepted).inDays > config.maxGapDays) {
    status = BaselineStatus.stale;
  }
  return BaselineResult(
    status: status,
    phase: phase,
    value: baseline,
    initialReference: initial,
    preflightReference: preflight,
    comparisonReference: comparison,
    latestRestingValue: latestResting,
    lastAcceptedAt: lastAccepted,
    eligibleDays: count,
    history: history,
    reason: reason,
  );
}
