import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/observing_site_manager.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/observing_site.dart';
import 'package:app/views/observing_sites_dialog.dart';
import 'package:app/l10n/app_localizations.dart';

void main() {
  group('ObservingSite Model Tests', () {
    test('Constructs with defaults and formats coordinates', () {
      const site = ObservingSite(
        id: 'test_1',
        name: 'Dark Sky Mountain',
        latitude: -22.456,
        longitude: -44.567,
        elevation: 1850.0,
        bortleClass: 2,
      );

      expect(site.id, 'test_1');
      expect(site.name, 'Dark Sky Mountain');
      expect(site.latitude, -22.456);
      expect(site.longitude, -44.567);
      expect(site.elevation, 1850.0);
      expect(site.bortleClass, 2);
      expect(site.bortleInfo.title, 'Truly Dark Site');
      expect(site.compactCoordinates, '22.5°S, 44.6°W');
      expect(site.coordinatesFormatted, '22.46°S, 44.57°W (1850m)');
    });

    test('Clamps coordinates and bortle values defensively', () {
      final site = const ObservingSite(
        id: 'test_clamp',
        name: 'Extreme Location',
        latitude: 0.0,
        longitude: 0.0,
        elevation: 0.0,
      ).copyWith(
        latitude: 120.0, // should clamp to 90.0
        longitude: -200.0, // should clamp to -180.0
        elevation: -600.0, // should clamp to -500.0
        bortleClass: 15, // should clamp to 9
      );

      expect(site.latitude, 90.0);
      expect(site.longitude, -180.0);
      expect(site.elevation, -500.0);
      expect(site.bortleClass, 9);
    });

    test('Serializes to and from JSON', () {
      const original = ObservingSite(
        id: 'site_json_test',
        name: 'Atacama Desert Lodge',
        latitude: -23.863,
        longitude: -67.785,
        elevation: 2400.0,
        bortleClass: 1,
        notes: 'World class darkness',
      );

      final json = original.toJson();
      final reconstituted = ObservingSite.fromJson(json);

      expect(reconstituted.id, original.id);
      expect(reconstituted.name, original.name);
      expect(reconstituted.latitude, original.latitude);
      expect(reconstituted.longitude, original.longitude);
      expect(reconstituted.elevation, original.elevation);
      expect(reconstituted.bortleClass, original.bortleClass);
      expect(reconstituted.notes, original.notes);
    });
  });

  group('ObservingSiteManager Tests', () {
    setUp(() {
      ObservingSiteManager.instance.resetToDefault();
    });

    test('Initializes with fallback FilterState', () {
      final filters = FilterState(
        observerLat: 48.8566,
        observerLon: 2.3522,
        observerElevation: 35.0,
        observerLocationName: 'Paris, France',
      );

      ObservingSiteManager.instance.init(fallbackFilters: filters);

      expect(ObservingSiteManager.instance.sites.length, 1);
      final active = ObservingSiteManager.instance.activeSite;
      expect(active.latitude, 48.8566);
      expect(active.longitude, 2.3522);
      expect(active.name, 'Paris, France');
    });

    test('Add, update, switch, and delete sites', () {
      final manager = ObservingSiteManager.instance;
      manager.resetToDefault();

      const newSite = ObservingSite(
        id: 'site_camp',
        name: 'Camping Dark Sky',
        latitude: -20.0,
        longitude: -40.0,
        elevation: 1200.0,
        bortleClass: 3,
      );

      // Add site
      manager.addSite(newSite, setAsActive: true);
      expect(manager.sites.length, 2);
      expect(manager.activeSiteId, 'site_camp');
      expect(manager.activeSite.name, 'Camping Dark Sky');

      // Update site
      final updatedSite = newSite.copyWith(name: 'Camping Dark Sky (Renamed)');
      manager.updateSite(updatedSite);
      expect(manager.activeSite.name, 'Camping Dark Sky (Renamed)');

      // Switch active site
      manager.setActiveSite(manager.sites.first.id);
      expect(manager.activeSiteId, manager.sites.first.id);

      // Cannot delete last remaining site
      manager.deleteSite(manager.sites.first.id);
      expect(manager.sites.length, 1);
      final couldDeleteLast = manager.deleteSite(manager.sites.first.id);
      expect(couldDeleteLast, isFalse);
      expect(manager.sites.length, 1);
    });
  });

  group('ObservingSitesDialog Widget Tests', () {
    testWidgets('Renders sites list and opens editor to add site', (tester) async {
      ObservingSiteManager.instance.resetToDefault();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(
            body: ObservingSitesDialog(
              isRedNightMode: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and list elements
      expect(find.text('Observing Sites'), findsOneWidget);
      expect(find.text(ObservingSiteManager.instance.activeSite.name), findsOneWidget);
      expect(find.textContaining('Bortle'), findsWidgets);

      // Tap "Add New Site" button
      final addBtn = find.text('Add New Site');
      expect(addBtn, findsOneWidget);
      await tester.tap(addBtn);
      await tester.pumpAndSettle();

      // Check editor fields
      expect(find.text('Add New Site'), findsOneWidget);
      expect(find.text('Bortle Sky Darkness'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      // Check Mini Bortle Palette chips (1..9)
      for (int i = 1; i <= 9; i++) {
        expect(find.text('$i'), findsOneWidget);
      }

      // Enter site name
      await tester.enterText(find.byType(TextField).first, 'Backyard Observatory');
      await tester.pump();

      // Tap Save Site button
      final saveBtn = find.text('Save Site');
      expect(saveBtn, findsOneWidget);
      await tester.tap(saveBtn);
      await tester.pumpAndSettle();

      // Returned to list and site was added
      expect(find.text('Backyard Observatory'), findsOneWidget);
      expect(ObservingSiteManager.instance.sites.any((s) => s.name == 'Backyard Observatory'), isTrue);
    });
  });
}
