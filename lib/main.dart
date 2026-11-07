import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

import 'ui/sequencer_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
  ));
  runApp(const BeatGoApp());
}

/// Palette lifted from the design reference (design/refs).
class Bg {
  static const base = Color(0xFF0E0E10);
  static const lane = Color(0xFF1B1B1F);
  static const laneAlt = Color(0xFF212126);
  static const line = Color(0xFF2E2E34);
  static const text = Color(0xFFF1F0EC);
  static const muted = Color(0xFF8E8E96);
  static const lime = Color(0xFFC9E552);
  static const limeDim = Color(0xFF6E7D2D);
  static const playhead = Color(0xFFFFFFFF);
}

class BeatGoApp extends StatelessWidget {
  const BeatGoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'BeatGo',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: Bg.base,
        colorScheme: base.colorScheme.copyWith(
          primary: Bg.lime,
          surface: Bg.base,
          onSurface: Bg.text,
        ),
        textTheme: GoogleFonts.interTextTheme(base.textTheme).apply(
          bodyColor: Bg.text,
          displayColor: Bg.text,
        ),
      ),
      home: const SequencerScreen(),
    );
  }
}
