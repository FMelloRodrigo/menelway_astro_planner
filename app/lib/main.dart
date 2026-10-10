import 'package:flutter/material.dart';

import 'core/astro_bridge.dart';
import 'core/equipment_manager.dart';
import 'core/observing_site_manager.dart';
import 'core/settings_service.dart';
import 'l10n/app_localizations.dart';
import 'theme/astro_theme.dart';
import 'views/main_scaffold.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AstroBridge.registerAsDefault();
  final initialSettings = await SettingsService.loadSettings();
  EquipmentManager.instance.init(
    savedProfiles: initialSettings.equipmentProfiles,
    savedActiveId: initialSettings.activeEquipmentProfileId,
  );
  ObservingSiteManager.instance.init(
    savedSites: initialSettings.observingSites,
    savedActiveId: initialSettings.activeObservingSiteId,
    fallbackFilters: initialSettings.filters,
  );
  final activeSite = ObservingSiteManager.instance.activeSite;
  final resolvedFilters = initialSettings.filters.copyWith(
    observerLat: activeSite.latitude,
    observerLon: activeSite.longitude,
    observerElevation: activeSite.elevation,
    observerLocationName: activeSite.name,
  );
  final resolvedSettings = initialSettings.copyWith(filters: resolvedFilters);

  runApp(AstroTargetsApp(initialSettings: resolvedSettings));
}

class AstroTargetsApp extends StatefulWidget {
  final AppSettingsData? initialSettings;
  const AstroTargetsApp({super.key, this.initialSettings});

  @override
  State<AstroTargetsApp> createState() => _AstroTargetsAppState();
}

class _AstroTargetsAppState extends State<AstroTargetsApp> {
  late bool _isRedNightMode;
  Locale? _locale;

  @override
  void initState() {
    super.initState();
    _isRedNightMode = widget.initialSettings?.isRedNightMode ?? false;
    final lang = widget.initialSettings?.languageCode;
    if (lang != null && lang.isNotEmpty) {
      _locale = Locale(lang);
    }
  }

  void _toggleNightMode() {
    setState(() {
      _isRedNightMode = !_isRedNightMode;
    });
    SettingsService.saveNightMode(_isRedNightMode);
  }

  void _resetNightMode() {
    setState(() {
      _isRedNightMode = false;
    });
    SettingsService.saveNightMode(false);
  }

  void _changeLanguage(String? languageCode) {
    setState(() {
      _locale = (languageCode != null && languageCode.isNotEmpty)
          ? Locale(languageCode)
          : null;
    });
    SettingsService.saveLanguage(languageCode);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Menelway Astro Planner',
      debugShowCheckedModeBanner: false,
      locale: _locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: _isRedNightMode ? AstroTheme.redNightVisionTheme() : AstroTheme.darkTheme(),
      home: MainScaffold(
        isRedNightMode: _isRedNightMode,
        onToggleNightMode: _toggleNightMode,
        onResetNightMode: _resetNightMode,
        initialSettings: widget.initialSettings,
        currentLanguageCode: _locale?.languageCode,
        onChangeLanguage: _changeLanguage,
      ),
    );
  }
}

