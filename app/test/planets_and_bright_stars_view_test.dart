import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
import 'package:app/views/planets_view.dart';
import 'package:app/views/bright_stars_view.dart';
import 'package:app/l10n/app_localizations.dart';

void main() {
  final testNight = NightSummary(
    sunset: DateTime(2026, 9, 26, 18, 0),
    civilDusk: DateTime(2026, 9, 26, 18, 30),
    nauticalDusk: DateTime(2026, 9, 26, 19, 0),
    astronomicalDusk: DateTime(2026, 9, 26, 19, 30),
    solarMidnight: DateTime(2026, 9, 27, 0, 0),
    astronomicalDawn: DateTime(2026, 9, 27, 4, 30),
    nauticalDawn: DateTime(2026, 9, 27, 5, 0),
    civilDawn: DateTime(2026, 9, 27, 5, 30),
    sunrise: DateTime(2026, 9, 27, 6, 0),
    moonIllumination: 0.15,
    moonPhaseName: 'Waxing Crescent',
    hasAstronomicalNight: true,
  );

  final testPlanets = [
    TargetItem(
      id: 90005,
      name: 'Jupiter',
      catalog: 'Solar System',
      objectType: 'Planet',
      constellation: 'Tau',
      raHours: 4.85,
      decDegrees: 22.1,
      magnitude: -2.4,
      majorAxisArcmin: 0.75,
      commonName: 'Jupiter',
      peakAltitudeDeg: 68.0,
      visibleDurationHours: 6.2,
      transitTime: DateTime(2026, 9, 26, 23, 0),
      visibleStartTime: DateTime(2026, 9, 26, 20, 0),
      visibleEndTime: DateTime(2026, 9, 27, 4, 0),
      minMoonSepDeg: 45.0,
      meetsCriteria: true,
    ),
    TargetItem(
      id: 90006,
      name: 'Saturn',
      catalog: 'Solar System',
      objectType: 'Planet',
      constellation: 'Aqr',
      raHours: 23.1,
      decDegrees: -7.5,
      magnitude: 0.6,
      majorAxisArcmin: 0.33,
      commonName: 'Saturn',
      peakAltitudeDeg: 54.0,
      visibleDurationHours: 5.5,
      transitTime: DateTime(2026, 9, 26, 21, 30),
      visibleStartTime: DateTime(2026, 9, 26, 19, 30),
      visibleEndTime: DateTime(2026, 9, 27, 3, 0),
      minMoonSepDeg: 60.0,
      meetsCriteria: true,
    ),
  ];

  final testStars = [
    TargetItem(
      id: 91001,
      name: 'Sirius',
      catalog: 'Stars',
      objectType: 'Double Star',
      constellation: 'CMa',
      raHours: 6.75,
      decDegrees: -16.72,
      magnitude: -1.46,
      commonName: 'Alpha Canis Majoris',
      peakAltitudeDeg: 72.0,
      visibleDurationHours: 7.5,
      transitTime: DateTime(2026, 9, 27, 1, 0),
      visibleStartTime: DateTime(2026, 9, 26, 21, 0),
      visibleEndTime: DateTime(2026, 9, 27, 4, 30),
      minMoonSepDeg: 55.0,
      meetsCriteria: true,
    ),
    TargetItem(
      id: 91005,
      name: 'Vega',
      catalog: 'Stars',
      objectType: 'Star',
      constellation: 'Lyr',
      raHours: 18.62,
      decDegrees: 38.78,
      magnitude: 0.03,
      commonName: 'Alpha Lyrae',
      peakAltitudeDeg: 48.0,
      visibleDurationHours: 4.5,
      transitTime: DateTime(2026, 9, 26, 20, 0),
      visibleStartTime: DateTime(2026, 9, 26, 19, 30),
      visibleEndTime: DateTime(2026, 9, 27, 0, 30),
      minMoonSepDeg: 50.0,
      meetsCriteria: true,
    ),
  ];

  Widget buildApp(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: child,
    );
  }

  testWidgets('PlanetsView renders planet list and search filter works', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: PlanetsView(
            planets: testPlanets,
            night: testNight,
            filters: FilterState(),
            isLoading: false,
            availableLists: const [],
            onFilterChanged: (_) {},
            onAddToList: (listId, targetId, notes) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Jupiter'), findsWidgets);
    expect(find.text('Saturn'), findsWidgets);
    expect(find.text('Solar System'), findsOneWidget);
    expect(find.text('Real-time Ephemeris'), findsOneWidget);

    // Search for Saturn
    await tester.enterText(find.byType(TextField), 'Saturn');
    await tester.pumpAndSettle();

    expect(find.text('Saturn'), findsWidgets);
    expect(find.text('Jupiter'), findsNothing);
  });

  testWidgets('BrightStarsView renders stars and search filter works', (tester) async {
    await tester.pumpWidget(
      buildApp(
        Scaffold(
          body: BrightStarsView(
            stars: testStars,
            night: testNight,
            filters: FilterState(),
            isLoading: false,
            availableLists: const [],
            onFilterChanged: (_) {},
            onAddToList: (listId, targetId, notes) {},
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sirius'), findsWidgets);
    expect(find.text('Vega'), findsWidgets);
    expect(find.text('Navigational Stars'), findsOneWidget);

    // Search for Vega
    await tester.enterText(find.byType(TextField), 'Vega');
    await tester.pumpAndSettle();

    expect(find.text('Vega'), findsWidgets);
    expect(find.text('Sirius'), findsNothing);
  });

  testWidgets('NavigationRail switches between Targets, Planets, and Bright Stars views', (tester) async {
    int selectedIndex = 0;

    await tester.pumpWidget(
      buildApp(
        StatefulBuilder(
          builder: (context, setState) {
            return Scaffold(
              body: Row(
                children: [
                  NavigationRail(
                    selectedIndex: selectedIndex,
                    onDestinationSelected: (idx) => setState(() => selectedIndex = idx),
                    destinations: const [
                      NavigationRailDestination(icon: Icon(Icons.radar_rounded), label: Text('Targets')),
                      NavigationRailDestination(icon: Icon(Icons.public_rounded), label: Text('Planets')),
                      NavigationRailDestination(icon: Icon(Icons.star_rounded), label: Text('Bright Stars')),
                    ],
                  ),
                  Expanded(
                    child: selectedIndex == 0
                        ? const Center(child: Text('Targets View Content'))
                        : selectedIndex == 1
                            ? PlanetsView(
                                planets: testPlanets,
                                night: testNight,
                                filters: FilterState(),
                                isLoading: false,
                                availableLists: const [],
                                onFilterChanged: (_) {},
                                onAddToList: (listId, targetId, notes) {},
                              )
                            : BrightStarsView(
                                stars: testStars,
                                night: testNight,
                                filters: FilterState(),
                                isLoading: false,
                                availableLists: const [],
                                onFilterChanged: (_) {},
                                onAddToList: (listId, targetId, notes) {},
                              ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Targets View Content'), findsOneWidget);

    // Tap Planets tab
    await tester.tap(find.byIcon(Icons.public_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Solar System'), findsOneWidget);
    expect(find.text('Real-time Ephemeris'), findsOneWidget);
    expect(find.text('Jupiter'), findsWidgets);

    // Tap Bright Stars tab
    await tester.tap(find.byIcon(Icons.star_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Navigational Stars'), findsOneWidget);
    expect(find.text('Telescope Alignment & Focus'), findsOneWidget);
    expect(find.text('Sirius'), findsWidgets);
  });
}
