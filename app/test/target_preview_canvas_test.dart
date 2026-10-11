import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:app/core/sky_image_service.dart';
import 'package:app/l10n/app_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/equipment_manager.dart';
import 'package:app/models/target_item.dart';
import 'package:app/views/equipment_framing_dialog.dart';
import 'package:app/widgets/target_preview_canvas.dart';

void main() {
  group('TargetPreviewCanvas Widget Tests', () {
    final testTarget = TargetItem(
      id: 42,
      name: 'NGC 1976',
      messier: 'M42',
      commonName: 'Great Orion Nebula',
      catalog: 'Messier',
      objectType: 'Nebula',
      constellation: 'Ori',
      raHours: 5.588,
      decDegrees: -5.39,
      magnitude: 4.0,
      majorAxisArcmin: 65.0,
      positionAngleDeg: 55.0,
      surfaceBrightness: 11.5,
      peakAltitudeDeg: 62.0,
      visibleDurationHours: 5.5,
      transitTime: DateTime(2026, 9, 6, 23, 0),
      minMoonSepDeg: 45.0,
      meetsCriteria: true,
    );

    testWidgets('Renders TargetPreviewCanvas with vector fallback and controls', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetPreviewCanvas(
              target: testTarget,
              isRedNightMode: false,
              height: 250,
            ),
          ),
        ),
      );

      // Verify custom paint vector canvas is present
      expect(find.byType(CustomPaint), findsWidgets);

      // Verify survey chip & FOV badge are displayed
      expect(find.textContaining('DSS2'), findsOneWidget);
      expect(find.textContaining('FOV:'), findsOneWidget);

      // Verify Zoom In & Zoom Out action buttons
      expect(find.byIcon(Icons.add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.remove_rounded), findsOneWidget);

      // Verify display mode toggle buttons
      expect(find.byIcon(Icons.filter_center_focus_rounded), findsOneWidget);
      expect(find.byIcon(Icons.draw_rounded), findsOneWidget);

      // Switch to Vector Only mode
      await tester.tap(find.byIcon(Icons.draw_rounded));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Ensure no crash occurred and canvas remains rendered
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Renders in Red Night Mode cleanly without error', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetPreviewCanvas(
              target: testTarget,
              isRedNightMode: true,
              height: 250,
            ),
          ),
        ),
      );

      expect(find.byType(TargetPreviewCanvas), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
    });

    testWidgets('Controls are located below image and framing controls toggle properly', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: SingleChildScrollView(
              child: TargetPreviewCanvas(
                target: testTarget,
                isRedNightMode: false,
                height: 250,
                enableExpandDialog: true,
              ),
            ),
          ),
        ),
      );

      // Verify that controls (e.g. FOV badge) are positioned below the 250px image canvas
      final vectorPainterFinder = find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TargetVectorPainter);
      final fovFinder = find.textContaining('FOV:');
      expect(tester.getTopLeft(fovFinder).dy, greaterThanOrEqualTo(tester.getBottomLeft(vectorPainterFinder).dy));

      // Verify Simulator button is present
      expect(find.text('Simulator'), findsOneWidget);

      // Tap Framing toggle
      final framingToggleFinder = find.text('Framing');
      expect(framingToggleFinder, findsOneWidget);
      await tester.tap(framingToggleFinder);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Check that rotation buttons and active rig strip appear (Align removed from preview box)
      expect(find.byIcon(Icons.rotate_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
      expect(find.text('Align'), findsNothing);
      expect(find.text('Fit to Sensor'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });

    testWidgets('EquipmentFramingDialog renders pan keypad, step size selector and handles pan events', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      EquipmentManager.instance.resetPan();

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentFramingDialog(
              target: testTarget,
              isRedNightMode: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Verify framing pan offset card elements
      expect(find.text('Framing Pan Offset'), findsOneWidget);
      expect(find.text('Centered'), findsOneWidget);
      expect(find.text("1'"), findsOneWidget);
      expect(find.text("5'"), findsOneWidget);
      expect(find.text("15'"), findsOneWidget);
      expect(find.text('Copy Info'), findsOneWidget);

      // Pan Up (North) by default 5 arcmin
      await tester.tap(find.byTooltip('Pan Up (North)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(EquipmentManager.instance.panOffsetArcminY, -5.0);
      expect(EquipmentManager.instance.totalPanOffsetArcmin, 5.0);
      expect(find.text("5.0' offset"), findsOneWidget);
      expect(find.textContaining('Center:'), findsOneWidget);

      // Change step size to 1'
      await tester.tap(find.text("1'"));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Pan Right (West) by 1 arcmin
      await tester.tap(find.byTooltip('Pan Right (West)'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(EquipmentManager.instance.panOffsetArcminX, 1.0);
      expect(EquipmentManager.instance.panOffsetArcminY, -5.0);

      // Reset to target center
      await tester.tap(find.byTooltip('Reset to Target Center'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(EquipmentManager.instance.panOffsetArcminX, 0.0);
      expect(EquipmentManager.instance.panOffsetArcminY, 0.0);
      expect(find.text('Centered'), findsOneWidget);

      // Tap Copy Info
      await tester.tap(find.text('Copy Info'));
      await tester.pump();
    });

    testWidgets('Photo Mode switches painter to isPhotoOnly and hides reticle/overlays', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetPreviewCanvas(
              target: testTarget,
              isRedNightMode: false,
              height: 300,
            ),
          ),
        ),
      );
      await tester.pump();

      // Find initial TargetVectorPainter in default photoWithReticle mode
      var customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TargetVectorPainter),
      );
      var painter = customPaint.painter as TargetVectorPainter;
      expect(painter.isPhotoOnly, isFalse);
      expect(painter.showReticle, isTrue);

      // Tap Photo Mode button
      final photoModeBtn = find.byTooltip('Photo Mode (Clean Image)');
      expect(photoModeBtn, findsOneWidget);
      await tester.tap(photoModeBtn);
      await tester.pump();

      // Check updated painter state
      customPaint = tester.widget<CustomPaint>(
        find.byWidgetPredicate((w) => w is CustomPaint && w.painter is TargetVectorPainter),
      );
      painter = customPaint.painter as TargetVectorPainter;
      expect(painter.isPhotoOnly, isTrue);
      expect(painter.showReticle, isFalse);
    });

    testWidgets('EquipmentFramingDialog does not auto-align to target, but fits to sensor upon entering and when a new rig is selected', (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      // Start with angle 0.0 and ensure multiple profiles exist
      EquipmentManager.instance.setCameraAngle(0.0);
      expect(EquipmentManager.instance.cameraAngleDeg, 0.0);
      expect(EquipmentManager.instance.profiles.length, greaterThan(1));

      final initialRig = EquipmentManager.instance.activeProfile;
      final secondProfile = EquipmentManager.instance.profiles.firstWhere((p) => p.id != initialRig.id);

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: EquipmentFramingDialog(
              target: testTarget,
              isRedNightMode: false,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // 1. Should NOT have auto-aligned to target (remains 0.0°), but FOV fits to sensor upon entering
      expect(EquipmentManager.instance.cameraAngleDeg, 0.0);
      final canvasState = tester.state<TargetPreviewCanvasState>(find.byType(TargetPreviewCanvas));
      final expectedInitialFov = (initialRig.sensorFovDiagonalDeg * 1.35).clamp(0.15, 14.0);
      expect(canvasState.fovDeg, closeTo(expectedInitialFov, 0.01));

      // Manually change angle away to 90°
      EquipmentManager.instance.setCameraAngle(90.0);
      expect(EquipmentManager.instance.cameraAngleDeg, 90.0);

      // 2. Switch rig using popup menu
      final rigsDropdown = find.widgetWithText(Container, 'Rigs');
      expect(rigsDropdown, findsOneWidget);
      await tester.tap(rigsDropdown);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      final secondProfileItem = find.text(secondProfile.name).last;
      await tester.tap(secondProfileItem);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      // Verify active rig switched, angle remains 90.0° (did not auto-align), and FOV fit to second sensor
      expect(EquipmentManager.instance.activeProfile.id, secondProfile.id);
      expect(EquipmentManager.instance.cameraAngleDeg, 90.0);
      final expectedSecondFov = (secondProfile.sensorFovDiagonalDeg * 1.35).clamp(0.15, 14.0);
      expect(canvasState.fovDeg, closeTo(expectedSecondFov, 0.01));

      // 3. Small Align button exists and manual tap aligns to target PA (55.0°)
      final alignBtn = find.widgetWithText(OutlinedButton, 'Align');
      expect(alignBtn, findsOneWidget);
      await tester.tap(alignBtn);
      await tester.pump();
      expect(EquipmentManager.instance.cameraAngleDeg, 55.0);
    });

    testWidgets('Zoom Step Size chips (10%, 25%, 50%) adjust step and zoom buttons scale FOV symmetrically', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetPreviewCanvas(
              target: testTarget,
              isRedNightMode: false,
              height: 250,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final canvasState = tester.state<TargetPreviewCanvasState>(find.byType(TargetPreviewCanvas));

      // Default should be 25% (0.25)
      expect(canvasState.zoomStepPercent, 0.25);
      expect(find.text('10%'), findsOneWidget);
      expect(find.text('25%'), findsOneWidget);
      expect(find.text('50%'), findsOneWidget);

      final initialFov = canvasState.fovDeg;

      // Tap 50%
      await tester.tap(find.text('50%'));
      await tester.pump();
      expect(canvasState.zoomStepPercent, 0.50);

      // Tap Zoom In (+) -> newFov = initialFov / 1.50
      await tester.tap(find.byIcon(Icons.add_rounded));
      await tester.pump();
      expect(canvasState.fovDeg, closeTo(initialFov / 1.50, 0.001));

      // Tap Zoom Out (-) -> returns to initialFov symmetrically
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(canvasState.fovDeg, closeTo(initialFov, 0.001));

      // Tap 10%
      await tester.tap(find.text('10%'));
      await tester.pump();
      expect(canvasState.zoomStepPercent, 0.10);

      // Tap Zoom Out (-) -> newFov = initialFov * 1.10
      await tester.tap(find.byIcon(Icons.remove_rounded));
      await tester.pump();
      expect(canvasState.fovDeg, closeTo(initialFov * 1.10, 0.001));
    });

    testWidgets('Displays sub-pixel clamp notice for planets and not for nebulae/Moon', (tester) async {
      final jupiter = TargetItem(
        id: 901,
        name: 'Jupiter',
        catalog: 'Solar System',
        objectType: 'Planet',
        constellation: 'Tau',
        raHours: 4.15,
        decDegrees: 21.3,
        magnitude: -2.5,
        majorAxisArcmin: 0.75, // 45 arcseconds
        peakAltitudeDeg: 65.0,
        visibleDurationHours: 6.0,
        transitTime: DateTime(2026, 9, 6, 23, 0),
        minMoonSepDeg: 60.0,
        meetsCriteria: true,
      );

      final moon = TargetItem(
        id: 902,
        name: 'Moon',
        catalog: 'Solar System',
        objectType: 'Planet',
        constellation: 'Cap',
        raHours: 20.5,
        decDegrees: -18.0,
        magnitude: -12.0,
        majorAxisArcmin: 31.0,
        peakAltitudeDeg: 55.0,
        visibleDurationHours: 8.0,
        transitTime: DateTime(2026, 9, 6, 21, 0),
        minMoonSepDeg: 0.0,
        meetsCriteria: true,
      );

      // 1. Render TargetPreviewCanvas with Jupiter -> Notice should appear
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetPreviewCanvas(
              target: jupiter,
              isRedNightMode: false,
              height: 350,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.textContaining('visibility clamp applied'), findsOneWidget);

      // 2. Render with Moon -> Notice should NOT appear
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TargetPreviewCanvas(
              target: moon,
              isRedNightMode: false,
              height: 350,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.textContaining('visibility clamp applied'), findsNothing);
    });

    testWidgets('Renders offline fallback with Retry button when image fetch fails without corrupting displayMode', (tester) async {
      SkyImageService.instance.clearMemoryCache();
      final mockClient = _ImmediateFailingClient();
      SkyImageService.instance.setClientForTesting(mockClient);
      final origBackoff = SkyImageService.instance.retryBackoff;
      SkyImageService.instance.retryBackoff = Duration.zero;

      final uncachedTarget = TargetItem(
        id: 999999,
        name: 'Uncached Test DSO',
        catalog: 'Custom',
        objectType: 'Galaxy',
        constellation: 'Cnc',
        raHours: 8.76543,
        decDegrees: 23.4567,
        magnitude: 10.0,
        majorAxisArcmin: 12.0,
        peakAltitudeDeg: 50.0,
        visibleDurationHours: 4.0,
        transitTime: DateTime(2026, 9, 6, 22, 0),
        minMoonSepDeg: 60.0,
        meetsCriteria: true,
      );

      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: TargetPreviewCanvas(
                target: uncachedTarget,
                isRedNightMode: false,
                height: 300,
              ),
            ),
          ),
        );

        // Advance real microtasks so async fetch finishes
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        final state = tester.state<TargetPreviewCanvasState>(find.byType(TargetPreviewCanvas));
        expect(state.hasError, isTrue);

        // Find the Retry button on the offline banner
        expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Verify that the user can tap Retry without errors
        await tester.tap(find.byIcon(Icons.refresh_rounded));
        await tester.runAsync(() async {
          await Future.delayed(const Duration(milliseconds: 100));
        });
        await tester.pump();

        // Canvas remains properly rendered
        expect(find.byType(CustomPaint), findsWidgets);
      } finally {
        SkyImageService.instance.retryBackoff = origBackoff;
        SkyImageService.instance.setClientForTesting(http.Client());
      }
    });

    testWidgets('Maintains scale parity in rectangular mobile landscape viewports without aspect ratio distortion', (tester) async {
      final mockClient = _ImmediateFailingClient();
      SkyImageService.instance.setClientForTesting(mockClient);
      final origBackoff = SkyImageService.instance.retryBackoff;
      SkyImageService.instance.retryBackoff = Duration.zero;

      try {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 480,
                  height: 380, // allows viewport to get wide rectangular aspect ratio
                  child: TargetPreviewCanvas(
                    target: testTarget,
                    isRedNightMode: false,
                    height: double.infinity,
                    initialFramingEnabled: true,
                    enableExpandDialog: false,
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final state = tester.state<TargetPreviewCanvasState>(find.byType(TargetPreviewCanvas));
        expect(state.fovDeg, greaterThan(0.0));
        expect(find.byType(CustomPaint), findsWidgets);
      } finally {
        SkyImageService.instance.retryBackoff = origBackoff;
        SkyImageService.instance.setClientForTesting(http.Client());
      }
    });
  });
}

class _ImmediateFailingClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    throw http.ClientException('Network unavailable', request.url);
  }
}
