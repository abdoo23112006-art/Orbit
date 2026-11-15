import 'package:flutter/material.dart';

import '../health.dart';
import '../main.dart';
import '../services/cosmo_service.dart';

class _Turn {
  final String question;
  String? answer, error;
  _Turn(this.question);
}

class CosmoChatScreen extends StatefulWidget {
  final HealthStore store;
  final CosmoService? service;
  const CosmoChatScreen({super.key, required this.store, this.service});
  @override
  State<CosmoChatScreen> createState() => _CosmoChatScreenState();
}

class _CosmoChatScreenState extends State<CosmoChatScreen> {
  late final CosmoService service = widget.service ?? CosmoService();
  final question = TextEditingController();
  final scroll = ScrollController();
  final turns = <_Turn>[];
  bool busy = false;
  HealthStore get s => widget.store;
  @override
  void dispose() {
    question.dispose();
    scroll.dispose();
    if (widget.service == null) service.close();
    super.dispose();
  }

  void scrollDown() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && scroll.hasClients)
      scroll.animateTo(
        scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
      );
  });
  Future<void> send({int? retry}) async {
    if (busy || !service.configured) return;
    final prompt = retry == null ? question.text.trim() : turns[retry].question;
    if (prompt.isEmpty || prompt.length > 2000) return;
    FocusScope.of(context).unfocus();
    late final _Turn turn;
    setState(() {
      busy = true;
      if (retry == null) {
        turn = _Turn(prompt);
        turns.add(turn);
        question.clear();
      } else {
        turn = turns[retry];
        turn.error = null;
      }
    });
    scrollDown();
    try {
      final answer = await service.ask(prompt, arabic: s.arabic);
      if (mounted) setState(() => turn.answer = answer);
    } on CosmoException catch (error) {
      if (mounted) setState(() => turn.error = error.code);
    } catch (_) {
      if (mounted) setState(() => turn.error = 'connection');
    } finally {
      if (mounted) {
        setState(() => busy = false);
        scrollDown();
      }
    }
  }

  String errorText(String code) => switch (code) {
    'not_configured' => s.t(
      'The assistant is not connected yet.',
      'المساعد غير متصل حاليًا.',
    ),
    'provider_auth' => s.t(
      'The assistant could not connect to its provider.',
      'تعذر اتصال المساعد بمزوّد الخدمة.',
    ),
    'rate_limited' => s.t(
      'Too many requests. Wait a minute before retrying.',
      'طلبات كثيرة. انتظر دقيقة قبل إعادة المحاولة.',
    ),
    'timeout' => s.t(
      'The request took too long. You can retry.',
      'استغرق الطلب وقتًا طويلًا. يمكنك إعادة المحاولة.',
    ),
    'invalid_response' => s.t(
      'The assistant returned an unreadable reply.',
      'وصل رد غير صالح من المساعد.',
    ),
    _ => s.t(
      'Connection failed. Check the connection and try again.',
      'تعذر الاتصال. تحقق من الاتصال وحاول مرة أخرى.',
    ),
  };
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: s,
    builder: (context, _) => Scaffold(
      appBar: AppBar(
        title: Text(
          s.t('Ask COSMO', 'اسأل COSMO'),
          style: const TextStyle(fontSize: 18),
        ),
        actions: [
          TextButton(
            onPressed: s.language,
            child: Text(s.arabic ? 'English' : 'العربية'),
          ),
          if (turns.isNotEmpty)
            IconButton(
              onPressed: busy ? null : () => setState(() => turns.clear()),
              icon: const Icon(Icons.delete_outline),
              tooltip: s.t('Clear this conversation', 'مسح المحادثة الحالية'),
            ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(18, 8, 18, 10),
                  padding: const EdgeInsets.all(13),
                  decoration: BoxDecoration(
                    color: pale,
                    borderRadius: BorderRadius.circular(7),
                  ),
                  child: Text(
                    s.t(
                      'Educational AI answers can be wrong. Only your question is sent to COSMO; your readings and journal are not attached. Do not enter real health or identifying information. Each question is sent independently.',
                      'إجابات تعليمية قد تخطئ. يُرسل نص سؤالك فقط إلى COSMO دون قراءاتك أو سجلك. لا تدخل بيانات صحية حقيقية أو معلومات تعرّف بشخص. يُرسل كل سؤال بشكل مستقل.',
                    ),
                    style: const TextStyle(
                      fontSize: 11,
                      color: muted,
                      height: 1.7,
                    ),
                  ),
                ),
                if (!service.configured)
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 8,
                    ),
                    child: Text(
                      s.t(
                        'The assistant is not connected yet. Your health journal remains available.',
                        'المساعد غير متصل حاليًا. سجلك الصحي يظل متاحًا.',
                      ),
                      style: const TextStyle(fontSize: 12, color: amber),
                    ),
                  ),
                Expanded(
                  child: turns.isEmpty
                      ? ListView(
                          padding: const EdgeInsets.all(24),
                          children: [
                            const SizedBox(height: 20),
                            const Icon(
                              Icons.chat_bubble_outline,
                              size: 40,
                              color: green,
                            ),
                            const SizedBox(height: 18),
                            Text(
                              s.t(
                                'Understand your mission health.',
                                'افهم متابعة صحتك في الرحلة.',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 23,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              s.t(
                                'Ask about the indicators, NASA resources or how Orbit works.',
                                'اسأل عن المؤشرات ومصادر ناسا وطريقة عمل Orbit.',
                              ),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 12,
                                color: muted,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ...[
                              s.t(
                                'What does a dynamic personal baseline mean?',
                                'ما معنى المرجع الشخصي المتحرك؟',
                              ),
                              s.t(
                                'Why track sleep and mood in space?',
                                'لماذا نتابع النوم والحالة النفسية في الفضاء؟',
                              ),
                              s.t(
                                'Can heart rate measure radiation exposure?',
                                'هل يمكن قياس التعرض للإشعاع من نبض القلب؟',
                              ),
                            ].map(
                              (text) => Padding(
                                padding: const EdgeInsets.only(bottom: 10),
                                child: OutlinedButton(
                                  onPressed: () =>
                                      setState(() => question.text = text),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 10,
                                    ),
                                    child: Text(
                                      text,
                                      style: const TextStyle(fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.all(18),
                          itemCount: turns.length,
                          itemBuilder: (context, i) {
                            final turn = turns[i];
                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(15),
                                  margin: const EdgeInsetsDirectional.only(
                                    start: 30,
                                    bottom: 10,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pale,
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: SelectableText(
                                    turn.question,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      height: 1.7,
                                    ),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  margin: const EdgeInsetsDirectional.only(
                                    end: 25,
                                    bottom: 22,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    border: Border.all(color: line),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'COSMO',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: green,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 9),
                                      if (turn.answer != null)
                                        SelectableText(
                                          turn.answer!,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            height: 1.8,
                                          ),
                                        )
                                      else if (turn.error != null) ...[
                                        Text(
                                          errorText(turn.error!),
                                          style: const TextStyle(
                                            fontSize: 12,
                                            color: amber,
                                          ),
                                        ),
                                        TextButton(
                                          onPressed: busy
                                              ? null
                                              : () => send(retry: i),
                                          child: Text(
                                            s.t('Retry', 'إعادة المحاولة'),
                                          ),
                                        ),
                                      ] else
                                        const SizedBox(
                                          width: 17,
                                          height: 17,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                ),
                const Divider(height: 1, color: line),
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('cosmo-question'),
                          controller: question,
                          enabled: !busy,
                          maxLength: 2000,
                          minLines: 1,
                          maxLines: 3,
                          textInputAction: TextInputAction.newline,
                          decoration: InputDecoration(
                            hintText: s.t(
                              'Write an educational question…',
                              'اكتب سؤالًا تعليميًا…',
                            ),
                            counterStyle: const TextStyle(fontSize: 9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 9),
                      IconButton.filled(
                        key: const ValueKey('cosmo-send'),
                        onPressed: busy || !service.configured
                            ? null
                            : () => send(),
                        tooltip: s.t('Send question', 'إرسال السؤال'),
                        icon: const Icon(Icons.send_outlined),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
