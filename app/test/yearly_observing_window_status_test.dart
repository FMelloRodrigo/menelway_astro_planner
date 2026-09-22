import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/astro_engine.dart';
import 'package:app/core/fake_astro_engine.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
import 'package:app/models/yearly_visibility.dart';
import 'package:app/views/target_details_sheet.dart';
import 'package:app/l10n/app_localizations.dart';

class CustomYearlyMockEngine extends FakeAstroEngine {
  final YearlyVisibilityModel Function(int targetId, FilterState? filters)? onGetYearly;

  CustomYearlyMockEngine({this.onGetYearly});

  @override
  YearlyVisibilityModel? getTargetYearlyVisibility({
    required int targetId,
    required double latitude,
    required double longitude,
    required double elevation,
    FilterState? filters,
    double minAltitude = 30.0,
    double minDurationHours = 2.0,
    int year = 2026,
  }) {
    if (onGetYearly != null) {
      return onGetYearly!(targetId, filters);
    }
    return super.getTargetYearlyVisibility(
      targetId: targetId,
      latitude: latitude,
      longitude: longitude,
      elevation: elevation,
      filters: filters,
      minAltitude: minAltitude,
      minDurationHours: minDurationHours,
      year: year,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('TargetDetailsSheet Yearly Observing Window Status Tests', () {
    tearDown(() {
      AstroEngine.reset();
    });

    testWidgets('Displays season countdown instead of Visible Tonight when target is pre-season', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockEngine = CustomYearlyMockEngine(
        onGetYearly: (id, filters) => YearlyVisibilityModel(
          targetId: id,
          theoreticalMaxAltitudeDeg: 60.0,
          canEverReachMinAlt: true,
          peakMonth: 11,
          peakDay: 15,
          startMonth: 10,
          startDay: 10,
          endMonth: 12,
          endDay: 20,
          bestWindowStart: 10,
          bestWindowEnd: 12,
          totalObservableDays: 70,
          maxHoursInPeak: 6.0,
          bestWindowSummary: 'Oct 10 – Dec 20',
          months: [
            const MonthVisibilityItem(
              month: 10,
              name: 'Oct',
              hoursObservable: 4.0,
              peakAltitudeDeg: 55.0,
              isObservable: true,
              observableDaysCount: 21,
              startDay: 10,
              endDay: 31,
            ),
            const MonthVisibilityItem(
              month: 9,
              name: 'Sep',
              hoursObservable: 0.0,
              peakAltitudeDeg: 20.0,
              isObservable: false,
              observableDaysCount: 0,
              startDay: 0,
              endDay: 0,
            ),
          ],
        ),
      );
      AstroEngine.instance = mockEngine;

      // Tonight is Sep 21 (pre-season; season starts Oct 10)
      final night = NightSummary(
        sunset: DateTime(2026, 9, 21, 18, 0),
        civilDusk: DateTime(2026, 9, 21, 18, 30),
        nauticalDusk: DateTime(2026, 9, 21, 19, 0),
        astronomicalDusk: DateTime(2026, 9, 21, 19, 30),
        solarMidnight: DateTime(2026, 9, 21, 23, 59),
        astronomicalDawn: DateTime(2026, 9, 22, 5, 0),
        nauticalDawn: DateTime(2026, 9, 22, 5, 30),
        civilDawn: DateTime(2026, 9, 22, 6, 0),
        sunrise: DateTime(2026, 9, 22, 6, 30),
        moonIllumination: 0.5,
        moonPhaseName: 'First Quarter',
        hasAstronomicalNight: true,
      );

      final target = TargetItem(
        id: 42,
        name: 'NGC 2244',
        catalog: 'Caldwell',
        objectType: 'Open Cluster',
        constellation: 'Mon',
        raHours: 6.5,
        decDegrees: 4.9,
        peakAltitudeDeg: 48.5,
        visibleDurationHours: 5.0,
        transitTime: DateTime(2026, 9, 21, 23, 45),
        minMoonSepDeg: 40.0,
        meetsCriteria: false, // Target does not meet criteria tonight
      );

      await tester.pumpWidget(
        buildTestableWidget(
          TargetDetailsSheet(
            target: target,
            night: night,
            latitude: -22.28,
            longitude: -42.53,
            elevation: 850.0,
            availableLists: const [],
            onAddToList: (_, __, ___) {},
            filters: FilterState(),
            engine: mockEngine,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify that it does NOT say 'Visible Tonight'
      expect(find.text('Visible Tonight'), findsNothing);

      // Verify it shows countdown to season start (Starts in 19 days)
      expect(find.textContaining('Starts in 19 days'), findsOneWidget);
    });

    testWidgets('Displays Not observable with active filters when totalObservableDays is 0', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockEngine = CustomYearlyMockEngine(
        onGetYearly: (id, filters) => YearlyVisibilityModel(
          targetId: id,
          theoreticalMaxAltitudeDeg: 70.0,
          canEverReachMinAlt: true,
          peakMonth: 1,
          peakDay: 1,
          startMonth: 0,
          startDay: 0,
          endMonth: 0,
          endDay: 0,
          bestWindowStart: 0,
          bestWindowEnd: 0,
          totalObservableDays: 0, // 0 days observable with active filters
          maxHoursInPeak: 0.0,
          bestWindowSummary: 'Not observable with current filters',
          months: [],
        ),
      );
      AstroEngine.instance = mockEngine;

      final night = NightSummary(
        sunset: DateTime(2026, 9, 21, 18, 0),
        civilDusk: DateTime(2026, 9, 21, 18, 30),
        nauticalDusk: DateTime(2026, 9, 21, 19, 0),
        astronomicalDusk: DateTime(2026, 9, 21, 19, 30),
        solarMidnight: DateTime(2026, 9, 21, 23, 59),
        astronomicalDawn: DateTime(2026, 9, 22, 5, 0),
        nauticalDawn: DateTime(2026, 9, 22, 5, 30),
        civilDawn: DateTime(2026, 9, 22, 6, 0),
        sunrise: DateTime(2026, 9, 22, 6, 30),
        moonIllumination: 0.5,
        moonPhaseName: 'First Quarter',
        hasAstronomicalNight: true,
      );

      final target = TargetItem(
        id: 42,
        name: 'NGC 2244',
        catalog: 'Caldwell',
        objectType: 'Open Cluster',
        constellation: 'Mon',
        raHours: 6.5,
        decDegrees: 4.9,
        peakAltitudeDeg: 48.5,
        visibleDurationHours: 0.0,
        transitTime: DateTime(2026, 9, 21, 23, 45),
        minMoonSepDeg: 40.0,
        meetsCriteria: false,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          TargetDetailsSheet(
            target: target,
            night: night,
            latitude: -22.28,
            longitude: -42.53,
            elevation: 850.0,
            availableLists: const [],
            onAddToList: (_, __, ___) {},
            filters: FilterState(minAltitude: 85.0),
            engine: mockEngine,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Visible Tonight'), findsNothing);
      expect(find.text('Not observable with active filters'), findsOneWidget);
    });

    testWidgets('Displays Visible Tonight when in season and meets criteria', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockEngine = CustomYearlyMockEngine(
        onGetYearly: (id, filters) => YearlyVisibilityModel(
          targetId: id,
          theoreticalMaxAltitudeDeg: 80.0,
          canEverReachMinAlt: true,
          peakMonth: 9,
          peakDay: 20,
          startMonth: 8,
          startDay: 1,
          endMonth: 11,
          endDay: 30,
          bestWindowStart: 8,
          bestWindowEnd: 11,
          totalObservableDays: 120,
          maxHoursInPeak: 7.0,
          bestWindowSummary: 'Aug 1 – Nov 30',
          months: [
            const MonthVisibilityItem(
              month: 9,
              name: 'Sep',
              hoursObservable: 6.0,
              peakAltitudeDeg: 78.0,
              isObservable: true,
              observableDaysCount: 30,
              startDay: 1,
              endDay: 30,
            ),
          ],
        ),
      );
      AstroEngine.instance = mockEngine;

      final night = NightSummary(
        sunset: DateTime(2026, 9, 21, 18, 0),
        civilDusk: DateTime(2026, 9, 21, 18, 30),
        nauticalDusk: DateTime(2026, 9, 21, 19, 0),
        astronomicalDusk: DateTime(2026, 9, 21, 19, 30),
        solarMidnight: DateTime(2026, 9, 21, 23, 59),
        astronomicalDawn: DateTime(2026, 9, 22, 5, 0),
        nauticalDawn: DateTime(2026, 9, 22, 5, 30),
        civilDawn: DateTime(2026, 9, 22, 6, 0),
        sunrise: DateTime(2026, 9, 22, 6, 30),
        moonIllumination: 0.5,
        moonPhaseName: 'First Quarter',
        hasAstronomicalNight: true,
      );

      final target = TargetItem(
        id: 1,
        name: 'M31',
        messier: 'M31',
        catalog: 'Messier',
        objectType: 'Galaxy',
        constellation: 'And',
        raHours: 0.7,
        decDegrees: 41.2,
        peakAltitudeDeg: 78.0,
        visibleDurationHours: 6.0,
        transitTime: DateTime(2026, 9, 21, 23, 45),
        minMoonSepDeg: 50.0,
        meetsCriteria: true,
      );

      await tester.pumpWidget(
        buildTestableWidget(
          TargetDetailsSheet(
            target: target,
            night: night,
            latitude: 35.0,
            longitude: -110.0,
            elevation: 1000.0,
            availableLists: const [],
            onAddToList: (_, __, ___) {},
            filters: FilterState(),
            engine: mockEngine,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Visible Tonight'), findsOneWidget);
    });
  });
}
