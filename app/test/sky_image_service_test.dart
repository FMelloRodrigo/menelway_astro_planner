import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:app/core/sky_image_service.dart';

void main() {
  group('SkyImageService Tests', () {
    test('computeRecommendedFovDeg clamps and scales FOV appropriately', () {
      // 1. Unlisted / null apparent size -> default 0.6° (36 arcmin)
      expect(SkyImageService.computeRecommendedFovDeg(null), closeTo(0.6, 0.001));
      expect(SkyImageService.computeRecommendedFovDeg(0.0), closeTo(0.6, 0.001));

      // 2. Very small object (e.g. Planetary nebula 1.4') -> clamped to min 0.25°
      expect(SkyImageService.computeRecommendedFovDeg(1.4), closeTo(0.25, 0.001));

      // 3. Medium object (e.g. M42 Orion Nebula 65') -> 65 * 2.2 / 60 = 2.383°
      expect(SkyImageService.computeRecommendedFovDeg(65.0), closeTo(2.383, 0.01));

      // 4. Large object (e.g. M31 Andromeda 180') -> 180 * 2.2 / 60 = 6.6°
      expect(SkyImageService.computeRecommendedFovDeg(180.0), closeTo(6.6, 0.01));

      // 5. Huge object (> 300') -> clamped to max 8.0°
      expect(SkyImageService.computeRecommendedFovDeg(500.0), closeTo(8.0, 0.001));
    });

    test('buildHiPSUrl produces valid CDS HiPS2FITS query URL', () {
      final url = SkyImageService.buildHiPSUrl(
        raHours: 5.588, // Betelgeuse RA ~ 5.588h = 83.82°
        decDegrees: 7.407,
        fovDeg: 1.5,
        surveyId: 'CDS/P/DSS2/color',
        width: 512,
        height: 512,
      );

      expect(url, startsWith('https://alasky.cds.unistra.fr/hips-image-services/hips2fits?'));
      expect(url, contains('hips=CDS%2FP%2FDSS2%2Fcolor'));
      expect(url, contains('ra=83.82000'));
      expect(url, contains('dec=7.40700'));
      expect(url, contains('fov=1.5000'));
      expect(url, contains('width=512'));
      expect(url, contains('height=512'));
      expect(url, contains('format=jpg'));
    });

    test('availableSurveys has expected optical and infrared surveys', () {
      final surveys = SkyImageService.availableSurveys;
      expect(surveys.any((s) => s.id == 'CDS/P/DSS2/color'), isTrue);
      expect(surveys.any((s) => s.id.contains('PanSTARRS')), isTrue);
      expect(surveys.any((s) => s.id.contains('DECaLS')), isTrue);
      expect(surveys.any((s) => s.id.contains('2MASS')), isTrue);
    });

    test('maxDiskCacheEntries defaults to 100', () {
      expect(SkyImageService.maxDiskCacheEntries, equals(100));
    });

    test('getMirrorCandidateUrls generates primary and mirror URLs in fallback order', () {
      final primaryUrl = SkyImageService.buildHiPSUrl(
        raHours: 12.0,
        decDegrees: 15.0,
        fovDeg: 1.0,
      );
      final candidates = SkyImageService.getMirrorCandidateUrls(primaryUrl);
      expect(candidates.length, equals(3));
      expect(candidates[0], contains('alasky.cds.unistra.fr'));
      expect(candidates[1], contains('alaskybis.cds.unistra.fr'));
      expect(candidates[2], contains('alasky.u-strasbg.fr'));
      // All candidate URLs must share identical query parameters
      final q0 = Uri.parse(candidates[0]).query;
      final q1 = Uri.parse(candidates[1]).query;
      final q2 = Uri.parse(candidates[2]).query;
      expect(q1, equals(q0));
      expect(q2, equals(q0));
    });

    test('normalizeCacheKey produces identical key across mirrors', () {
      final urlPrimary = 'https://alasky.cds.unistra.fr/hips-image-services/hips2fits?hips=DSS2&ra=180.0';
      final urlMirror = 'https://alaskybis.cds.unistra.fr/hips-image-services/hips2fits?hips=DSS2&ra=180.0';
      expect(SkyImageService.normalizeCacheKey(urlPrimary), equals(SkyImageService.normalizeCacheKey(urlMirror)));
      expect(SkyImageService.normalizeCacheKey(urlPrimary), equals('hips=DSS2&ra=180.0'));
    });

    test('fetchSkyImage fails over to mirror when primary endpoint returns error', () async {
      await SkyImageService.instance.clearCache();
      final requestedUrls = <String>[];
      final fakeBytes = [255, 216, 255, 224, 0, 16]; // JPEG magic header bytes

      final testClient = _MockHttpClient((request) async {
        requestedUrls.add(request.url.toString());
        if (request.url.host == 'alasky.cds.unistra.fr') {
          // Primary is unavailable / erroring
          return http.Response('Service Unavailable', 503);
        } else if (request.url.host == 'alaskybis.cds.unistra.fr') {
          // Mirror succeeds
          return http.Response.bytes(fakeBytes, 200);
        }
        return http.Response('Not Found', 404);
      });

      SkyImageService.instance.setClientForTesting(testClient);

      final url = SkyImageService.buildHiPSUrl(
        raHours: 1.234,
        decDegrees: -20.5,
        fovDeg: 0.75,
      );

      final result = await SkyImageService.instance.fetchSkyImage(
        url,
        attemptTimeout: const Duration(seconds: 3),
        retryBackoff: Duration.zero,
      );

      expect(result, isNotNull);
      expect(result, equals(fakeBytes));
      expect(requestedUrls.length, greaterThanOrEqualTo(2));
      expect(requestedUrls[0], contains('alasky.cds.unistra.fr'));
      expect(requestedUrls[1], contains('alaskybis.cds.unistra.fr'));

      // Restore client
      SkyImageService.instance.setClientForTesting(http.Client());
    });

    test('pruneDiskCache respects entry limit', () async {
      final service = SkyImageService.instance;
      // pruneDiskCache should execute without throwing error
      await service.pruneDiskCache(maxEntries: 100);
      final count = await service.getDiskCacheCount();
      expect(count, lessThanOrEqualTo(100));
    });
  });
}

class _MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) _handler;
  _MockHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final res = await _handler(request);
    return http.StreamedResponse(
      Stream.value(res.bodyBytes),
      res.statusCode,
      headers: res.headers,
    );
  }
}
