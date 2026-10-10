import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'app_logger.dart';
import 'catalog_manager.dart';

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
  static const MethodChannel _storageChannel = MethodChannel('com.astrotargets.app/storage');

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

  /// Official CDS Strasbourg HiPS endpoints and active mirrors.
  static const String primaryEndpoint = 'https://alasky.cds.unistra.fr/hips-image-services/hips2fits';
  static const String mirrorEndpoint = 'https://alaskybis.cds.unistra.fr/hips-image-services/hips2fits';
  static const String altMirrorEndpoint = 'https://alasky.u-strasbg.fr/hips-image-services/hips2fits';

  static const List<String> fallbackEndpoints = [
    primaryEndpoint,
    mirrorEndpoint,
    altMirrorEndpoint,
  ];

  /// Default overall request timeout and per-attempt timeout.
  static const Duration defaultTimeout = Duration(seconds: 25);
  static const Duration perAttemptTimeout = Duration(seconds: 12);

  final Map<String, Uint8List> _memCache = {};
  Directory? _diskCacheDir;
  bool _diskCacheInitialized = false;

  /// Backoff duration between retries (configurable; default Duration.zero for instant mirror failover).
  Duration retryBackoff = Duration.zero;

  /// Reusable persistent HTTP client for connection pooling and Keep-Alive.
  http.Client _client = http.Client();

  @visibleForTesting
  void setClientForTesting(http.Client client) {
    _client = client;
  }

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
    String endpoint = primaryEndpoint,
  }) {
    var raDeg = (raHours * 15.0) % 360.0;
    if (raDeg < 0) raDeg += 360.0;
    final clampedDec = decDegrees.clamp(-90.0, 90.0);
    final cleanRa = raDeg.toStringAsFixed(5);
    final cleanDec = clampedDec.toStringAsFixed(5);
    final cleanFov = fovDeg.toStringAsFixed(4);

    return '$endpoint'
        '?hips=${Uri.encodeComponent(surveyId)}'
        '&ra=$cleanRa'
        '&dec=$cleanDec'
        '&fov=$cleanFov'
        '&width=$width'
        '&height=$height'
        '&format=$format';
  }

  /// Returns candidate mirror URLs for failover when the primary server is congested or down.
  static List<String> getMirrorCandidateUrls(String url) {
    final candidates = <String>[url];
    for (final ep in fallbackEndpoints) {
      for (final existingEp in fallbackEndpoints) {
        if (url.startsWith(existingEp) && ep != existingEp) {
          final substituted = url.replaceFirst(existingEp, ep);
          if (!candidates.contains(substituted)) {
            candidates.add(substituted);
          }
        }
      }
    }
    return candidates;
  }

  /// Normalizes a HiPS URL to its query parameters so caching is shared across primary and mirrors.
  static String normalizeCacheKey(String url) {
    final uri = Uri.tryParse(url);
    if (uri != null && uri.hasQuery) {
      return uri.query;
    }
    return url;
  }

  /// Hashes a URL query string to create a consistent local filename across all mirrors.
  static String _urlToCacheFilename(String url) {
    final key = normalizeCacheKey(url);
    var hash = 0xcbf29ce484222325;
    for (var i = 0; i < key.length; i++) {
      hash ^= key.codeUnitAt(i);
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return 'sky_${hash.toRadixString(16).padLeft(16, '0')}.jpg';
  }

  /// Initializes the local disk cache directory safely across mobile (Android/iOS) and desktop platforms.
  Future<Directory?> _getCacheDirectory() async {
    if (_diskCacheInitialized) return _diskCacheDir;

    // 1. Android specific verified cache directory
    if (Platform.isAndroid) {
      try {
        final String? nativeCacheDir = await _storageChannel.invokeMethod<String>('getCacheDir');
        if (nativeCacheDir != null && nativeCacheDir.isNotEmpty) {
          final dir = Directory(p.join(nativeCacheDir, 'astro_sky_images'));
          if (!dir.existsSync()) {
            dir.createSync(recursive: true);
          }
          _diskCacheDir = dir;
          _diskCacheInitialized = true;
          return _diskCacheDir;
        }
      } catch (e) {
        AppLogger.debug('Storage channel getCacheDir fallback on Android: $e', tag: _tag);
      }
    }

    // 2. Standard system temp fallback (cross-platform desktop & testing)
    try {
      final baseTemp = Directory.systemTemp;
      final cacheDir = Directory(p.join(baseTemp.path, 'astro_sky_images'));
      if (!cacheDir.existsSync()) {
        cacheDir.createSync(recursive: true);
      }
      _diskCacheDir = cacheDir;
      _diskCacheInitialized = true;
      return _diskCacheDir;
    } catch (e) {
      AppLogger.warning('Failed to initialize sky image cache directory', tag: _tag, error: e);
      _diskCacheInitialized = true;
      return null;
    }
  }

  /// Fetches sky image bytes from memory cache, local disk cache, or CDS HiPS2FITS API.
  /// Automatically tries active CDS mirror endpoints if primary times out or returns HTTP errors.
  Future<Uint8List?> fetchSkyImage(
    String url, {
    Duration timeout = defaultTimeout,
    Duration attemptTimeout = perAttemptTimeout,
    int maxRetries = 2,
    Duration? retryBackoff,
  }) async {
    final effectiveBackoff = retryBackoff ?? this.retryBackoff;
    final cacheKey = normalizeCacheKey(url);

    // 1. Check memory cache (fastest, 0ms)
    if (_memCache.containsKey(cacheKey)) {
      return _memCache[cacheKey];
    }

    // 2. Check disk cache
    final diskDir = await _getCacheDirectory();
    File? cacheFile;
    if (diskDir != null) {
      cacheFile = File(p.join(diskDir.path, _urlToCacheFilename(url)));
      try {
        if (cacheFile.existsSync()) {
          final bytes = await cacheFile.readAsBytes();
          if (bytes.isNotEmpty) {
            _addToMemCache(cacheKey, bytes);
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

    // 3. Network fetch via CDS HiPS2FITS with mirror failover
    final candidateUrls = getMirrorCandidateUrls(url);
    final totalAttempts = math.min(candidateUrls.length, maxRetries + 1);

    for (var attempt = 0; attempt < totalAttempts; attempt++) {
      final candidateUrl = candidateUrls[attempt];
      try {
        final response = await _client.get(
          Uri.parse(candidateUrl),
          headers: const {
            'User-Agent': 'AstroTargetsPlanner/1.0 (Astronomy Deep Sky Planner; contact: open-source)',
            'Accept': 'image/jpeg,image/*,*/*',
          },
        ).timeout(attemptTimeout);

        if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
          final bytes = response.bodyBytes;
          _addToMemCache(cacheKey, bytes);

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
          AppLogger.warning(
            'CDS HiPS2FITS endpoint attempt ${attempt + 1} returned HTTP ${response.statusCode} ($candidateUrl)',
            tag: _tag,
          );
        }
      } catch (e) {
        AppLogger.debug(
          'CDS HiPS2FITS fetch attempt ${attempt + 1} failed for ($candidateUrl): $e',
          tag: _tag,
        );
      }

      // Small backoff before trying mirror or retrying (e.g. 500ms)
      if (attempt < totalAttempts - 1 && effectiveBackoff > Duration.zero) {
        await Future.delayed(effectiveBackoff * (attempt + 1));
      }
    }

    return null;
  }

  void _addToMemCache(String url, Uint8List bytes) {
    final key = normalizeCacheKey(url);
    if (_memCache.length >= maxMemCacheEntries) {
      // Evict oldest entry
      _memCache.remove(_memCache.keys.first);
    }
    _memCache[key] = bytes;
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

  /// Clears in-memory sky image cache synchronously.
  void clearMemoryCache() {
    _memCache.clear();
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
