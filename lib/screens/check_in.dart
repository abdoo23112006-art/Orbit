import 'package:flutter/material.dart';

import '../health.dart';
import '../main.dart';
import 'widgets.dart';

Future<void> showCheckIn(BuildContext context, HealthStore store) => showDialog(
  context: context,
  builder: (_) => CheckInDialog(store: store),
);

class CheckInDialog extends StatefulWidget {
  final HealthStore store;
  const CheckInDialog({super.key, required this.store});
  @override
  State<CheckInDialog> createState() => _CheckInDialogState();
}

class _CheckInDialogState extends State<CheckInDialog> {
  final form = GlobalKey<FormState>();
  final fields = {for (final m in Metric.values) m: TextEditingController()};
  final notes = TextEditingController();
  late DateTime time = widget.store.now();
  bool saving = false;
  MissionPhase phase = MissionPhase.unspecified;
  MeasurementContext measurementContext = MeasurementContext.unspecified;
  bool verified = false, hasSymptoms = false;
  String? failure;
  HealthStore get s => widget.store;
  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    notes.dispose();
    super.dispose();
  }

  String? validate(Metric metric, String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final value = double.tryParse(normalize(raw));
    if (value == null || !value.isFinite)
      return s.t('Enter a number', 'أدخل رقمًا صحيحًا');
    if (value < metric.minimum || value > metric.maximum)
      return '${metric.minimum} – ${metric.maximum}';
    if (metric == Metric.mood && value != value.roundToDouble())
      return s.t(
        'Choose a whole number from 1 to 5',
        'اختر عددًا صحيحًا من ١ إلى ٥',
      );
    return null;
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final values = <Metric, double>{};
    for (final item in fields.entries) {
      if (item.value.text.trim().isNotEmpty)
        values[item.key] = double.parse(normalize(item.value.text));
    }
    if (values.isEmpty) {
      setState(
        () => failure = s.t(
          'Add at least one measurement.',
          'أضف قراءة واحدة على الأقل.',
        ),
      );
      return;
    }
    if (values.containsKey(Metric.systolic) !=
        values.containsKey(Metric.diastolic)) {
      setState(
        () => failure = s.t(
          'Enter both blood pressure values.',
          'أدخل قيمتَي ضغط الدم معًا.',
        ),
      );
      return;
    }
    if (values.containsKey(Metric.systolic) &&
        values[Metric.systolic]! <= values[Metric.diastolic]!) {
      setState(
        () => failure = s.t(
          'Systolic pressure must exceed diastolic pressure.',
          'الضغط الانقباضي يجب أن يكون أكبر من الانبساطي.',
        ),
      );
      return;
    }
    if (time.isAfter(s.now())) {
      setState(
        () => failure = s.t(
          'The check-in time cannot be in the future.',
          'لا يمكن تسجيل قراءة في المستقبل.',
        ),
      );
      return;
    }
    setState(() {
      saving = true;
      failure = null;
    });
    final ok = await s.add(
      HealthEntry(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        time: time,
        values: values,
        notes: notes.text.trim(),
        phase: phase,
        context: measurementContext,
        verified: verified,
        hasSymptoms: hasSymptoms,
      ),
    );
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.t(
              'Check-in saved on this device.',
              'تم حفظ القراءة على هذا الجهاز.',
            ),
          ),
        ),
      );
    } else {
      setState(() {
        saving = false;
        failure = s.t(
          'Could not save. Your input is still here; try again.',
          'تعذر الحفظ. بياناتك ما زالت هنا؛ حاول مرة أخرى.',
        );
      });
    }
  }

  Future<void> pickTime() async {
    final current = s.now();
    final date = await showDatePicker(
      context: context,
      initialDate: time,
      firstDate: DateTime(2020),
      lastDate: current,
    );
    if (date == null || !mounted) return;
    final clock = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(time),
    );
    if (clock != null)
      setState(
        () => time = DateTime(
          date.year,
          date.month,
          date.day,
          clock.hour,
          clock.minute,
        ),
      );
  }

  @override
  Widget build(BuildContext context) => Dialog(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 640),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Eyebrow('HEALTH JOURNAL'),
                        const SizedBox(height: 6),
                        Text(
                          s.t('Log a health check', 'سجّل حالتك الصحية'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: saving ? null : () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: s.t('Close', 'إغلاق'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                s.t(
                  'Only enter measurements you have taken. Empty fields remain unrecorded.',
                  'أدخل القياسات التي أخذتها فقط. يمكنك ترك باقي الحقول فارغة.',
                ),
                style: const TextStyle(fontSize: 12, color: muted),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: saving ? null : pickTime,
                icon: const Icon(Icons.schedule, size: 17),
                label: Text(stamp(time), textDirection: TextDirection.ltr),
              ),
              const SizedBox(height: 20),
              DropdownButtonFormField<MissionPhase>(
                initialValue: phase,
                decoration: InputDecoration(
                  labelText: s.t('Mission phase', 'مرحلة المهمة'),
                ),
                items: MissionPhase.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          s.t(
                            [
                              'Not specified',
                              'Before flight',
                              'During flight',
                              'After return',
                            ][v.index],
                            [
                              'غير محددة',
                              'قبل الرحلة',
                              'أثناء الرحلة',
                              'بعد العودة',
                            ][v.index],
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: saving ? null : (v) => setState(() => phase = v!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MeasurementContext>(
                initialValue: measurementContext,
                decoration: InputDecoration(
                  labelText: s.t(
                    'Pulse measurement conditions',
                    'ظروف قياس النبض',
                  ),
                ),
                items: MeasurementContext.values
                    .map(
                      (v) => DropdownMenuItem(
                        value: v,
                        child: Text(
                          s.t(
                            [
                              'Not specified',
                              'At rest',
                              'After exercise',
                            ][v.index],
                            ['غير محددة', 'أثناء الراحة', 'بعد تمرين'][v.index],
                          ),
                        ),
                      ),
                    )
                    .toList(),
                onChanged: saving
                    ? null
                    : (v) => setState(() => measurementContext = v!),
              ),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: verified,
                onChanged: saving ? null : (v) => setState(() => verified = v!),
                title: Text(
                  s.t(
                    'I checked the measurement and its conditions',
                    'راجعت القياس وظروف تسجيله',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: hasSymptoms,
                onChanged: saving
                    ? null
                    : (v) => setState(() => hasSymptoms = v!),
                title: Text(
                  s.t(
                    'Symptoms or unusual discomfort reported',
                    'توجد أعراض أو شعور غير معتاد',
                  ),
                  style: const TextStyle(fontSize: 12),
                ),
              ),
              Text(
                s.t(
                  'The resting pulse reference uses only checked, symptom-free resting readings with a specified mission phase. Other readings are still saved.',
                  'مرجع نبض الراحة يستخدم القراءات المراجعة دون أعراض، مع تحديد مرحلة المهمة. باقي القراءات تُحفظ أيضًا.',
                ),
                style: const TextStyle(fontSize: 10, color: muted),
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, c) => Wrap(
                  spacing: 14,
                  runSpacing: 18,
                  children: Metric.values
                      .map(
                        (metric) => SizedBox(
                          width: c.maxWidth < 380
                              ? c.maxWidth
                              : (c.maxWidth - 14) / 2,
                          child: TextFormField(
                            controller: fields[metric],
                            enabled: !saving,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            textDirection: TextDirection.ltr,
                            decoration: InputDecoration(
                              labelText:
                                  '${s.t(metric.en, metric.ar)} · ${metric.unit}',
                              helperText: metric == Metric.mood
                                  ? s.t(
                                      '1 very low · 3 okay · 5 great',
                                      '١ منخفضة جدًا · ٣ متوسطة · ٥ ممتازة',
                                    )
                                  : null,
                            ),
                            validator: (value) => validate(metric, value),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: notes,
                enabled: !saving,
                maxLines: 3,
                maxLength: 1000,
                decoration: InputDecoration(
                  labelText: s.t('Notes / symptoms', 'ملاحظات أو أعراض'),
                  alignLabelWithHint: true,
                ),
              ),
              if (failure != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    failure!,
                    style: const TextStyle(color: Colors.red, fontSize: 12),
                  ),
                ),
              Text(
                s.t(
                  'Local prototype storage, not encrypted. Use non-sensitive test data.',
                  'حفظ محلي تجريبي غير مشفّر. استخدم بيانات اختبار غير حساسة.',
                ),
                style: const TextStyle(color: muted, fontSize: 10),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: saving ? null : save,
                  icon: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(s.t('Save check-in', 'حفظ القراءة')),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

String normalize(String raw) {
  const arabic = '٠١٢٣٤٥٦٧٨٩';
  var result = raw.trim().replaceAll('٫', '.').replaceAll(',', '.');
  for (var i = 0; i < 10; i++) {
    result = result.replaceAll(arabic[i], '$i');
  }
  return result;
}
