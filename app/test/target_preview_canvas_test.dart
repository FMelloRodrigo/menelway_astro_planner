import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/target_item.dart';
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

      // Check that rotation buttons and active rig strip appear
      expect(find.byIcon(Icons.rotate_left_rounded), findsOneWidget);
      expect(find.byIcon(Icons.rotate_right_rounded), findsOneWidget);
      expect(find.text('Align'), findsOneWidget);
      expect(find.text('Fit'), findsOneWidget);
      expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    });
  });
}
