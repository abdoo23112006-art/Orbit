import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../health.dart';
import '../baseline.dart';
import 'baseline_card.dart';
import '../main.dart';
import 'widgets.dart';
import 'check_in.dart';
import 'preferences.dart';
import 'cosmo_chat.dart';

class HomeScreen extends StatefulWidget {
  final HealthStore store;
  final VoidCallback? onSignOut;
  const HomeScreen({super.key, required this.store, this.onSignOut});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int page = 0, days = 7;
  Metric selected = Metric.heartRate;
  HealthStore get s => widget.store;
  BaselineResult get baseline => calculateRestingBaseline(
    entries: s.entries,
    target: s.targets[Metric.heartRate]!,
    now: s.now(),
    demo: s.demo,
  );
  List<BaselinePoint> baselinePoints(Metric metric, int days) =>
      metric == Metric.heartRate
      ? baseline.history
            .where(
              (p) => !p.time.isBefore(s.now().subtract(Duration(days: days))),
            )
            .toList()
      : const [];
  List<String> get titles => [
    s.t('Overview', 'نظرة عامة'),
    s.t('Health trends', 'المؤشرات الصحية'),
    s.t('Health journal', 'السجل الصحي'),
    s.t('Field guide', 'دليل الرحلة'),
  ];
  final icons = const [
    Icons.grid_view_outlined,
    Icons.show_chart,
    Icons.receipt_long_outlined,
    Icons.auto_stories_outlined,
  ];
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

  void preferences() => showDialog(
    context: context,
    builder: (_) => PreferencesDialog(store: s),
  );
  Future<void> export() async {
    final content = s.exportJson();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.t('Export health journal', 'تصدير السجل الصحي')),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 580, maxHeight: 400),
          child: SingleChildScrollView(
            child: SelectableText(
              content,
              style: const TextStyle(fontSize: 11, fontFamily: 'monospace'),
              textDirection: TextDirection.ltr,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('Close', 'إغلاق')),
          ),
          FilledButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: content));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      s.t(
                        'JSON copied. Save it as a .json file.',
                        'تم نسخ البيانات. يمكنك حفظها في ملف ‎.json',
                      ),
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: Text(s.t('Copy JSON', 'نسخ البيانات')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final wide = c.maxWidth >= 980;
      return Scaffold(
        floatingActionButton: FloatingActionButton.extended(
          key: const ValueKey('open-cosmo'),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => CosmoChatScreen(store: s)),
          ),
          backgroundColor: green,
          foregroundColor: Colors.white,
          icon: const Icon(Icons.chat_bubble_outline, size: 19),
          label: Text(
            s.t('Ask COSMO', 'اسأل COSMO'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        bottomNavigationBar: wide
            ? null
            : NavigationBar(
                selectedIndex: page,
                onDestinationSelected: (value) => setState(() => page = value),
                backgroundColor: Colors.white,
                indicatorColor: pale,
                destinations: List.generate(
                  4,
                  (i) => NavigationDestination(
                    icon: Icon(icons[i], size: 21),
                    label: titles[i],
                  ),
                ),
              ),
        body: Row(
          children: [
            if (wide) sidebar(),
            Expanded(
              child: Column(
                children: [
                  topbar(wide),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(wide ? 32 : 18),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1180),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              pageHeader(),
                              const SizedBox(height: 24),
                              if (s.error != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  child: MaterialBanner(
                                    content: Text(
                                      s.error == 'load'
                                          ? s.t(
                                              'Saved data could not be read. No stored data was overwritten. Export any data you can see before retrying.',
                                              'تعذر قراءة البيانات المحفوظة. لم يتم استبدالها. احتفظ بنسخة مما يظهر قبل إعادة المحاولة.',
                                            )
                                          : s.t(
                                              'Changes could not be saved. Check device storage.',
                                              'تعذر حفظ التغييرات. تحقق من مساحة الجهاز.',
                                            ),
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => s.load(),
                                        child: Text(
                                          s.t('Retry', 'إعادة المحاولة'),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (page == 0)
                                overview()
                              else if (page == 1)
                                trends()
                              else if (page == 2)
                                journal()
                              else
                                guide(),
                              const SizedBox(height: 28),
                              const Divider(height: 1, color: line),
                              const SizedBox(height: 17),
                              Wrap(
                                alignment: WrapAlignment.spaceBetween,
                                spacing: 30,
                                runSpacing: 8,
                                children: [
                                  Text(
                                    s.t(
                                      'ORBIT / Crew health, one day at a time.',
                                      'ORBIT / صحة الطاقم، يومًا بيوم.',
                                    ),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                  Text(
                                    s.t(
                                      'Space Apps 2026 · Prototype · Not for clinical use',
                                      'Space Apps 2026 · نموذج أولي · غير مخصص للاستخدام الطبي',
                                    ),
                                    style: const TextStyle(
                                      color: muted,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget sidebar() => Container(
    width: 224,
    decoration: const BoxDecoration(
      color: Colors.white,
      border: BorderDirectional(end: BorderSide(color: line)),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          textDirection: TextDirection.ltr,
          children: [
            Icon(Icons.track_changes, size: 36, color: green),
            SizedBox(width: 8),
            Text(
              'orbit',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.w600,
                letterSpacing: -1.5,
              ),
            ),
            Text('.', style: TextStyle(fontSize: 36, color: Color(0xFF91A96C))),
          ],
        ),
        const SizedBox(height: 7),
        const Eyebrow('CREW HEALTH SYSTEM'),
        const SizedBox(height: 35),
        ...List.generate(
          4,
          (i) => Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Material(
              color: page == i ? pale : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              child: InkWell(
                borderRadius: BorderRadius.circular(6),
                onTap: () => setState(() => page = i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 13,
                    vertical: 13,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        icons[i],
                        size: 19,
                        color: page == i ? green : muted,
                      ),
                      const SizedBox(width: 11),
                      Expanded(
                        child: Text(
                          titles[i],
                          style: TextStyle(
                            fontSize: 12,
                            color: page == i ? green : muted,
                            fontWeight: page == i
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 28),
        const Divider(color: line),
        const SizedBox(height: 18),
        Eyebrow(s.t('MISSION PROFILE', 'ملف المهمة')),
        const SizedBox(height: 13),
        Text(
          s.t('Horizon Expedition', 'بعثة Horizon'),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 5),
        Text(
          s.t(
            'Deep-space transit · Scenario',
            'رحلة في الفضاء العميق · سيناريو',
          ),
          style: const TextStyle(fontSize: 10, color: muted),
        ),
        const SizedBox(height: 17),
        ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: const LinearProgressIndicator(
            value: 42 / 180,
            minHeight: 4,
            color: Color(0xFF81986B),
            backgroundColor: pale,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          s.t(
            'MISSION DAY 042 / 180 · SIMULATED',
            'يوم المهمة ٠٤٢ / ١٨٠ · محاكاة',
          ),
          style: const TextStyle(fontSize: 9, color: muted),
        ),
        const Spacer(),
        Row(
          children: [
            const Icon(Icons.circle, size: 6, color: green),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                s.t('Stored on this device', 'محفوظ على هذا الجهاز'),
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: preferences,
          icon: const Icon(Icons.settings_outlined, size: 18),
          label: Text(
            s.t('Preferences', 'الإعدادات'),
            style: const TextStyle(fontSize: 12),
          ),
        ),
        const SizedBox(height: 10),
        const Divider(color: line),
        const SizedBox(height: 15),
        Row(
          children: [
            const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFEBEDDF),
              child: Text('AC', style: TextStyle(fontSize: 11, color: green)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t('Alex Carter', 'أليكس كارتر'),
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    s.t('Example crew profile', 'ملف طاقم توضيحي'),
                    style: const TextStyle(fontSize: 9, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    ),
  );
  Widget topbar(bool wide) => Container(
    height: 65,
    padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 18),
    decoration: const BoxDecoration(
      color: Color(0xFFFBFCF8),
      border: Border(bottom: BorderSide(color: line)),
    ),
    child: Row(
      children: [
        if (!wide) ...[
          const Icon(Icons.track_changes, size: 22, color: green),
          const SizedBox(width: 8),
        ],
        Text(
          wide ? 'Horizon / ${titles[page]}' : 'orbit.',
          style: TextStyle(
            fontSize: wide ? 12 : 20,
            fontWeight: wide ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (wide) Pill(s.t('LOCAL PROTOTYPE', 'نموذج محلي')),
        TextButton(
          onPressed: s.language,
          child: Text(
            s.arabic ? 'English' : 'العربية',
            style: const TextStyle(fontSize: 11),
          ),
        ),
        if (!wide)
          IconButton(
            onPressed: preferences,
            icon: const Icon(Icons.settings_outlined, size: 20),
            tooltip: s.t('Preferences', 'الإعدادات'),
          ),
        if (widget.onSignOut != null)
          IconButton(
            key: const ValueKey('sign-out'),
            onPressed: widget.onSignOut,
            icon: const Icon(Icons.logout, size: 20),
            tooltip: s.t('Sign out', 'تسجيل الخروج'),
          ),
      ],
    ),
  );
  Widget pageHeader() => LayoutBuilder(
    builder: (context, c) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Eyebrow(s.t('YOUR DAILY MISSION CHECK-IN', 'كل يوم خطوة لصحة أفضل')),
        const SizedBox(height: 9),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    page == 0
                        ? s.t(
                            'Your health. In perspective.',
                            'صحتك، في صورة أوضح.',
                          )
                        : titles[page],
                    style: TextStyle(
                      fontSize: c.maxWidth > 600 ? 30 : 25,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
                      letterSpacing: s.arabic ? 0 : -.8,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    [
                      s.t(
                        'A quiet moment to check in, before the day begins.',
                        'لحظة هادئة للاطمئنان على نفسك قبل بداية اليوم.',
                      ),
                      s.t(
                        'Small changes become clearer over time.',
                        'التغيّرات الصغيرة تصبح أوضح مع الوقت.',
                      ),
                      s.t(
                        'Your measurements, notes and daily check-ins.',
                        'قراءاتك وملاحظاتك وتسجيلاتك اليومية.',
                      ),
                      s.t(
                        'Understand what you measure, and why it matters.',
                        'افهم ما تقيسه ولماذا يهم أثناء الرحلة.',
                      ),
                    ][page],
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
            if (c.maxWidth > 600)
              FilledButton.icon(
                onPressed: () => showCheckIn(context, s),
                icon: const Icon(Icons.add, size: 17),
                label: Text(s.t('Log health check', 'تسجيل قراءة')),
              ),
          ],
        ),
        if (c.maxWidth <= 600) ...[
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => showCheckIn(context, s),
            icon: const Icon(Icons.add, size: 17),
            label: Text(s.t('Log health check', 'تسجيل قراءة')),
          ),
        ],
        const SizedBox(height: 18),
        Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 10,
          runSpacing: 8,
          children: [
            SegmentedButton<bool>(
              style: const ButtonStyle(
                visualDensity: VisualDensity.compact,
                textStyle: WidgetStatePropertyAll(
                  TextStyle(
                    fontSize: 11,
                    fontFamily: "OrbitSans",
                    fontFamilyFallback: ["OrbitArabic"],
                  ),
                ),
              ),
              segments: [
                ButtonSegment(
                  value: true,
                  label: Text(s.t('Demo data', 'بيانات تجريبية')),
                ),
                ButtonSegment(
                  value: false,
                  label: Text(s.t('My journal', 'سجلي')),
                ),
              ],
              selected: {s.demo},
              onSelectionChanged: (v) => s.setDemo(v.first),
            ),
            Text(
              s.demo
                  ? s.t(
                      'Simulated readings · no live sensors',
                      'قراءات محاكاة · لا يوجد اتصال بأجهزة قياس',
                    )
                  : s.t(
                      'Manual measurements · local to this device',
                      'قراءات يدوية · محفوظة على هذا الجهاز',
                    ),
              style: const TextStyle(color: muted, fontSize: 10),
            ),
          ],
        ),
      ],
    ),
  );
  Widget heading(String title, {Widget? trailing}) => Padding(
    padding: const EdgeInsets.only(bottom: 17),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
        ?trailing,
      ],
    ),
  );
  Widget overview() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        padding: const EdgeInsets.all(17),
        decoration: BoxDecoration(
          color: pale,
          border: Border.all(color: const Color(0xFFDDE6D4)),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const CircleAvatar(
              radius: 17,
              backgroundColor: Color(0xFFDDE8D4),
              child: Icon(Icons.spa_outlined, size: 19, color: green),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.latest == null
                        ? s.t(
                            'Start with a small check-in.',
                            'ابدأ بقراءة بسيطة.',
                          )
                        : s.stale
                        ? s.t(
                            'It is time for a fresh check-in.',
                            'حان وقت تسجيل قراءة جديدة.',
                          )
                        : s.flagged.isEmpty
                        ? s.t(
                            'Latest readings are within your set targets.',
                            'آخر القراءات داخل النطاقات المحددة.',
                          )
                        : s.t(
                            '${s.flagged.length} indicator(s) to review today.',
                            '${s.flagged.length} مؤشر يحتاج مراجعة اليوم.',
                          ),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    s.t(
                      'Targets are illustrative, not a medical assessment.',
                      'النطاقات توضيحية، وليست تقييمًا طبيًا.',
                    ),
                    style: const TextStyle(fontSize: 11, color: muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 24),
      heading(
        s.t('Latest health check', 'آخر تسجيل صحي'),
        trailing: s.latest == null
            ? null
            : Flexible(
                child: Text(
                  stamp(s.latest!.time),
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ),
      ),
      LayoutBuilder(
        builder: (context, c) {
          final count = c.maxWidth > 960
              ? 3
              : c.maxWidth > 700
              ? 3
              : 2;
          return Wrap(
            spacing: 12,
            runSpacing: 12,
            children:
                [
                      Metric.heartRate,
                      Metric.systolic,
                      Metric.temperature,
                      Metric.glucose,
                      Metric.sleep,
                      Metric.mood,
                    ]
                    .map(
                      (m) => SizedBox(
                        width: (c.maxWidth - 12 * (count - 1)) / count,
                        child: metricCard(m),
                      ),
                    )
                    .toList(),
          );
        },
      ),
      const SizedBox(height: 21),
      BaselineCard(store: s, result: baseline),
      const SizedBox(height: 21),
      responsivePair(
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(
                s.t('The last 7 days', 'آخر ٧ أيام'),
                trailing: TextButton(
                  onPressed: () => setState(() => page = 1),
                  child: Text(
                    s.t('All trends', 'كل المؤشرات'),
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [Metric.heartRate, Metric.sleep]
                    .map(
                      (m) => ChoiceChip(
                        label: Text(
                          s.t(m.en, m.ar),
                          style: const TextStyle(fontSize: 11),
                        ),
                        selected: selected == m,
                        onSelected: (_) => setState(() => selected = m),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),
              TrendChart(
                entries: s.entries
                    .where(
                      (e) => !e.time.isBefore(
                        s.now().subtract(const Duration(days: 7)),
                      ),
                    )
                    .toList(),
                metric: selected,
                baselinePoints: baselinePoints(selected, 7),
                range: s.targets[selected]!,
                arabic: s.arabic,
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(s.t('Today’s routine', 'روتين اليوم')),
              Text(
                s.t(
                  'A little consistency goes a long way.',
                  'الاستمرارية تبدأ بخطوات صغيرة.',
                ),
                style: const TextStyle(fontSize: 11, color: muted),
              ),
              const SizedBox(height: 12),
              routine(
                'check',
                s.t('Morning health check', 'التسجيل الصحي الصباحي'),
                s.t('Record your measured vitals', 'سجّل المؤشرات التي قستها'),
                s.entries.any(
                  (e) => e.time.toIso8601String().substring(0, 10) == s.today,
                ),
                automatic: true,
              ),
              routine(
                'exercise',
                s.t('Movement & exercise', 'الحركة والتمرين'),
                s.t(
                  'Follow your assigned mission plan',
                  'اتبع خطة المهمة المحددة لك',
                ),
                s.taskDone('exercise'),
              ),
              routine(
                'rest',
                s.t('Make room for rest', 'وقت للراحة'),
                s.t(
                  'Review your sleep and wind down',
                  'راجع نومك واستعد للراحة',
                ),
                s.taskDone('rest'),
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value:
                    ((s.entries.any(
                              (e) =>
                                  e.time.toIso8601String().substring(0, 10) ==
                                  s.today,
                            )
                            ? 1
                            : 0) +
                        (s.taskDone('exercise') ? 1 : 0) +
                        (s.taskDone('rest') ? 1 : 0)) /
                    3,
                minHeight: 4,
                backgroundColor: pale,
                color: const Color(0xFF819B69),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 20),
      responsivePair(
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(s.t('Worth a closer look', 'يستحق المتابعة')),
              if (s.latest == null)
                Text(
                  s.t(
                    'Add a reading to see observations here.',
                    'أضف قراءة لتظهر الملاحظات هنا.',
                  ),
                  style: const TextStyle(color: muted, fontSize: 12),
                )
              else if (s.flagged.isEmpty)
                Text(
                  s.t(
                    'No target deviations in this check-in. Keep recording to follow changes.',
                    'لا توجد قراءات خارج النطاق المحدد في هذا التسجيل. واصل المتابعة لملاحظة التغيّرات.',
                  ),
                  style: const TextStyle(fontSize: 12, color: muted),
                )
              else
                ...s.flagged
                    .take(2)
                    .map(
                      (m) => Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: const BoxDecoration(
                            color: Color(0xFFFBF8F0),
                            border: BorderDirectional(
                              start: BorderSide(
                                color: Color(0xFFD6B879),
                                width: 3,
                              ),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.t(m.en, m.ar),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                observation(m),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: muted,
                                  height: 1.7,
                                ),
                              ),
                              const SizedBox(height: 8),
                              TextButton(
                                onPressed: () => detail(m),
                                child: Text(
                                  s.t('Review reading', 'مراجعة القراءة'),
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
              const SizedBox(height: 10),
              Text(
                s.t(
                  'If you feel unwell, follow the mission medical protocol and contact the responsible clinician.',
                  'إذا شعرت بأعراض، اتبع البروتوكول الطبي للمهمة وتواصل مع الطبيب المسؤول.',
                ),
                style: const TextStyle(color: muted, fontSize: 10),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(s.t('A note from the field guide', 'من دليل الرحلة')),
              const Icon(Icons.public, size: 29, color: Color(0xFF829568)),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'A different environment. The same you.',
                  'بيئة مختلفة، واهتمام مستمر.',
                ),
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.t(
                  'NASA groups the challenges of spaceflight into five hazards. Understanding them gives your daily check-ins context.',
                  'تقسم ناسا مخاطر الرحلات الفضائية إلى خمس فئات. فهمها يوضح أهمية المتابعة اليومية.',
                ),
                style: const TextStyle(fontSize: 12, color: muted, height: 1.8),
              ),
              const SizedBox(height: 13),
              TextButton(
                onPressed: () => setState(() => page = 3),
                child: Text(s.t('Explore the field guide', 'افتح دليل الرحلة')),
              ),
            ],
          ),
        ),
      ),
    ],
  );
  Widget responsivePair(Widget a, Widget b) => LayoutBuilder(
    builder: (context, c) => c.maxWidth >= 760
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(flex: 3, child: a),
              const SizedBox(width: 20),
              Expanded(flex: 2, child: b),
            ],
          )
        : Column(children: [a, const SizedBox(height: 16), b]),
  );
  Widget routine(
    String id,
    String title,
    String subtitle,
    bool checked, {
    bool automatic = false,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 28,
          height: 29,
          child: Checkbox(
            value: checked,
            onChanged: automatic ? null : (_) => s.toggleTask(id),
            activeColor: green,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 3),
              Text(
                automatic
                    ? s.t(
                        'Updates when you record a check-in',
                        'يتحدّث عند تسجيل قراءة',
                      )
                    : subtitle,
                style: const TextStyle(fontSize: 10, color: muted),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Widget metricCard(Metric metric) {
    final value = s.latest?.values[metric];
    final dia = s.latest?.values[Metric.diastolic];
    final warning =
        value != null &&
        (!s.targets[metric]!.contains(value) ||
            (metric == Metric.systolic &&
                dia != null &&
                !s.targets[Metric.diastolic]!.contains(dia)));
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: const BorderSide(color: line),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => detail(metric),
        child: Padding(
          padding: const EdgeInsets.all(17),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      metric == Metric.systolic
                          ? s.t('Blood pressure', 'ضغط الدم')
                          : s.t(metric.en, metric.ar),
                      style: const TextStyle(fontSize: 11, color: muted),
                    ),
                  ),
                  Icon(
                    metricIcons[metric],
                    size: 19,
                    color: const Color(0xFF8A9B7C),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: AlignmentDirectional.centerStart,
                child: Row(
                  textDirection: TextDirection.ltr,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value == null
                          ? '—'
                          : metric == Metric.systolic
                          ? '${metric.format(value)}/${dia == null ? '—' : dia.toInt()}'
                          : metric.format(value),
                      style: const TextStyle(
                        fontSize: 29,
                        fontWeight: FontWeight.w500,
                        letterSpacing: -1,
                      ),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      metric.unit,
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 13),
              Pill(
                value == null
                    ? s.t('Not recorded', 'غير مسجل')
                    : warning
                    ? s.t('Review target', 'راجع النطاق')
                    : s.t('Within target', 'داخل النطاق'),
                warning: warning,
              ),
              const SizedBox(height: 5),
              Text(
                s.stale
                    ? s.t('Needs a fresh check', 'يحتاج قراءة جديدة')
                    : s.t('Tap to review', 'اضغط للمراجعة'),
                style: const TextStyle(fontSize: 9, color: muted),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String observation(Metric m) {
    final v = s.latest?.values[m];
    if (v == null)
      return s.t('Not recorded in this check-in.', 'غير مسجل في هذا التسجيل.');
    final range = s.targets[m]!;
    return s.t(
      '${m.format(v)} ${m.unit}; your illustrative target is ${m.format(range.low)}–${m.format(range.high)}. Recheck the measurement and compare with your mission plan.',
      'القراءة ${m.format(v)} ${m.unit}، والنطاق التوضيحي المحدد ${m.format(range.low)}–${m.format(range.high)}. أعد التحقق من القياس وقارنه بخطة المهمة.',
    );
  }

  Future<void> detail(Metric metric) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          metric == Metric.systolic
              ? s.t('Blood pressure', 'ضغط الدم')
              : s.t(metric.en, metric.ar),
        ),
        content: SizedBox(
          width: 520,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  observation(metric),
                  style: const TextStyle(fontSize: 13, height: 1.7),
                ),
                if (metric == Metric.systolic) ...[
                  const SizedBox(height: 8),
                  Text(
                    observation(Metric.diastolic),
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  measurementHelp(metric),
                  style: const TextStyle(
                    fontSize: 12,
                    color: muted,
                    height: 1.8,
                  ),
                ),
                const SizedBox(height: 15),
                TrendChart(
                  entries: s.entries,
                  metric: metric,
                  baselinePoints: baselinePoints(metric, 36500),
                  range: s.targets[metric]!,
                  arabic: s.arabic,
                ),
                const SizedBox(height: 18),
                Text(
                  s.t(
                    'Prototype targets are not diagnostic limits. The source material does not prescribe these numeric ranges.',
                    'النطاقات في النموذج ليست حدودًا تشخيصية، والمصادر لا تحدد هذه القيم الرقمية.',
                  ),
                  style: const TextStyle(fontSize: 10, color: muted),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(s.t('Close', 'إغلاق')),
          ),
        ],
      ),
    );
  }

  String measurementHelp(Metric m) => switch (m) {
    Metric.heartRate => s.t(
      'Record the reading from your approved monitor at rest. Note recent activity. Gravity changes can affect cardiovascular function. Source: NASA Risks.',
      'سجّل القراءة من جهاز القياس المعتمد أثناء الراحة، ودوّن أي نشاط سابق. تغير الجاذبية قد يؤثر على القلب والدورة الدموية. المصدر: مخاطر ناسا.',
    ),
    Metric.systolic || Metric.diastolic => s.t(
      'Use the approved cuff and mission measurement procedure. Record both values. Source: NASA Risks, cardiovascular adaptations.',
      'استخدم جهاز الضغط المعتمد واتبع إجراء القياس الخاص بالمهمة. سجّل القيمتين. المصدر: ناسا، تغيّرات القلب والدورة الدموية.',
    ),
    Metric.temperature => s.t(
      'Use a thermometer and record the measurement site in your notes. A temperature reading alone cannot assess immune health. Source: NASA Risks.',
      'استخدم ميزان حرارة وسجّل موضع القياس في الملاحظات. الحرارة وحدها لا تقيّم صحة المناعة. المصدر: مخاطر ناسا.',
    ),
    Metric.glucose => s.t(
      'Record a reading from an approved meter. Note whether it was before or after a meal. No glucose value is inferred from symptoms. Source: challenge indicators; NASA nutrition risks.',
      'سجّل قراءة من جهاز معتمد ودوّن توقيتها بالنسبة للوجبات. لا يستنتج التطبيق السكر من الأعراض. المصدر: مؤشرات التحدي ومخاطر التغذية لدى ناسا.',
    ),
    Metric.sleep => s.t(
      'Record actual sleep duration, not just time in bed. ARCHeR studies sleep, activity and well-being in space. Source: Ongoing HRP Research.',
      'سجّل ساعات النوم الفعلية، وليس الوقت في السرير فقط. تدرس ARCHeR النوم والنشاط والعافية في الفضاء. المصدر: أبحاث HRP.',
    ),
    Metric.mood => s.t(
      'Choose 1 (very low) to 5 (great). This is a simple self-report, not a validated mental-health questionnaire. Isolation can affect well-being. Source: NASA Hazards.',
      'اختر من ١ (منخفضة جدًا) إلى ٥ (ممتازة). هذا تقييم ذاتي بسيط وليس استبيانًا نفسيًا معتمدًا. العزلة قد تؤثر على العافية. المصدر: مخاطر ناسا.',
    ),
  };
  Widget trends() {
    final filtered = s.entries
        .where((e) => !e.time.isBefore(s.now().subtract(Duration(days: days))))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selected == Metric.heartRate) ...[
          BaselineCard(store: s, result: baseline),
          const SizedBox(height: 18),
        ],
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 14,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  DropdownButton<Metric>(
                    value: selected,
                    items: Metric.values
                        .map(
                          (m) => DropdownMenuItem(
                            value: m,
                            child: Text(
                              s.t(m.en, m.ar),
                              style: const TextStyle(fontSize: 13),
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => selected = v!),
                  ),
                  SegmentedButton<int>(
                    segments: [
                      ButtonSegment(
                        value: 7,
                        label: Text(s.t('7 days', '٧ أيام')),
                      ),
                      ButtonSegment(
                        value: 30,
                        label: Text(s.t('30 days', '٣٠ يومًا')),
                      ),
                      ButtonSegment(
                        value: 90,
                        label: Text(s.t('90 days', '٩٠ يومًا')),
                      ),
                    ],
                    selected: {days},
                    onSelectionChanged: (v) => setState(() => days = v.first),
                    style: const ButtonStyle(
                      textStyle: WidgetStatePropertyAll(
                        TextStyle(
                          fontSize: 11,
                          fontFamily: "OrbitSans",
                          fontFamilyFallback: ["OrbitArabic"],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              TrendChart(
                entries: filtered,
                metric: selected,
                baselinePoints: baselinePoints(selected, days),
                range: s.targets[selected]!,
                arabic: s.arabic,
                height: 240,
              ),
              const SizedBox(height: 18),
              Text(
                s.t(
                  'Each point is a recorded measurement. Gaps do not imply continuous monitoring.',
                  'كل نقطة تمثل قياسًا مسجلًا؛ الخط لا يعني وجود مراقبة مستمرة.',
                ),
                style: const TextStyle(fontSize: 11, color: muted),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              heading(s.t('Recorded values', 'القراءات المسجلة')),
              ...filtered
                  .where((e) => e.values.containsKey(selected))
                  .map(
                    (e) => ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        stamp(e.time),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 12),
                      ),
                      trailing: Text(
                        '${selected.format(e.values[selected]!)} ${selected.unit}',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                      subtitle: Text(
                        e.demo
                            ? s.t('Simulated', 'محاكاة')
                            : s.t('Manual entry', 'إدخال يدوي'),
                        style: const TextStyle(fontSize: 10, color: muted),
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }

  Widget journal() => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        heading(
          s.t('${s.entries.length} check-ins', '${s.entries.length} تسجيلات'),
          trailing: OutlinedButton.icon(
            onPressed: export,
            icon: const Icon(Icons.ios_share, size: 15),
            label: Text(
              s.t('Export', 'تصدير'),
              style: const TextStyle(fontSize: 11),
            ),
          ),
        ),
        if (s.entries.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 45),
            child: Center(
              child: Column(
                children: [
                  const Icon(Icons.edit_note, size: 42, color: muted),
                  const SizedBox(height: 10),
                  Text(s.t('Your journal starts here.', 'سجلك يبدأ من هنا.')),
                  const SizedBox(height: 8),
                  Text(
                    s.t(
                      'Add your first measured reading.',
                      'أضف أول قراءة قمت بقياسها.',
                    ),
                    style: const TextStyle(fontSize: 12, color: muted),
                  ),
                ],
              ),
            ),
          ),
        ...s.entries.map(
          (e) => ExpansionTile(
            key: ValueKey('${s.demo}-${e.id}'),
            tilePadding: EdgeInsets.zero,
            title: Text(
              stamp(e.time),
              textDirection: TextDirection.ltr,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
            ),
            subtitle: Text(
              '${e.values.length} ${s.t('indicators', 'مؤشرات')} · ${e.demo ? s.t('Simulated', 'محاكاة') : s.t('Manual', 'يدوي')}',
              style: const TextStyle(fontSize: 11, color: muted),
            ),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: e.values.entries
                          .map(
                            (v) => Chip(
                              label: Text(
                                '${s.t(v.key.en, v.key.ar)}: ${v.key.format(v.value)} ${v.key.unit}',
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: canvas,
                              side: const BorderSide(color: line),
                            ),
                          )
                          .toList(),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      s.t(
                        'Phase: ${e.phase.name} · Conditions: ${e.context.name} · Checked: ${e.verified} · Symptoms: ${e.hasSymptoms}',
                        'المرحلة: ${['غير محددة', 'قبل الرحلة', 'أثناء الرحلة', 'بعد العودة'][e.phase.index]} · القياس: ${['غير محدد', 'راحة', 'بعد تمرين'][e.context.index]} · مراجَع: ${e.verified ? 'نعم' : 'لا'} · أعراض: ${e.hasSymptoms ? 'نعم' : 'لا'}',
                      ),
                      style: const TextStyle(fontSize: 10, color: muted),
                    ),
                    if (e.notes.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      SelectableText(
                        e.notes,
                        style: const TextStyle(fontSize: 12, height: 1.7),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
  Future<void> openSource(String url) async {
    try {
      if (!await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      ))
        throw StateError('launch');
    } catch (_) {
      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.t('Open this source', 'افتح هذا المصدر')),
          content: SelectableText(url, textDirection: TextDirection.ltr),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(s.t('Close', 'إغلاق')),
            ),
          ],
        ),
      );
    }
  }

  Widget guide() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      heading(
        s.t(
          'The five hazards, in daily life',
          'المخاطر الخمسة في الحياة اليومية',
        ),
      ),
      ...List.generate(5, (i) {
        final en = [
          'Space radiation',
          'Isolation & confinement',
          'Distance from Earth',
          'Gravity fields',
          'Hostile / closed environments',
        ][i];
        final ar = [
          'الإشعاع الفضائي',
          'العزلة والأماكن المحدودة',
          'البعد عن الأرض',
          'تغيّر الجاذبية',
          'البيئة المغلقة والمعادية',
        ][i];
        final enBody = [
          'Radiation exposure requires a dedicated dosimeter. This app has no radiation sensor and cannot estimate dose from pulse or symptoms.',
          'A daily mood and sleep journal can help you describe changes in well-being to your support team.',
          'Store check-ins locally and export a copy for an authorized medical handover. There is no automatic ground communication.',
          'Changes in gravity affect bones, muscles and circulation. Follow the mission’s approved exercise and measurement procedures.',
          'Cabin temperature, pressure, lighting and microbes all matter. Vitals alone cannot describe cabin safety. Follow environmental monitoring procedures.',
        ][i];
        final arBody = [
          'قياس التعرض للإشعاع يحتاج جهاز جرعات مخصصًا. التطبيق لا يحتوي على حساس إشعاع ولا يقدّر الجرعة من النبض أو الأعراض.',
          'سجل النوم والحالة النفسية يساعدك في وصف التغيّرات لفريق الدعم.',
          'احفظ التسجيلات محليًا وصدّر نسخة عند تسليمها للفريق الطبي المصرّح له. لا يوجد إرسال تلقائي إلى الأرض.',
          'تغيّر الجاذبية يؤثر على العظام والعضلات والدورة الدموية. اتبع إجراءات القياس والتمرين المعتمدة للمهمة.',
          'حرارة المقصورة وضغطها وإضاءتها والميكروبات مهمة. المؤشرات الصحية وحدها لا تصف أمان المقصورة؛ اتبع إجراءات رصد البيئة.',
        ][i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Panel(
            padding: const EdgeInsets.symmetric(horizontal: 19, vertical: 5),
            child: ExpansionTile(
              tilePadding: EdgeInsets.zero,
              leading: Text(
                '0${i + 1}',
                style: const TextStyle(color: muted, fontSize: 12),
              ),
              title: Text(s.t(en, ar), style: const TextStyle(fontSize: 14)),
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 18),
                  child: Text(
                    s.t(enBody, arBody),
                    style: const TextStyle(
                      color: muted,
                      fontSize: 12,
                      height: 1.9,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }),
      const SizedBox(height: 25),
      heading(
        s.t('Built on the challenge’s resources', 'مبني على مصادر التحدي'),
      ),
      Text(
        s.t(
          'These are the five sources listed on the official Resources tab. They inform the design, not the illustrative numerical targets.',
          'هذه هي المصادر الخمسة المدرجة في تبويب مصادر التحدي. استُخدمت في تصميم التجربة، وليس لتحديد النطاقات الرقمية التوضيحية.',
        ),
        style: const TextStyle(fontSize: 12, color: muted, height: 1.8),
      ),
      const SizedBox(height: 18),
      LayoutBuilder(
        builder: (context, c) {
          final count = c.maxWidth > 700 ? 2 : 1;
          return Wrap(
            spacing: 16,
            runSpacing: 16,
            children: resources
                .map(
                  (r) => SizedBox(
                    width: (c.maxWidth - 16 * (count - 1)) / count,
                    child: Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Eyebrow(r.agency),
                          const SizedBox(height: 12),
                          Text(
                            s.t(r.en, r.ar),
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s.t(r.descriptionEn, r.descriptionAr),
                            style: const TextStyle(
                              fontSize: 12,
                              color: muted,
                              height: 1.8,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            s.t(r.useEn, r.useAr),
                            style: const TextStyle(fontSize: 11, height: 1.8),
                          ),
                          const SizedBox(height: 10),
                          TextButton.icon(
                            onPressed: () => openSource(r.url),
                            icon: const Icon(Icons.open_in_new, size: 15),
                            label: Text(
                              s.t(
                                'Read official source',
                                'قراءة المصدر الرسمي',
                              ),
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                )
                .toList(),
          );
        },
      ),
      const SizedBox(height: 20),
      TextButton.icon(
        onPressed: () => openSource(
          'https://www.spaceappschallenge.org/2026/challenges/health-monitoring-software/?tab=resources',
        ),
        icon: const Icon(Icons.link),
        label: Text(
          s.t(
            'Original challenge & resource list',
            'التحدي الأصلي وقائمة المصادر',
          ),
        ),
      ),
    ],
  );
}
