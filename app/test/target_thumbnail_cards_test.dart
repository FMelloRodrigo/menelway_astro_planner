import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'package:app/controllers/app_controller.dart';
import 'package:app/core/fake_astro_engine.dart';
import 'package:app/core/sky_image_service.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
import 'package:app/views/target_search_view.dart';
import 'package:app/widgets/target_sky_thumbnail.dart';

class _MockHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) _handler;
  _MockHttpClient(this._handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await _handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
      request: request,
    );
  }
}

void main() {
  // Valid 1x1 transparent PNG bytes for Image.memory decoding in widget tests
  final Uint8List validPngBytes = base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  );

  final testNight = NightSummary(
    sunset: DateTime(2026, 9, 6, 18, 0),
    civilDusk: DateTime(2026, 9, 6, 18, 30),
    nauticalDusk: DateTime(2026, 9, 6, 19, 0),
    astronomicalDusk: DateTime(2026, 9, 6, 19, 30),
    solarMidnight: DateTime(2026, 9, 6, 23, 59),
    astronomicalDawn: DateTime(2026, 9, 7, 5, 0),
    nauticalDawn: DateTime(2026, 9, 7, 5, 30),
    civilDawn: DateTime(2026, 9, 7, 6, 0),
    sunrise: DateTime(2026, 9, 7, 6, 30),
    moonIllumination: 0.25,
    moonPhaseName: 'Waxing Crescent',
    hasAstronomicalNight: true,
  );

  final testTarget = TargetItem(
    id: 42,
    name: 'NGC 1976',
    messier: 'M42',
    commonName: 'Orion Nebula',
    catalog: 'Messier',
    objectType: 'Bright Nebula',
    constellation: 'Ori',
    raHours: 19.777,
    decDegrees: 33.333,
    magnitude: 4.0,
    majorAxisArcmin: 65.0,
    positionAngleDeg: 55.0,
    surfaceBrightness: 11.5,
    peakAltitudeDeg: 68.0,
    visibleDurationHours: 4.5,
    transitTime: DateTime(2026, 9, 6, 23, 45),
    visibleStartTime: DateTime(2026, 9, 6, 21, 15),
    visibleEndTime: DateTime(2026, 9, 7, 1, 45),
    minMoonSepDeg: 82.0,
    meetsCriteria: true,
  );

  tearDown(() {
    SkyImageService.instance.setClientForTesting(http.Client());
    SkyImageService.instance.provider = SkyImageService.defaultProvider;
    SkyImageService.instance.clearMemoryCache();
  });

  group('Target Thumbnail Cards & Streaming Tests', () {
    testWidgets('TargetSearchView toggles to bigger thumbnail cards and shows all target metadata', (tester) async {
      await tester.runAsync(() => SkyImageService.instance.clearCache());
      SkyImageService.instance.provider = SkySurveyProvider.cdsHips2Fits;
      final requestedUrls = <String>[];

      final mockClient = _MockHttpClient((request) async {
        requestedUrls.add(request.url.toString());
        return http.Response.bytes(validPngBytes, 200);
      });
      SkyImageService.instance.setClientForTesting(mockClient);

      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      bool? toggledValue;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: TargetSearchView(
              targets: [testTarget],
              night: testNight,
              filters: FilterState(),
              isLoading: false,
              availableLists: const [],
              showTargetThumbnails: false,
              onShowTargetThumbnailsChanged: (val) => toggledValue = val,
              onFilterChanged: (_) {},
              onAddToList: (_, _, _) {},
            ),
          ),
        ),
      );

      // Initially in compact mode (no thumbnails)
      expect(find.byType(TargetSkyThumbnail), findsNothing);
      expect(requestedUrls, isEmpty);

      // Tap toolbar view mode toggle
      await tester.tap(find.byKey(const ValueKey('target_view_mode_toggle')));
      await tester.pump();

      await tester.runAsync(() async {
        final sw = Stopwatch()..start();
        while (sw.elapsedMilliseconds < 2000 && requestedUrls.isEmpty) {
          await Future.delayed(const Duration(milliseconds: 20));
        }
        await Future.delayed(const Duration(milliseconds: 50));
      });
      await tester.pump();

      expect(toggledValue, isTrue);
      expect(find.byType(TargetSkyThumbnail), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);

      // Verify same HiPS streaming parameters as TargetPreviewCanvas
      expect(requestedUrls.length, equals(1));
      final expectedFov = SkyImageService.computeRecommendedFovDeg(testTarget.majorAxisArcmin);
      expect(requestedUrls.first, contains('hips=CDS%2FP%2FDSS2%2Fcolor'));
      expect(requestedUrls.first, contains('fov=${expectedFov.toStringAsFixed(4)}'));
      expect(requestedUrls.first, contains('width=512'));
      expect(requestedUrls.first, contains('height=512'));

      // Verify all target information is rendered in the bigger card
      expect(find.text('M42 (Orion Nebula)'), findsOneWidget);
      expect(find.text('M42'), findsOneWidget);
      expect(find.text('Bright Nebula'), findsOneWidget);
      expect(find.text('Ori'), findsOneWidget);
      expect(find.text('Peak: 68°'), findsOneWidget);
      expect(find.text('21:15 – 01:45'), findsOneWidget);
      expect(find.text('Moon: 82°'), findsOneWidget);
      expect(find.text('4.5h above 30°'), findsOneWidget);
    });

    testWidgets('Thumbnail cards render cleanly on mobile 360x640 without overflow and fall back offline', (tester) async {
      await tester.runAsync(() => SkyImageService.instance.clearCache());
      final origBackoff = SkyImageService.instance.retryBackoff;
      SkyImageService.instance.retryBackoff = Duration.zero;
      final mockClient = _MockHttpClient((request) async {
        throw http.ClientException('Network unavailable', request.url);
      });
      SkyImageService.instance.setClientForTesting(mockClient);

      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(() => SkyImageService.instance.retryBackoff = origBackoff);

      // Use unique coordinates so no prior cached disk file can match
      final offlineTarget = TargetItem(
        id: 999123,
        name: 'Offline Test Nebula',
        catalog: 'NGC',
        objectType: 'Bright Nebula',
        constellation: 'Ori',
        raHours: 11.12345,
        decDegrees: -12.3456,
        magnitude: 6.5,
        majorAxisArcmin: 20.0,
        peakAltitudeDeg: 55.0,
        visibleDurationHours: 3.0,
        transitTime: DateTime(2026, 9, 6, 23, 45),
        minMoonSepDeg: 70.0,
        meetsCriteria: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: TargetSearchView(
              targets: [offlineTarget],
              night: testNight,
              filters: FilterState(),
              isLoading: false,
              availableLists: const [],
              showTargetThumbnails: true,
              onFilterChanged: (_) {},
              onAddToList: (_, _, _) {},
            ),
          ),
        ),
      );

      await tester.pump();
      await tester.runAsync(() async {
        await Future.delayed(const Duration(milliseconds: 200));
      });
      await tester.pump();

      expect(find.byType(TargetSkyThumbnail), findsOneWidget);
      expect(find.byIcon(Icons.cloud_off_rounded), findsOneWidget);
      expect(find.text('Offline Test Nebula'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test('SkyImageService deduplicates concurrent requests for identical cutout URLs', () async {
      await SkyImageService.instance.clearCache();
      SkyImageService.instance.provider = SkySurveyProvider.cdsHips2Fits;
      int networkCalls = 0;

      final mockClient = _MockHttpClient((request) async {
        networkCalls++;
        await Future.delayed(const Duration(milliseconds: 30));
        return http.Response.bytes(validPngBytes, 200);
      });
      SkyImageService.instance.setClientForTesting(mockClient);

      final url = SkyImageService.buildHiPSUrl(
        raHours: 14.321,
        decDegrees: 42.123,
        fovDeg: 1.1234,
      );

      final results = await Future.wait([
        SkyImageService.instance.fetchSkyImage(url),
        SkyImageService.instance.fetchSkyImage(url),
        SkyImageService.instance.fetchSkyImage(url),
      ]);

      expect(networkCalls, equals(1));
      for (final res in results) {
        expect(res, equals(validPngBytes));
      }
    });

    test('AppController manages showTargetThumbnails state and resets on cleanAllData', () {
      final controller = AppController(
        engine: FakeAstroEngine(),
        enableIsolate: false,
        initialShowTargetThumbnails: false,
      );

      expect(controller.showTargetThumbnails, isFalse);

      var notified = 0;
      controller.addListener(() => notified++);

      controller.setShowTargetThumbnails(true);
      expect(controller.showTargetThumbnails, isTrue);
      expect(notified, equals(1));

      // Setting the same value does not re-notify
      controller.setShowTargetThumbnails(true);
      expect(notified, equals(1));

      controller.cleanAllData();
      expect(controller.showTargetThumbnails, isFalse);

      controller.dispose();
    });
  });
}
