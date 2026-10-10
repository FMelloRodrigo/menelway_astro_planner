import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/fake_astro_engine.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
import 'package:app/views/planner_view.dart';
import 'package:app/views/target_search_view.dart';

void main() {
  final testNight = NightSummary(
    sunset: DateTime(2026, 9, 6, 18, 0),
    civilDusk: DateTime(2026, 9, 6, 18, 30),
    nauticalDusk: DateTime(2026, 9, 6, 19, 0),
    astronomicalDusk: DateTime(2026, 9, 6, 19, 30),
    solarMidnight: DateTime(2026, 9, 6, 23, 59),
    astronomicalDawn: DateTime(2026, 9, 7, 5, 0),
    nauticalDawn: DateTime(2026, 9, 7, 5, 30),
    civilDawn: DateTime(2026, 9, 7, 6, 0),
    sunrise: DateTime(2026, 9, 7, 6, 30),
    moonIllumination: 0.5,
    moonPhaseName: 'First Quarter',
    hasAstronomicalNight: true,
  );

  final smallTarget = TargetItem(
    id: 1,
    name: 'Small Target',
    catalog: 'NGC',
    objectType: 'Planetary Nebula',
    constellation: 'Lyr',
    raHours: 18.8,
    decDegrees: 33.0,
    magnitude: 8.8,
    majorAxisArcmin: 1.4,
    peakAltitudeDeg: 50.0,
    visibleDurationHours: 5.0,
    transitTime: DateTime(2026, 9, 6, 21, 0),
    minMoonSepDeg: 60.0,
    meetsCriteria: true,
  );

  final largeTarget = TargetItem(
    id: 2,
    name: 'Large Target',
    catalog: 'Messier',
    objectType: 'Galaxy',
    constellation: 'And',
    raHours: 0.7,
    decDegrees: 41.2,
    magnitude: 3.4,
    majorAxisArcmin: 178.0,
    peakAltitudeDeg: 65.0,
    visibleDurationHours: 6.0,
    transitTime: DateTime(2026, 9, 6, 23, 0),
    minMoonSepDeg: 75.0,
    meetsCriteria: true,
  );

  final mediumTarget = TargetItem(
    id: 3,
    name: 'Medium Target',
    catalog: 'Messier',
    objectType: 'Nebula',
    constellation: 'Ori',
    raHours: 5.5,
    decDegrees: -5.4,
    magnitude: 4.0,
    majorAxisArcmin: 85.0,
    peakAltitudeDeg: 55.0,
    visibleDurationHours: 4.0,
    transitTime: DateTime(2026, 9, 7, 3, 0),
    minMoonSepDeg: 80.0,
    meetsCriteria: true,
  );

  final unknownSizeTarget = TargetItem(
    id: 4,
    name: 'Unknown Size Target',
    catalog: 'IC',
    objectType: 'Cluster',
    constellation: 'Cas',
    raHours: 2.0,
    decDegrees: 60.0,
    magnitude: 10.0,
    majorAxisArcmin: null,
    peakAltitudeDeg: 70.0,
    visibleDurationHours: 4.0,
    transitTime: DateTime(2026, 9, 6, 22, 0),
    minMoonSepDeg: 50.0,
    meetsCriteria: true,
  );

  Widget createTargetSearchWidget({required List<TargetItem> targets}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TargetSearchView(
          targets: targets,
          night: testNight,
          filters: FilterState(),
          isLoading: false,
          availableLists: const [],
          onFilterChanged: (_) {},
          onAddToList: (_, _, _) {},
        ),
      ),
    );
  }

  group('Apparent Size Sort Tests', () {
    testWidgets('TargetSearchView has Size sort option and sorts descending by majorAxisArcmin', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTargetSearchWidget(
        targets: [smallTarget, unknownSizeTarget, mediumTarget, largeTarget],
      ));
      await tester.pumpAndSettle();

      // Find sort dropdown and tap it
      final dropdownFinder = find.byType(DropdownButton<SortMode>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      // Verify SortMode.size option is in dropdown
      final sizeOptionFinder = find.byWidgetPredicate(
        (widget) => widget is DropdownMenuItem<SortMode> && widget.value == SortMode.size,
      );
      expect(sizeOptionFinder, findsOneWidget);
      await tester.tap(sizeOptionFinder.last);
      await tester.pumpAndSettle();

      // With size sort active:
      // Order should be Large (178') -> Medium (85') -> Small (1.4') -> Unknown (null)
      final largeFinder = find.text('Large Target');
      final mediumFinder = find.text('Medium Target');
      final smallFinder = find.text('Small Target');
      final unknownFinder = find.text('Unknown Size Target');

      expect(largeFinder, findsOneWidget);
      expect(mediumFinder, findsOneWidget);
      expect(smallFinder, findsOneWidget);
      expect(unknownFinder, findsOneWidget);

      final largeY = tester.getTopLeft(largeFinder).dy;
      final mediumY = tester.getTopLeft(mediumFinder).dy;
      final smallY = tester.getTopLeft(smallFinder).dy;
      final unknownY = tester.getTopLeft(unknownFinder).dy;

      expect(largeY, lessThan(mediumY));
      expect(mediumY, lessThan(smallY));
      expect(smallY, lessThan(unknownY));
    });

    testWidgets('PlannerView has Size sort option and orders period targets by apparent size', (tester) async {
      final mockEngine = FakeAstroEngine();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: PlannerView(
              filters: FilterState(maxTargets: 1),
              night: testNight,
              isRedNightMode: false,
              availableLists: const [],
              onAddToList: (listId, targetId, notes) {},
              onFilterChanged: (_) {},
              engine: mockEngine,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Find sort dropdown and switch to PeriodSortBy.size
      final dropdownFinder = find.byType(DropdownButton<PeriodSortBy>);
      expect(dropdownFinder, findsOneWidget);
      await tester.tap(dropdownFinder);
      await tester.pumpAndSettle();

      final sizeOptionFinder = find.byWidgetPredicate(
        (widget) => widget is DropdownMenuItem<PeriodSortBy> && widget.value == PeriodSortBy.size,
      );
      expect(sizeOptionFinder, findsOneWidget);
      await tester.tap(sizeOptionFinder.last);
      await tester.pumpAndSettle();

      // In FakeAstroEngine, M 31 has majorAxisArcmin 178.0' vs M 42 85.0',
      // so with maxTargets = 1, M 31 must be the top target selected
      expect(find.textContaining('M 31'), findsOneWidget);
      expect(find.textContaining('M 42'), findsNothing);
    });
  });
}
