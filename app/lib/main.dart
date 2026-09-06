import 'package:flutter/material.dart';

import 'core/equipment_manager.dart';
import 'core/settings_service.dart';
import 'theme/astro_theme.dart';
import 'views/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final initialSettings = await SettingsService.loadSettings();
  EquipmentManager.instance.init(
    savedProfiles: initialSettings.equipmentProfiles,
    savedActiveId: initialSettings.activeEquipmentProfileId,
  );
  runApp(AstroTargetsApp(initialSettings: initialSettings));
}

class AstroTargetsApp extends StatefulWidget {
  final AppSettingsData? initialSettings;
  const AstroTargetsApp({super.key, this.initialSettings});

  @override
  State<AstroTargetsApp> createState() => _AstroTargetsAppState();
}

class _AstroTargetsAppState extends State<AstroTargetsApp> {
  late bool _isRedNightMode;

  @override
  void initState() {
    super.initState();
    _isRedNightMode = widget.initialSettings?.isRedNightMode ?? false;
  }

  void _toggleNightMode() {
    setState(() {
      _isRedNightMode = !_isRedNightMode;
    });
  }

  void _resetNightMode() {
    setState(() {
      _isRedNightMode = false;
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
        onResetNightMode: _resetNightMode,
        initialSettings: widget.initialSettings,
      ),
    );
  }
}
