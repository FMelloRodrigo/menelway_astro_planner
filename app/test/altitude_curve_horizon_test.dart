import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/altitude_point.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/terrain_profile_model.dart';
import 'package:app/views/altitude_curve_chart.dart';

void main() {
  final testNight = NightSummary(
    sunset: DateTime(2026, 9, 27, 18, 0),
    civilDusk: DateTime(2026, 9, 27, 18, 25),
    nauticalDusk: DateTime(2026, 9, 27, 18, 55),
    astronomicalDusk: DateTime(2026, 9, 27, 19, 25),
    solarMidnight: DateTime(2026, 9, 28, 0, 0),
    astronomicalDawn: DateTime(2026, 9, 28, 4, 30),
    nauticalDawn: DateTime(2026, 9, 28, 5, 0),
    civilDawn: DateTime(2026, 9, 28, 5, 30),
    sunrise: DateTime(2026, 9, 28, 6, 0),
    moonIllumination: 0.15,
    moonPhaseName: 'Waxing Crescent',
    hasAstronomicalNight: true,
  );

  final testPoints = List.generate(20, (i) {
    return AltitudePoint(
      time: DateTime(2026, 9, 27, 18).add(Duration(minutes: i * 36)),
      altitude: 10.0 + i * 2.5, // 10 deg to 57.5 deg
      azimuth: 80.0 + i * 10,   // 80 deg to 270 deg
      moonSeparation: 45.0,
      meetsCriteria: true,
    );
  });

  group('FilterState Horizon Sampling Tests', () {
    test('FilterState interpolates polygon horizon points circularly', () {
      final filters = FilterState(
        useCustomHorizon: true,
        horizonPoints: const [
          HorizonPointModel(azimuth: 0.0, altitude: 10.0),
          HorizonPointModel(azimuth: 90.0, altitude: 20.0),
          HorizonPointModel(azimuth: 180.0, altitude: 30.0),
          HorizonPointModel(azimuth: 270.0, altitude: 10.0),
        ],
      );

      expect(filters.hasHorizon, isTrue);
      // Midpoint between 0 and 90 deg -> 15 deg
      expect(filters.getHorizonAltitudeAt(45.0), closeTo(15.0, 0.1));
      // Midpoint between 90 and 180 deg -> 25 deg
      expect(filters.getHorizonAltitudeAt(135.0), closeTo(25.0, 0.1));
      // Midpoint between 270 and 360(0) deg -> 10 deg
      expect(filters.getHorizonAltitudeAt(315.0), closeTo(10.0, 0.1));
    });

    test('FilterState combines terrain profile and custom obstacles', () {
      final filters = FilterState(
        useCustomHorizon: true,
        horizonPoints: const [
          HorizonPointModel(azimuth: 90.0, altitude: 35.0), // tall tree in East
          HorizonPointModel(azimuth: 270.0, altitude: 5.0),
        ],
        showTerrainSilhouette: true,
        terrainProfile: TerrainProfileModel(
          originLat: -22.28,
          originLon: -42.53,
          groundElevation: 850.0,
          stepDeg: 1.0,
          altitudes: List.generate(360, (i) => 15.0), // 15 deg mountains all around
          generatedAt: DateTime.now(),
        ),
      );

      expect(filters.hasHorizon, isTrue);
      // At 90 deg, the custom tree (35 deg) is taller than mountain (15 deg)
      expect(filters.getHorizonAltitudeAt(90.0), closeTo(35.0, 0.1));
      // At 270 deg, mountain (15 deg) is taller than custom obstacle (5 deg)
      expect(filters.getHorizonAltitudeAt(270.0), closeTo(15.0, 0.1));
    });
  });

  group('AltitudeCurveChart Widget Tests', () {
    testWidgets('Renders Horizon toggle chip and Zoom controls', (tester) async {
      final filters = FilterState(
        useCustomHorizon: true,
        horizonPoints: const [
          HorizonPointModel(azimuth: 0.0, altitude: 15.0),
          HorizonPointModel(azimuth: 180.0, altitude: 25.0),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AltitudeCurveChart(
              targetPoints: testPoints,
              night: testNight,
              targetName: "M31 Andromeda Galaxy",
              filterState: filters,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Check title and horizon chip
      expect(find.textContaining("M31 Andromeda Galaxy"), findsOneWidget);
      expect(find.text("Horizon: ON"), findsOneWidget);
      expect(find.text("1.0x"), findsOneWidget);

      // Tap Zoom In button
      final zoomInBtn = find.byIcon(Icons.zoom_in_rounded);
      expect(zoomInBtn, findsOneWidget);
      await tester.tap(zoomInBtn);
      await tester.pumpAndSettle();

      // Zoom level should have increased and viewport scrubber should appear
      expect(find.text("1.4x"), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text("Transit"), findsOneWidget);

      // Tapping Transit centers the view
      await tester.tap(find.text("Transit"));
      await tester.pumpAndSettle();

      // Toggle Horizon to OFF
      await tester.tap(find.text("Horizon: ON"));
      await tester.pumpAndSettle();
      expect(find.text("Horizon: OFF"), findsOneWidget);

      // Reset zoom
      await tester.tap(find.text("1.4x"));
      await tester.pumpAndSettle();
      expect(find.text("1.0x"), findsOneWidget);
    });

    testWidgets('Skyline 360 mode allows panning and jumping to 360 degrees', (tester) async {
      final filters = FilterState(
        useCustomHorizon: true,
        horizonPoints: const [
          HorizonPointModel(azimuth: 0.0, altitude: 12.0),
          HorizonPointModel(azimuth: 270.0, altitude: 22.0),
          HorizonPointModel(azimuth: 360.0, altitude: 12.0),
        ],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AltitudeCurveChart(
              targetPoints: testPoints,
              night: testNight,
              targetName: "Test Target",
              filterState: filters,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Zoom in to 2.0x
      final zoomInBtn = find.byIcon(Icons.zoom_in_rounded);
      await tester.tap(zoomInBtn);
      await tester.pumpAndSettle();
      await tester.tap(zoomInBtn);
      await tester.pumpAndSettle();

      // Cardinal jump buttons should exist
      expect(find.text("W"), findsOneWidget);
      expect(find.text("N (360°)"), findsOneWidget);

      // Jump to N (360°)
      await tester.tap(find.text("N (360°)"));
      await tester.pumpAndSettle();

      // Slider text should show visible span ending at 360°
      expect(find.textContaining("360° (N)"), findsOneWidget);
    });
  });
}
