import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

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

  AppSettingsData({
    required this.filters,
    this.isRedNightMode = false,
    this.sortMode,
    this.selectedTargetId,
    this.observingListsBackup,
    this.equipmentProfiles,
    this.activeEquipmentProfileId,
    this.favorites,
  });
}

class SettingsService {
  static const String settingsFileName = 'user_settings.json';

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
    } catch (_) {
      // If exe directory is protected or read-only, fallback to storage directory
    }

    // 2. Storage directory (native filesDir on mobile or local AppData on desktop)
    final appDir = await CatalogManager.getStorageDirectory();
    return File(p.join(appDir.path, settingsFileName));
  }

  /// Loads saved user settings. Returns default values if no configuration exists.
  static Future<AppSettingsData> loadSettings() async {
    try {
      final file = await getSettingsFile();
      if (!await file.exists()) {
        return AppSettingsData(filters: FilterState());
      }

      final content = await file.readAsString();
      if (content.trim().isEmpty || content.trim() == '{}') {
        return AppSettingsData(filters: FilterState());
      }

      final data = jsonDecode(content) as Map<String, dynamic>;

      FilterState filters = FilterState();
      if (data.containsKey('filters') && data['filters'] is Map<String, dynamic>) {
        filters = FilterState.fromJson(data['filters'] as Map<String, dynamic>);
      }

      final isRedNightMode = data['isRedNightMode'] as bool? ?? false;
      final sortMode = data['sortMode'] as String?;
      final selectedTargetId = data['selectedTargetId'] as int?;

      List<ObservingListModel>? observingBackup;
      if (data.containsKey('observingLists') && data['observingLists'] is List) {
        observingBackup = (data['observingLists'] as List<dynamic>)
            .map((e) => ObservingListModel.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      List<EquipmentProfile>? equipmentProfiles;
      if (data.containsKey('equipmentProfiles') && data['equipmentProfiles'] is List) {
        equipmentProfiles = (data['equipmentProfiles'] as List<dynamic>)
            .map((e) => EquipmentProfile.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      final activeEquipmentProfileId = data['activeEquipmentProfileId'] as String?;

      List<TargetItem>? favorites;
      if (data.containsKey('favorites') && data['favorites'] is List) {
        favorites = (data['favorites'] as List<dynamic>)
            .map((e) => TargetItem.fromJson(e as Map<String, dynamic>))
            .toList();
      }

      return AppSettingsData(
        filters: filters,
        isRedNightMode: isRedNightMode,
        sortMode: sortMode,
        selectedTargetId: selectedTargetId,
        observingListsBackup: observingBackup,
        equipmentProfiles: equipmentProfiles,
        activeEquipmentProfileId: activeEquipmentProfileId,
        favorites: favorites,
      );
    } catch (_) {
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
  }) async {
    try {
      final file = await getSettingsFile();
      final data = <String, dynamic>{
        'version': 1,
        'savedAt': DateTime.now().toIso8601String(),
        'isRedNightMode': isRedNightMode,
        'filters': filters.toJson(),
      };

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

      await file.writeAsString(const JsonEncoder.withIndent('  ').convert(data));
    } catch (_) {
      // Non-fatal persistence failure
    }
  }

  /// Clears user configuration, resetting settings file to empty defaults.
  static Future<void> clearSettings() async {
    try {
      final file = await getSettingsFile();
      await file.writeAsString('{}');
    } catch (_) {}
  }
}
