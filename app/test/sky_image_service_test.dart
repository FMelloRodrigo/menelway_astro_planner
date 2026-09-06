import 'package:flutter_test/flutter_test.dart';
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
  });
}
