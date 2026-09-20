import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/astro_engine.dart';
import 'package:app/core/fake_astro_engine.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/target_item.dart';
import 'package:app/models/observing_list.dart';
import 'package:app/views/target_details_sheet.dart';
import 'package:app/views/target_search_view.dart';
import 'package:app/views/observing_lists_view.dart';
import 'package:app/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeAstroEngine fakeEngine;

  setUp(() {
    fakeEngine = FakeAstroEngine();
    AstroEngine.instance = fakeEngine;
  });

  tearDown(() {
    AstroEngine.reset();
  });

  group('FakeAstroEngine Unit Tests', () {
    test('Lifecycle and night summary computation', () {
      expect(fakeEngine.isInitialized, isFalse);
      fakeEngine.initEngine('test_path.db');
      expect(fakeEngine.isInitialized, isTrue);
      expect(fakeEngine.initializedDbPath, 'test_path.db');

      final night = fakeEngine.getNightSummary(
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        date: DateTime(2026, 9, 20),
      );
      expect(night.sunset.isBefore(night.sunrise), isTrue);
      expect(night.moonIllumination, 0.25);
      expect(night.hasAstronomicalNight, isTrue);

      fakeEngine.dispose();
      expect(fakeEngine.isInitialized, isFalse);
    });

    test('Target filtering and search query match', () {
      final night = fakeEngine.getNightSummary(
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        date: DateTime(2026, 9, 20),
      );

      final allTargets = fakeEngine.filterTargets(
        filters: FilterState(),
        night: night,
      );
      expect(allTargets.length, 3);

      final searchM31 = fakeEngine.filterTargets(
        filters: FilterState(searchQuery: 'Andromeda'),
        night: night,
      );
      expect(searchM31.length, 1);
      expect(searchM31.first.displayName, contains('Andromeda Galaxy'));

      final noResults = fakeEngine.filterTargets(
        filters: FilterState(searchQuery: 'NonExistentObjectXYZ'),
        night: night,
      );
      expect(noResults.isEmpty, isTrue);
    });

    test('In-memory observing lists CRUD workflow', () {
      expect(fakeEngine.getObservingLists(), isEmpty);

      // Create list
      final listId = fakeEngine.createObservingList('Autumn Run', 'Messier targets', '2026-09-20');
      expect(listId, greaterThan(0));
      expect(fakeEngine.getObservingLists().length, 1);

      // Add target
      final added = fakeEngine.addTargetToList(listId, 1, 'Lum 180s x 20');
      expect(added, isTrue);
      final lists = fakeEngine.getObservingLists();
      expect(lists.first.items.length, 1);
      expect(lists.first.items.first.dsoId, 1);
      expect(lists.first.items.first.notes, 'Lum 180s x 20');

      // Remove target
      final removed = fakeEngine.removeTargetFromList(listId, 1);
      expect(removed, isTrue);
      expect(fakeEngine.getObservingLists().first.items, isEmpty);

      // Delete list
      final deleted = fakeEngine.deleteObservingList(listId);
      expect(deleted, isTrue);
      expect(fakeEngine.getObservingLists(), isEmpty);
    });

    test('Altitude curve and yearly visibility calculations', () {
      final now = DateTime(2026, 9, 20, 20, 0);
      final morning = DateTime(2026, 9, 21, 5, 0);

      final curve = fakeEngine.generateAltitudeCurve(
        targetId: 1,
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        start: now,
        end: morning,
        stepMinutes: 15,
      );
      expect(curve.isNotEmpty, isTrue);
      expect(curve.first.altitude, greaterThan(0.0));

      final yearly = fakeEngine.getTargetYearlyVisibility(
        targetId: 1,
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
      );
      expect(yearly, isNotNull);
      expect(yearly!.months.length, 12);
    });
  });

  group('Engine-Driven Widget Tests with FakeAstroEngine', () {
    Widget buildTestableWidget(Widget child) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      );
    }

    testWidgets('TargetDetailsSheet generates curve and yearly visibility with FakeAstroEngine', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final night = fakeEngine.getNightSummary(
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        date: DateTime(2026, 9, 20),
      );

      final target = FakeAstroEngine.defaultMockTargets.first;

      await tester.pumpWidget(
        buildTestableWidget(
          TargetDetailsSheet(
            target: target,
            night: night,
            latitude: -22.28,
            longitude: -42.53,
            elevation: 850.0,
            availableLists: const [],
            onAddToList: (listId, dsoId, notes) {},
            engine: fakeEngine,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify TargetDetailsSheet renders target displayName
      expect(find.textContaining('Andromeda Galaxy'), findsWidgets);
    });

    testWidgets('TargetSearchView renders target catalog items produced by AstroEngine', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final night = fakeEngine.getNightSummary(
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        date: DateTime(2026, 9, 20),
      );

      final targets = fakeEngine.filterTargets(
        filters: FilterState(),
        night: night,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          TargetSearchView(
            targets: targets,
            night: night,
            filters: FilterState(),
            isLoading: false,
            isRedNightMode: false,
            availableLists: const [],
            onFilterChanged: (newFilters) {},
            onAddToList: (listId, dsoId, notes) {},
          ),
        ),
      );

      await tester.pump();

      // Verify mock targets render in the catalog list
      expect(find.textContaining('Andromeda Galaxy'), findsWidgets);
      expect(find.textContaining('Orion Nebula'), findsWidgets);
      expect(find.textContaining('North America Nebula'), findsWidgets);
    });

    testWidgets('ObservingListsView renders observing lists stored in AstroEngine', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final listId = fakeEngine.createObservingList('Astrophotography Targets', 'Favorites for autumn', '2026-09-20');
      fakeEngine.addTargetToList(listId, 1, 'Lum 180s x 25');

      final lists = fakeEngine.getObservingLists();

      await tester.pumpWidget(
        buildTestableWidget(
          ObservingListsView(
            lists: lists,
            isRedNightMode: false,
            onCreateList: (name, desc, date) {},
            onDeleteList: (id) {},
            onRemoveItem: (listId, dsoId) {},
          ),
        ),
      );

      await tester.pump();

      // Verify list name renders
      expect(find.text('Astrophotography Targets'), findsOneWidget);
    });
  });
}
