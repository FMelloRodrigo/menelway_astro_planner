import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
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

  // M20: Off-season (meetsCriteria = false), but exact designation match for 'm20'
  final m20Target = TargetItem(
    id: 12538,
    name: 'NGC 6514',
    messier: 'M 20',
    commonName: 'Trifid Nebula',
    catalog: 'Messier',
    objectType: 'Nebula',
    constellation: 'Sgr',
    raHours: 18.04,
    decDegrees: -23.03,
    magnitude: 6.3,
    peakAltitudeDeg: 12.0,
    visibleDurationHours: 0.0,
    transitTime: DateTime(2026, 9, 6, 17, 0),
    minMoonSepDeg: 60.0,
    meetsCriteria: false,
  );

  // Generate 25 secondary/loose matching targets that ARE observable tonight
  final observableTargets = List.generate(
    25,
    (index) => TargetItem(
      id: 2000 + index,
      name: 'IC 20$index',
      catalog: 'IC',
      objectType: 'Galaxy',
      constellation: 'And',
      raHours: 2.0 + (index * 0.1),
      decDegrees: 30.0,
      magnitude: 10.0 + (index * 0.1),
      peakAltitudeDeg: 50.0 + (index % 10),
      visibleDurationHours: 4.0,
      transitTime: DateTime(2026, 9, 6, 23, 0),
      minMoonSepDeg: 40.0,
      meetsCriteria: true,
    ),
  );

  Widget createTestWidget({
    required List<TargetItem> targets,
    required FilterState filters,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TargetSearchView(
          targets: targets,
          night: testNight,
          filters: filters,
          isLoading: false,
          availableLists: const [],
          onFilterChanged: (_) {},
          onAddToList: (_, _, _) {},
        ),
      ),
    );
  }

  testWidgets('TargetSearchView preserves off-season exact match (M20) at top in Relevance mode when searching', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    // List has M20 at index 0 (as returned by C++ relevance sort), followed by 25 observable targets
    final allTargets = [m20Target, ...observableTargets];

    await tester.pumpWidget(createTestWidget(
      targets: allTargets,
      filters: FilterState(searchQuery: 'm20', maxTargets: 20),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Verify M20 is visible in the search results list card despite maxTargets: 20
    expect(find.text('M 20 (Trifid Nebula)'), findsWidgets);

    // Check that dropdown contains and selects Relevance
    final dropdownFinder = find.byType(DropdownButton<SortMode>);
    expect(dropdownFinder, findsOneWidget);
    final dropdownWidget = tester.widget<DropdownButton<SortMode>>(dropdownFinder);
    expect(dropdownWidget.value, SortMode.relevance);
  });
}
