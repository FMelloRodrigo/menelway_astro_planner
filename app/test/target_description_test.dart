import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/core/astro_engine.dart';
import 'package:app/core/fake_astro_engine.dart';
import 'package:app/core/target_description_service.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_description.dart';
import 'package:app/models/target_item.dart';
import 'package:app/views/target_details_sheet.dart';

void main() {
  late FakeAstroEngine fakeEngine;

  setUp(() {
    fakeEngine = FakeAstroEngine();
    AstroEngine.instance = fakeEngine;
    TargetDescriptionService.instance.clearSessionCache();
  });

  tearDown(() {
    AstroEngine.reset();
  });

  group('TargetDescription Model & Service Tests', () {
    test('TargetDescription serializes and deserializes correctly', () {
      final desc = const TargetDescription(
        title: 'Andromeda Galaxy',
        description: 'Spiral galaxy',
        extract: 'The Andromeda Galaxy is a barred spiral galaxy.',
        thumbnailUrl: 'https://example.com/m31.jpg',
        pageUrl: 'https://en.wikipedia.org/wiki/Andromeda_Galaxy',
        source: 'Wikipedia',
      );

      final json = desc.toJson();
      final fromJson = TargetDescription.fromJson(json);

      expect(fromJson.title, 'Andromeda Galaxy');
      expect(fromJson.description, 'Spiral galaxy');
      expect(fromJson.extract, 'The Andromeda Galaxy is a barred spiral galaxy.');
      expect(fromJson.thumbnailUrl, 'https://example.com/m31.jpg');
      expect(fromJson.pageUrl, 'https://en.wikipedia.org/wiki/Andromeda_Galaxy');
      expect(fromJson.source, 'Wikipedia');
      expect(fromJson, equals(desc));
    });

    test('TargetDescriptionService returns pre-baked offline description for Messier 31', () async {
      final target = TargetItem(
        id: 1,
        name: 'NGC 224',
        messier: 'M 31',
        commonName: 'Andromeda Galaxy',
        catalog: 'Messier',
        objectType: 'Galaxy',
        constellation: 'And',
        raHours: 0.712,
        decDegrees: 41.27,
        peakAltitudeDeg: 80.0,
        visibleDurationHours: 6.0,
        transitTime: DateTime(2026, 9, 21, 0, 0),
        visibleStartTime: DateTime(2026, 9, 20, 21, 0),
        visibleEndTime: DateTime(2026, 9, 21, 3, 0),
        minMoonSepDeg: 60.0,
        meetsCriteria: true,
      );

      final desc = await TargetDescriptionService.instance.getDescription(
        target,
        engine: fakeEngine,
        allowOnline: false,
      );

      expect(desc, isNotNull);
      expect(desc!.title, 'Andromeda Galaxy');
      expect(desc.extract, contains('nearest major galaxy'));
    });

    test('TargetDescriptionService returns pre-baked offline description for bright star Sirius', () async {
      final target = TargetItem(
        id: 91001,
        name: 'Sirius',
        catalog: 'Stars',
        objectType: 'Double Star',
        constellation: 'CMa',
        raHours: 6.75,
        decDegrees: -16.72,
        magnitude: -1.46,
        commonName: 'Alpha Canis Majoris',
        peakAltitudeDeg: 72.0,
        visibleDurationHours: 7.5,
        transitTime: DateTime(2026, 9, 21, 1, 0),
        visibleStartTime: DateTime(2026, 9, 20, 21, 0),
        visibleEndTime: DateTime(2026, 9, 21, 4, 30),
        minMoonSepDeg: 55.0,
        meetsCriteria: true,
      );

      final desc = await TargetDescriptionService.instance.getDescription(
        target,
        engine: fakeEngine,
        allowOnline: false,
      );

      expect(desc, isNotNull);
      expect(desc!.title, 'Sirius');
      expect(desc.extract, contains('brightest star'));
    });

    test('TargetDescriptionService returns pre-baked offline description for planet Jupiter', () async {
      final target = TargetItem(
        id: 90005,
        name: 'Jupiter',
        catalog: 'Solar System',
        objectType: 'Planet',
        constellation: 'Tau',
        raHours: 4.85,
        decDegrees: 22.1,
        magnitude: -2.4,
        majorAxisArcmin: 0.75,
        commonName: 'Jupiter',
        peakAltitudeDeg: 68.0,
        visibleDurationHours: 6.2,
        transitTime: DateTime(2026, 9, 21, 23, 0),
        visibleStartTime: DateTime(2026, 9, 20, 20, 0),
        visibleEndTime: DateTime(2026, 9, 21, 4, 0),
        minMoonSepDeg: 45.0,
        meetsCriteria: true,
      );

      final desc = await TargetDescriptionService.instance.getDescription(
        target,
        engine: fakeEngine,
        allowOnline: false,
      );

      expect(desc, isNotNull);
      expect(desc!.title, 'Jupiter');
      expect(desc.extract, contains('fifth planet'));
    });

    test('TargetDescriptionService returns null when target not in cache and offline', () async {
      final target = TargetItem(
        id: 999,
        name: 'PGC 999999',
        catalog: 'PGC',
        objectType: 'Galaxy',
        constellation: 'Peg',
        raHours: 23.5,
        decDegrees: 15.0,
        peakAltitudeDeg: 50.0,
        visibleDurationHours: 3.0,
        transitTime: DateTime(2026, 9, 21, 0, 0),
        visibleStartTime: DateTime(2026, 9, 20, 22, 0),
        visibleEndTime: DateTime(2026, 9, 21, 1, 0),
        minMoonSepDeg: 40.0,
        meetsCriteria: true,
      );

      final desc = await TargetDescriptionService.instance.getDescription(
        target,
        engine: fakeEngine,
        allowOnline: false,
      );

      expect(desc, isNull);
    });
  });

  group('TargetDetailsSheet Description Card Widget Tests', () {
    final testNight = NightSummary(
      sunset: DateTime(2026, 9, 20, 18, 30),
      civilDusk: DateTime(2026, 9, 20, 19, 0),
      nauticalDusk: DateTime(2026, 9, 20, 19, 30),
      astronomicalDusk: DateTime(2026, 9, 20, 20, 0),
      solarMidnight: DateTime(2026, 9, 21, 0, 0),
      astronomicalDawn: DateTime(2026, 9, 21, 4, 30),
      nauticalDawn: DateTime(2026, 9, 21, 5, 0),
      civilDawn: DateTime(2026, 9, 21, 5, 30),
      sunrise: DateTime(2026, 9, 21, 6, 0),
      moonIllumination: 0.25,
      moonPhaseName: 'Crescent',
      hasAstronomicalNight: true,
    );

    testWidgets('Renders Target Overview card with description title, subtitle and extract', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final target = TargetItem(
        id: 1,
        name: 'NGC 224',
        messier: 'M 31',
        commonName: 'Andromeda Galaxy',
        catalog: 'Messier',
        objectType: 'Galaxy',
        constellation: 'And',
        raHours: 0.712,
        decDegrees: 41.27,
        peakAltitudeDeg: 80.0,
        visibleDurationHours: 6.0,
        transitTime: DateTime(2026, 9, 21, 0, 0),
        visibleStartTime: DateTime(2026, 9, 20, 21, 0),
        visibleEndTime: DateTime(2026, 9, 21, 3, 0),
        minMoonSepDeg: 60.0,
        meetsCriteria: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TargetDetailsSheet(
              target: target,
              night: testNight,
              latitude: 40.0,
              longitude: -74.0,
              elevation: 100.0,
              availableLists: const [],
              onAddToList: (listId, targetId, notes) {},
              engine: fakeEngine,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Andromeda Galaxy'), findsAtLeastNWidgets(1));
      expect(find.text('Barred spiral galaxy in the Local Group'), findsOneWidget);
      expect(find.textContaining('nearest major galaxy to the Milky Way'), findsOneWidget);
      expect(find.text('Wikipedia'), findsOneWidget);
      expect(find.byIcon(Icons.auto_stories_rounded), findsOneWidget);
    });

    testWidgets('Renders fallback when no description is cached', (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      final unbakedTarget = TargetItem(
        id: 888,
        name: 'PGC 88888',
        catalog: 'PGC',
        objectType: 'Galaxy',
        constellation: 'Vir',
        raHours: 12.0,
        decDegrees: 10.0,
        peakAltitudeDeg: 60.0,
        visibleDurationHours: 4.0,
        transitTime: DateTime(2026, 9, 21, 0, 0),
        visibleStartTime: DateTime(2026, 9, 20, 21, 0),
        visibleEndTime: DateTime(2026, 9, 21, 1, 0),
        minMoonSepDeg: 50.0,
        meetsCriteria: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TargetDetailsSheet(
              target: unbakedTarget,
              night: testNight,
              latitude: 40.0,
              longitude: -74.0,
              elevation: 100.0,
              availableLists: const [],
              onAddToList: (listId, targetId, notes) {},
              engine: fakeEngine,
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No local description available.'), findsOneWidget);
      expect(find.text('Fetch (Wiki)'), findsOneWidget);
    });
  });
}
