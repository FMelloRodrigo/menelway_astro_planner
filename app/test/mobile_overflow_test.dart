import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/favorites_manager.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/altitude_point.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/models/night_summary.dart';
import 'package:app/models/target_item.dart';
import 'package:app/views/altitude_curve_chart.dart';
import 'package:app/views/equipment_dialog.dart';
import 'package:app/views/favorites_view.dart';
import 'package:app/views/horizon_maker_dialog.dart';
import 'package:app/views/observing_lists_view.dart';
import 'package:app/views/planner_view.dart';
import 'package:app/views/target_details_sheet.dart';

void main() {
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
    moonIllumination: 0.74,
    moonPhaseName: 'Waxing Gibbous',
    hasAstronomicalNight: true,
  );

  final testTarget = TargetItem(
    id: 1,
    name: 'M42',
    messier: 'M42',
    commonName: 'Orion Nebula',
    catalog: 'Messier',
    objectType: 'Bright Nebula',
    constellation: 'Orion',
    raHours: 5.588,
    decDegrees: -5.39,
    magnitude: 4.0,
    majorAxisArcmin: 65.0,
    surfaceBrightness: 11.2,
    peakAltitudeDeg: 68.4,
    visibleDurationHours: 4.5,
    transitTime: DateTime(2026, 9, 6, 23, 45),
    minMoonSepDeg: 82.0,
    meetsCriteria: true,
  );

  Widget createTestApp(Widget child, {Locale locale = const Locale('pt', 'BR')}) {
    return MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  group('Mobile Viewport Overflow Detection (360x640)', () {
    testWidgets('AppBar with title and action buttons does not overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) {
              final l10n = AppLocalizations.of(context);
              return Scaffold(
                appBar: AppBar(
                  title: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        child: const Icon(Icons.blur_on_rounded, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              "MENELWAY",
                              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                            ),
                            Text(
                              l10n.appSubtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 10),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  actions: [
                    IconButton(icon: const Icon(Icons.remove_red_eye_rounded), onPressed: () {}),
                    const SizedBox(width: 8),
                    Container(width: 60, height: 32, color: Colors.blue),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.camera_alt_rounded), onPressed: () {}),
                    const SizedBox(width: 8),
                    IconButton(icon: const Icon(Icons.settings_suggest_rounded), onPressed: () {}),
                    const SizedBox(width: 10),
                  ],
                ),
              );
            },
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('AltitudeCurveChart does not overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final List<AltitudePoint> points = List.generate(
        10,
        (i) => AltitudePoint(
          time: DateTime(2026, 9, 6, 20 + i),
          altitude: 30.0 + i * 4,
          azimuth: 100.0 + i * 10,
          moonSeparation: 60.0 + i * 2,
          meetsCriteria: true,
        ),
      );

      await tester.pumpWidget(
        createTestApp(
          AltitudeCurveChart(
            targetPoints: points,
            night: testNight,
            targetName: "NGC 7000 (North America Nebula)",
          ),
          locale: const Locale('pt', 'BR'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('PlannerView does not overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          PlannerView(
            filters: FilterState(),
            night: testNight,
            isRedNightMode: false,
            availableLists: const [],
            onAddToList: (_, _, _) {},
            onFilterChanged: (_) {},
          ),
          locale: const Locale('pt', 'BR'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('FavoritesView with items does not overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      FavoritesManager.instance.init([testTarget]);

      await tester.pumpWidget(
        createTestApp(
          FavoritesView(
            night: testNight,
            filters: FilterState(),
            availableLists: const [],
            onAddToList: (_, _, _) {},
            onExploreTargets: () {},
          ),
          locale: const Locale('pt', 'BR'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });

    testWidgets('HorizonMakerDialog does not overflow on 360px when zooming in and selecting points', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          HorizonMakerDialog(
            initialFilters: FilterState(
              horizonPoints: [
                const HorizonPointModel(azimuth: 45.0, altitude: 20.0),
                const HorizonPointModel(azimuth: 180.0, altitude: 15.0),
              ],
            ),
            onApply: (_) {},
          ),
          locale: const Locale('pt', 'BR'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Tap zoom in button to test viewport scrubber on mobile
      final zoomInBtn = find.byTooltip("Zoom In (Wheel Up)");
      expect(zoomInBtn, findsOneWidget);
      await tester.tap(zoomInBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);

      // Tap on the chart to select/add a point to test point inspector on mobile
      final canvasFinder = find.byType(CustomPaint).first;
      await tester.tap(canvasFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
      expect(tester.takeException(), isNull);
    });

    testWidgets('HorizonMakerDialog on desktop renders full toolbar without cutting off Import Panorama or presets', (tester) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          HorizonMakerDialog(
            initialFilters: FilterState(),
            onApply: (_) {},
          ),
          locale: const Locale('en', 'US'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final importBtn = find.text("Import Panorama Image...");
      expect(importBtn, findsOneWidget);

      final clearPreset = find.text("Clear (0°)");
      expect(clearPreset, findsOneWidget);

      final backyardPreset = find.text("Backyard Sample");
      expect(backyardPreset, findsOneWidget);

      // Ensure buttons are within the screen bounds and rendered cleanly
      final importRect = tester.getRect(importBtn);
      final backyardRect = tester.getRect(backyardPreset);
      expect(importRect.right, lessThanOrEqualTo(1280.0));
      expect(backyardRect.right, lessThanOrEqualTo(1280.0));
      expect(tester.takeException(), isNull);
    });

    testWidgets('EquipmentDialog does not overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          EquipmentDialog(
            onSaved: () {},
          ),
          locale: const Locale('pt', 'BR'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Tap 'Criar Novo Equipamento' to enter editor mode with "Salvar Equipamento"
      final createRigBtn = find.text("Criar Novo Equipamento");
      expect(createRigBtn, findsOneWidget);
      await tester.tap(createRigBtn);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify "Salvar Equipamento" button is present and there is no overflow
      expect(find.text("Salvar Equipamento"), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ObservingListsView empty state does not overflow and is centered on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          ObservingListsView(
            lists: const [],
            onCreateList: (_, _, _) {},
            onDeleteList: (_) {},
            onRemoveItem: (_, _) {},
          ),
          locale: const Locale('pt', 'BR'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Verify empty text is found and centered
      final emptyText = find.text("Nenhuma lista de observação ainda. Crie uma para organizar sua sessão!");
      expect(emptyText, findsOneWidget);
      final textWidget = tester.widget<Text>(emptyText);
      expect(textWidget.textAlign, TextAlign.center);
      expect(tester.takeException(), isNull);
    });

    testWidgets('TargetDetailsSheet does not overflow on 360px', (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createTestApp(
          Scaffold(
            body: TargetDetailsSheet(
              target: testTarget,
              night: testNight,
              latitude: -23.55,
              longitude: -46.63,
              elevation: 760,
              isRedNightMode: false,
              filters: FilterState(),
              availableLists: const [],
              onAddToList: (_, _, _) {},
            ),
          ),
          locale: const Locale('pt', 'BR'),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));
    });
  });
}
