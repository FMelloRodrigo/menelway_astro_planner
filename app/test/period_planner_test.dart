import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/period_target_item.dart';
import 'package:app/core/astro_engine.dart';
import 'package:app/core/fake_astro_engine.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
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
  group('PeriodTargetItem Model Tests', () {
    test('PeriodTargetItem parses and converts to TargetItem properly', () {
      final periodItem = PeriodTargetItem(
        id: 42,
        name: 'NGC 2244',
        caldwell: 'C49',
        commonName: 'Rosette Nebula',
        catalog: 'Caldwell',
        objectType: 'Open Cluster',
        constellation: 'Mon',
        raHours: 6.54,
        decDegrees: 4.95,
        magnitude: 4.8,
        majorAxisArcmin: 24.0,
        positionAngleDeg: 35.0,
        surfaceBrightness: 12.0,
        peakAltitudeDeg: 48.5,
        maxHoursObservable: 1.8,
        peakDate: DateTime(2026, 2, 14),
        observableDaysCount: 17,
        totalPeriodDays: 28,
        startMonth: 2,
        startDay: 1,
        endMonth: 2,
        endDay: 28,
        isObservable: true,
      );

      expect(periodItem.id, 42);
      expect(periodItem.caldwell, 'C49');
      expect(periodItem.positionAngleDeg, 35.0);
      expect(periodItem.observableDaysCount, 17);
      expect(periodItem.totalPeriodDays, 28);
      expect(periodItem.isObservable, isTrue);
      expect(periodItem.peakAltitudeDeg, 48.5);
      expect(periodItem.displayName, 'C49 (Rosette Nebula)');

      final targetItem = periodItem.toTargetItem();
      expect(targetItem.id, 42);
      expect(targetItem.name, 'NGC 2244');
      expect(targetItem.caldwell, 'C49');
      expect(targetItem.positionAngleDeg, 35.0);
      expect(targetItem.commonName, 'Rosette Nebula');
      expect(targetItem.objectType, 'Open Cluster');
      expect(targetItem.constellation, 'Mon');
      expect(targetItem.peakAltitudeDeg, 48.5);
      expect(targetItem.visibleDurationHours, 1.8);
      expect(targetItem.meetsCriteria, isTrue);
    });

    test('PeriodTargetItem with 0 observable days handles ratio safely', () {
      final periodItem = const PeriodTargetItem(
        id: 100,
        name: 'NGC 224',
        messier: 'M31',
        commonName: 'Andromeda Galaxy',
        catalog: 'Messier',
        objectType: 'Galaxy',
        constellation: 'And',
        raHours: 0.71,
        decDegrees: 41.27,
        magnitude: 3.4,
        majorAxisArcmin: 180.0,
        surfaceBrightness: 13.5,
        peakAltitudeDeg: 0.0,
        maxHoursObservable: 0.0,
        peakDate: null,
        observableDaysCount: 0,
        totalPeriodDays: 30,
        startMonth: 9,
        startDay: 1,
        endMonth: 9,
        endDay: 30,
        isObservable: false,
      );

      expect(periodItem.observableDaysCount, 0);
      expect(periodItem.isObservable, isFalse);
      expect(periodItem.peakDate, isNull);
      expect(periodItem.positionAngleDeg, isNull);

      final targetItem = periodItem.toTargetItem();
      expect(targetItem.meetsCriteria, isFalse);
      expect(targetItem.visibleDurationHours, 0.0);
      expect(targetItem.positionAngleDeg, isNull);
    });

    test('PeriodTargetItem.isObservableOn and date-aware toTargetItem', () {
      final periodItem = const PeriodTargetItem(
        id: 42,
        name: 'NGC 2244',
        catalog: 'Caldwell',
        objectType: 'Open Cluster',
        constellation: 'Mon',
        raHours: 6.5,
        decDegrees: 4.9,
        peakAltitudeDeg: 48.5,
        maxHoursObservable: 5.0,
        observableDaysCount: 20,
        totalPeriodDays: 30,
        startMonth: 10,
        startDay: 10,
        endMonth: 10,
        endDay: 29,
        isObservable: true,
      );

      // Observable between Oct 10 and Oct 29
      expect(periodItem.isObservableOn(DateTime(2026, 9, 21)), isFalse);
      expect(periodItem.isObservableOn(DateTime(2026, 10, 5)), isFalse);
      expect(periodItem.isObservableOn(DateTime(2026, 10, 10)), isTrue);
      expect(periodItem.isObservableOn(DateTime(2026, 10, 20)), isTrue);
      expect(periodItem.isObservableOn(DateTime(2026, 10, 29)), isTrue);
      expect(periodItem.isObservableOn(DateTime(2026, 10, 30)), isFalse);
      expect(periodItem.isObservableOn(DateTime(2026, 11, 15)), isFalse);

      // toTargetItem with specific dates
      final tonightTarget = periodItem.toTargetItem(date: DateTime(2026, 9, 21));
      expect(tonightTarget.meetsCriteria, isFalse);

      final inSeasonTarget = periodItem.toTargetItem(date: DateTime(2026, 10, 15));
      expect(inSeasonTarget.meetsCriteria, isTrue);

      // toTargetItem without date defaults to isObservable
      final legacyTarget = periodItem.toTargetItem();
      expect(legacyTarget.meetsCriteria, isTrue);
    });

    test('PeriodTargetItem.isObservableOn handles year wrap-around', () {
      final periodItem = const PeriodTargetItem(
        id: 1,
        name: 'Winter DSO',
        catalog: 'Messier',
        objectType: 'Nebula',
        constellation: 'Ori',
        raHours: 5.5,
        decDegrees: -5.0,
        peakAltitudeDeg: 60.0,
        maxHoursObservable: 6.0,
        observableDaysCount: 90,
        totalPeriodDays: 120,
        startMonth: 11,
        startDay: 15,
        endMonth: 2,
        endDay: 20,
        isObservable: true,
      );

      expect(periodItem.isObservableOn(DateTime(2026, 9, 21)), isFalse);
      expect(periodItem.isObservableOn(DateTime(2026, 11, 10)), isFalse);
      expect(periodItem.isObservableOn(DateTime(2026, 11, 15)), isTrue);
      expect(periodItem.isObservableOn(DateTime(2026, 12, 25)), isTrue);
      expect(periodItem.isObservableOn(DateTime(2027, 1, 15)), isTrue);
      expect(periodItem.isObservableOn(DateTime(2027, 2, 20)), isTrue);
      expect(periodItem.isObservableOn(DateTime(2027, 2, 21)), isFalse);
      expect(periodItem.isObservableOn(DateTime(2027, 5, 10)), isFalse);
    });
  });

  group('TargetDetailsSheet Period Planning Mode Tests', () {
    tearDown(() {
      AstroEngine.reset();
    });

    testWidgets('Displays Planned Period banner, Period Peak, and Annual Peak in Yearly Observing Window', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final mockEngine = CustomYearlyMockEngine(
        onGetYearly: (id, filters) => YearlyVisibilityModel(
          targetId: id,
          theoreticalMaxAltitudeDeg: 65.0,
          canEverReachMinAlt: true,
          peakMonth: 9,
          peakDay: 16,
          startMonth: 7,
          startDay: 10,
          endMonth: 11,
          endDay: 20,
          bestWindowStart: 7,
          bestWindowEnd: 11,
          totalObservableDays: 134,
          maxHoursInPeak: 5.2,
          bestWindowSummary: 'Jul 10 – Nov 20',
          months: [
            const MonthVisibilityItem(
              month: 10,
              name: 'Oct',
              hoursObservable: 4.8,
              peakAltitudeDeg: 62.0,
              isObservable: true,
              observableDaysCount: 28,
              startDay: 1,
              endDay: 31,
            ),
          ],
        ),
      );
      AstroEngine.instance = mockEngine;

      final periodTarget = PeriodTargetItem(
        id: 30,
        name: 'NGC 7331',
        caldwell: 'C30',
        catalog: 'Caldwell',
        objectType: 'Galaxy',
        constellation: 'Peg',
        raHours: 22.62,
        decDegrees: 34.42,
        peakAltitudeDeg: 62.5,
        maxHoursObservable: 4.8,
        peakDate: DateTime(2026, 10, 9),
        observableDaysCount: 28,
        totalPeriodDays: 31,
        startMonth: 10,
        startDay: 1,
        endMonth: 10,
        endDay: 31,
        isObservable: true,
      );

      final plannedNight = NightSummary(
        sunset: DateTime(2026, 10, 9, 18, 15),
        civilDusk: DateTime(2026, 10, 9, 18, 40),
        nauticalDusk: DateTime(2026, 10, 9, 19, 10),
        astronomicalDusk: DateTime(2026, 10, 9, 19, 45),
        solarMidnight: DateTime(2026, 10, 10, 0, 1),
        astronomicalDawn: DateTime(2026, 10, 10, 4, 30),
        nauticalDawn: DateTime(2026, 10, 10, 5, 5),
        civilDawn: DateTime(2026, 10, 10, 5, 35),
        sunrise: DateTime(2026, 10, 10, 6, 0),
        moonIllumination: 0.05,
        moonPhaseName: 'Waxing Crescent',
        hasAstronomicalNight: true,
      );

      final target = periodTarget.toTargetItem(date: DateTime(2026, 10, 9));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetDetailsSheet(
              target: target,
              night: plannedNight,
              latitude: 35.0,
              longitude: -110.0,
              elevation: 1500.0,
              availableLists: const [],
              onAddToList: (_, __, ___) {},
              filters: FilterState(),
              engine: mockEngine,
              periodTarget: periodTarget,
              plannedStartDate: DateTime(2026, 10, 1),
              plannedEndDate: DateTime(2026, 10, 31),
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 1. Verify Planned Period Banner exists
      expect(find.textContaining('PLANNED PERIOD: Oct 1 – Oct 31'), findsOneWidget);

      // 2. Verify Period Peak badge
      expect(find.text('Period Peak: Oct 9'), findsOneWidget);

      // 3. Verify Best Night in Window summary
      expect(find.textContaining('Best Night in Window: Oct 9'), findsOneWidget);

      // 4. Verify Annual Peak in Yearly Observing Window
      expect(find.textContaining('Annual Peak: Sep 16'), findsOneWidget);

      // 5. Verify status pill says 'Observable from Oct 1' rather than 'Visible Tonight'
      expect(find.text('Visible Tonight'), findsNothing);
      expect(find.text('Observable from Oct 1'), findsOneWidget);
    });
  });
}
