import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

import '../models/filter_state.dart';
import '../models/observing_list.dart';

class AppSettingsData {
  final FilterState filters;
  final bool isRedNightMode;
  final String? sortMode;
  final int? selectedTargetId;
  final List<ObservingListModel>? observingListsBackup;

  AppSettingsData({
    required this.filters,
    this.isRedNightMode = false,
    this.sortMode,
    this.selectedTargetId,
    this.observingListsBackup,
  });
}

class SettingsService {
  static const String settingsFileName = 'user_settings.json';

  /// Resolves the portable configuration file path.
  static Future<File> getSettingsFile() async {
    // 1. Try next to the executable for true Windows portable zero-install mode
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final portableFile = File(p.join(exeDir, settingsFileName));
      if (await portableFile.exists()) {
        return portableFile;
      }
      // Test if directory is writable by attempting to create/touch the file
      await portableFile.writeAsString('{}');
      return portableFile;
    } catch (_) {
      // If exe directory is protected or read-only, fallback to local app data
    }

    // 2. Fallback to user AppData or mobile files directory
    final appDir = Platform.isAndroid
        ? Directory('/data/data/com.astrotargets.app/files')
        : Directory(p.join(Platform.environment['LOCALAPPDATA'] ?? '.', 'AstroTargetsTool'));

    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

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

      return AppSettingsData(
        filters: filters,
        isRedNightMode: isRedNightMode,
        sortMode: sortMode,
        selectedTargetId: selectedTargetId,
        observingListsBackup: observingBackup,
      );
    } catch (_) {
      return AppSettingsData(filters: FilterState());
    }
  }

  /// Saves current filters, location, night mode, and observing lists backup.
  static Future<void> saveSettings({
    required FilterState filters,
    required bool isRedNightMode,
    String? sortMode,
    int? selectedTargetId,
    List<ObservingListModel>? observingLists,
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
