import 'package:flutter/material.dart';

import '../baseline.dart';
import '../health.dart';
import '../main.dart';
import 'widgets.dart';

class BaselineCard extends StatelessWidget {
  final HealthStore store;
  final BaselineResult result;
  const BaselineCard({super.key, required this.store, required this.result});
  @override
  Widget build(BuildContext context) {
    final s = store, r = result;
    final status = switch (r.status) {
      BaselineStatus.collecting => s.t('Gathering days', 'جارٍ تكوين المرجع'),
      BaselineStatus.active => s.t('Tracking', 'متابعة التغيّر'),
      BaselineStatus.paused => s.t('Update skipped', 'تم تخطي التحديث'),
      BaselineStatus.frozen => s.t(
        'Frozen · review drift',
        'مجمّد · راجع التغيّر',
      ),
      BaselineStatus.stale => s.t('Needs fresh data', 'يحتاج بيانات حديثة'),
      BaselineStatus.unknownContext => s.t(
        'Add measurement context',
        'أضف ظروف القياس',
      ),
    };
    String number(double? v) => v == null ? '—' : v.toStringAsFixed(1);
    String signed(double? v) =>
        v == null ? '—' : '${v >= 0 ? '+' : ''}${v.toStringAsFixed(1)}';
    Widget value(String label, String amount, String unit) => SizedBox(
      width: 180,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: muted)),
          const SizedBox(height: 7),
          Text(
            '$amount $unit',
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 14,
            runSpacing: 10,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                s.t(
                  'Your evolving resting-pulse reference',
                  'مرجع نبض الراحة المتحرك',
                ),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Pill(
                status,
                warning:
                    r.status == BaselineStatus.frozen ||
                    r.status == BaselineStatus.stale,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 24,
            runSpacing: 18,
            children: [
              value(
                s.t('Current personal reference', 'المرجع الشخصي الحالي'),
                number(r.value),
                'bpm',
              ),
              value(
                s.t(
                  'Latest vs prior-day reference',
                  'آخر نبض مقابل المرجع السابق',
                ),
                signed(r.difference),
                'bpm',
              ),
              value(
                s.t('Original in-phase reference', 'مرجع بداية هذه المرحلة'),
                number(r.initialReference),
                'bpm',
              ),
              value(
                s.t(
                  'Preflight reference, if recorded',
                  'مرجع ما قبل الرحلة، إن سُجّل',
                ),
                number(r.preflightReference),
                'bpm',
              ),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            s.t(
              'Eligible days: ${r.eligibleDays} · Phase: ${['Unspecified', 'Preflight', 'Inflight', 'Postflight'][r.phase.index]}',
              'الأيام المؤهلة: ${r.eligibleDays} · المرحلة: ${['غير محددة', 'قبل الرحلة', 'أثناء الرحلة', 'بعد العودة'][r.phase.index]}',
            ),
            style: const TextStyle(fontSize: 11, color: muted),
          ),
          if (r.driftPercent != null) ...[
            const SizedBox(height: 6),
            Text(
              s.t(
                'Reference change since the original: ${signed(r.driftPercent)}%',
                'تغيّر المرجع عن بدايته: ${signed(r.driftPercent)}%',
              ),
              style: const TextStyle(fontSize: 11, color: muted),
            ),
          ],
          if (r.lastAcceptedAt != null) ...[
            const SizedBox(height: 6),
            Text(
              '${s.t('Last accepted measurement', 'آخر قياس مؤهل')}: ${stamp(r.lastAcceptedAt!)}',
              style: const TextStyle(fontSize: 10, color: muted),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            s.t(
              r.status == BaselineStatus.frozen
                  ? 'A daily value crossed the prototype drift guard. Updates stay frozen in this phase; review the measurements. This is not a diagnosis.'
                  : r.status == BaselineStatus.paused
                  ? 'Latest day was excluded: symptoms, out-of-target pulse or insufficient measurement context. Existing target alerts stay active.'
                  : r.status == BaselineStatus.unknownContext
                  ? 'Choose a mission phase, resting conditions and a checked measurement in your next check-in. Older readings are not assumed to be resting.'
                  : r.status == BaselineStatus.stale
                  ? 'The old estimate is displayed for reference only. Fresh qualifying days are needed before tracking resumes.'
                  : 'Seven qualifying days form the starting reference. Updates use one daily median. The latest comparison excludes its own day; it appears after a prior reference exists.',
              r.status == BaselineStatus.frozen
                  ? 'تجاوزت قيمة يومية حد التغيّر التجريبي. تظل التحديثات مجمّدة في هذه المرحلة لمراجعة القياسات. هذه ليست نتيجة تشخيصية.'
                  : r.status == BaselineStatus.paused
                  ? 'تم استبعاد آخر يوم بسبب أعراض أو نبض خارج النطاق أو نقص ظروف القياس. تنبيهات النطاقات الحالية تظل فعّالة.'
                  : r.status == BaselineStatus.unknownContext
                  ? 'حدد مرحلة المهمة والراحة ومراجعة القياس في التسجيل التالي. لا نفترض أن القراءات القديمة أُخذت أثناء الراحة.'
                  : r.status == BaselineStatus.stale
                  ? 'المرجع القديم ظاهر للمقارنة فقط. يحتاج الحساب أيامًا مؤهلة حديثة قبل استئناف المتابعة.'
                  : 'يتكوّن المرجع بعد ٧ أيام مؤهلة، ويتحدّث بوسيط يومي واحد. مقارنة آخر نبض تستبعد يومه بالكامل، وتظهر بعد وجود مرجع سابق.',
            ),
            style: const TextStyle(fontSize: 11, height: 1.7, color: muted),
          ),
          const SizedBox(height: 9),
          Text(
            s.t(
              'Research prototype · EWMA α=0.1 · 10% drift guard · 14-day gap limit. These settings are engineering choices, not NASA or medical thresholds.',
              'نموذج بحثي · معامل تحديث 0.1 · حد تغيّر 10% · حد فجوة 14 يومًا. هذه إعدادات هندسية تجريبية وليست حدودًا معتمدة من ناسا أو حدودًا طبية.',
            ),
            style: const TextStyle(fontSize: 10, height: 1.7, color: muted),
          ),
        ],
      ),
    );
  }
}
