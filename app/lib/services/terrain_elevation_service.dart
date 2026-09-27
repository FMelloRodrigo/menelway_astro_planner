import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:http/http.dart' as http;

import '../models/terrain_profile_model.dart';

class _TileKey {
  final int z;
  final int x;
  final int y;

  const _TileKey(this.z, this.x, this.y);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is _TileKey &&
          runtimeType == other.runtimeType &&
          z == other.z &&
          x == other.x &&
          y == other.y;

  @override
  int get hashCode => Object.hash(z, x, y);

  String get path => '$z/$x/$y';
}

class _RingSpec {
  final double fromDistM;
  final double toDistM;
  final int zoom;
  final double stepM;
  final bool bilinear;

  const _RingSpec({
    required this.fromDistM,
    required this.toDistM,
    required this.zoom,
    required this.stepM,
    required this.bilinear,
  });
}

/// Service to query and raymarch bare-earth digital elevation models (DEM)
/// from the free AWS Open Data Terrain Tiles (Terrarium format).
class TerrainElevationService {
  static const String tileBaseUrl =
      'https://s3.amazonaws.com/elevation-tiles-prod/terrarium/';

  static const double rEarth = 6371000.0; // Earth mean radius in meters
  static const double rEff = rEarth * 7.0 / 6.0; // Effective radius with atmospheric refraction
  static const double eyeHeightM = 1.6; // Observer eye level above ground
  static const double startDistM = 50.0; // Disregard ground under observer's feet (<50m)
  static const double maxRangeM = 120000.0; // 120 km horizon horizon limit
  static const int rayCount = 720; // 0.5 degree steps

  static const double d2r = math.pi / 180.0;
  static const double r2d = 180.0 / math.pi;

  /// In-memory cache for decoded elevation tiles during session
  static final Map<_TileKey, Int16List> _tileCache = {};

  /// Build concentric rings tailored to latitude to avoid overfetching poleward tiles.
  static List<_RingSpec> _buildRings(double latDeg) {
    return const [
      _RingSpec(fromDistM: 0, toDistM: 5000, zoom: 13, stepM: 25, bilinear: true),
      _RingSpec(fromDistM: 5000, toDistM: 30000, zoom: 11, stepM: 80, bilinear: false),
      _RingSpec(fromDistM: 30000, toDistM: 120000, zoom: 8, stepM: 350, bilinear: false),
    ];
  }

  static double _lonToX(double lon, int z) {
    return (lon + 180.0) / 360.0 * math.pow(2, z);
  }

  static double _latToY(double lat, int z) {
    final s = lat.clamp(-85.0511, 85.0511) * d2r;
    final y = (1.0 - math.log(math.tan(s) + 1.0 / math.cos(s)) / math.pi) / 2.0;
    return y * math.pow(2, z);
  }

  /// Calculates destination coordinate (lat, lon) along great-circle bearing and distance.
  static List<double> _destPoint(double lat, double lon, double azDeg, double distM) {
    final d = distM / rEarth;
    final br = azDeg * d2r;
    final la = lat * d2r;
    final lo = lon * d2r;

    final sinLa = math.sin(la);
    final cosLa = math.cos(la);
    final sinD = math.sin(d);
    final cosD = math.cos(d);

    final la2 = math.asin(sinLa * cosD + cosLa * sinD * math.cos(br));
    final lo2 = lo + math.atan2(math.sin(br) * sinD * cosLa, cosD - sinLa * math.sin(la2));

    return [
      la2 * r2d,
      ((lo2 * r2d + 540.0) % 360.0) - 180.0,
    ];
  }

  /// Precomputes the exact set of tiles required by the raymarching pass.
  static Set<_TileKey> _identifyRequiredTiles(double lat, double lon, List<_RingSpec> rings) {
    final keys = <_TileKey>{};

    for (int i = 0; i < rayCount; i++) {
      final az = (i * 360.0) / rayCount;
      double d = startDistM;

      while (d <= maxRangeM) {
        _RingSpec ring = rings.last;
        for (final r in rings) {
          if (d >= r.fromDistM && d <= r.toDistM) {
            ring = r;
            break;
          }
        }

        final p = _destPoint(lat, lon, az, d);
        final n = math.pow(2, ring.zoom).toInt();
        int tx = _lonToX(p[1], ring.zoom).floor();
        tx = ((tx % n) + n) % n;
        final ty = _latToY(p[0], ring.zoom).floor().clamp(0, n - 1);

        keys.add(_TileKey(ring.zoom, tx, ty));

        if (ring.bilinear) {
          keys.add(_TileKey(ring.zoom, ((tx + 1) % n + n) % n, ty));
          keys.add(_TileKey(ring.zoom, tx, math.min(n - 1, ty + 1)));
        }

        d += ring.stepM;
      }
    }

    // Always include the center observer tile
    final innerZ = rings[0].zoom;
    final n0 = math.pow(2, innerZ).toInt();
    final cX = (_lonToX(lon, innerZ).floor() % n0 + n0) % n0;
    final cY = _latToY(lat, innerZ).floor().clamp(0, n0 - 1);
    keys.add(_TileKey(innerZ, cX, cY));

    return keys;
  }

  /// Downloads a single Terrarium PNG tile, decodes pixels, and extracts 16-bit elevation values.
  static Future<Int16List?> _fetchAndDecodeTile(http.Client client, _TileKey key) async {
    if (_tileCache.containsKey(key)) {
      return _tileCache[key];
    }

    final url = Uri.parse('$tileBaseUrl${key.path}.png');
    final resp = await client.get(url).timeout(const Duration(seconds: 15));

    if (resp.statusCode != 200) {
      return null;
    }

    final codec = await ui.instantiateImageCodec(resp.bodyBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final w = image.width;
    final h = image.height;

    final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();

    if (byteData == null) return null;

    final pixels = byteData.buffer.asUint8List();
    final grid = Int16List(w * h);

    // Terrarium encoding: elev = (R * 256 + G + B / 256) - 32768
    for (int i = 0, p = 0; i < grid.length; i++, p += 4) {
      final r = pixels[p];
      final g = pixels[p + 1];
      final b = pixels[p + 2];
      final e = (r * 256.0 + g + b / 256.0) - 32768.0;
      grid[i] = e < 0 ? 0 : e.round().clamp(0, 32767);
    }

    _tileCache[key] = grid;
    return grid;
  }

  /// Sample elevation in meters at a given geographic point from decoded tiles.
  static double? _sampleElevation(
    double lat,
    double lon,
    _RingSpec ring,
    Map<_TileKey, Int16List> tiles,
  ) {
    final fx = _lonToX(lon, ring.zoom);
    final fy = _latToY(lat, ring.zoom);
    final tx = fx.floor();
    final ty = fy.floor();

    final key = _TileKey(ring.zoom, tx, ty);
    final grid = tiles[key];
    if (grid == null) return null;

    const w = 256;
    final px = (fx - tx) * w;
    final py = (fy - ty) * w;

    if (!ring.bilinear) {
      final ix = px.floor().clamp(0, w - 1);
      final iy = py.floor().clamp(0, w - 1);
      return grid[iy * w + ix].toDouble();
    }

    final x0 = px.floor().clamp(0, w - 1);
    final y0 = py.floor().clamp(0, w - 1);
    final x1 = (x0 + 1).clamp(0, w - 1);
    final y1 = (y0 + 1).clamp(0, w - 1);

    final dx = px - x0;
    final dy = py - y0;

    final a = grid[y0 * w + x0];
    final b = grid[y0 * w + x1];
    final c = grid[y1 * w + x0];
    final d = grid[y1 * w + x1];

    final elev = (a * (1.0 - dx) + b * dx) * (1.0 - dy) +
        (c * (1.0 - dx) + d * dx) * dy;
    return elev;
  }

  /// Computes the complete 360-degree topographical horizon profile.
  /// [onProgress] callback reports progress as tiles are fetched.
  static Future<TerrainProfileModel> generateProfile({
    required double latitude,
    required double longitude,
    double? observerKnownElevation,
    void Function(double fraction, String status)? onProgress,
  }) async {
    final client = http.Client();

    try {
      final rings = _buildRings(latitude);
      final requiredTiles = _identifyRequiredTiles(latitude, longitude, rings);

      onProgress?.call(0.05, 'Connecting to AWS Open Data terrain tiles...');

      final tiles = <_TileKey, Int16List>{};
      int loaded = 0;
      final total = requiredTiles.length;

      // Concurrent fetch pool (6 parallel requests)
      final queue = requiredTiles.toList();
      const concurrency = 6;

      Future<void> worker() async {
        while (queue.isNotEmpty) {
          final key = queue.removeLast();
          try {
            final grid = await _fetchAndDecodeTile(client, key);
            if (grid != null) {
              tiles[key] = grid;
            }
          } catch (_) {
            // Ignore individual tile failure; raymarch will sample nearest available
          }
          loaded++;
          final frac = 0.05 + 0.70 * (loaded / total);
          onProgress?.call(frac, 'Downloaded tile $loaded of $total...');
        }
      }

      await Future.wait(List.generate(concurrency, (_) => worker()));

      onProgress?.call(0.80, 'Raymarching 360° terrain skyline...');

      // Find local ground elevation
      double ground = observerKnownElevation ?? 0.0;
      final innerRing = rings[0];
      final siteElev = _sampleElevation(latitude, longitude, innerRing, tiles);
      if (siteElev != null && siteElev > 0) {
        ground = siteElev;
      }

      final h0 = ground + eyeHeightM;
      final altitudes = <double>[];
      final distances = <double>[];

      // Perform 720-ray viewshed raymarch
      for (int i = 0; i < rayCount; i++) {
        final az = (i * 360.0) / rayCount;
        double bestAlt = -90.0;
        double bestDist = 0.0;
        double d = startDistM;

        while (d <= maxRangeM) {
          _RingSpec ring = rings.last;
          for (final r in rings) {
            if (d >= r.fromDistM && d <= r.toDistM) {
              ring = r;
              break;
            }
          }

          final dest = _destPoint(latitude, longitude, az, d);
          final h = _sampleElevation(dest[0], dest[1], ring, tiles);

          if (h != null) {
            // Earth curvature drop with atmospheric refraction
            final drop = (d * d) / (2.0 * rEff);
            final alt = math.atan2(h - h0 - drop, d) * r2d;
            if (alt > bestAlt) {
              bestAlt = alt;
              bestDist = d;
            }
          }

          d += ring.stepM;
        }

        // Clamp altitude to 0..90 for sky obstruction representation
        final finalAlt = bestAlt < 0.0 ? 0.0 : math.min(90.0, bestAlt);
        altitudes.add((finalAlt * 100).round() / 100.0);
        distances.add(bestDist);
      }

      onProgress?.call(1.0, 'Skyline profile ready');

      return TerrainProfileModel(
        originLat: latitude,
        originLon: longitude,
        groundElevation: ground,
        stepDeg: 360.0 / rayCount,
        altitudes: altitudes,
        distances: distances,
        generatedAt: DateTime.now(),
      );
    } finally {
      client.close();
    }
  }
}
