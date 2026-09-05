import 'package:flutter/material.dart';

import 'theme/astro_theme.dart';
import 'views/main_scaffold.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AstroTargetsApp());
}

class AstroTargetsApp extends StatefulWidget {
  const AstroTargetsApp({super.key});

  @override
  State<AstroTargetsApp> createState() => _AstroTargetsAppState();
}

class _AstroTargetsAppState extends State<AstroTargetsApp> {
  bool _isRedNightMode = false;

  void _toggleNightMode() {
    setState(() {
      _isRedNightMode = !_isRedNightMode;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Astro Targets Planner',
      debugShowCheckedModeBanner: false,
      theme: _isRedNightMode ? AstroTheme.redNightVisionTheme() : AstroTheme.darkTheme(),
      home: MainScaffold(
        isRedNightMode: _isRedNightMode,
        onToggleNightMode: _toggleNightMode,
      ),
    );
  }
}
