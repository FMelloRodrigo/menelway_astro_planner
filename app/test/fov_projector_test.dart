import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/fov_projector.dart';

void main() {
  group('FovProjector Tests', () {
    test('computes pixels per arcminute correctly', () {
      // 600x400 -> minDim = 400. fovDeg = 2.0 -> 120 arcminutes.
      const projector = FovProjector(
        viewportSize: Size(600, 400),
        fovDeg: 2.0,
      );

      expect(projector.minDim, 400.0);
      expect(projector.fovArcmin, 120.0);
      expect(projector.pixelsPerArcmin, closeTo(400.0 / 120.0, 1e-6));
      expect(projector.viewportCenter, const Offset(300, 200));
    });

    test('computes target center with pan offset', () {
      const projector = FovProjector(
        viewportSize: Size(600, 400),
        fovDeg: 2.0,
        panOffsetArcminX: 15.0,
        panOffsetArcminY: -10.0,
      );

      final pxScale = projector.pixelsPerArcmin;
      final expectedCenter = Offset(300.0 - 15.0 * pxScale, 200.0 - (-10.0) * pxScale);

      expect(projector.targetCenter.dx, closeTo(expectedCenter.dx, 1e-6));
      expect(projector.targetCenter.dy, closeTo(expectedCenter.dy, 1e-6));
    });

    test('calculates sensor pixel dimensions accurately', () {
      const projector = FovProjector(
        viewportSize: Size(500, 500),
        fovDeg: 1.0, // 60 arcminutes -> 500 / 60 px/arcmin
      );

      final sensorSize = projector.calculateSensorPixelSize(60.0, 30.0);
      expect(sensorSize.width, closeTo(500.0, 1e-6));
      expect(sensorSize.height, closeTo(250.0, 1e-6));
    });

    test('calculates target radii with and without surface brightness', () {
      const projector = FovProjector(
        viewportSize: Size(600, 600),
        fovDeg: 1.0, // 60 arcmin -> 10 px/arcmin
      );

      // Null or 0 major axis -> Size.zero
      expect(projector.calculateTargetRadii(null, null), Size.zero);
      expect(projector.calculateTargetRadii(0.0, null), Size.zero);

      // Without surface brightness: radX == radY
      final symmetric = projector.calculateTargetRadii(20.0, null);
      expect(symmetric.width, closeTo(100.0, 1e-6)); // (20 / 2) * 10
      expect(symmetric.height, closeTo(100.0, 1e-6));

      // With surface brightness: minor axis is compressed to 0.65
      final elliptical = projector.calculateTargetRadii(20.0, 14.5);
      expect(elliptical.width, closeTo(100.0, 1e-6));
      expect(elliptical.height, closeTo(65.0, 1e-6)); // (20 * 0.65 / 2) * 10
    });

    test('calculates scale bar thresholds properly', () {
      const p15 = FovProjector(viewportSize: Size(400, 400), fovDeg: 0.25); // 15'
      final s15 = p15.calculateScaleBar();
      expect(s15.scaleArcmin, 5.0);
      expect(s15.label, "5'");
      expect(s15.isValid, isTrue);

      const p45 = FovProjector(viewportSize: Size(400, 400), fovDeg: 0.75); // 45'
      final s45 = p45.calculateScaleBar();
      expect(s45.scaleArcmin, 10.0);
      expect(s45.label, "10'");

      const p90 = FovProjector(viewportSize: Size(400, 400), fovDeg: 1.5); // 90'
      final s90 = p90.calculateScaleBar();
      expect(s90.scaleArcmin, 30.0);
      expect(s90.label, "30'");

      const p180 = FovProjector(viewportSize: Size(400, 400), fovDeg: 3.0); // 180'
      final s180 = p180.calculateScaleBar();
      expect(s180.scaleArcmin, 60.0);
      expect(s180.label, "1°");

      const p360 = FovProjector(viewportSize: Size(400, 400), fovDeg: 6.0); // 360'
      final s360 = p360.calculateScaleBar();
      expect(s360.scaleArcmin, 120.0);
      expect(s360.label, "2°");
    });

    test('formats apparent target dimensions', () {
      expect(FovProjector.formatApparentSize(null), 'Point Source');
      expect(FovProjector.formatApparentSize(0.0), 'Point Source');
      expect(FovProjector.formatApparentSize(15.5), "Size: 15.5'");
      expect(FovProjector.formatApparentSize(60.0), 'Size: 1.0°');
      expect(FovProjector.formatApparentSize(186.0), 'Size: 3.1°');
    });
  });
}
