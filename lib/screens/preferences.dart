import 'package:flutter/material.dart';

import '../health.dart';
import '../main.dart';
import 'check_in.dart';
import 'widgets.dart';

class PreferencesDialog extends StatefulWidget {
  final HealthStore store;
  const PreferencesDialog({super.key, required this.store});
  @override
  State<PreferencesDialog> createState() => _PreferencesDialogState();
}

class _PreferencesDialogState extends State<PreferencesDialog> {
  HealthStore get s => widget.store;
  final form = GlobalKey<FormState>();
  late final low = {
    for (final m in Metric.values)
      m: TextEditingController(text: s.targets[m]!.low.toString()),
  };
  late final high = {
    for (final m in Metric.values)
      m: TextEditingController(text: s.targets[m]!.high.toString()),
  };
  bool saving = false;
  String? error;
  @override
  void dispose() {
    for (final c in [...low.values, ...high.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final next = {
      for (final m in Metric.values)
        m: TargetRange(
          double.parse(normalize(low[m]!.text)),
          double.parse(normalize(high[m]!.text)),
        ),
    };
    if (next.entries.any((e) => e.value.low >= e.value.high)) {
      setState(
        () => error = s.t(
          'Each lower value must be below the upper value.',
          'كل حد أدنى يجب أن يكون أقل من الحد الأعلى.',
        ),
      );
      return;
    }
    setState(() => saving = true);
    final ok = await s.setTargets(next);
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
    } else {
      setState(() {
        saving = false;
        error = s.t('Could not save. Try again.', 'تعذر الحفظ. حاول مرة أخرى.');
      });
    }
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      s.t('Preferences', 'الإعدادات'),
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: s.t('Close', 'إغلاق'),
                  ),
                ],
              ),
              const SizedBox(height: 15),
              const Eyebrow('LOCAL PROTOTYPE'),
              const SizedBox(height: 10),
              Text(
                s.t(
                  'Data stays in this app on this device. There is no account, cloud sync or sensor connection. This prototype uses unencrypted preference storage and is not a medical record system.',
                  'البيانات محفوظة في التطبيق على هذا الجهاز. لا يوجد حساب أو مزامنة أو اتصال بحساسات. النموذج يستخدم حفظًا محليًا غير مشفر ولا يُعد نظامًا للسجلات الطبية.',
                ),
                style: const TextStyle(fontSize: 12, color: muted, height: 1.8),
              ),
              const SizedBox(height: 20),
              const Divider(color: line),
              const SizedBox(height: 15),
              Text(
                s.t('Illustrative target ranges', 'نطاقات متابعة توضيحية'),
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                s.t(
                  'These defaults demonstrate the interface only. They are not NASA thresholds and must be replaced by an approved mission plan before any real-world use. A target deviation is not a diagnosis.',
                  'القيم الافتراضية لعرض الفكرة فقط. ليست حدودًا معتمدة من ناسا، ويجب استبدالها بخطة طبية معتمدة قبل أي استخدام فعلي. الخروج عن النطاق ليس تشخيصًا.',
                ),
                style: const TextStyle(fontSize: 11, color: muted, height: 1.8),
              ),
              const SizedBox(height: 18),
              ...Metric.values.map(
                (m) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.t(m.en, m.ar)} · ${m.unit}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: targetInput(
                              m,
                              low[m]!,
                              s.t('Lower', 'الأدنى'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: targetInput(
                              m,
                              high[m]!,
                              s.t('Upper', 'الأعلى'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (error != null)
                Text(
                  error!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving ? null : save,
                  child: Text(s.t('Save target ranges', 'حفظ النطاقات')),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  Widget targetInput(
    Metric m,
    TextEditingController controller,
    String label,
  ) => TextFormField(
    controller: controller,
    enabled: !saving,
    textDirection: TextDirection.ltr,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      final n = double.tryParse(normalize(value ?? ''));
      if (n == null || !n.isFinite || n < m.minimum || n > m.maximum)
        return '${m.minimum} – ${m.maximum}';
      if (m == Metric.mood && n != n.roundToDouble())
        return s.t('Whole numbers only', 'أعداد صحيحة فقط');
      return null;
    },
  );
}
