import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';

import 'package:app/core/astro_engine.dart';
import 'package:app/core/fake_astro_engine.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/altitude_point.dart';
import 'package:app/views/altitude_curve_chart.dart';
import 'package:app/views/target_details_sheet.dart';

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

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('Temporary Trajectory Date Tests', () {
    testWidgets('AltitudeCurveChart renders date stepper and fires callbacks', (tester) async {
      final night = fakeEngine.getNightSummary(
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        date: DateTime(2026, 9, 20),
      );

      DateTime? lastDateChanged;
      bool resetCalled = false;

      final samplePoints = [
        AltitudePoint(
          time: DateTime(2026, 9, 20, 20, 0),
          altitude: 45.0,
          azimuth: 120.0,
          moonSeparation: 80.0,
          meetsCriteria: true,
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          AltitudeCurveChart(
            targetPoints: samplePoints,
            night: night,
            targetName: 'M31',
            onDateChanged: (newDate) => lastDateChanged = newDate,
            onResetDate: () => resetCalled = true,
            isDateOverridden: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Formatted session date should be visible (e.g. Sep 20)
      final initialDateStr = DateFormat('MMM d').format(night.sunset);
      expect(find.text(initialDateStr), findsOneWidget);

      // Previous day icon button (<)
      expect(find.byIcon(Icons.chevron_left_rounded), findsOneWidget);
      await tester.tap(find.byIcon(Icons.chevron_left_rounded));
      await tester.pumpAndSettle();

      expect(lastDateChanged, isNotNull);
      expect(lastDateChanged!.day, 19);

      // Next day icon button (>)
      await tester.tap(find.byIcon(Icons.chevron_right_rounded));
      await tester.pumpAndSettle();

      expect(lastDateChanged!.day, 21);

      // When date is overridden, TEMP badge and Today reset button appear
      await tester.pumpWidget(
        buildTestableWidget(
          AltitudeCurveChart(
            targetPoints: samplePoints,
            night: night,
            targetName: 'M31',
            activeDate: DateTime(2026, 9, 25),
            isDateOverridden: true,
            onDateChanged: (newDate) => lastDateChanged = newDate,
            onResetDate: () => resetCalled = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TEMP'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // Clicking Today triggers onResetDate callback
      await tester.tap(find.text('Today'));
      await tester.pumpAndSettle();
      expect(resetCalled, isTrue);
    });

    testWidgets('TargetDetailsSheet temporarily overrides trajectory day and resets on target change', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final baseDate = DateTime(2026, 9, 20);
      final night = fakeEngine.getNightSummary(
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        date: baseDate,
      );

      final target1 = FakeAstroEngine.defaultMockTargets[0]; // M31
      final target2 = FakeAstroEngine.defaultMockTargets[1]; // M42

      await tester.pumpWidget(
        buildTestableWidget(
          TargetDetailsSheet(
            target: target1,
            night: night,
            latitude: -22.28,
            longitude: -42.53,
            elevation: 850.0,
            availableLists: const [],
            onAddToList: (_, __, ___) {},
            engine: fakeEngine,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final baseDateStr = DateFormat('MMM d').format(night.sunset);
      expect(find.text(baseDateStr), findsWidgets);

      // Initially no TEMP badge
      expect(find.text('TEMP'), findsNothing);

      // Tap next day (>) to step forward
      final nextDayBtn = find.byIcon(Icons.chevron_right_rounded);
      expect(nextDayBtn, findsWidgets);
      await tester.ensureVisible(nextDayBtn.first);
      await tester.tap(nextDayBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now TEMP badge is shown and Today button is displayed
      expect(find.text('TEMP'), findsOneWidget);
      expect(find.text('Today'), findsOneWidget);

      // Next day date string should be visible
      final nextDateStr = DateFormat('MMM d').format(baseDate.add(const Duration(days: 1)));
      expect(find.text(nextDateStr), findsWidgets);

      // When user clicks another target (e.g. target2 in desktop split view)
      await tester.pumpWidget(
        buildTestableWidget(
          TargetDetailsSheet(
            target: target2,
            night: night,
            latitude: -22.28,
            longitude: -42.53,
            elevation: 850.0,
            availableLists: const [],
            onAddToList: (_, __, ___) {},
            engine: fakeEngine,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Temporary override must be cleared: TEMP badge should be gone and base date shown
      expect(find.text('TEMP'), findsNothing);
      expect(find.text(baseDateStr), findsWidgets);
    });

    testWidgets('TargetDetailsSheet resetting via Today button reverts to base night', (tester) async {
      tester.view.physicalSize = const Size(1200, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      final baseDate = DateTime(2026, 9, 20);
      final night = fakeEngine.getNightSummary(
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        date: baseDate,
      );

      final target = FakeAstroEngine.defaultMockTargets[0];

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
            engine: fakeEngine,
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Step forward by 1 day
      final nextDayBtn = find.byIcon(Icons.chevron_right_rounded);
      await tester.ensureVisible(nextDayBtn.first);
      await tester.tap(nextDayBtn.first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('TEMP'), findsOneWidget);

      // Tap Today button to reset
      final todayBtn = find.text('Today');
      await tester.ensureVisible(todayBtn);
      await tester.tap(todayBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // TEMP is cleared and base night date is displayed
      expect(find.text('TEMP'), findsNothing);
      final baseDateStr = DateFormat('MMM d').format(night.sunset);
      expect(find.text(baseDateStr), findsWidgets);
    });

    testWidgets('Tapping date opens DatePicker and selecting date triggers callback', (tester) async {
      final night = fakeEngine.getNightSummary(
        latitude: -22.28,
        longitude: -42.53,
        elevation: 850.0,
        date: DateTime(2026, 9, 20),
      );

      DateTime? pickedDate;
      final samplePoints = [
        AltitudePoint(
          time: DateTime(2026, 9, 20, 20, 0),
          altitude: 45.0,
          azimuth: 120.0,
          moonSeparation: 80.0,
          meetsCriteria: true,
        ),
      ];

      await tester.pumpWidget(
        buildTestableWidget(
          AltitudeCurveChart(
            targetPoints: samplePoints,
            night: night,
            targetName: 'M31',
            onDateChanged: (d) => pickedDate = d,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap calendar date button
      final calendarIcon = find.byIcon(Icons.calendar_month_rounded);
      expect(calendarIcon, findsOneWidget);
      await tester.tap(calendarIcon);
      await tester.pumpAndSettle();

      // DatePicker dialog should be visible
      expect(find.byType(DatePickerDialog), findsOneWidget);

      // Tap OK button
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();

      expect(pickedDate, isNotNull);
    });
  });
}
