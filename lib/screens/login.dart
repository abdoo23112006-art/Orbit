import 'package:flutter/material.dart';

import '../health.dart';
import '../demo_access.dart';
import '../main.dart';
import 'widgets.dart';

/// The form delegates authentication; a production app must use a server-backed
/// provider instead of treating form validation as authentication.
class LoginScreen extends StatefulWidget {
  final HealthStore store;
  final Future<bool> Function(String email, String password) onSignIn;
  final bool demoMode;
  const LoginScreen({
    super.key,
    required this.store,
    required this.onSignIn,
    required this.demoMode,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final form = GlobalKey<FormState>();
  final email = TextEditingController();
  final password = TextEditingController();
  bool obscure = true, busy = false;
  String? error;
  HealthStore get s => widget.store;

  @override
  void dispose() {
    email.dispose();
    password.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    if (busy || !form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final accepted = await widget.onSignIn(email.text.trim(), password.text);
      if (!mounted) return;
      if (!accepted) {
        password.clear();
        setState(() {
          busy = false;
          error = s.t(
            'Email or password is incorrect.',
            'الإيميل أو كلمة السر غير صحيحة.',
          );
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        busy = false;
        error = s.t(
          'Could not sign in. Please try again.',
          'تعذر تسجيل الدخول. حاول مرة أخرى.',
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= 1000;
          return Row(
            children: [
              if (wide) Expanded(child: _intro()),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: constraints.maxWidth < 400 ? 20 : 40,
                    vertical: 24,
                  ),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 410),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.track_changes,
                                size: 28,
                                color: green,
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'orbit.',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontSize: 30,
                                  fontWeight: FontWeight.w600,
                                  letterSpacing: -1,
                                ),
                              ),
                              const Spacer(),
                              TextButton(
                                onPressed: busy ? null : s.language,
                                child: Text(s.arabic ? 'English' : 'العربية'),
                              ),
                            ],
                          ),
                          SizedBox(height: wide ? 58 : 32),
                          Eyebrow(s.t('CREW ACCESS', 'دخول الطاقم')),
                          const SizedBox(height: 10),
                          Text(
                            s.t('Welcome back.', 'أهلًا بعودتك.'),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            s.t(
                              'Sign in to open your health journal.',
                              'سجّل الدخول للوصول إلى سجلك الصحي.',
                            ),
                            style: const TextStyle(
                              fontSize: 13,
                              color: muted,
                              height: 1.7,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Form(
                            key: form,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                TextFormField(
                                  key: const ValueKey('login-email'),
                                  controller: email,
                                  enabled: !busy,
                                  textDirection: TextDirection.ltr,
                                  keyboardType: TextInputType.emailAddress,
                                  textInputAction: TextInputAction.next,
                                  autocorrect: false,
                                  decoration: InputDecoration(
                                    labelText: s.t(
                                      'Email address',
                                      'البريد الإلكتروني',
                                    ),
                                    hintText: 'name@example.com',
                                    prefixIcon: const Icon(
                                      Icons.alternate_email,
                                      size: 19,
                                    ),
                                  ),
                                  validator: (value) {
                                    final raw = value?.trim() ?? '';
                                    if (raw.isEmpty)
                                      return s.t(
                                        'Enter your email address.',
                                        'أدخل البريد الإلكتروني.',
                                      );
                                    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                        .hasMatch(raw))
                                      return s.t(
                                        'Enter a valid email address.',
                                        'أدخل بريدًا إلكترونيًا صالحًا.',
                                      );
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 20),
                                TextFormField(
                                  key: const ValueKey('login-password'),
                                  controller: password,
                                  enabled: !busy,
                                  textDirection: TextDirection.ltr,
                                  obscureText: obscure,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  textInputAction: TextInputAction.done,
                                  onFieldSubmitted: (_) => signIn(),
                                  decoration: InputDecoration(
                                    labelText: s.t('Password', 'كلمة السر'),
                                    prefixIcon: const Icon(
                                      Icons.lock_outline,
                                      size: 19,
                                    ),
                                    suffixIcon: IconButton(
                                      onPressed: busy
                                          ? null
                                          : () => setState(
                                              () => obscure = !obscure,
                                            ),
                                      tooltip: obscure
                                          ? s.t(
                                              'Show password',
                                              'إظهار كلمة السر',
                                            )
                                          : s.t(
                                              'Hide password',
                                              'إخفاء كلمة السر',
                                            ),
                                      icon: Icon(
                                        obscure
                                            ? Icons.visibility_outlined
                                            : Icons.visibility_off_outlined,
                                        size: 19,
                                      ),
                                    ),
                                  ),
                                  validator: (value) =>
                                      (value == null || value.isEmpty)
                                      ? s.t(
                                          'Enter your password.',
                                          'أدخل كلمة السر.',
                                        )
                                      : null,
                                ),
                                if (error != null) ...[
                                  const SizedBox(height: 16),
                                  Semantics(
                                    liveRegion: true,
                                    child: Text(
                                      error!,
                                      style: const TextStyle(
                                        color: Color(0xFFA84536),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 26),
                                FilledButton(
                                  onPressed: busy ? null : signIn,
                                  child: busy
                                      ? const SizedBox(
                                          width: 20,
                                          height: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: Colors.white,
                                          ),
                                        )
                                      : Text(s.t('Sign in', 'تسجيل الدخول')),
                                ),
                              ],
                            ),
                          ),
                          if (widget.demoMode) ...[
                            const SizedBox(height: 24),
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: pale,
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    s.t('DEMO ACCESS', 'دخول تجريبي للعرض'),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: green,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  const SelectableText(
                                    '$demoEmail\n$demoPassword',
                                    textDirection: TextDirection.ltr,
                                    style: TextStyle(fontSize: 12, height: 1.8),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    s.t(
                                      'A shared demo account. This screen does not secure or separate device data.',
                                      'حساب تجريبي مشترك. الصفحة لا تحمي بيانات الجهاز أو تفصلها بين أشخاص.',
                                    ),
                                    style: const TextStyle(
                                      fontSize: 10,
                                      color: muted,
                                      height: 1.7,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 32),
                          Text(
                            s.t(
                              'Space Apps 2026 · Crew health prototype',
                              'Space Apps 2026 · نموذج متابعة صحة الطاقم',
                            ),
                            style: const TextStyle(fontSize: 10, color: muted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    ),
  );

  Widget _intro() => Container(
    color: green,
    padding: const EdgeInsets.all(60),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.track_changes, size: 76, color: Color(0xFFCBDFCF)),
        const SizedBox(height: 34),
        Text(
          s.t(
            'A little perspective.\nEvery mission day.',
            'صحتك في صورة أوضح.\nفي كل يوم من الرحلة.',
          ),
          style: const TextStyle(
            fontSize: 37,
            color: Colors.white,
            height: 1.5,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 22),
        Text(
          s.t(
            'Track your readings, follow your personal reference, and keep your daily check-ins together.',
            'سجّل قراءاتك، وتابع مرجعك الشخصي المتحرك، واحتفظ بتسجيلاتك اليومية في مكان واحد.',
          ),
          style: const TextStyle(
            fontSize: 14,
            color: Color(0xFFD7E4D8),
            height: 1.9,
          ),
        ),
        const SizedBox(height: 35),
        ...[
          s.t('Measured readings, clearly presented', 'قراءات مسجلة وعرض واضح'),
          s.t('An evolving resting-pulse reference', 'مرجع متحرك لنبض الراحة'),
          s.t('A simple daily health journal', 'سجل صحي يومي بسيط'),
        ].map(
          (text) => Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  size: 18,
                  color: Color(0xFFCBDFCF),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}
