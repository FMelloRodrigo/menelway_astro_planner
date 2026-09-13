import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/favorites_manager.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
import 'package:app/views/favorites_view.dart';
import 'package:app/views/target_details_sheet.dart';

void main() {
  group('Favorites Manager & Serialization Tests', () {
    final sampleTarget = TargetItem(
      id: 7000,
      name: 'NGC 7000',
      caldwell: 'C20',
      commonName: 'North America Nebula',
      catalog: 'NGC',
      objectType: 'Emission Nebula',
      constellation: 'Cyg',
      raHours: 20.98,
      decDegrees: 44.53,
      magnitude: 4.0,
      majorAxisArcmin: 120.0,
      positionAngleDeg: 145.0,
      surfaceBrightness: 13.0,
      peakAltitudeDeg: 82.0,
      visibleDurationHours: 6.5,
      transitTime: DateTime(2026, 9, 21, 22, 0),
      minMoonSepDeg: 60.0,
      meetsCriteria: true,
    );

    test('TargetItem serializes to and from JSON correctly', () {
      final json = sampleTarget.toJson();
      expect(json['id'], 7000);
      expect(json['name'], 'NGC 7000');
      expect(json['caldwell'], 'C20');
      expect(json['commonName'], 'North America Nebula');
      expect(json['positionAngleDeg'], 145.0);

      final restored = TargetItem.fromJson(json);
      expect(restored.id, sampleTarget.id);
      expect(restored.name, sampleTarget.name);
      expect(restored.caldwell, sampleTarget.caldwell);
      expect(restored.commonName, sampleTarget.commonName);
      expect(restored.positionAngleDeg, sampleTarget.positionAngleDeg);
      expect(restored.majorAxisArcmin, sampleTarget.majorAxisArcmin);
      expect(restored.meetsCriteria, sampleTarget.meetsCriteria);
    });

    test('FavoritesManager manages target collection and notifies listeners', () {
      final mgr = FavoritesManager.instance;
      mgr.clear();
      expect(mgr.isEmpty, isTrue);
      expect(mgr.isFavorite(7000), isFalse);

      int notifyCount = 0;
      void listener() => notifyCount++;
      mgr.addListener(listener);

      // Add favorite
      mgr.addFavorite(sampleTarget);
      expect(mgr.count, 1);
      expect(mgr.isFavorite(7000), isTrue);
      expect(notifyCount, 1);

      // Toggle off
      mgr.toggleFavorite(sampleTarget);
      expect(mgr.count, 0);
      expect(mgr.isFavorite(7000), isFalse);
      expect(notifyCount, 2);

      // Toggle on
      mgr.toggleFavorite(sampleTarget);
      expect(mgr.count, 1);
      expect(mgr.isFavorite(7000), isTrue);
      expect(notifyCount, 3);

      // Remove favorite
      mgr.removeFavorite(7000);
      expect(mgr.count, 0);
      expect(notifyCount, 4);

      mgr.removeListener(listener);
    });
  });

  group('Favorites UI Widget Tests', () {
    final sampleNight = NightSummary(
      sunset: DateTime(2026, 9, 21, 18, 30),
      civilDusk: DateTime(2026, 9, 21, 18, 50),
      nauticalDusk: DateTime(2026, 9, 21, 19, 15),
      astronomicalDusk: DateTime(2026, 9, 21, 19, 45),
      solarMidnight: DateTime(2026, 9, 21, 23, 59),
      astronomicalDawn: DateTime(2026, 9, 22, 6, 30),
      nauticalDawn: DateTime(2026, 9, 22, 6, 0),
      civilDawn: DateTime(2026, 9, 22, 5, 30),
      sunrise: DateTime(2026, 9, 22, 7, 0),
      moonIllumination: 0.15,
      moonPhaseName: "Waxing Crescent",
      hasAstronomicalNight: true,
    );

    final targetA = TargetItem(
      id: 1976,
      name: 'NGC 1976',
      messier: 'M42',
      commonName: 'Great Orion Nebula',
      catalog: 'Messier',
      objectType: 'Nebula',
      constellation: 'Ori',
      raHours: 5.588,
      decDegrees: -5.39,
      magnitude: 4.0,
      majorAxisArcmin: 65.0,
      positionAngleDeg: 55.0,
      surfaceBrightness: 11.5,
      peakAltitudeDeg: 62.0,
      visibleDurationHours: 5.5,
      transitTime: DateTime(2026, 9, 21, 23, 0),
      minMoonSepDeg: 45.0,
      meetsCriteria: true,
    );

    final targetB = TargetItem(
      id: 224,
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
      positionAngleDeg: 35.0,
      surfaceBrightness: 13.5,
      peakAltitudeDeg: 88.0,
      visibleDurationHours: 8.0,
      transitTime: DateTime(2026, 9, 21, 21, 30),
      minMoonSepDeg: 70.0,
      meetsCriteria: true,
    );

    testWidgets('TargetDetailsSheet heart button toggles favorite status', (tester) async {
      FavoritesManager.instance.clear();
      expect(FavoritesManager.instance.isFavorite(targetA.id), isFalse);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TargetDetailsSheet(
              target: targetA,
              night: sampleNight,
              latitude: 40.71,
              longitude: -74.00,
              elevation: 10.0,
              isRedNightMode: false,
              availableLists: const [],
              onAddToList: (listId, dsoId, notes) {},
            ),
          ),
        ),
      );

      // Verify "Add to List" button and heart button are rendered
      expect(find.text("Add to List"), findsOneWidget);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);

      // Tap heart button to add to favorites
      await tester.tap(find.byIcon(Icons.favorite_border_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(FavoritesManager.instance.isFavorite(targetA.id), isTrue);
      expect(find.byIcon(Icons.favorite_rounded), findsOneWidget);

      // Tap again to remove
      await tester.tap(find.byIcon(Icons.favorite_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(FavoritesManager.instance.isFavorite(targetA.id), isFalse);
      expect(find.byIcon(Icons.favorite_border_rounded), findsOneWidget);
    });

    testWidgets('FavoritesView displays empty state and target cards', (tester) async {
      FavoritesManager.instance.clear();

      bool explored = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FavoritesView(
              night: sampleNight,
              filters: FilterState(),
              isRedNightMode: false,
              availableLists: const [],
              onAddToList: (listId, dsoId, notes) {},
              onExploreTargets: () => explored = true,
            ),
          ),
        ),
      );

      // 1. Verify empty state
      expect(find.text("No Favorite Targets Yet"), findsOneWidget);
      expect(find.text("Explore Night Targets"), findsOneWidget);

      await tester.tap(find.text("Explore Night Targets"));
      expect(explored, isTrue);

      // 2. Add targets and verify cards appear
      FavoritesManager.instance.addFavorite(targetA);
      FavoritesManager.instance.addFavorite(targetB);
      await tester.pumpAndSettle();

      expect(find.text("Favorite Targets"), findsOneWidget);
      expect(find.textContaining("M42"), findsWidgets);
      expect(find.textContaining("M31"), findsWidgets);

      // 3. Test search filter in favorites
      final searchInput = find.byType(TextField);
      expect(searchInput, findsOneWidget);
      await tester.enterText(searchInput, "Andromeda");
      await tester.pumpAndSettle();

      expect(find.textContaining("M31"), findsWidgets);
      expect(find.textContaining("M42"), findsNothing);
    });
  });
}
