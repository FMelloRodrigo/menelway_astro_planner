import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

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
      return _diskCacheDir;
    } catch (_) {
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
            return bytes;
          }
        }
      } catch (_) {
        // Disk read error, fall through to network
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

        // Asynchronously persist to disk cache
        if (cacheFile != null) {
          Future.microtask(() async {
            try {
              await cacheFile!.writeAsBytes(bytes);
            } catch (_) {}
          });
        }

        return bytes;
      }
    } catch (_) {
      // Network timeout or offline
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

  /// Clears in-memory and disk cache.
  Future<void> clearCache() async {
    _memCache.clear();
    final diskDir = await _getCacheDirectory();
    if (diskDir != null && await diskDir.exists()) {
      try {
        await diskDir.delete(recursive: true);
        _diskCacheInitialized = false;
      } catch (_) {}
    }
  }
}
