import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'app_logger.dart';

/// Lightweight in-memory tile structure holding decoded RGBA pixels for a single HEALPix tile.
class _DecodedTile {
  final int tilePix;
  final Uint8List rgba;
  final int width;
  final int height;

  const _DecodedTile({
    required this.tilePix,
    required this.rgba,
    required this.width,
    required this.height,
  });
}

/// Standalone, lightweight client-side HEALPix tile fetcher and gnomonic reprojector.
///
/// Fetches raw static 512x512 JPEG tiles from the European Space Agency (ESA) ESASky
/// infrastructure (skies.esac.esa.int) and reprojects them into a tangential (gnomonic)
/// camera-plane cutout directly in memory.
///
/// This provides a zero-storage, completely independent fallback when centralized
/// reprojection services (like CDS Strasbourg hips2fits) are down.
class EsaHipsService {
  EsaHipsService._() {
    _initLut();
  }
  static final EsaHipsService instance = EsaHipsService._();
  static const String _tag = 'EsaHipsService';

  /// Official ESA ESASky static survey base endpoints.
  static const String dssBaseUrl = 'https://skies.esac.esa.int/DSSColor';
  static const String ir2massBaseUrl = 'https://skies.esac.esa.int/2MASSColor';

  /// Precomputed 8-bit deinterleave lookup table for Morton / Z-order curve decoding.
  final Uint8List _lut = Uint8List(256);

  void _initLut() {
    for (int i = 0; i < 256; i++) {
      _lut[i] = (i & 1) | (((i >> 2) & 1) << 1) | (((i >> 4) & 1) << 2) | (((i >> 6) & 1) << 3);
    }
  }

  /// Maps a CDS survey identifier to an available ESA static mirror base URL.
  static String resolveEsaBaseUrl(String surveyId) {
    if (surveyId.contains('2MASS')) {
      return ir2massBaseUrl;
    }
    // Default to DSS2 Color optical survey
    return dssBaseUrl;
  }

  /// Converts spherical coordinates (colatitude [theta] in [0, pi], longitude [phi] in [0, 2pi])
  /// into a HEALPix pixel index in the NESTED ordering scheme for a given [nside].
  static int ang2pixNest(int nside, double theta, double phi) {
    final z = math.cos(theta);
    final za = z.abs();
    final tt = (phi % (2.0 * math.pi)) / (0.5 * math.pi);

    const twothird = 2.0 / 3.0;
    int faceNum;
    int ix;
    int iy;

    if (za <= twothird) {
      // Equatorial belt
      final temp1 = nside * (0.5 + tt);
      final temp2 = nside * 0.75 * z;
      final jp = (temp1 - temp2).floor();
      final jm = (temp1 + temp2).floor();

      final ip = jp ~/ nside;
      final im = jm ~/ nside;

      if (ip == im) {
        faceNum = ip + 4;
      } else if (ip < im) {
        faceNum = ip;
      } else {
        faceNum = im + 8;
      }

      ix = jm % nside;
      iy = nside - 1 - (jp % nside);
    } else {
      // Polar caps
      final tp = tt - tt.floor();
      final tmp = nside * math.sqrt(3.0 * (1.0 - za));

      final jp = (tp * tmp).floor();
      final jm = ((1.0 - tp) * tmp).floor();

      final ip = tt.floor();

      if (z > 0) {
        faceNum = ip;
        ix = nside - 1 - jm;
        iy = nside - 1 - jp;
      } else {
        faceNum = ip + 8;
        ix = jp;
        iy = jm;
      }
    }

    // Interleave bits of ix and iy
    int pix = 0;
    for (int b = 0; b < 30; b++) {
      if ((1 << b) > nside) break;
      pix |= ((ix >> b) & 1) << (2 * b);
      pix |= ((iy >> b) & 1) << (2 * b + 1);
    }

    return (faceNum * nside * nside) + pix;
  }

  /// Calculates the optimal HEALPix resolution order for a given field of view in degrees.
  /// Tile angular size is approx 58.63° / (2^order).
  static int computeOrder(double fovDeg) {
    if (fovDeg <= 0) return 5;
    final order = (math.log(58.63 / fovDeg) / math.ln2).round();
    return order.clamp(0, 9);
  }

  /// Fetches and reprojects a tangential sky image cutout from ESA static HEALPix tiles.
  ///
  /// This method is purely transient: no files are written to disk, and all tile buffers
  /// are released immediately upon completion.
  Future<Uint8List?> fetchReprojectedCutout({
    required double raHours,
    required double decDegrees,
    required double fovDeg,
    String surveyId = 'CDS/P/DSS2/color',
    int outputWidth = 512,
    int outputHeight = 512,
    http.Client? client,
  }) async {
    final effectiveClient = client ?? http.Client();
    final baseUrl = resolveEsaBaseUrl(surveyId);

    // Normalize coordinates
    var normRaHours = raHours % 24.0;
    if (normRaHours < 0) normRaHours += 24.0;
    final ra0 = normRaHours * 15.0 * math.pi / 180.0;
    final dec0 = decDegrees.clamp(-90.0, 90.0) * math.pi / 180.0;
    final clampedFov = fovDeg.clamp(0.15, 14.0);
    final fovRad = clampedFov * math.pi / 180.0;

    final order = computeOrder(clampedFov);
    final nsideTile = 1 << order;
    final nsideSub = 1 << (order + 9);

    final cosDec0 = math.cos(dec0);
    final sinDec0 = math.sin(dec0);

    // 1. Identify which tiles intersect the requested field of view
    // Using a 9x9 grid (81 sample points across the tangential viewport)
    final requiredTileIndices = <int>{};
    for (int gy = 0; gy < 9; gy++) {
      final y = -(gy * (outputHeight - 1) / 8.0 - outputHeight / 2.0) * (fovRad / outputHeight);
      for (int gx = 0; gx < 9; gx++) {
        final x = -(gx * (outputWidth - 1) / 8.0 - outputWidth / 2.0) * (fovRad / outputWidth);
        final rho = math.sqrt(x * x + y * y);
        double dec;
        double ra;
        if (rho == 0.0) {
          dec = dec0;
          ra = ra0;
        } else {
          final c = math.atan(rho);
          final cosC = math.cos(c);
          final sinC = math.sin(c);
          final sinDec = (cosC * sinDec0 + (y * sinC * cosDec0) / rho).clamp(-1.0, 1.0);
          dec = math.asin(sinDec);
          final denom = rho * cosDec0 * cosC - y * sinDec0 * sinC;
          final numer = x * sinC;
          ra = ra0 + math.atan2(numer, denom);
        }

        final theta = math.pi / 2.0 - dec;
        var phi = ra % (2.0 * math.pi);
        if (phi < 0) phi += 2.0 * math.pi;

        final tilePix = ang2pixNest(nsideTile, theta, phi);
        requiredTileIndices.add(tilePix);
      }
    }

    if (requiredTileIndices.isEmpty) return null;

    // 2. Concurrently download required tiles from ESA
    final tileFutures = requiredTileIndices.map(
      (pix) => _fetchAndDecodeTile(baseUrl, order, pix, effectiveClient),
    );
    final downloadedTiles = await Future.wait(tileFutures);

    final tileMap = <int, _DecodedTile>{};
    for (final tile in downloadedTiles) {
      if (tile != null) {
        tileMap[tile.tilePix] = tile;
      }
    }

    // If no tiles could be retrieved from ESA, fail gracefully
    if (tileMap.isEmpty) {
      AppLogger.warning('No ESA tiles could be retrieved for RA: $normRaHours, Dec: $decDegrees', tag: _tag);
      return null;
    }

    // 3. Fast tangential (gnomonic) reprojection onto flat output buffer
    final outBuffer = Uint8List(outputWidth * outputHeight * 4);

    for (int Y = 0; Y < outputHeight; Y++) {
      final y = -(Y - outputHeight / 2.0) * (fovRad / outputHeight);
      final rowOffset = Y * outputWidth * 4;
      for (int X = 0; X < outputWidth; X++) {
        // In astronomical WCS tangent plane (TAN), East (higher RA) is LEFT (-x)
        final x = -(X - outputWidth / 2.0) * (fovRad / outputWidth);
        final rho = math.sqrt(x * x + y * y);
        double dec;
        double ra;
        if (rho == 0.0) {
          dec = dec0;
          ra = ra0;
        } else {
          final c = math.atan(rho);
          final cosC = math.cos(c);
          final sinC = math.sin(c);
          final sinDec = (cosC * sinDec0 + (y * sinC * cosDec0) / rho).clamp(-1.0, 1.0);
          dec = math.asin(sinDec);
          final denom = rho * cosDec0 * cosC - y * sinDec0 * sinC;
          final numer = x * sinC;
          ra = ra0 + math.atan2(numer, denom);
        }

        final theta = math.pi / 2.0 - dec;
        var phi = ra % (2.0 * math.pi);
        if (phi < 0) phi += 2.0 * math.pi;

        final psub = ang2pixNest(nsideSub, theta, phi);
        final tilePix = psub >> 18;
        final tile = tileMap[tilePix];

        final outOffset = rowOffset + (X * 4);
        if (tile != null) {
          final m = psub & 0x3FFFF;
          final u = _lut[m & 0xFF] | (_lut[(m >> 8) & 0xFF] << 4) | (((m >> 16) & 1) << 8);
          final v = _lut[(m >> 1) & 0xFF] | (_lut[(m >> 9) & 0xFF] << 4) | (((m >> 17) & 1) << 8);

          // Standard IVOA HiPS JPEG raster axis mapping:
          // Horizontal pixel axis is v (deinterleaved odd bits),
          // Vertical pixel axis is u (deinterleaved even bits).
          final tileX = v.clamp(0, tile.width - 1);
          final tileY = u.clamp(0, tile.height - 1);
          final tileOffset = (tileY * tile.width + tileX) * 4;

          outBuffer[outOffset] = tile.rgba[tileOffset];
          outBuffer[outOffset + 1] = tile.rgba[tileOffset + 1];
          outBuffer[outOffset + 2] = tile.rgba[tileOffset + 2];
          outBuffer[outOffset + 3] = 255;
        } else {
          // Deep space dark background for unmapped edge pixels (RGB: 11, 14, 20)
          outBuffer[outOffset] = 11;
          outBuffer[outOffset + 1] = 14;
          outBuffer[outOffset + 2] = 20;
          outBuffer[outOffset + 3] = 255;
        }
      }
    }

    // 4. Encode RGBA output buffer into standard PNG bytes via Flutter's graphics engine
    try {
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
        outBuffer,
        outputWidth,
        outputHeight,
        ui.PixelFormat.rgba8888,
        (img) => completer.complete(img),
      );

      final reprojectedImage = await completer.future;
      final byteData = await reprojectedImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData != null) {
        AppLogger.info(
          'Successfully reprojected sky cutout via ESA HiPS (Order $order, ${tileMap.length} tiles)',
          tag: _tag,
        );
        return byteData.buffer.asUint8List();
      }
    } catch (e) {
      AppLogger.warning('Failed encoding reprojected ESA image to PNG: $e', tag: _tag);
    }

    return null;
  }

  /// Downloads and hardware-decodes a single static HEALPix tile from ESA.
  Future<_DecodedTile?> _fetchAndDecodeTile(
    String baseUrl,
    int order,
    int tilePix,
    http.Client client,
  ) async {
    final dirIdx = (tilePix ~/ 10000) * 10000;
    final tileUrl = '$baseUrl/Norder$order/Dir$dirIdx/Npix$tilePix.jpg';

    try {
      final response = await client.get(
        Uri.parse(tileUrl),
        headers: const {
          'User-Agent': 'AstroTargetsPlanner/1.0 (Astronomy Deep Sky Planner; contact: open-source)',
          'Accept': 'image/jpeg,image/*,*/*',
        },
      ).timeout(const Duration(seconds: 4));

      if (response.statusCode == 200 && response.bodyBytes.length > 500) {
        final codec = await ui.instantiateImageCodec(response.bodyBytes);
        final frame = await codec.getNextFrame();
        final image = frame.image;
        final byteData = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
        if (byteData != null) {
          return _DecodedTile(
            tilePix: tilePix,
            rgba: byteData.buffer.asUint8List(),
            width: image.width,
            height: image.height,
          );
        }
      }
    } catch (e) {
      AppLogger.debug('Failed to fetch/decode ESA tile ($tileUrl): $e', tag: _tag);
    }
    return null;
  }
}
