import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum Metric {
  heartRate,
  systolic,
  diastolic,
  temperature,
  glucose,
  sleep,
  mood,
}

extension MetricInfo on Metric {
  String get en => [
    'Heart rate',
    'Systolic pressure',
    'Diastolic pressure',
    'Temperature',
    'Blood glucose',
    'Sleep',
    'Mood',
  ][index];
  String get ar => [
    'نبض القلب',
    'الضغط الانقباضي',
    'الضغط الانبساطي',
    'درجة الحرارة',
    'سكر الدم',
    'النوم',
    'الحالة النفسية',
  ][index];
  String get unit => ['bpm', 'mmHg', 'mmHg', '°C', 'mg/dL', 'h', '/ 5'][index];
  double get minimum => [20, 50, 30, 30, 20, 0, 1][index].toDouble();
  double get maximum => [250, 260, 180, 45, 600, 24, 5][index].toDouble();
  String format(double value) => value.toStringAsFixed(
    this == Metric.temperature || this == Metric.sleep ? 1 : 0,
  );
}

enum MissionPhase { unspecified, preflight, inflight, postflight }

enum MeasurementContext { unspecified, rest, afterExercise }

class HealthEntry {
  final String id;
  final DateTime time;
  final Map<Metric, double> values;
  final String notes;
  final bool demo;
  final MissionPhase phase;
  final MeasurementContext context;
  final bool verified;
  final bool hasSymptoms;
  HealthEntry({
    required this.id,
    required this.time,
    required this.values,
    this.notes = '',
    this.demo = false,
    this.phase = MissionPhase.unspecified,
    this.context = MeasurementContext.unspecified,
    this.verified = false,
    this.hasSymptoms = false,
  });
  Map<String, dynamic> toJson() => {
    'id': id,
    'time': time.toIso8601String(),
    'values': values.map((k, v) => MapEntry(k.name, v)),
    'notes': notes,
    'phase': phase.name,
    'context': context.name,
    'verified': verified,
    'hasSymptoms': hasSymptoms,
  };
  factory HealthEntry.fromJson(Map<String, dynamic> json) => HealthEntry(
    id: json['id'] as String,
    time: DateTime.parse(json['time'] as String),
    values: (json['values'] as Map<String, dynamic>).map(
      (k, v) => MapEntry(Metric.values.byName(k), (v as num).toDouble()),
    ),
    notes: json['notes'] as String? ?? '',
    phase:
        MissionPhase.values.where((v) => v.name == json['phase']).firstOrNull ??
        MissionPhase.unspecified,
    context:
        MeasurementContext.values
            .where((v) => v.name == json['context'])
            .firstOrNull ??
        MeasurementContext.unspecified,
    verified: json['verified'] as bool? ?? false,
    hasSymptoms: json['hasSymptoms'] as bool? ?? false,
  );
}

class TargetRange {
  final double low, high;
  const TargetRange(this.low, this.high);
  bool contains(double value) => value >= low && value <= high;
  List<double> toJson() => [low, high];
}

const defaultTargets = <Metric, TargetRange>{
  Metric.heartRate: TargetRange(50, 100),
  Metric.systolic: TargetRange(90, 140),
  Metric.diastolic: TargetRange(60, 90),
  Metric.temperature: TargetRange(36, 37.8),
  Metric.glucose: TargetRange(70, 140),
  Metric.sleep: TargetRange(7, 9),
  Metric.mood: TargetRange(3, 5),
};

class HealthStore extends ChangeNotifier {
  final SharedPreferencesAsync prefs;
  HealthStore({SharedPreferencesAsync? preferences, DateTime Function()? clock})
    : prefs = preferences ?? SharedPreferencesAsync(),
      now = clock ?? DateTime.now;
  bool arabic = true, demo = true, ready = false;
  String? error;
  List<HealthEntry> ownEntries = [];
  Map<Metric, TargetRange> targets = {...defaultTargets};
  Set<String> tasks = {};
  String taskDate = '';
  bool loadFailed = false;
  final DateTime Function() now;

  String t(String en, String ar) => arabic ? ar : en;
  String get today => now().toIso8601String().substring(0, 10);
  List<HealthEntry> get entries {
    final list = demo ? sampleEntries(now()) : [...ownEntries];
    list.sort((a, b) => b.time.compareTo(a.time));
    return list;
  }

  HealthEntry? get latest => entries.isEmpty ? null : entries.first;
  bool get stale =>
      latest == null || now().difference(latest!.time).inHours >= 24;
  List<Metric> get flagged =>
      latest?.values.entries
          .where((v) => !targets[v.key]!.contains(v.value))
          .map((v) => v.key)
          .toList() ??
      [];
  bool taskDone(String id) => taskDate == today && tasks.contains(id);
  Future<void> load() async {
    try {
      final raw = await prefs.getString('orbit_v1');
      error = null;
      if (raw != null) {
        final data = jsonDecode(raw) as Map<String, dynamic>;
        final loadedEntries = (data['entries'] as List)
            .map(
              (e) => HealthEntry.fromJson(Map<String, dynamic>.from(e as Map)),
            )
            .toList();
        final loadedTargets = {...defaultTargets};
        (data['targets'] as Map<String, dynamic>?)?.forEach((key, value) {
          final pair = value as List;
          loadedTargets[Metric.values.byName(key)] = TargetRange(
            (pair[0] as num).toDouble(),
            (pair[1] as num).toDouble(),
          );
        });
        ownEntries = loadedEntries;
        targets = loadedTargets;
        arabic = data['arabic'] as bool? ?? true;
        demo = data['demo'] as bool? ?? true;
        taskDate = data['taskDate'] as String? ?? '';
        tasks = Set<String>.from(data['tasks'] as List? ?? []);
      }
    } catch (_) {
      error = 'load';
    }
    loadFailed = error == 'load';
    ready = true;
    notifyListeners();
  }

  Future<bool> _persist(Map<String, dynamic> data) async {
    if (loadFailed) {
      error = 'load';
      notifyListeners();
      return false;
    }
    try {
      await prefs.setString('orbit_v1', jsonEncode(data));
      error = null;
      return true;
    } catch (_) {
      error = 'save';
      notifyListeners();
      return false;
    }
  }

  Map<String, dynamic> _data() => {
    'entries': ownEntries.map((e) => e.toJson()).toList(),
    'targets': targets.map((k, v) => MapEntry(k.name, v.toJson())),
    'arabic': arabic,
    'demo': demo,
    'taskDate': taskDate,
    'tasks': tasks.toList(),
  };
  Future<bool> add(HealthEntry entry) async {
    final data = _data();
    data['entries'] = [...ownEntries, entry].map((e) => e.toJson()).toList();
    data['demo'] = false;
    if (!await _persist(data)) return false;
    ownEntries.add(entry);
    demo = false;
    notifyListeners();
    return true;
  }

  Future<void> language() async {
    arabic = !arabic;
    notifyListeners();
    await _persist(_data());
  }

  Future<void> setDemo(bool value) async {
    demo = value;
    notifyListeners();
    await _persist(_data());
  }

  Future<void> toggleTask(String id) async {
    if (taskDate != today) {
      tasks = {};
      taskDate = today;
    }
    tasks.contains(id) ? tasks.remove(id) : tasks.add(id);
    notifyListeners();
    await _persist(_data());
  }

  Future<bool> setTargets(Map<Metric, TargetRange> next) async {
    final data = _data();
    data['targets'] = next.map((k, v) => MapEntry(k.name, v.toJson()));
    if (!await _persist(data)) return false;
    targets = next;
    notifyListeners();
    return true;
  }

  String exportJson() => const JsonEncoder.withIndent('  ').convert({
    'application': 'Orbit health prototype',
    'exportedAt': now().toIso8601String(),
    'simulated': demo,
    'entries': entries.map((e) => {...e.toJson(), 'demo': e.demo}).toList(),
    'targetNote':
        'Illustrative, user-editable targets; not validated medical thresholds',
    'targets': targets.map((k, v) => MapEntry(k.name, v.toJson())),
  });
}

List<HealthEntry> sampleEntries(DateTime now) {
  const rates = [
    68.0,
    69.0,
    67.0,
    68.0,
    69.0,
    68.0,
    68.0,
    69.0,
    70.0,
    71.0,
    70.0,
    71.0,
    72.0,
    71.0,
  ];
  const sleeps = [7.8, 7.5, 8.0, 7.2, 7.6, 6.8, 6.4];
  return List.generate(
        rates.length,
        (i) => HealthEntry(
          id: 'demo-$i',
          time: DateTime(now.year, now.month, now.day)
              .subtract(Duration(days: rates.length - 1 - i))
              .add(const Duration(hours: 7, minutes: 30)),
          demo: true,
          phase: MissionPhase.inflight,
          context: MeasurementContext.rest,
          verified: true,
          values: {
            Metric.heartRate: rates[i],
            Metric.systolic: 118 + (i % 3).toDouble(),
            Metric.diastolic: 76 + (i % 2).toDouble(),
            Metric.temperature: 36.6 + (i % 2) * 0.1,
            Metric.glucose: 90 + (i % 4).toDouble(),
            Metric.sleep: sleeps[i % sleeps.length],
            Metric.mood: i == 6 ? 3 : 4,
          },
          notes: i == 6
              ? 'SIMULATED: Light sleep after a busy workday.'
              : 'SIMULATED: Routine morning check.',
        ),
      )
      // Keep example timestamps at or before the current time.
      .map(
        (e) => e.time.isAfter(now)
            ? HealthEntry(
                id: e.id,
                time: now,
                values: e.values,
                notes: e.notes,
                demo: true,
                phase: e.phase,
                context: e.context,
                verified: e.verified,
                hasSymptoms: e.hasSymptoms,
              )
            : e,
      )
      .toList();
}

class SpaceResource {
  final String agency, en, ar, url, descriptionEn, descriptionAr, useEn, useAr;
  const SpaceResource(
    this.agency,
    this.en,
    this.ar,
    this.url,
    this.descriptionEn,
    this.descriptionAr,
    this.useEn,
    this.useAr,
  );
}

const resources = [
  SpaceResource(
    'NASA',
    '5 Hazards of Human Spaceflight',
    'المخاطر الخمسة للرحلات الفضائية',
    'https://www.nasa.gov/hrp/hazards/',
    'Radiation, isolation, distance, gravity and the spacecraft environment shape crew health.',
    'الإشعاع والعزلة والبعد عن الأرض والجاذبية والبيئة المغلقة تؤثر على صحة الطاقم.',
    'Used to organize the five hazard explanations below.',
    'أساس تنظيم شرح المخاطر الخمسة في الدليل.',
  ),
  SpaceResource(
    'NASA',
    'Risks of Human Spaceflight',
    'المخاطر الصحية في الفضاء',
    'https://www.nasa.gov/hrp/risks/',
    'Research connects spaceflight with changes in cardiovascular fitness, bones, immunity and behavior.',
    'تتناول الأبحاث التغيّرات في القلب والعظام والمناعة والسلوك أثناء الرحلات.',
    'Informs the purpose of vital signs, mood and exercise tracking.',
    'يوضح سبب متابعة المؤشرات والحالة النفسية والنشاط.',
  ),
  SpaceResource(
    'NASA',
    'Ongoing HRP Research',
    'أبحاث برنامج البحوث البشرية',
    'https://www.nasa.gov/hrp/ongoing-hrp-research/',
    'Standard Measures collects physiological and psychological data. ARCHeR studies activity, sleep and well-being.',
    'يجمع برنامج Standard Measures بيانات جسدية ونفسية، وتدرس ARCHeR النشاط والنوم والعافية.',
    'Inspires consistent, timestamped check-ins and sleep trends.',
    'أساس فكرة التسجيل المنتظم بتوقيت واضح ومتابعة النوم.',
  ),
  SpaceResource(
    'CSA',
    'Monitoring Radiation for Astronaut Health',
    'رصد الإشعاع لحماية رواد الفضاء',
    'https://www.asc-csa.gc.ca/eng/news/articles/2026/2026-02-26-monitoring-radiation-astronaut-health.asp',
    'Canada is developing CANS to measure neutron radiation exposure continuously.',
    'تطوّر كندا جهاز CANS لرصد التعرض لإشعاع النيوترونات بشكل مستمر.',
    'Radiation requires a dosimeter. Orbit does not infer exposure from vital signs.',
    'قياس الإشعاع يحتاج جهازًا مخصصًا؛ التطبيق لا يستنتجه من القراءات الصحية.',
  ),
  SpaceResource(
    'CSA',
    'Why Conduct Science in Space?',
    'لماذا نجري تجارب علمية في الفضاء؟',
    'https://www.asc-csa.gc.ca/eng/iss/science/why-do-we-conduct-science-experiments-in-space.asp',
    'Space research studies risks and countermeasures for longer, more independent missions.',
    'تدرس أبحاث الفضاء المخاطر ووسائل تقليلها للرحلات الأطول والأكثر استقلالية.',
    'Motivates local storage when communication with Earth is delayed.',
    'يدعم فكرة الحفظ المحلي عند تأخر الاتصال بالأرض.',
  ),
];
