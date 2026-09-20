import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'app_logger.dart';

class SkySurvey {
  final String id;
  final String label;
  final String description;

  const SkySurvey({
    required this.id,
    required this.label,
    required this.description,
  });
}

class SkyImageService {
  SkyImageService._();
  static final SkyImageService instance = SkyImageService._();
  static const String _tag = 'SkyImageService';

  static const List<SkySurvey> availableSurveys = [
    SkySurvey(
      id: 'CDS/P/DSS2/color',
      label: 'DSS2 Color',
      description: 'Digitized Sky Survey 2 (All-Sky Optical RGB composite)',
    ),
    SkySurvey(
      id: 'CDS/P/PanSTARRS/DR1/color-z-zg-g',
      label: 'Pan-STARRS DR1',
      description: 'High-resolution optical survey (Dec > -30°)',
    ),
    SkySurvey(
      id: 'CDS/P/DECaLS/DR9/color',
      label: 'DECaLS DR9',
      description: 'Dark Energy Camera Legacy Survey (Equatorial & South)',
    ),
    SkySurvey(
      id: 'CDS/P/2MASS/color',
      label: '2MASS Infrared',
      description: 'Two Micron All Sky Survey (Near-Infrared JHK)',
    ),
  ];

  static const String defaultSurveyId = 'CDS/P/DSS2/color';
  static const int maxMemCacheEntries = 30;
  static const int maxDiskCacheEntries = 100;

  final Map<String, Uint8List> _memCache = {};
  Directory? _diskCacheDir;
  bool _diskCacheInitialized = false;

  /// Computes a recommended FOV in degrees based on the target's major axis in arcminutes.
  /// Generates a comfortable frame (approx 2.2x the target's physical extent) clamped
  /// between 0.25° (15') and 8.0° (480').
  static double computeRecommendedFovDeg(double? majorAxisArcmin) {
    if (majorAxisArcmin != null && majorAxisArcmin > 0) {
      final fov = (majorAxisArcmin * 2.2) / 60.0;
      return fov.clamp(0.25, 8.0);
    }
    // Default FOV: 0.6° = 36 arcminutes (typical DSO framing)
    return 0.6;
  }

  /// Builds the CDS HiPS2FITS cutout REST API URL.
  static String buildHiPSUrl({
    required double raHours,
    required double decDegrees,
    required double fovDeg,
    String surveyId = defaultSurveyId,
    int width = 512,
    int height = 512,
    String format = 'jpg',
  }) {
    final raDeg = (raHours * 15.0) % 360.0;
    final cleanRa = raDeg.toStringAsFixed(5);
    final cleanDec = decDegrees.toStringAsFixed(5);
    final cleanFov = fovDeg.toStringAsFixed(4);

    return 'https://alasky.cds.unistra.fr/hips-image-services/hips2fits'
        '?hips=${Uri.encodeComponent(surveyId)}'
        '&ra=$cleanRa'
        '&dec=$cleanDec'
        '&fov=$cleanFov'
        '&width=$width'
        '&height=$height'
        '&format=$format';
  }

  /// Hashes a URL to create a safe local filename.
  static String _urlToCacheFilename(String url) {
    // Simple fast 64-bit integer hash fallback if crypto is not imported
    var hash = 0xcbf29ce484222325;
    for (var i = 0; i < url.length; i++) {
      hash ^= url.codeUnitAt(i);
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return 'sky_${hash.toRadixString(16).padLeft(16, '0')}.jpg';
  }

  /// Initializes the local disk cache directory.
  Future<Directory?> _getCacheDirectory() async {
    if (_diskCacheInitialized) return _diskCacheDir;

    try {
      final baseTemp = Directory.systemTemp;
      final cacheDir = Directory(p.join(baseTemp.path, 'astro_sky_images'));
      if (!await cacheDir.exists()) {
        await cacheDir.create(recursive: true);
      }
      _diskCacheDir = cacheDir;
      _diskCacheInitialized = true;
      // Auto-prune existing disk cache on startup to enforce the cap
      Future.microtask(() => pruneDiskCache());
      return _diskCacheDir;
    } catch (e) {
      AppLogger.warning('Failed to initialize sky image cache directory', tag: _tag, error: e);
      _diskCacheInitialized = true;
      return null;
    }
  }

  /// Fetches sky image bytes from memory cache, local disk cache, or CDS HiPS2FITS API.
  Future<Uint8List?> fetchSkyImage(
    String url, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    // 1. Check memory cache (fastest, 0ms)
    if (_memCache.containsKey(url)) {
      return _memCache[url];
    }

    // 2. Check disk cache
    final diskDir = await _getCacheDirectory();
    File? cacheFile;
    if (diskDir != null) {
      cacheFile = File(p.join(diskDir.path, _urlToCacheFilename(url)));
      try {
        if (await cacheFile.exists()) {
          final bytes = await cacheFile.readAsBytes();
          if (bytes.isNotEmpty) {
            _addToMemCache(url, bytes);
            // Touch file to update LRU timestamp
            try {
              await cacheFile.setLastModified(DateTime.now());
            } catch (e) {
              AppLogger.debug('Failed to touch cached file: $e', tag: _tag);
            }
            return bytes;
          }
        }
      } catch (e) {
        AppLogger.debug('Disk cache read error for $url: $e', tag: _tag);
      }
    }

    // 3. Network fetch via CDS HiPS2FITS
    try {
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'AstroTargetsPlanner/1.0 (Astronomy Deep Sky Planner; contact: open-source)',
        },
      ).timeout(timeout);

      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        final bytes = response.bodyBytes;
        _addToMemCache(url, bytes);

        // Asynchronously persist to disk cache and enforce count cap
        if (cacheFile != null) {
          Future.microtask(() async {
            try {
              await cacheFile!.writeAsBytes(bytes);
              await pruneDiskCache();
            } catch (e) {
              AppLogger.debug('Failed writing sky image to disk cache: $e', tag: _tag);
            }
          });
        }

        return bytes;
      } else {
        AppLogger.warning('CDS HiPS2FITS request failed with HTTP ${response.statusCode}', tag: _tag);
      }
    } catch (e) {
      AppLogger.debug('Network fetch failed for sky image ($url): $e', tag: _tag);
    }

    return null;
  }

  void _addToMemCache(String url, Uint8List bytes) {
    if (_memCache.length >= maxMemCacheEntries) {
      // Evict oldest entry
      _memCache.remove(_memCache.keys.first);
    }
    _memCache[url] = bytes;
  }

  /// Prunes disk cache to ensure it does not exceed [maxEntries] (default: 100).
  /// Deletes the oldest files based on LRU last-modified timestamps.
  Future<void> pruneDiskCache({int maxEntries = maxDiskCacheEntries}) async {
    final dir = await _getCacheDirectory();
    if (dir == null || !await dir.exists()) return;

    try {
      final files = <File>[];
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          files.add(entity);
        }
      }

      if (files.length <= maxEntries) return;

      final timestamps = <File, DateTime>{};
      for (final f in files) {
        try {
          timestamps[f] = await f.lastModified();
        } catch (e) {
          AppLogger.debug('Could not read timestamp for ${f.path}: $e', tag: _tag);
          timestamps[f] = DateTime.fromMillisecondsSinceEpoch(0);
        }
      }

      // Sort oldest first (LRU eviction)
      files.sort((a, b) {
        final timeA = timestamps[a] ?? DateTime.fromMillisecondsSinceEpoch(0);
        final timeB = timestamps[b] ?? DateTime.fromMillisecondsSinceEpoch(0);
        return timeA.compareTo(timeB);
      });

      final excessCount = files.length - maxEntries;
      for (var i = 0; i < excessCount; i++) {
        try {
          await files[i].delete();
        } catch (e) {
          AppLogger.debug('Could not delete old cached sky image: $e', tag: _tag);
        }
      }
    } catch (e) {
      AppLogger.warning('Error during sky image cache prune', tag: _tag, error: e);
    }
  }

  /// Returns the number of cached sky image files currently stored on disk.
  Future<int> getDiskCacheCount() async {
    final dir = await _getCacheDirectory();
    if (dir == null || !await dir.exists()) return 0;

    var count = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          count++;
        }
      }
    } catch (e) {
      AppLogger.debug('Error counting disk cache files: $e', tag: _tag);
    }
    return count;
  }

  /// Returns the total size in bytes of all cached sky image files on disk.
  Future<int> getDiskCacheSizeBytes() async {
    final dir = await _getCacheDirectory();
    if (dir == null || !await dir.exists()) return 0;

    var totalBytes = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File && entity.path.endsWith('.jpg')) {
          try {
            totalBytes += await entity.length();
          } catch (e) {
            AppLogger.debug('Error reading cache file size: $e', tag: _tag);
          }
        }
      }
    } catch (e) {
      AppLogger.debug('Error calculating disk cache size: $e', tag: _tag);
    }
    return totalBytes;
  }

  /// Clears both in-memory and on-disk sky image cache.
  Future<void> clearCache() async {
    _memCache.clear();
    final diskDir = await _getCacheDirectory();
    if (diskDir != null && await diskDir.exists()) {
      try {
        await diskDir.delete(recursive: true);
        _diskCacheInitialized = false;
      } catch (e) {
        AppLogger.warning('Failed deleting sky image cache directory', tag: _tag, error: e);
      }
    }
  }
}
