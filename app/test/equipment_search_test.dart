import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/equipment_database.dart';
import 'package:app/core/equipment_search.dart';
import 'package:app/models/equipment_profile.dart';

void main() {
  group('EquipmentSearchUtil Tests', () {
    const testScopes = [
      TelescopeProfile(
        id: 'wo_redcat51',
        name: 'William Optics RedCat 51 III (250mm f/4.9)',
        focalLengthMm: 250.0,
        apertureMm: 51.0,
        reducerFactor: 1.0,
      ),
      TelescopeProfile(
        id: 'sw_evostar80ed',
        name: 'Sky-Watcher Evostar 80ED (600mm f/7.5)',
        focalLengthMm: 600.0,
        apertureMm: 80.0,
        reducerFactor: 1.0,
      ),
      TelescopeProfile(
        id: 'cel_edgehd800',
        name: 'Celestron EdgeHD 800 (2032mm f/10)',
        focalLengthMm: 2032.0,
        apertureMm: 203.2,
        reducerFactor: 1.0,
      ),
    ];

    const testCameras = [
      CameraProfile(
        id: 'zwo_asi2600mc',
        name: 'ZWO ASI2600MC Pro (Sony IMX571 APS-C)',
        sensorWidthMm: 23.5,
        sensorHeightMm: 15.6,
        pixelSizeMicrons: 3.76,
        resolutionWidthPx: 6248,
        resolutionHeightPx: 4176,
      ),
      CameraProfile(
        id: 'zwo_asi533mc',
        name: 'ZWO ASI533MC Pro (Sony IMX533 Square 1")',
        sensorWidthMm: 11.31,
        sensorHeightMm: 11.31,
        pixelSizeMicrons: 3.76,
        resolutionWidthPx: 3008,
        resolutionHeightPx: 3008,
      ),
      CameraProfile(
        id: 'qhy_qhy268m',
        name: 'QHY 268M Monochrome (Sony IMX571)',
        sensorWidthMm: 23.5,
        sensorHeightMm: 15.6,
        pixelSizeMicrons: 3.76,
        resolutionWidthPx: 6280,
        resolutionHeightPx: 4210,
      ),
    ];

    test('tokenize handles whitespace and lowercases', () {
      expect(EquipmentSearchUtil.tokenize(''), isEmpty);
      expect(EquipmentSearchUtil.tokenize('   '), isEmpty);
      expect(
        EquipmentSearchUtil.tokenize('  RedCat   51   III  '),
        ['redcat', '51', 'iii'],
      );
    });

    test('searches telescopes by name, aperture, and focal length', () {
      // Empty query returns all
      expect(EquipmentSearchUtil.searchTelescopes(testScopes, '').length, 3);

      // Single brand token
      final celestron = EquipmentSearchUtil.searchTelescopes(testScopes, 'celestron');
      expect(celestron.length, 1);
      expect(celestron.first.id, 'cel_edgehd800');

      // Multi-token: name + aperture
      final redcat = EquipmentSearchUtil.searchTelescopes(testScopes, 'redcat 51');
      expect(redcat.length, 1);
      expect(redcat.first.id, 'wo_redcat51');

      // Focal length token
      final fl600 = EquipmentSearchUtil.searchTelescopes(testScopes, '600');
      expect(fl600.length, 1);
      expect(fl600.first.id, 'sw_evostar80ed');

      // No match
      final none = EquipmentSearchUtil.searchTelescopes(testScopes, 'takahashi');
      expect(none, isEmpty);
    });

    test('searches cameras by brand, chip, and pixel size', () {
      // Empty query returns all
      expect(EquipmentSearchUtil.searchCameras(testCameras, '').length, 3);

      // Search by sensor chip
      final imx571 = EquipmentSearchUtil.searchCameras(testCameras, 'IMX571');
      expect(imx571.length, 2);

      // Multi-token: brand + chip
      final zwo571 = EquipmentSearchUtil.searchCameras(testCameras, 'zwo imx571');
      expect(zwo571.length, 1);
      expect(zwo571.first.id, 'zwo_asi2600mc');

      // Search by square chip
      final square = EquipmentSearchUtil.searchCameras(testCameras, '533');
      expect(square.length, 1);
      expect(square.first.id, 'zwo_asi533mc');
    });

    test('EquipmentDatabase delegates to EquipmentSearchUtil seamlessly', () {
      final results = EquipmentDatabase.searchTelescopes('RedCat');
      expect(results, isNotEmpty);
      expect(results.any((t) => t.id == 'wo_redcat51'), isTrue);

      final camResults = EquipmentDatabase.searchCameras('2600');
      expect(camResults, isNotEmpty);
      expect(camResults.any((c) => c.id == 'zwo_asi2600mc'), isTrue);
    });
  });
}
