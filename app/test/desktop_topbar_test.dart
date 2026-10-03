import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
import 'package:app/theme/astro_theme.dart';
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

  testWidgets('Check Desktop Topbar elements height', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AstroTheme.darkTheme(),
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

    final searchBox = tester.renderObject(find.byType(TextField)) as RenderBox;
    final filterBox = tester.renderObject(find.widgetWithText(FilledButton, "Filters")) as RenderBox;
    final sortDropdownFinder = find.byType(DropdownButton<SortMode>);
    final containerFinder = find.ancestor(of: sortDropdownFinder, matching: find.byType(Container)).first;
    final containerBox = tester.renderObject(containerFinder) as RenderBox;

    expect(searchBox.size.height, 48.0);
    expect(filterBox.size.height, 48.0);
    expect(containerBox.size.height, 48.0);
  });
}
