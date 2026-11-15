import 'package:flutter/material.dart';

import '../health.dart';
import '../demo_access.dart';
import 'home.dart';
import 'login.dart';

/// Presentation-only demo gate. These public credentials are deliberately not
/// authentication or an access-control mechanism for stored health data.

class LoginGate extends StatefulWidget {
  final HealthStore store;
  const LoginGate({super.key, required this.store});

  @override
  State<LoginGate> createState() => _LoginGateState();
}

class _LoginGateState extends State<LoginGate> {
  bool signedIn = false;

  Future<bool> signIn(String email, String password) async {
    final accepted =
        email.trim().toLowerCase() == demoEmail && password == demoPassword;
    if (accepted && mounted) setState(() => signedIn = true);
    return accepted;
  }

  void signOut() {
    FocusManager.instance.primaryFocus?.unfocus();
    ScaffoldMessenger.of(context).clearSnackBars();
    setState(() => signedIn = false);
  }

  @override
  Widget build(BuildContext context) => signedIn
      ? HomeScreen(store: widget.store, onSignOut: signOut)
      : LoginScreen(store: widget.store, onSignIn: signIn, demoMode: true);
}
