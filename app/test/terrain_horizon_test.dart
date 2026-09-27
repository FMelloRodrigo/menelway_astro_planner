import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/terrain_profile_model.dart';

void main() {
  group('TerrainProfileModel Tests', () {
    test('interpolates altitude accurately across 360 degrees', () {
      // 4 points (0°, 90°, 180°, 270°)
      final profile = TerrainProfileModel(
        originLat: -22.28,
        originLon: -42.53,
        groundElevation: 850.0,
        stepDeg: 90.0,
        altitudes: [10.0, 20.0, 30.0, 40.0],
        generatedAt: DateTime(2026, 1, 1),
      );

      expect(profile.altitudeAt(0.0), closeTo(10.0, 0.001));
      expect(profile.altitudeAt(90.0), closeTo(20.0, 0.001));
      expect(profile.altitudeAt(180.0), closeTo(30.0, 0.001));
      expect(profile.altitudeAt(270.0), closeTo(40.0, 0.001));

      // Midpoints
      expect(profile.altitudeAt(45.0), closeTo(15.0, 0.001));
      expect(profile.altitudeAt(135.0), closeTo(25.0, 0.001));
      // Wrap-around between 270° (40°) and 360°/0° (10°)
      expect(profile.altitudeAt(315.0), closeTo(25.0, 0.001));
    });

    test('simplifies dense ray scan using RDP algorithm to salient landmark peaks', () {
      // Simulate 720 rays with flat ground and two mountain peaks
      final altitudes = List<double>.generate(720, (i) {
        final az = i * 0.5;
        // Peak 1 at 90 deg (height 25 deg)
        final p1 = 25.0 * math.exp(-math.pow((az - 90.0) / 10.0, 2));
        // Peak 2 at 270 deg (height 35 deg)
        final p2 = 35.0 * math.exp(-math.pow((az - 270.0) / 15.0, 2));
        return 5.0 + math.max(p1, p2);
      });

      final profile = TerrainProfileModel(
        originLat: -22.28,
        originLon: -42.53,
        groundElevation: 850.0,
        stepDeg: 0.5,
        altitudes: altitudes,
        generatedAt: DateTime.now(),
      );

      final simplified = profile.toSimplifiedHorizonPoints(epsilonDeg: 0.5);

      // Verify points were reduced from 720 down to < 50
      expect(simplified.length, lessThan(50));
      expect(simplified.length, greaterThan(3));

      // Highest points around Peak 1 (90°) and Peak 2 (270°) should be preserved
      final nearEast = simplified.where((p) => (p.azimuth - 90).abs() < 5.0);
      expect(nearEast.isNotEmpty, isTrue);
      expect(nearEast.any((p) => p.altitude >= 28.0), isTrue);

      final nearWest = simplified.where((p) => (p.azimuth - 270).abs() < 5.0);
      expect(nearWest.isNotEmpty, isTrue);
      expect(nearWest.any((p) => p.altitude >= 38.0), isTrue);
    });

    test('serializes and deserializes correctly via JSON', () {
      final original = TerrainProfileModel(
        originLat: -22.2819,
        originLon: -42.5311,
        groundElevation: 858.0,
        stepDeg: 0.5,
        altitudes: [12.5, 14.2, 18.0],
        distances: [1200.0, 2500.0, 4800.0],
        generatedAt: DateTime(2026, 9, 27, 12, 0),
      );

      final jsonMap = original.toJson();
      final restored = TerrainProfileModel.fromJson(jsonMap);

      expect(restored.originLat, closeTo(original.originLat, 0.0001));
      expect(restored.originLon, closeTo(original.originLon, 0.0001));
      expect(restored.groundElevation, closeTo(original.groundElevation, 0.0001));
      expect(restored.stepDeg, closeTo(original.stepDeg, 0.0001));
      expect(restored.altitudes, equals(original.altitudes));
      expect(restored.distances, equals(original.distances));
    });

    test('integrates into FilterState serialization', () {
      final profile = TerrainProfileModel(
        originLat: -22.2819,
        originLon: -42.5311,
        groundElevation: 858.0,
        altitudes: [15.0, 16.0],
        generatedAt: DateTime.now(),
      );

      final state = FilterState(
        showTerrainSilhouette: true,
        terrainProfile: profile,
      );

      final json = state.toJson();
      expect(json['showTerrainSilhouette'], isTrue);
      expect(json['terrainProfile'], isNotNull);

      final restored = FilterState.fromJson(json);
      expect(restored.showTerrainSilhouette, isTrue);
      expect(restored.terrainProfile, isNotNull);
      expect(restored.terrainProfile!.originLat, closeTo(-22.2819, 0.0001));
    });
  });
}
