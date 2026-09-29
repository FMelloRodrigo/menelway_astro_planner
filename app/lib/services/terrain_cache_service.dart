import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'package:path/path.dart' as p;

import '../core/app_logger.dart';
import '../models/terrain_profile_model.dart';

/// Local disk cache manager for computed 360-degree terrain horizon profiles.
class TerrainCacheService {
  static const String _tag = 'TerrainCacheService';
  static const String _cacheFolder = 'terrain_cache';

  /// Resolves the storage directory for terrain cache files.
  static Future<Directory> _getCacheDirectory() async {
    Directory baseDir;
    try {
      if (Platform.isWindows) {
        final exeDir = p.dirname(Platform.resolvedExecutable);
        baseDir = Directory(p.join(exeDir, _cacheFolder));
        // Check if writeable (e.g. portable installation)
        if (!baseDir.existsSync()) {
          baseDir.createSync(recursive: true);
        }
        return baseDir;
      }
    } catch (_) {}

    // Fallback to user home / app data
    final home = Platform.environment['USERPROFILE'] ??
        Platform.environment['HOME'] ??
        Directory.current.path;
    baseDir = Directory(p.join(home, '.astro_targets_tool', _cacheFolder));
    if (!baseDir.existsSync()) {
      baseDir.createSync(recursive: true);
    }
    return baseDir;
  }

  static String _coordKey(double lat, double lon) {
    // Round to ~100m precision (3 decimal places)
    final latStr = lat.toStringAsFixed(3).replaceAll('.', '_');
    final lonStr = lon.toStringAsFixed(3).replaceAll('.', '_');
    return 'profile_${latStr}_$lonStr.json';
  }

  /// Calculates geodesic distance between two coordinate pairs in meters.
  static double _distanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000.0;
    const d2r = math.pi / 180.0;
    final dLat = (lat2 - lat1) * d2r;
    final dLon = (lon2 - lon1) * d2r;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * d2r) * math.cos(lat2 * d2r) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  /// Saves a computed terrain profile to disk for permanent offline availability.
  static Future<void> saveProfile(TerrainProfileModel profile) async {
    try {
      final dir = await _getCacheDirectory();
      final file = File(p.join(dir.path, _coordKey(profile.originLat, profile.originLon)));
      final jsonStr = jsonEncode(profile.toJson());
      await file.writeAsString(jsonStr);
      AppLogger.info('Saved terrain profile for (${profile.originLat}, ${profile.originLon}) to ${file.path}', tag: _tag);
    } catch (e) {
      AppLogger.error('Failed to save terrain profile: $e', tag: _tag);
    }
  }

  /// Loads a cached terrain profile if one exists within [maxDistanceMeters] of the site.
  /// If no profile is within [maxDistanceMeters], automatically falls back to the closest
  /// cached profile in the cache directory to prevent unconfigured or flat silhouettes.
  static Future<TerrainProfileModel?> loadProfile(
    double lat,
    double lon, {
    double maxDistanceMeters = 15000.0,
  }) async {
    try {
      final dir = await _getCacheDirectory();
      if (!dir.existsSync()) return null;

      // Exact key first
      final directFile = File(p.join(dir.path, _coordKey(lat, lon)));
      if (directFile.existsSync()) {
        final content = await directFile.readAsString();
        final jsonMap = jsonDecode(content) as Map<String, dynamic>;
        AppLogger.info('Found exact coordinate cached terrain profile', tag: _tag);
        return TerrainProfileModel.fromJson(jsonMap);
      }

      // Proximity scan across cached profiles
      TerrainProfileModel? closestProfile;
      double minDistance = double.infinity;

      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.endsWith('.json')) {
          try {
            final content = await entity.readAsString();
            final jsonMap = jsonDecode(content) as Map<String, dynamic>;
            final profile = TerrainProfileModel.fromJson(jsonMap);
            final dist = _distanceMeters(lat, lon, profile.originLat, profile.originLon);
            if (dist < minDistance) {
              minDistance = dist;
              closestProfile = profile;
            }
          } catch (_) {}
        }
      }

      if (closestProfile != null) {
        if (minDistance <= maxDistanceMeters) {
          AppLogger.info('Found cached profile within ${minDistance.toStringAsFixed(1)}m of coordinates', tag: _tag);
          return closestProfile;
        } else {
          AppLogger.info('Using closest cached profile (${minDistance.toStringAsFixed(1)}m away) as fallback', tag: _tag);
          return closestProfile;
        }
      }
    } catch (e) {
      AppLogger.error('Error loading cached terrain profile: $e', tag: _tag);
    }
    return null;
  }

  /// Loads the most recently saved or closest terrain profile from the local cache.
  static Future<TerrainProfileModel?> loadLatestOrClosestProfile({double? lat, double? lon}) async {
    if (lat != null && lon != null) {
      return loadProfile(lat, lon);
    }
    try {
      final dir = await _getCacheDirectory();
      if (!dir.existsSync()) return null;

      File? newestFile;
      DateTime? newestTime;

      for (final entity in dir.listSync()) {
        if (entity is File && entity.path.endsWith('.json')) {
          final modTime = entity.lastModifiedSync();
          if (newestTime == null || modTime.isAfter(newestTime)) {
            newestTime = modTime;
            newestFile = entity;
          }
        }
      }

      if (newestFile != null) {
        final content = await newestFile.readAsString();
        final jsonMap = jsonDecode(content) as Map<String, dynamic>;
        AppLogger.info('Loaded most recent terrain profile from ${newestFile.path}', tag: _tag);
        return TerrainProfileModel.fromJson(jsonMap);
      }
    } catch (e) {
      AppLogger.error('Error loading latest terrain profile: $e', tag: _tag);
    }
    return null;
  }
}
