import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'app_logger.dart';
import 'catalog_manager.dart';
import '../models/equipment_profile.dart';
import '../models/filter_state.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';

class AppSettingsData {
  final FilterState filters;
  final bool isRedNightMode;
  final String? sortMode;
  final int? selectedTargetId;
  final List<ObservingListModel>? observingListsBackup;
  final List<EquipmentProfile>? equipmentProfiles;
  final String? activeEquipmentProfileId;
  final List<TargetItem>? favorites;
  final String? languageCode;
  final int schemaVersion;

  AppSettingsData({
    required this.filters,
    this.isRedNightMode = false,
    this.sortMode,
    this.selectedTargetId,
    this.observingListsBackup,
    this.equipmentProfiles,
    this.activeEquipmentProfileId,
    this.favorites,
    this.languageCode,
    this.schemaVersion = SettingsService.currentSchemaVersion,
  });
}

class SettingsService {
  static const String settingsFileName = 'user_settings.json';
  static const String settingsBackupFileName = 'user_settings.json.bak';
  static const int currentSchemaVersion = 1;

  static const String _tag = 'SettingsService';

  /// Resolves the portable configuration file path.
  static Future<File> getSettingsFile() async {
    // 1. Try next to the executable for true Windows portable zero-install mode
    try {
      if (Platform.isWindows) {
        final exeDir = p.dirname(Platform.resolvedExecutable);
        final portableFile = File(p.join(exeDir, settingsFileName));
        if (await portableFile.exists()) {
          return portableFile;
        }
        // Test if directory is writable by attempting to create/touch the file
        await portableFile.writeAsString('{}');
        return portableFile;
      }
    } catch (e) {
      AppLogger.debug('Exe directory not writable for portable settings, falling back to app storage: $e', tag: _tag);
    }

    // 2. Storage directory (native filesDir on mobile or local AppData on desktop)
    final appDir = await CatalogManager.getStorageDirectory();
    return File(p.join(appDir.path, settingsFileName));
  }

  /// Resolves the backup configuration file path.
  static Future<File> getSettingsBackupFile() async {
    final file = await getSettingsFile();
    return File('${file.path}.bak');
  }

  /// Helper to safely read and parse a JSON settings file with automatic backup fallback.
  static Future<Map<String, dynamic>> _readSettingsJson() async {
    final primaryFile = await getSettingsFile();
    final backupFile = await getSettingsBackupFile();

    // 1. Try reading the primary settings file
    if (await primaryFile.exists()) {
      try {
        final content = await primaryFile.readAsString();
        if (content.trim().isNotEmpty && content.trim() != '{}') {
          final decoded = jsonDecode(content);
          if (decoded is Map<String, dynamic>) {
            return _migrateData(decoded);
          }
        } else {
          return {};
        }
      } catch (e, st) {
        AppLogger.warning(
          'Corrupted primary settings file at ${primaryFile.path}. Attempting backup recovery.',
          tag: _tag,
          error: e,
          stackTrace: st,
        );
      }
    }

    // 2. If primary failed or missing, try backup file
    if (await backupFile.exists()) {
      try {
        final backupContent = await backupFile.readAsString();
        if (backupContent.trim().isNotEmpty && backupContent.trim() != '{}') {
          final decoded = jsonDecode(backupContent);
          if (decoded is Map<String, dynamic>) {
            AppLogger.info('Successfully recovered settings from backup file', tag: _tag);
            return _migrateData(decoded);
          }
        }
      } catch (e, st) {
        AppLogger.error(
          'Failed reading backup settings file as well',
          tag: _tag,
          error: e,
          stackTrace: st,
        );
      }
    }

    return {};
  }

  /// Safely writes JSON data with backup creation and atomic overwrite.
  static Future<void> _writeSettingsJson(Map<String, dynamic> data) async {
    try {
      final file = await getSettingsFile();
      final backupFile = await getSettingsBackupFile();

      data['version'] = currentSchemaVersion;
      data['savedAt'] = DateTime.now().toIso8601String();

      final jsonString = const JsonEncoder.withIndent('  ').convert(data);

      // Create backup of current valid file before overwriting
      if (await file.exists()) {
        try {
          final currentContent = await file.readAsString();
          if (currentContent.trim().isNotEmpty && currentContent.trim() != '{}') {
            await backupFile.writeAsString(currentContent, flush: true);
          }
        } catch (e) {
          AppLogger.warning('Failed to create settings backup before write', tag: _tag, error: e);
        }
      }

      // Write atomically via temporary file
      final tempFile = File('${file.path}.tmp');
      await tempFile.writeAsString(jsonString, flush: true);

      if (await file.exists()) {
        await file.delete();
      }
      await tempFile.rename(file.path);
    } catch (e, st) {
      AppLogger.error('Failed to write settings to disk', tag: _tag, error: e, stackTrace: st);
    }
  }

  /// Migrates older settings formats to the current schema.
  static Map<String, dynamic> _migrateData(Map<String, dynamic> data) {
    final version = data['version'] as int? ?? 1;
    if (version < currentSchemaVersion) {
      AppLogger.info('Migrating settings schema from v$version to v$currentSchemaVersion', tag: _tag);
      data['version'] = currentSchemaVersion;
    }
    return data;
  }

  /// Loads saved user settings. Returns default values if no configuration exists.
  static Future<AppSettingsData> loadSettings() async {
    try {
      final data = await _readSettingsJson();
      if (data.isEmpty) {
        return AppSettingsData(filters: FilterState());
      }

      FilterState filters = FilterState();
      if (data.containsKey('filters') && data['filters'] is Map<String, dynamic>) {
        try {
          filters = FilterState.fromJson(data['filters'] as Map<String, dynamic>);
        } catch (e) {
          AppLogger.warning('Failed to parse saved FilterState, using defaults', tag: _tag, error: e);
        }
      }

      final isRedNightMode = data['isRedNightMode'] as bool? ?? false;
      final sortMode = data['sortMode'] as String?;
      final selectedTargetId = data['selectedTargetId'] as int?;

      List<ObservingListModel>? observingBackup;
      if (data.containsKey('observingLists') && data['observingLists'] is List) {
        observingBackup = (data['observingLists'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((e) => ObservingListModel.fromJson(e))
            .toList();
      }

      List<EquipmentProfile>? equipmentProfiles;
      if (data.containsKey('equipmentProfiles') && data['equipmentProfiles'] is List) {
        equipmentProfiles = (data['equipmentProfiles'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((e) => EquipmentProfile.fromJson(e))
            .toList();
      }
      final activeEquipmentProfileId = data['activeEquipmentProfileId'] as String?;
      final languageCode = data['languageCode'] as String?;

      List<TargetItem>? favorites;
      if (data.containsKey('favorites') && data['favorites'] is List) {
        favorites = (data['favorites'] as List<dynamic>)
            .whereType<Map<String, dynamic>>()
            .map((e) => TargetItem.fromJson(e))
            .toList();
      }

      final schemaVersion = data['version'] as int? ?? currentSchemaVersion;

      return AppSettingsData(
        filters: filters,
        isRedNightMode: isRedNightMode,
        sortMode: sortMode,
        selectedTargetId: selectedTargetId,
        observingListsBackup: observingBackup,
        equipmentProfiles: equipmentProfiles,
        activeEquipmentProfileId: activeEquipmentProfileId,
        favorites: favorites,
        languageCode: languageCode,
        schemaVersion: schemaVersion,
      );
    } catch (e, st) {
      AppLogger.error('Unexpected error loading settings, returning defaults', tag: _tag, error: e, stackTrace: st);
      return AppSettingsData(filters: FilterState());
    }
  }

  /// Saves current filters, location, night mode, observing lists backup, equipment profiles, and favorites.
  static Future<void> saveSettings({
    required FilterState filters,
    required bool isRedNightMode,
    String? sortMode,
    int? selectedTargetId,
    List<ObservingListModel>? observingLists,
    List<EquipmentProfile>? equipmentProfiles,
    String? activeEquipmentProfileId,
    List<TargetItem>? favorites,
    String? languageCode,
  }) async {
    try {
      final data = await _readSettingsJson();

      data['isRedNightMode'] = isRedNightMode;
      data['filters'] = filters.toJson();

      if (sortMode != null) {
        data['sortMode'] = sortMode;
      }
      if (selectedTargetId != null) {
        data['selectedTargetId'] = selectedTargetId;
      }
      if (observingLists != null) {
        data['observingLists'] = observingLists.map((l) => l.toJson()).toList();
      }
      if (equipmentProfiles != null) {
        data['equipmentProfiles'] = equipmentProfiles.map((p) => p.toJson()).toList();
      }
      if (activeEquipmentProfileId != null) {
        data['activeEquipmentProfileId'] = activeEquipmentProfileId;
      }
      if (favorites != null) {
        data['favorites'] = favorites.map((t) => t.toJson()).toList();
      }
      if (languageCode != null) {
        data['languageCode'] = languageCode;
      }

      await _writeSettingsJson(data);
    } catch (e, st) {
      AppLogger.error('Failed saving user settings', tag: _tag, error: e, stackTrace: st);
    }
  }

  /// Quick helper to update just the user's preferred language code ('en', 'pt', etc.).
  static Future<void> saveLanguage(String? languageCode) async {
    try {
      final data = await _readSettingsJson();
      if (languageCode != null) {
        data['languageCode'] = languageCode;
      } else {
        data.remove('languageCode');
      }
      await _writeSettingsJson(data);
    } catch (e, st) {
      AppLogger.error('Failed saving language setting', tag: _tag, error: e, stackTrace: st);
    }
  }

  /// Clears user configuration, resetting settings file to empty defaults.
  static Future<void> clearSettings() async {
    try {
      final file = await getSettingsFile();
      final backupFile = await getSettingsBackupFile();
      await file.writeAsString('{}', flush: true);
      if (await backupFile.exists()) {
        await backupFile.delete();
      }
      AppLogger.info('Settings cleared to defaults', tag: _tag);
    } catch (e, st) {
      AppLogger.error('Error clearing settings', tag: _tag, error: e, stackTrace: st);
    }
  }
}
