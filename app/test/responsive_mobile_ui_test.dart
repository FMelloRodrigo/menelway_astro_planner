import 'package:flutter/material.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
import 'package:app/views/filter_dialog.dart';
import 'package:app/views/target_search_view.dart';
import 'package:app/views/target_details_sheet.dart';
import 'package:app/views/equipment_framing_dialog.dart';

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
    moonIllumination: 0.74,
    moonPhaseName: 'Waxing Gibbous',
    hasAstronomicalNight: true,
  );

  final testTarget = TargetItem(
    id: 1,
    name: 'M42',
    messier: 'M42',
    commonName: 'Orion Nebula',
    catalog: 'Messier',
    objectType: 'Bright Nebula',
    constellation: 'Orion',
    raHours: 5.588,
    decDegrees: -5.39,
    magnitude: 4.0,
    majorAxisArcmin: 65.0,
    surfaceBrightness: 11.2,
    peakAltitudeDeg: 68.4,
    visibleDurationHours: 4.5,
    transitTime: DateTime(2026, 9, 6, 23, 45),
    minMoonSepDeg: 82.0,
    meetsCriteria: true,
  );

  group('Mobile Responsive UI Tests', () {
    testWidgets('TargetSearchView search bar takes full width on mobile', (WidgetTester tester) async {
      // Simulate standard mobile phone viewport (360 x 640)
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FilterState filterState = FilterState();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetSearchView(
              targets: [testTarget],
              night: testNight,
              filters: filterState,
              isLoading: false,
              availableLists: const [],
              onFilterChanged: (f) => filterState = f,
              onAddToList: (listId, dsoId, notes) {},
            ),
          ),
        ),
      );

      // Verify search text field is present
      final searchFieldFinder = find.byType(TextField);
      expect(searchFieldFinder, findsOneWidget);

      // Verify search field is wide on mobile (should be > 300px out of 360px)
      final RenderBox searchBox = tester.renderObject(searchFieldFinder);
      expect(searchBox.size.width, greaterThan(300.0));

      // Verify "Filters" button and Sort dropdown are present in row 2 on mobile (defaulting to Brightness)
      expect(find.text("Filters"), findsOneWidget);
      expect(find.text("Magnitude (Brightest)"), findsOneWidget);

      // Type search text into search bar
      await tester.enterText(searchFieldFinder, "TestSearchQuery");
      await tester.pumpAndSettle();

      // Verify clear search icon button appears
      expect(find.byIcon(Icons.clear), findsOneWidget);

      // Tap clear search button
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      expect(find.text("TestSearchQuery"), findsNothing);
    });

    testWidgets('Target card renders in mobile layout without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetSearchView(
              targets: [testTarget],
              night: testNight,
              filters: FilterState(),
              isLoading: false,
              availableLists: const [],
              onFilterChanged: (_) {},
              onAddToList: (listId, dsoId, notes) {},
            ),
          ),
        ),
      );

      // Verify target display name and stats are rendered
      expect(find.text('M42 (Orion Nebula)'), findsOneWidget);
      expect(find.text('68°'), findsOneWidget);
      expect(find.text('4.5h visible'), findsOneWidget);
      expect(find.text('82°'), findsOneWidget);
    });

    testWidgets('FilterDialog renders on mobile viewport without overflow', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: FilterDialog(
              initialFilters: FilterState(),
              night: testNight,
              onApply: (_) {},
            ),
          ),
        ),
      );

      // Verify header and action buttons render without overflow
      expect(find.text('Filter Targets'), findsOneWidget);
      expect(find.text('Apply Filters'), findsOneWidget);
      expect(find.text('Reset Filters'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);
    });

    testWidgets('TargetDetailsSheet renders on mobile viewport with responsive metrics', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetDetailsSheet(
              target: testTarget,
              night: testNight,
              latitude: 40.7128,
              longitude: -74.0060,
              elevation: 10.0,
              availableLists: const [],
              onAddToList: (_, _, _) {},
            ),
          ),
        ),
      );

      // Verify details sheet renders title and mobile Add button
      expect(find.text('M42 (Orion Nebula)'), findsOneWidget);
      expect(find.text('Add to List'), findsOneWidget);
      expect(find.text('Peak Alt'), findsOneWidget);
      expect(find.text('68.4°'), findsOneWidget);
      expect(find.text('Visible Duration'), findsOneWidget);
      expect(find.text('4.5 hrs'), findsOneWidget);
    });

    testWidgets('Simulator button is visible and accessible on mobile viewport in Visual Sky Preview', (WidgetTester tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetDetailsSheet(
              target: testTarget,
              night: testNight,
              latitude: 40.7128,
              longitude: -74.0060,
              elevation: 10.0,
              availableLists: const [],
              onAddToList: (_, _, _) {},
            ),
          ),
        ),
      );

      // Scroll down to Visual Sky Preview
      await tester.scrollUntilVisible(
        find.text('Visual Sky Preview'),
        200.0,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Visual Sky Preview'), findsOneWidget);

      // Verify single Simulator button in toolbar below canvas is accessible on screen
      final simulatorFinder = find.widgetWithText(InkWell, 'Simulator');
      expect(simulatorFinder, findsOneWidget);

      final simulatorRect = tester.getRect(simulatorFinder);
      expect(simulatorRect.left, lessThan(360.0));

      // Tap the Simulator button to ensure it opens EquipmentFramingDialog
      await tester.tap(simulatorFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(EquipmentFramingDialog), findsOneWidget);
    });
  });
}

