import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:app/core/esa_hips_service.dart';

class _MockEsaClient extends http.BaseClient {
  final Future<http.Response> Function(http.Request request) handler;
  _MockEsaClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request as http.Request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('EsaHipsService Core Tests', () {
    test('ang2pixNest computes consistent HEALPix indices', () {
      // North pole (theta = 0.01)
      final npPix = EsaHipsService.ang2pixNest(1, 0.01, 0.1);
      expect(npPix, inInclusiveRange(0, 3));

      // Equator (theta = pi/2)
      final eqPix = EsaHipsService.ang2pixNest(1, 1.57079, 0.1);
      expect(eqPix, inInclusiveRange(4, 7));

      // South pole (theta = pi - 0.01)
      final spPix = EsaHipsService.ang2pixNest(1, 3.14159 - 0.01, 0.1);
      expect(spPix, inInclusiveRange(8, 11));
    });

    test('computeOrder maps FOV accurately to native HiPS orders', () {
      expect(EsaHipsService.computeOrder(1.5), equals(5));
      expect(EsaHipsService.computeOrder(0.5), equals(7));
      expect(EsaHipsService.computeOrder(3.0), equals(4));
      expect(EsaHipsService.computeOrder(6.0), equals(3));
      expect(EsaHipsService.computeOrder(0.1), equals(9));
      expect(EsaHipsService.computeOrder(30.0), equals(1));
    });

    test('resolveEsaBaseUrl correctly routes optical vs 2MASS surveys', () {
      expect(
        EsaHipsService.resolveEsaBaseUrl('CDS/P/DSS2/color'),
        equals('https://skies.esac.esa.int/DSSColor'),
      );
      expect(
        EsaHipsService.resolveEsaBaseUrl('CDS/P/2MASS/color'),
        equals('https://skies.esac.esa.int/2MASSColor'),
      );
    });

    test('resolveMirrorBaseUrls includes STScI AWS and NASA/IPAC mirrors', () {
      final dssMirrors = EsaHipsService.resolveMirrorBaseUrls('CDS/P/DSS2/color');
      expect(dssMirrors, contains('https://stpubdata.s3.us-east-1.amazonaws.com/mast/skybackgrounds/DSSColor'));

      final irMirrors = EsaHipsService.resolveMirrorBaseUrls('CDS/P/2MASS/color');
      expect(irMirrors, contains('https://irsa.ipac.caltech.edu/data/hips/CDS/2MASS/Color'));

      final psMirrors = EsaHipsService.resolveMirrorBaseUrls('CDS/P/PanSTARRS/DR1/color-z-zg-g');
      expect(psMirrors, contains('https://stpubdata.s3.us-east-1.amazonaws.com/mast/skybackgrounds/PanSTARRS'));
    });

    test('getPrioritizedBaseUrls places healthy mirror ahead of failing mirror', () async {
      EsaHipsService.instance.clearMirrorStatus();
      final initial = EsaHipsService.instance.getPrioritizedBaseUrls('CDS/P/DSS2/color');
      expect(initial.first, equals('https://skies.esac.esa.int/DSSColor'));

      // Simulate ESA failing and STScI succeeding via fetchReprojectedCutout
      final mockClient = _MockEsaClient((request) async {
        if (request.url.toString().contains('skies.esac.esa.int')) {
          return http.Response('Service Unavailable', 503);
        }
        return http.Response('Not Found', 404);
      });

      // Call fetchReprojectedCutout to trigger mirror outage marking
      await EsaHipsService.instance.fetchReprojectedCutout(
        raHours: 5.588,
        decDegrees: -5.391,
        fovDeg: 1.5,
        client: mockClient,
      );

      // Now STScI should be prioritized first
      final reprioritized = EsaHipsService.instance.getPrioritizedBaseUrls('CDS/P/DSS2/color');
      expect(reprioritized.first, equals('https://stpubdata.s3.us-east-1.amazonaws.com/mast/skybackgrounds/DSSColor'));

      EsaHipsService.instance.clearMirrorStatus();
    });

    test('ang2pixNest correctly maps M42 coordinates at order 6', () {
      // M42: RA = 83.822°, Dec = -5.391°
      const raRad = 83.822 * 3.141592653589793 / 180.0;
      const decRad = -5.391 * 3.141592653589793 / 180.0;
      const theta = 3.141592653589793 / 2.0 - decRad;
      const phi = raRad;

      const nside = 1 << 6;
      final tilePix = EsaHipsService.ang2pixNest(nside, theta, phi);
      expect(tilePix, equals(21439));
    });

    test('fetchReprojectedCutout returns null when network fails completely', () async {
      final mockClient = _MockEsaClient((request) async {
        return http.Response('Network Error', 500);
      });

      final result = await EsaHipsService.instance.fetchReprojectedCutout(
        raHours: 5.588,
        decDegrees: -5.391,
        fovDeg: 1.5,
        client: mockClient,
      );

      expect(result, isNull);
    });
  });
}
