import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/target_item.dart';
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

    test('isTargetSubpixelClamped identifies sub-pixel clamped planets correctly', () {
      const projector = FovProjector(
        viewportSize: Size(400, 400),
        fovDeg: 2.0, // 120' -> pixelsPerArcmin = 400 / 120 = 3.33 px/arcmin
      );

      final jupiter = TargetItem(
        id: 1,
        name: 'Jupiter',
        catalog: 'Solar System',
        objectType: 'Planet',
        constellation: 'Tau',
        raHours: 4.0,
        decDegrees: 20.0,
        magnitude: -2.5,
        majorAxisArcmin: 0.75, // radius = 0.375' -> 1.25 px (< 9.0 px clamp)
        peakAltitudeDeg: 60.0,
        visibleDurationHours: 6.0,
        transitTime: DateTime(2026, 9, 6, 23, 0),
        minMoonSepDeg: 60.0,
        meetsCriteria: true,
      );

      final moon = TargetItem(
        id: 2,
        name: 'Moon',
        catalog: 'Solar System',
        objectType: 'Planet',
        constellation: 'Cap',
        raHours: 20.0,
        decDegrees: -18.0,
        magnitude: -12.0,
        majorAxisArcmin: 31.0, // radius = 15.5' -> ~51 px (> 9.0 px clamp)
        peakAltitudeDeg: 55.0,
        visibleDurationHours: 8.0,
        transitTime: DateTime(2026, 9, 6, 21, 0),
        minMoonSepDeg: 0.0,
        meetsCriteria: true,
      );

      final deepSkyNebula = TargetItem(
        id: 3,
        name: 'M42',
        catalog: 'Messier',
        objectType: 'Nebula',
        constellation: 'Ori',
        raHours: 5.5,
        decDegrees: -5.0,
        magnitude: 4.0,
        majorAxisArcmin: 65.0,
        peakAltitudeDeg: 60.0,
        visibleDurationHours: 6.0,
        transitTime: DateTime(2026, 9, 6, 23, 0),
        minMoonSepDeg: 60.0,
        meetsCriteria: true,
      );

      // Jupiter is clamped on 2.0° FOV
      expect(projector.isTargetSubpixelClamped(jupiter), isTrue);

      // Moon is not sub-pixel clamped
      expect(projector.isTargetSubpixelClamped(moon), isFalse);

      // Deep sky objects are not flagged as clamped planets
      expect(projector.isTargetSubpixelClamped(deepSkyNebula), isFalse);

      // At extreme zoom (0.02° = 1.2' FOV -> px/arcmin = 400 / 1.2 = 333 px/arcmin)
      // Jupiter radius = 0.375 * 333 = 125 px (> 9.0 px) -> no longer clamped!
      const extremeZoomProjector = FovProjector(
        viewportSize: Size(400, 400),
        fovDeg: 0.02,
      );
      expect(extremeZoomProjector.isTargetSubpixelClamped(jupiter), isFalse);
    });

    test('calculates aspect ratio and coverage FOV correctly for non-square viewports', () {
      // 1. Square Viewport (500x500)
      const squareProjector = FovProjector(
        viewportSize: Size(500, 500),
        fovDeg: 2.0,
      );
      expect(squareProjector.minDim, 500.0);
      expect(squareProjector.maxDim, 500.0);
      expect(squareProjector.aspectScaleFactor, 1.0);
      expect(squareProjector.coverageFovDeg, 2.0);

      // 2. Wide Landscape Viewport (typical mobile/tablet landscape: 480x270)
      const wideProjector = FovProjector(
        viewportSize: Size(480, 270),
        fovDeg: 2.0,
      );
      expect(wideProjector.minDim, 270.0);
      expect(wideProjector.maxDim, 480.0);
      expect(wideProjector.aspectScaleFactor, closeTo(480.0 / 270.0, 1e-6));
      expect(wideProjector.coverageFovDeg, closeTo(2.0 * (480.0 / 270.0), 1e-6));

      // 3. Tall Portrait Viewport (300x600)
      const tallProjector = FovProjector(
        viewportSize: Size(300, 600),
        fovDeg: 1.5,
      );
      expect(tallProjector.minDim, 300.0);
      expect(tallProjector.maxDim, 600.0);
      expect(tallProjector.aspectScaleFactor, 2.0);
      expect(tallProjector.coverageFovDeg, 3.0);
    });

    test('calculateImageRect guarantees strict 1:1 scale parity with pixelsPerArcmin', () {
      const wideProjector = FovProjector(
        viewportSize: Size(480, 270),
        fovDeg: 2.0, // 120 arcminutes -> px/arcmin = 270 / 120 = 2.25
        panOffsetArcminX: 10.0,
        panOffsetArcminY: -5.0,
      );

      final pxScale = wideProjector.pixelsPerArcmin;
      expect(pxScale, closeTo(2.25, 1e-6));

      // Coverage image with coverageFovDeg
      final coverageFov = wideProjector.coverageFovDeg;
      final imageRect = wideProjector.calculateImageRect(
        imageFovDeg: coverageFov,
        imageBasePanX: 0.0,
        imageBasePanY: 0.0,
      );

      // 1. The image side in pixels must equal maxDim (480px) to fully cover the wide viewport
      expect(imageRect.width, closeTo(480.0, 1e-6));
      expect(imageRect.height, closeTo(480.0, 1e-6));

      // 2. Scale parity: width in pixels divided by (imageFov * 60 arcminutes) must exactly equal pixelsPerArcmin
      final imageScale = imageRect.width / (coverageFov * 60.0);
      expect(imageScale, closeTo(pxScale, 1e-6));

      // 3. Sensor pixel dimensions at the same scale
      final sensor = wideProjector.calculateSensorPixelSize(102.2, 68.3); // Generic 150 + T3i FOV in arcmin
      expect(sensor.width, closeTo(102.2 * pxScale, 1e-6));
      expect(sensor.height, closeTo(68.3 * pxScale, 1e-6));

      // 4. Center of the image shifts with pan offset
      final expectedCenterX = (480.0 / 2.0) - (10.0 * pxScale);
      final expectedCenterY = (270.0 / 2.0) - (-5.0 * pxScale);
      expect(imageRect.center.dx, closeTo(expectedCenterX, 1e-6));
      expect(imageRect.center.dy, closeTo(expectedCenterY, 1e-6));
    });
  });
}
