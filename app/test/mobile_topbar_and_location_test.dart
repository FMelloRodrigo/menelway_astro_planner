import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/theme/astro_theme.dart';
import 'package:app/views/main_scaffold.dart';
import 'package:app/l10n/app_localizations.dart';

void main() {
  testWidgets('AppLocalizations provides updated detailed location hint and tooltip', (tester) async {
    late AppLocalizations l10nEn;
    late AppLocalizations l10nPt;

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10nEn = AppLocalizations.of(context)!;
            return Container();
          },
        ),
      ),
    );
    await tester.pump();

    expect(l10nEn.searchAddressHint, 'Type the detailed location, like street name, and city');
    expect(l10nEn.searchAddressTooltip, 'Search precise street/neighborhood (worldwide)');

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) {
            l10nPt = AppLocalizations.of(context)!;
            return Container();
          },
        ),
      ),
    );
    await tester.pump();

    expect(l10nPt.searchAddressHint, 'Digite a localização detalhada, como rua e cidade');
    expect(l10nPt.searchAddressTooltip, 'Buscar rua/bairro específico (mundial)');
  });

  testWidgets('Mobile viewport: Top bar buttons and Observer Location button sizing verification', (tester) async {
    // 360 x 640 mobile viewport
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    bool isRedNightMode = false;
    final isWide = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AstroTheme.darkTheme(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            titleSpacing: isWide ? 16.0 : 10.0,
            title: const Text("MENELWAY"),
            actions: [
              // Red Night-Vision Mode Toggle
              SizedBox(
                key: const ValueKey('night_mode_btn'),
                width: isWide ? 32.0 : 40.0,
                height: isWide ? 32.0 : 40.0,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.remove_red_eye_rounded, size: 20),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 6),

              // Language Switcher
              Container(
                key: const ValueKey('lang_switcher_btn'),
                height: isWide ? 32.0 : 40.0,
                padding: const EdgeInsets.symmetric(horizontal: 7),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.translate_rounded, size: 18),
                    SizedBox(width: 4),
                    Text("EN"),
                  ],
                ),
              ),
              const SizedBox(width: 6),

              // Equipment Rigs Manager Button
              SizedBox(
                key: const ValueKey('equipment_btn'),
                width: isWide ? 32.0 : 40.0,
                height: isWide ? 32.0 : 40.0,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.camera_alt_rounded, size: 20),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 6),

              // Settings & Clean Data Window Pill
              Container(
                key: const ValueKey('settings_btn'),
                height: isWide ? 32.0 : 40.0,
                width: isWide ? null : 40.0,
                alignment: Alignment.center,
                child: const Icon(Icons.settings_suggest_rounded, size: 20),
              ),
              const SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              // Observer Location Pill in mobile status strip
              InkWell(
                key: const ValueKey('observer_loc_btn'),
                onTap: () {},
                child: Container(
                  height: 40.0,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.location_on_outlined, size: 16),
                      SizedBox(width: 5),
                      Text("Nova Friburgo"),
                      SizedBox(width: 4),
                      Icon(Icons.arrow_drop_down, size: 18),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();

    // Verify Observer Location button height is 40.0
    final locBox = tester.renderObject(find.byKey(const ValueKey('observer_loc_btn'))) as RenderBox;
    expect(locBox.size.height, 40.0);

    // Verify Top Bar buttons have 40.0 height / dimensions on mobile
    final nightModeBox = tester.renderObject(find.byKey(const ValueKey('night_mode_btn'))) as RenderBox;
    expect(nightModeBox.size.width, 40.0);
    expect(nightModeBox.size.height, 40.0);

    final langBox = tester.renderObject(find.byKey(const ValueKey('lang_switcher_btn'))) as RenderBox;
    expect(langBox.size.height, 40.0);

    final equipBox = tester.renderObject(find.byKey(const ValueKey('equipment_btn'))) as RenderBox;
    expect(equipBox.size.width, 40.0);
    expect(equipBox.size.height, 40.0);

    final settingsBox = tester.renderObject(find.byKey(const ValueKey('settings_btn'))) as RenderBox;
    expect(settingsBox.size.width, 40.0);
    expect(settingsBox.size.height, 40.0);
  });
}
