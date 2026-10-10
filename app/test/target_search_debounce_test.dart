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

  final sampleTargets = [
    TargetItem(
      id: 1,
      name: 'M 33',
      messier: 'M 33',
      commonName: 'Triangulum Galaxy',
      catalog: 'Messier',
      objectType: 'Galaxy',
      constellation: 'Tri',
      raHours: 1.56,
      decDegrees: 30.65,
      magnitude: 5.7,
      peakAltitudeDeg: 60.0,
      visibleDurationHours: 5.0,
      transitTime: DateTime(2026, 9, 6, 23, 0),
      minMoonSepDeg: 50.0,
      meetsCriteria: true,
    ),
  ];

  Widget createWidget({
    required FilterState filters,
    required void Function(FilterState) onFilterChanged,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: TargetSearchView(
          targets: sampleTargets,
          night: testNight,
          filters: filters,
          isLoading: false,
          availableLists: const [],
          onFilterChanged: onFilterChanged,
          onAddToList: (_, _, _) {},
        ),
      ),
    );
  }

  group('TargetSearchView Debounce & Race-Condition Prevention Tests', () {
    testWidgets('Typing "m" does not immediately fire query due to single-char debounce delay', (tester) async {
      final queriesDispatched = <String>[];

      await tester.pumpWidget(createWidget(
        filters: FilterState(searchQuery: ''),
        onFilterChanged: (f) => queriesDispatched.add(f.searchQuery),
      ));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      expect(searchField, findsOneWidget);

      await tester.enterText(searchField, 'm');
      await tester.pump();

      // At 300ms, single-character debounce (750ms) must NOT have fired
      await tester.pump(const Duration(milliseconds: 300));
      expect(queriesDispatched, isEmpty);

      // Fast-forward past remaining debounce duration
      await tester.pump(const Duration(milliseconds: 500));
      expect(queriesDispatched, ['m']);
    });

    testWidgets('Rapidly typing "m33" cancels premature queries and emits only final query', (tester) async {
      final queriesDispatched = <String>[];

      await tester.pumpWidget(createWidget(
        filters: FilterState(searchQuery: ''),
        onFilterChanged: (f) => queriesDispatched.add(f.searchQuery),
      ));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // User types 'm'
      await tester.enterText(searchField, 'm');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(queriesDispatched, isEmpty);

      // User types 'm3' within debounce window
      await tester.enterText(searchField, 'm3');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(queriesDispatched, isEmpty);

      // User finishes 'm33'
      await tester.enterText(searchField, 'm33');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      expect(queriesDispatched, isEmpty);

      // After user pauses and 600ms passes, exactly ONE query is dispatched with 'm33'
      await tester.pump(TargetSearchView.searchDebounceDelay);
      expect(queriesDispatched, ['m33']);
    });

    testWidgets('Submitting via keyboard done/enter immediately dispatches query', (tester) async {
      final queriesDispatched = <String>[];

      await tester.pumpWidget(createWidget(
        filters: FilterState(searchQuery: ''),
        onFilterChanged: (f) => queriesDispatched.add(f.searchQuery),
      ));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);
      await tester.enterText(searchField, 'ngc7000');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(queriesDispatched, ['ngc7000']);
    });

    testWidgets('Tapping clear button cancels debounce and clears query immediately', (tester) async {
      final queriesDispatched = <String>[];

      await tester.pumpWidget(createWidget(
        filters: FilterState(searchQuery: 'm31'),
        onFilterChanged: (f) => queriesDispatched.add(f.searchQuery),
      ));
      await tester.pumpAndSettle();

      final clearButton = find.byIcon(Icons.clear);
      expect(clearButton, findsOneWidget);

      await tester.tap(clearButton);
      await tester.pump();

      expect(queriesDispatched, ['']);
    });

    testWidgets('didUpdateWidget does not clobber user typing when parent acknowledges debounced query', (tester) async {
      FilterState currentFilters = FilterState(searchQuery: '');
      late StateSetter parentSetState;

      await tester.pumpWidget(StatefulBuilder(
        builder: (context, setState) {
          parentSetState = setState;
          return createWidget(
            filters: currentFilters,
            onFilterChanged: (updated) {
              setState(() => currentFilters = updated);
            },
          );
        },
      ));
      await tester.pumpAndSettle();

      final searchField = find.byType(TextField);

      // User types 'm'
      await tester.enterText(searchField, 'm');
      await tester.pump();

      // Debounce fires for 'm', updating parent state
      await tester.pump(TargetSearchView.singleCharSearchDebounceDelay);
      expect(currentFilters.searchQuery, 'm');

      // Now user continues typing 'm33' in TextField
      await tester.enterText(searchField, 'm33');
      await tester.pump();

      // Rebuild parent with currentFilters ('m') to simulate didUpdateWidget
      parentSetState(() {});
      await tester.pump();

      // TextField must STILL have 'm33', not be overwritten back to 'm'
      final textFieldWidget = tester.widget<TextField>(searchField);
      expect(textFieldWidget.controller!.text, 'm33');
    });
  });
}
