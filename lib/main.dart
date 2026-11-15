import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'health.dart';
import 'screens/login_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final store = HealthStore();
  await store.load();
  runApp(OrbitApp(store: store));
}

const ink = Color(0xFF243E34),
    green = Color(0xFF2C604A),
    muted = Color(0xFF7A8377),
    line = Color(0xFFE2E7DD),
    canvas = Color(0xFFF6F7F2),
    pale = Color(0xFFEAF0E4),
    amber = Color(0xFF9A6C2F);

class OrbitApp extends StatelessWidget {
  final HealthStore store;
  const OrbitApp({super.key, required this.store});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: store,
    builder: (context, _) => MaterialApp(
      title: 'Orbit — Crew Health',
      debugShowCheckedModeBanner: false,
      locale: Locale(store.arabic ? 'ar' : 'en'),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: "OrbitSans",
        fontFamilyFallback: const ["OrbitArabic"],
        colorScheme: ColorScheme.fromSeed(
          seedColor: green,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: canvas,
        textTheme: ThemeData.light().textTheme.apply(
          bodyColor: ink,
          displayColor: ink,
          fontFamily: "OrbitSans",
          fontFamilyFallback: const ["OrbitArabic"],
        ),
        dividerColor: line,
        appBarTheme: const AppBarTheme(
          backgroundColor: canvas,
          surfaceTintColor: Colors.transparent,
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: green,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: ink,
            side: const BorderSide(color: line),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(7),
            ),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: canvas,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: line),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(7),
            borderSide: const BorderSide(color: line),
          ),
          labelStyle: const TextStyle(color: muted, fontSize: 13),
        ),
      ),
      home: LoginGate(store: store),
    ),
  );
}
