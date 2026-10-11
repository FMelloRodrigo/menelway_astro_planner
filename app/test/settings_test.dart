import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/observing_list.dart';
import 'package:app/core/settings_service.dart';
import 'package:app/core/catalog_manager.dart';
import 'package:app/core/app_logger.dart';
import 'package:path/path.dart' as p;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Settings & FilterState Persistence Tests', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('settings_test_');
      SettingsService.customSettingsFile = File(p.join(tempDir.path, 'user_settings.json'));
    });

    tearDown(() async {
      SettingsService.customSettingsFile = null;
      try {
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      } catch (_) {}
    });
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
      expect(cleared.filters.observerLocationName, 'Nova Friburgo, Rio de Janeiro, Brazil');
      expect(cleared.filters.observerLat, -22.2819);
    });

    test('SettingsService saveNightMode persists and loads updated night mode state', () async {
      await SettingsService.clearSettings();

      // Verify default is false
      var loaded = await SettingsService.loadSettings();
      expect(loaded.isRedNightMode, isFalse);

      // Toggle to true
      await SettingsService.saveNightMode(true);
      loaded = await SettingsService.loadSettings();
      expect(loaded.isRedNightMode, isTrue);

      // Toggle to false
      await SettingsService.saveNightMode(false);
      loaded = await SettingsService.loadSettings();
      expect(loaded.isRedNightMode, isFalse);
    });

    test('SettingsService backup creation and corruption recovery', () async {
      await SettingsService.clearSettings();

      // 1. Initial write
      final filterV1 = FilterState(observerLocationName: 'Original City', observerLat: 10.0);
      await SettingsService.saveSettings(
        filters: filterV1,
        isRedNightMode: false,
      );

      final settingsFile = await SettingsService.getSettingsFile();
      final backupFile = await SettingsService.getSettingsBackupFile();
      expect(settingsFile.existsSync(), isTrue);

      // 2. Second write should trigger creation of .bak of first write
      final filterV2 = FilterState(observerLocationName: 'Updated City', observerLat: 20.0);
      await SettingsService.saveSettings(
        filters: filterV2,
        isRedNightMode: true,
      );
      expect(backupFile.existsSync(), isTrue);

      // Verify normal load gets v2
      var loaded = await SettingsService.loadSettings();
      expect(loaded.isRedNightMode, true);
      expect(loaded.filters.observerLocationName, 'Updated City');

      // 3. Corrupt primary file with broken JSON
      await settingsFile.writeAsString('{ "corrupted_json": [ incomplete ...');

      // 4. Loading should fail on primary, log warning, and fall back to backup
      loaded = await SettingsService.loadSettings();
      expect(loaded.filters.observerLocationName, isNotEmpty);

      // Clean up
      await SettingsService.clearSettings();
      expect(backupFile.existsSync(), isFalse);
    });

    test('AppLogger records messages and notifies listener', () {
      final logs = <String>[];
      AppLogger.onLog = (level, tag, message, error, stackTrace) {
        logs.add('${level.name}:$tag:$message');
      };

      AppLogger.info('Test Info Message', tag: 'TestTag');
      AppLogger.warning('Test Warning Message', tag: 'TestTag');
      AppLogger.error('Test Error Message', tag: 'TestTag', error: Exception('Boom'));

      expect(logs.any((l) => l.contains('info:TestTag:Test Info Message')), isTrue);
      expect(logs.any((l) => l.contains('warning:TestTag:Test Warning Message')), isTrue);
      expect(logs.any((l) => l.contains('error:TestTag:Test Error Message')), isTrue);

      AppLogger.onLog = null;
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

    test('FilterState.currentObservingDate anchors to previous evening before dawn cutoff and today after', () {
      // 03:00 AM on Oct 11 -> active session began evening of Oct 10
      final morning3am = DateTime(2026, 10, 11, 3, 0);
      final sessionMorning = FilterState.currentObservingDate(morning3am);
      expect(sessionMorning, DateTime(2026, 10, 10));

      // 05:59 AM on Oct 11 -> active session began evening of Oct 10
      final morning559am = DateTime(2026, 10, 11, 5, 59);
      final session559 = FilterState.currentObservingDate(morning559am);
      expect(session559, DateTime(2026, 10, 10));

      // 06:00 AM on Oct 11 -> dawn cutoff reached, planning for evening of Oct 11
      final morning6am = DateTime(2026, 10, 11, 6, 0);
      final session6am = FilterState.currentObservingDate(morning6am);
      expect(session6am, DateTime(2026, 10, 11));

      // 16:00 PM on Oct 11 -> planning for tonight (Oct 11)
      final afternoon4pm = DateTime(2026, 10, 11, 16, 0);
      final sessionAfternoon = FilterState.currentObservingDate(afternoon4pm);
      expect(sessionAfternoon, DateTime(2026, 10, 11));
    });

    test('FilterState.toJson excludes date by default and SettingsService replaces stale persisted dates', () async {
      final staleDateFilters = FilterState(
        date: DateTime(2026, 10, 10),
        observerLocationName: 'Stale Date Test Site',
      );

      // Verify date is not included in toJson by default
      final defaultJson = staleDateFilters.toJson();
      expect(defaultJson.containsKey('date'), isFalse);

      // Verify opt-in includeDate works
      final explicitJson = staleDateFilters.toJson(includeDate: true);
      expect(explicitJson.containsKey('date'), isTrue);

      // Test that SettingsService loading settings replaces any stale date on disk
      final tempDir = Directory.systemTemp.createTempSync('astro_settings_date_test_');
      final settingsFile = File('${tempDir.path}/settings.json');
      SettingsService.customSettingsFile = settingsFile;

      try {
        // Manually write an older settings file with a stale date from Oct 10
        await settingsFile.writeAsString('''{
          "version": 1,
          "filters": {
            "date": "2026-10-10T00:00:00.000",
            "observerLocationName": "Saved Test Site"
          }
        }''');

        final loaded = await SettingsService.loadSettings();
        expect(loaded.filters.observerLocationName, 'Saved Test Site');
        // Date must NOT be the stale Oct 10 from disk
        expect(loaded.filters.date, FilterState.currentObservingDate());
      } finally {
        SettingsService.customSettingsFile = null;
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      }
    });
  });
}
