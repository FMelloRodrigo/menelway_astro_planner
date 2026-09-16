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
    });
  });
}
