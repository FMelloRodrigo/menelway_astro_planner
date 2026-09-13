import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/observing_list.dart';
import 'package:app/core/settings_service.dart';
import 'package:app/core/catalog_manager.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings & FilterState Persistence Tests', () {
    test('FilterState serialization and deserialization preserves all values', () {
      final original = FilterState(
        minAltitude: 35.0,
        minDurationHours: 3.5,
        minMoonSeparation: 45.0,
        minAzimuth: 90.0,
        maxAzimuth: 270.0,
        quadrant: 2,
        maxMagnitude: 11.5,
        minMagnitude: 0.0,
        minSizeArcmin: 15.0,
        maxSizeArcmin: 120.0,
        selectedCatalogs: {'Messier', 'Arp', 'Herschel'},
        selectedObjectTypes: {'Galaxy', 'Bright Nebula'},
        searchQuery: 'Whirlpool',
        useCustomTimeWindow: true,
        customStartHour: 22,
        customStartMinute: 30,
        customEndHour: 2,
        customEndMinute: 15,
        observerLat: -23.5505,
        observerLon: -46.6333,
        observerElevation: 760.0,
        observerLocationName: 'São Paulo, Brazil',
      );

      final jsonMap = original.toJson();
      final restored = FilterState.fromJson(jsonMap);

      expect(restored.minAltitude, 35.0);
      expect(restored.minDurationHours, 3.5);
      expect(restored.minMoonSeparation, 45.0);
      expect(restored.minAzimuth, 90.0);
      expect(restored.maxAzimuth, 270.0);
      expect(restored.quadrant, 2);
      expect(restored.maxMagnitude, 11.5);
      expect(restored.minMagnitude, 0.0);
      expect(restored.minSizeArcmin, 15.0);
      expect(restored.maxSizeArcmin, 120.0);
      expect(restored.selectedCatalogs, {'Messier', 'Arp', 'Herschel'});
      expect(restored.selectedObjectTypes, {'Galaxy', 'Bright Nebula'});
      expect(restored.searchQuery, 'Whirlpool');
      expect(restored.useCustomTimeWindow, true);
      expect(restored.customStartHour, 22);
      expect(restored.customStartMinute, 30);
      expect(restored.customEndHour, 2);
      expect(restored.customEndMinute, 15);
      expect(restored.observerLat, -23.5505);
      expect(restored.observerLon, -46.6333);
      expect(restored.observerElevation, 760.0);
      expect(restored.observerLocationName, 'São Paulo, Brazil');
    });

    test('ObservingListModel serialization preserves target items', () {
      final list = ObservingListModel(
        id: 42,
        name: 'Tonight Targets',
        description: 'Deep sky run',
        sessionDate: '2026-09-05',
        createdAt: 1788655976,
        items: [
          ObservingListItemModel(
            listId: 42,
            dsoId: 5824,
            name: 'NGC 224',
            displayName: 'M 31 (Andromeda Galaxy)',
            catalog: 'NGC',
            objectType: 'Galaxy',
            constellation: 'And',
            magnitude: 3.44,
            notes: 'Lum 120s x 30',
            status: 'planned',
            addedAt: 1788655976,
          ),
        ],
      );

      final json = list.toJson();
      final restored = ObservingListModel.fromJson(json);

      expect(restored.id, 42);
      expect(restored.name, 'Tonight Targets');
      expect(restored.items.length, 1);
      expect(restored.items.first.dsoId, 5824);
      expect(restored.items.first.displayName, 'M 31 (Andromeda Galaxy)');
    });

    test('SettingsService save, load, and clear lifecycle', () async {
      final filters = FilterState(
        observerLat: 48.8566,
        observerLon: 2.3522,
        observerElevation: 35.0,
        observerLocationName: 'Paris, France',
      );

      final dummyList = ObservingListModel(
        id: 1,
        name: 'Paris Session',
        description: 'Test session',
        sessionDate: '2026-09-05',
        createdAt: 123456,
        items: [],
      );

      await SettingsService.saveSettings(
        filters: filters,
        isRedNightMode: true,
        sortMode: 'brightness',
        selectedTargetId: 100,
        observingLists: [dummyList],
      );

      final loaded = await SettingsService.loadSettings();
      expect(loaded.isRedNightMode, true);
      expect(loaded.filters.observerLocationName, 'Paris, France');
      expect(loaded.filters.observerLat, 48.8566);
      expect(loaded.sortMode, 'brightness');
      expect(loaded.selectedTargetId, 100);
      expect(loaded.observingListsBackup?.length, 1);
      expect(loaded.observingListsBackup?.first.name, 'Paris Session');

      // Clear settings
      await SettingsService.clearSettings();
      final cleared = await SettingsService.loadSettings();
      expect(cleared.isRedNightMode, false);
      expect(cleared.filters.observerLocationName, 'New York, USA');
      expect(cleared.filters.observerLat, 40.7128);
    });

    test('CatalogManager getStorageDirectory resolves an existing writable directory', () async {
      final dir = await CatalogManager.getStorageDirectory();
      expect(dir.existsSync(), isTrue);
      // Verify directory is writable by creating a small test probe
      final probe = File('${dir.path}/.probe_test');
      await probe.writeAsString('test');
      expect(probe.existsSync(), isTrue);
      await probe.delete();
    });

    test('CatalogManager getDatabasePath resolves a valid non-empty path', () async {
      final dbPath = await CatalogManager.getDatabasePath();
      expect(dbPath.isNotEmpty, isTrue);
      expect(dbPath.endsWith('catalogs.db'), isTrue);
      final file = File(dbPath);
      expect(file.existsSync(), isTrue);
      expect(await file.length(), greaterThan(1024 * 1024));
    });
  });
}
