import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/settings_service.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/l10n/l10n_helpers.dart';
import 'package:app/models/filter_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Localization (l10n) Tests', () {
    test('Supported locales include English and Portuguese', () {
      final locales = AppLocalizations.supportedLocales;
      expect(locales.map((l) => l.languageCode), containsAll(['en', 'pt']));
    });

    testWidgets('AppLocalizations loads English strings correctly', (WidgetTester tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Container();
            },
          ),
        ),
      );

      expect(l10n.tabTargets, 'Targets');
      expect(l10n.tabPlanner, 'Planner');
      expect(l10n.tabObservingLists, 'Observing Lists');
      expect(l10n.tabFavorites, 'Favorites');
      expect(l10n.filtersButton, 'Filters');
      expect(l10n.cleanDataConfirmTitle, 'Clear All Saved Data?');
      expect(l10n.objGalaxy, 'Galaxy');
      expect(l10n.objPlanetaryNebula, 'Planetary Nebula');

      // Filter Window Keys
      expect(l10n.observingTimeWindow, 'Observing Time Window');
      expect(l10n.astronomicalDarkness, 'Astronomical Darkness');
      expect(l10n.visibilityAltitudeRange, 'Visibility & Altitude Range');
      expect(l10n.directionAzimuthRange, 'Direction & Azimuth Range');
      expect(l10n.customHorizonMask, 'Custom Horizon Obstruction Mask');
      expect(l10n.moonDistance, 'Moon Distance');
      expect(l10n.magnitudeApparentSize, 'Magnitude & Apparent Size');

      // Settings Keys
      expect(l10n.settingsAndData, 'Settings & Data');
      expect(l10n.settingsLocation, 'Observer Location...');
      expect(l10n.resetFilters, 'Reset Target Filters');
      expect(l10n.cleanData, 'Clean All Saved Data...');

      // Equipment Keys
      expect(l10n.equipmentDialogTitle, 'Equipment Rigs & Optics');
      expect(l10n.equipmentRigsButton, 'Equipment Rigs');
      expect(l10n.gearButton, 'Gear');
      expect(l10n.framingSimulatorTitle, 'Equipment Framing Simulator');
      expect(l10n.telescopeOptics, 'Telescope / Optics');
      expect(l10n.cameraSensor, 'Camera / Sensor');
      expect(l10n.computedOpticalSpecs, 'Computed Optical Specifications');
    });

    testWidgets('AppLocalizations loads Portuguese strings correctly', (WidgetTester tester) async {
      late AppLocalizations l10n;

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              l10n = AppLocalizations.of(context)!;
              return Container();
            },
          ),
        ),
      );

      expect(l10n.tabTargets, 'Alvos');
      expect(l10n.tabPlanner, 'Planejador');
      expect(l10n.tabObservingLists, 'Listas de Observação');
      expect(l10n.tabFavorites, 'Favoritos');
      expect(l10n.filtersButton, 'Filtros');
      expect(l10n.cleanDataConfirmTitle, 'Limpar Todos os Dados Salvos?');
      expect(l10n.objGalaxy, 'Galáxia');
      expect(l10n.objPlanetaryNebula, 'Nebulosa Planetária');
      expect(l10n.objOpenCluster, 'Aglomerado Aberto');
      expect(l10n.objGlobularCluster, 'Aglomerado Globular');

      // Filter Window Keys (PT-BR)
      expect(l10n.observingTimeWindow, 'Janela de Tempo de Observação');
      expect(l10n.astronomicalDarkness, 'Escuridão Astronômica');
      expect(l10n.visibilityAltitudeRange, 'Visibilidade e Faixa de Altitude');
      expect(l10n.directionAzimuthRange, 'Direção e Faixa de Azimute');
      expect(l10n.customHorizonMask, 'Máscara de Obstrução de Horizonte');
      expect(l10n.moonDistance, 'Distância da Lua');
      expect(l10n.magnitudeApparentSize, 'Magnitude e Tamanho Aparente');

      // Settings Keys (PT-BR)
      expect(l10n.settingsAndData, 'Configurações e Dados');
      expect(l10n.settingsLocation, 'Local do Observador...');
      expect(l10n.resetFilters, 'Redefinir Filtros de Alvos');
      expect(l10n.cleanData, 'Limpar Todos os Dados Salvos...');

      // Equipment Keys (PT-BR)
      expect(l10n.equipmentDialogTitle, 'Equipamentos e Óptica');
      expect(l10n.equipmentRigsButton, 'Equipamentos');
      expect(l10n.gearButton, 'Equip.');
      expect(l10n.framingSimulatorTitle, 'Simulador de Enquadramento');
      expect(l10n.telescopeOptics, 'Telescópio / Óptica');
      expect(l10n.cameraSensor, 'Câmera / Sensor');
      expect(l10n.computedOpticalSpecs, 'Especificações Ópticas Calculadas');
    });

    testWidgets('localizeObjectType helper translates canonical names to Portuguese', (WidgetTester tester) async {
      late AppLocalizations l10nPt;

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

      expect(localizeObjectType('Galaxy', l10nPt), 'Galáxia');
      expect(localizeObjectType('Planetary Nebula', l10nPt), 'Nebulosa Planetária');
      expect(localizeObjectType('Bright Nebula', l10nPt), 'Nebulosa Brilhante');
      expect(localizeObjectType('Dark Nebula', l10nPt), 'Nebulosa Escura');
      expect(localizeObjectType('Supernova Remnant', l10nPt), 'Remanescente de Supernova');
      expect(localizeObjectType('Star', l10nPt), 'Estrela');
      expect(localizeObjectType('Double Star', l10nPt), 'Estrela Dupla');
      expect(localizeObjectType('Asterism', l10nPt), 'Asterismo');
    });

    test('SettingsService persists and loads languageCode', () async {
      final tempDir = await Directory.systemTemp.createTemp('l10n_settings_');
      final tempFile = File(p.join(tempDir.path, 'l10n_settings.json'));
      SettingsService.customSettingsFile = tempFile;

      try {
        final filters = FilterState();

        await SettingsService.saveSettings(
          filters: filters,
          isRedNightMode: false,
          languageCode: 'pt',
        );

        final loaded = await SettingsService.loadSettings();
        expect(loaded.languageCode, 'pt');

        // Test saveLanguage helper
        await SettingsService.saveLanguage('en');
        final updated = await SettingsService.loadSettings();
        expect(updated.languageCode, 'en');

        // Reset
        await SettingsService.saveLanguage(null);
      } finally {
        SettingsService.customSettingsFile = null;
        try {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        } catch (_) {}
      }
    });

    testWidgets('localizeMoonPhase translates all 8 moon phases to Portuguese', (WidgetTester tester) async {
      late AppLocalizations l10nPt;

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

      expect(localizeMoonPhase('New Moon', l10nPt), 'Lua Nova');
      expect(localizeMoonPhase('Waxing Crescent', l10nPt), 'Lua Crescente');
      expect(localizeMoonPhase('First Quarter', l10nPt), 'Quarto Crescente');
      expect(localizeMoonPhase('Waxing Gibbous', l10nPt), 'Crescente Gibosa');
      expect(localizeMoonPhase('Full Moon', l10nPt), 'Lua Cheia');
      expect(localizeMoonPhase('Waning Gibbous', l10nPt), 'Minguante Gibosa');
      expect(localizeMoonPhase('Third Quarter', l10nPt), 'Quarto Minguante');
      expect(localizeMoonPhase('Last Quarter', l10nPt), 'Quarto Minguante');
      expect(localizeMoonPhase('Waning Crescent', l10nPt), 'Lua Minguante');
    });

    testWidgets('Targets window and Observer Location keys translate properly in Portuguese', (WidgetTester tester) async {
      late AppLocalizations l10nPt;

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

      // Observer Location
      expect(l10nPt.elevationShort, 'Elevação');
      expect(l10nPt.searchResultSubtitle('-23.03', '-67.75', '2500'), 'Lat: -23.03° | Lon: -67.75° | Elevação: 2500m');

      // Top bar & Status
      expect(l10nPt.darkTime, 'Escuro');

      // Targets window
      expect(l10nPt.visualSkyPreview, 'Pré-visualização do Céu');
      expect(l10nPt.addToListDialogTitle('M42'), 'Adicionar M42 à Lista');
      expect(l10nPt.simbadQuerying, 'Consultando CDS / SIMBAD...');
      expect(l10nPt.selectSkySurveyTooltip, 'Selecionar Levantamento do Céu');
      expect(l10nPt.photoReticleTooltip, 'Foto + Retículo');
      expect(l10nPt.zoomOutTooltip, 'Diminuir Zoom (FOV Mais Amplo)');
      expect(l10nPt.zoomInTooltip, 'Aumentar Zoom (FOV Mais Próximo)');
      expect(l10nPt.rotateMinus15, 'Girar -15°');
      expect(l10nPt.rotatePlus15, 'Girar +15°');
      expect(l10nPt.yearlyObservingWindow, 'JANELA ANUAL DE OBSERVAÇÃO');
      expect(l10nPt.visibleTonight, 'Visível Esta Noite');
      expect(l10nPt.astronomicalDarknessLabel, 'ESCURIDÃO ASTRONÔMICA');
      expect(l10nPt.observingWindowLabel, 'JANELA DE OBSERVAÇÃO');

      // Month abbreviation helper
      expect(localizeMonthAbbr(1, l10nPt), 'Jan');
      expect(localizeMonthAbbr(2, l10nPt), 'Fev');
      expect(localizeMonthAbbr(5, l10nPt), 'Mai');
      expect(localizeMonthAbbr(8, l10nPt), 'Ago');
      expect(localizeMonthAbbr(9, l10nPt), 'Set');
      expect(localizeMonthAbbr(10, l10nPt), 'Out');
      expect(localizeMonthAbbr(12, l10nPt), 'Dez');
    });
  });
}
