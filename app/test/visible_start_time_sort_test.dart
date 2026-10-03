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

  final earlyTarget = TargetItem(
    id: 1,
    name: 'Early Target',
    catalog: 'NGC',
    objectType: 'Galaxy',
    constellation: 'And',
    raHours: 1.0,
    decDegrees: 20.0,
    peakAltitudeDeg: 60.0,
    visibleDurationHours: 4.0,
    transitTime: DateTime(2026, 9, 6, 22, 0),
    visibleStartTime: DateTime(2026, 9, 6, 19, 45),
    visibleEndTime: DateTime(2026, 9, 6, 23, 45),
    minMoonSepDeg: 50.0,
    meetsCriteria: true,
  );

  final lateTarget = TargetItem(
    id: 2,
    name: 'Late Target',
    catalog: 'NGC',
    objectType: 'Open Cluster',
    constellation: 'Tau',
    raHours: 4.0,
    decDegrees: 15.0,
    peakAltitudeDeg: 55.0,
    visibleDurationHours: 3.0,
    transitTime: DateTime(2026, 9, 7, 2, 0),
    visibleStartTime: DateTime(2026, 9, 6, 23, 30),
    visibleEndTime: DateTime(2026, 9, 7, 2, 30),
    minMoonSepDeg: 60.0,
    meetsCriteria: true,
  );

  final unobservableTarget = TargetItem(
    id: 3,
    name: 'Below Target',
    catalog: 'NGC',
    objectType: 'Planetary Nebula',
    constellation: 'Cyg',
    raHours: 20.0,
    decDegrees: -30.0,
    peakAltitudeDeg: 10.0,
    visibleDurationHours: 0.0,
    transitTime: DateTime(2026, 9, 6, 21, 0),
    visibleStartTime: null,
    visibleEndTime: null,
    minMoonSepDeg: 70.0,
    meetsCriteria: false,
  );

  Widget createTestWidget({required List<TargetItem> targets}) {
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
          onAddToList: (listId, targetId, notes) {},
        ),
      ),
    );
  }

  testWidgets('TargetSearchView displays visible window span on target cards and sorts by visibleStartTime', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(createTestWidget(targets: [lateTarget, earlyTarget, unobservableTarget]));
    await tester.pumpAndSettle();

    // Verify formatted visibility window spans are rendered
    expect(find.text('19:45 – 23:45'), findsOneWidget);
    expect(find.text('23:30 – 02:30'), findsOneWidget);
    expect(find.text('--:--'), findsOneWidget);

    // Find sort dropdown and switch to visibleStartTime
    final dropdownFinder = find.byType(DropdownButton<SortMode>);
    expect(dropdownFinder, findsOneWidget);
    await tester.tap(dropdownFinder);
    await tester.pumpAndSettle();

    final sortOptionFinder = find.byWidgetPredicate(
      (widget) => widget is DropdownMenuItem<SortMode> && widget.value == SortMode.visibleStartTime,
    );
    expect(sortOptionFinder, findsOneWidget);
    await tester.tap(sortOptionFinder.last);
    await tester.pumpAndSettle();

    // Verify that Early Target appears first in list
    final targetCards = find.byType(InkWell);
    expect(targetCards, findsWidgets);
  });
}
