import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'screens/home_page.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.instance.initialize();
  await NotificationService.instance.requestPermission();
  runApp(const WalletNotesApp());
}

/// Central palette & gradient definitions used across the whole app.
class AppTheme {
  AppTheme._();

  // ── Core brand ───────────────────────────────────────────────────
  static const Color primary = Color(0xFF22C55E); // vibrant green
  static const Color primaryDark = Color(0xFF1A5928); // deep forest green
  static const Color primaryDeep = Color(0xFF0A1A0E); // near-black dark green
  static const Color accent = Color(0xFF4ADE80); // bright light green

  // ── Semantic ─────────────────────────────────────────────────────
  static const Color income = Color(0xFF00C896); // vibrant teal-green
  static const Color expense = Color(0xFFFF6584); // vibrant pink-red

  // ── Surfaces ─────────────────────────────────────────────────────
  static const Color background = Color(0xFFF0FDF4); // soft green-white
  static const Color surface = Colors.white;

  // ── Text ─────────────────────────────────────────────────────────
  static const Color textPrimary = Color(0xFF0F1F14);
  static const Color textSecondary = Color(0xFF6B7C72);

  // ── Gradient ─────────────────────────────────────────────────────
  static const List<Color> headerGradient = [
    Color(0xFF0A1A0E), // near-black green
    Color(0xFF1A5928), // deep forest green
    Color(0xFF22C55E), // vibrant green
  ];

  static BoxDecoration get headerGradientDecoration => const BoxDecoration(
    gradient: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: headerGradient,
      stops: [0.0, 0.5, 1.0],
    ),
  );
}

class WalletNotesApp extends StatelessWidget {
  const WalletNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'WalletNotes',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppTheme.primary,
          brightness: Brightness.light,
        ),
        useMaterial3: true,
        scaffoldBackgroundColor: AppTheme.background,
        cardTheme: CardThemeData(
          elevation: 0,
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      home: const HomePage(),
    );
  }
}
