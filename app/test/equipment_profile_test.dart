import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/equipment_profile.dart';
import 'package:app/core/equipment_database.dart';
import 'package:app/core/equipment_manager.dart';

void main() {
  group('EquipmentProfile Optics Math & Serialization', () {
    test('TelescopeProfile calculates effective focal length and focal ratio correctly', () {
      const scope = TelescopeProfile(
        id: 'scope1',
        name: 'Askar FRA400',
        focalLengthMm: 400.0,
        apertureMm: 72.0,
        reducerFactor: 0.7,
      );

      expect(scope.effectiveFocalLength, closeTo(280.0, 0.001));
      expect(scope.focalRatio, closeTo(280.0 / 72.0, 0.01));
      expect(scope.focalRatioString, 'f/3.9');

      final json = scope.toJson();
      final restored = TelescopeProfile.fromJson(json);
      expect(restored.id, 'scope1');
      expect(restored.effectiveFocalLength, closeTo(280.0, 0.001));
    });

    test('CameraProfile calculates aspect ratio and megapixels correctly', () {
      const camera = CameraProfile(
        id: 'cam1',
        name: 'ZWO ASI2600MC Pro',
        sensorWidthMm: 23.5,
        sensorHeightMm: 15.6,
        pixelSizeMicrons: 3.76,
        resolutionWidthPx: 6248,
        resolutionHeightPx: 4176,
      );

      expect(camera.aspectRatio, closeTo(23.5 / 15.6, 0.01));
      expect(camera.megapixels, closeTo((6248 * 4176) / 1000000.0, 0.05));

      final json = camera.toJson();
      final restored = CameraProfile.fromJson(json);
      expect(restored.id, 'cam1');
      expect(restored.pixelSizeMicrons, 3.76);
    });

    test('EquipmentProfile computes FOV and image scale accurately', () {
      // RedCat 51 (250mm, 51mm) + ASI2600MC (23.5 x 15.6mm, 3.76um)
      const rig = EquipmentProfile(
        id: 'rig_redcat',
        name: 'RedCat 51 + ASI2600',
        telescope: TelescopeProfile(
          id: 'redcat51',
          name: 'William Optics RedCat 51',
          focalLengthMm: 250.0,
          apertureMm: 51.0,
          reducerFactor: 1.0,
        ),
        camera: CameraProfile(
          id: 'asi2600mc',
          name: 'ZWO ASI2600MC Pro',
          sensorWidthMm: 23.5,
          sensorHeightMm: 15.6,
          pixelSizeMicrons: 3.76,
          resolutionWidthPx: 6248,
          resolutionHeightPx: 4176,
        ),
      );

      // FOV = 2 * atan(size / (2 * 250)) * (180/pi)
      // W: 2 * atan(23.5 / 500) = 2 * 0.046965 rad = 0.09393 rad = ~5.38 deg
      expect(rig.sensorFovWidthDeg, closeTo(5.38, 0.05));
      expect(rig.sensorFovHeightDeg, closeTo(3.57, 0.05));
      expect(rig.sensorFovWidthArcmin, closeTo(5.38 * 60, 3.0));

      // Image scale: (206.265 * 3.76) / 250 = 3.10 arcsec/pixel
      expect(rig.imageScaleArcsecPerPixel, closeTo(3.10, 0.05));
      expect(rig.samplingCategory, contains('Wide-field'));

      final json = rig.toJson();
      final restored = EquipmentProfile.fromJson(json);
      expect(restored.id, 'rig_redcat');
      expect(restored.sensorFovWidthDeg, closeTo(5.38, 0.05));
    });
  });

  group('EquipmentDatabase Search Engine', () {
    test('Searches telescopes by partial keyword across brand and model', () {
      final redcatResults = EquipmentDatabase.searchTelescopes('redcat');
      expect(redcatResults.isNotEmpty, isTrue);
      expect(redcatResults.any((s) => s.name.contains('RedCat 51')), isTrue);

      final askarResults = EquipmentDatabase.searchTelescopes('fra400');
      expect(askarResults.isNotEmpty, isTrue);
      expect(askarResults.first.focalLengthMm, 400.0);

      final seestar = EquipmentDatabase.searchTelescopes('seestar');
      expect(seestar.isNotEmpty, isTrue);
      expect(seestar.first.name, contains('Seestar S50'));
    });

    test('Searches cameras by sensor or model name', () {
      final asi2600 = EquipmentDatabase.searchCameras('2600');
      expect(asi2600.isNotEmpty, isTrue);
      expect(asi2600.any((c) => c.name.contains('2600')), isTrue);

      final sony = EquipmentDatabase.searchCameras('Sony');
      expect(sony.isNotEmpty, isTrue);
      expect(sony.any((c) => c.name.contains('Sony A7')), isTrue);

      final asi533 = EquipmentDatabase.searchCameras('533');
      expect(asi533.isNotEmpty, isTrue);
      // ASI533 is square sensor: 11.31 x 11.31
      expect(asi533.first.sensorWidthMm, closeTo(11.3, 0.1));

      final t3i = EquipmentDatabase.searchCameras('T3i');
      expect(t3i.isNotEmpty, isTrue);
      expect(t3i.first.name, contains('T3i'));
      expect(t3i.first.pixelSizeMicrons, 4.30);
      expect(t3i.first.resolutionWidthPx, 5184);
      expect(t3i.first.resolutionHeightPx, 3456);
    });

    test('Default starter profiles are valid and have non-zero optics', () {
      final defaults = EquipmentDatabase.defaultProfiles;
      expect(defaults.length, greaterThanOrEqualTo(3));
      for (final profile in defaults) {
        expect(profile.sensorFovWidthDeg, greaterThan(0.1));
        expect(profile.sensorFovHeightDeg, greaterThan(0.1));
        expect(profile.imageScaleArcsecPerPixel, greaterThan(0.01));
      }
    });
  });

  group('EquipmentManager State & Controls', () {
    test('Rotation angle clamps or normalizes appropriately', () {
      final manager = EquipmentManager.instance;
      manager.init(
        savedProfiles: EquipmentDatabase.defaultProfiles,
        savedActiveId: EquipmentDatabase.defaultProfiles.first.id,
      );

      manager.setCameraAngle(45.0);
      expect(manager.cameraAngleDeg, 45.0);

      manager.setCameraAngle(375.0);
      expect(manager.cameraAngleDeg, 15.0);

      manager.setCameraAngle(-30.0);
      expect(manager.cameraAngleDeg, 330.0);
    });

    test('Auto-aligns camera to target position angle', () {
      final manager = EquipmentManager.instance;
      manager.autoAlignWithTarget(120.0);
      expect(manager.cameraAngleDeg, 120.0);
    });

    test('Framing and grid toggles work', () {
      final manager = EquipmentManager.instance;
      manager.setFramingEnabled(true);
      expect(manager.isFramingEnabled, isTrue);

      manager.toggleRuleOfThirds(true);
      expect(manager.showRuleOfThirds, isTrue);
    });
  });
}
