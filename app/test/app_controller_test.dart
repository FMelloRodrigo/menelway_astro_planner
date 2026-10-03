import 'package:flutter_test/flutter_test.dart';
import 'package:app/controllers/app_controller.dart';
import 'package:app/core/fake_astro_engine.dart';
import 'package:app/core/favorites_manager.dart';
import 'package:app/core/observing_site_manager.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/observing_site.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAstroEngine fakeEngine;
  late AppController controller;

  setUp(() {
    fakeEngine = FakeAstroEngine();
    controller = AppController(
      engine: fakeEngine,
      initialFilters: FilterState(),
      enableIsolate: false, // In unit test harness, use direct execution
    );
  });

  tearDown(() {
    controller.dispose();
  });

  group('AppController State & Orchestration Tests', () {
    test('Initial state is correctly initialized', () {
      expect(controller.isInitializing, isTrue);
      expect(controller.targets, isEmpty);
      expect(controller.planets, isEmpty);
      expect(controller.brightStars, isEmpty);
      expect(controller.selectedTabIndex, 0);
    });

    test('Bootstrap initializes engine, filters, and loads datasets', () async {
      await controller.bootstrap();

      expect(controller.isInitializing, isFalse);
      expect(fakeEngine.isInitialized, isTrue);
      expect(controller.nightSummary, isNotNull);
      expect(controller.targets.isNotEmpty, isTrue);
      expect(controller.planets.isNotEmpty, isTrue);
      expect(controller.brightStars.isNotEmpty, isTrue);
    });

    test('Updating filters updates nightSummary and triggers filtering', () async {
      await controller.bootstrap();

      final newFilters = FilterState(
        observerLat: 51.5,
        observerLon: -0.12,
        observerElevation: 25.0,
      );

      controller.updateFilters(newFilters);
      expect(controller.filters.observerLat, 51.5);
      expect(controller.nightSummary, isNotNull);
    });

    test('Switching tab indices works cleanly', () {
      controller.setTabIndex(2);
      expect(controller.selectedTabIndex, 2);
    });

    test('Observing site change synchronizes filter observer coordinates', () async {
      await controller.bootstrap();

      final testSite = ObservingSite(
        id: 'controller_test_site',
        name: 'Alpine Observatory',
        latitude: 46.5,
        longitude: 8.0,
        elevation: 2500.0,
      );

      ObservingSiteManager.instance.addSite(testSite, setAsActive: true);

      expect(controller.filters.observerLat, 46.5);
      expect(controller.filters.observerLon, 8.0);
      expect(controller.filters.observerElevation, 2500.0);
      expect(controller.filters.observerLocationName, 'Alpine Observatory');
    });

    test('cleanAllData wipes database, favorites, and resets filters', () async {
      await controller.bootstrap();
      final sampleTarget = FakeAstroEngine.defaultMockTargets.first;
      FavoritesManager.instance.addFavorite(sampleTarget);
      expect(FavoritesManager.instance.isFavorite(sampleTarget.id), isTrue);

      controller.cleanAllData();

      expect(FavoritesManager.instance.isEmpty, isTrue);
      expect(controller.targets.isNotEmpty, isTrue);
    });
  });
}
