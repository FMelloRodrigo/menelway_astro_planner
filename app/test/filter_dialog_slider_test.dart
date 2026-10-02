import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/filter_state.dart';
import 'package:app/views/filter_dialog.dart';

void main() {
  group('FilterDialog Altitude Sliders Step Size Tests', () {
    setUp(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.physicalSize = const Size(1280, 900);
      binding.platformDispatcher.views.first.devicePixelRatio = 1.0;
    });

    tearDown(() {
      final binding = TestWidgetsFlutterBinding.ensureInitialized();
      binding.platformDispatcher.views.first.resetPhysicalSize();
      binding.platformDispatcher.views.first.resetDevicePixelRatio();
    });

    testWidgets('Min altitude slider has step size of 5 with default maxAltitude (90°)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterDialog(
              initialFilters: FilterState(minAltitude: 30.0, maxAltitude: 90.0),
              onApply: (_) {},
            ),
          ),
        ),
      );

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      // First slider is Min Altitude
      final minAltSlider = sliders[0];
      expect(minAltSlider.min, 10.0);
      expect(minAltSlider.max, 70.0);
      expect(minAltSlider.divisions, 12);
      expect((minAltSlider.max - minAltSlider.min) / minAltSlider.divisions!, 5.0);

      // Second slider is Max Altitude
      final maxAltSlider = sliders[1];
      expect(maxAltSlider.min, 50.0);
      expect(maxAltSlider.max, 90.0);
      expect(maxAltSlider.divisions, 8);
      expect((maxAltSlider.max - maxAltSlider.min) / maxAltSlider.divisions!, 5.0);
    });

    testWidgets('Min altitude slider maintains step size of 5 when maxAltitude is 70° (preventing 19, 24, 28 bug)', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterDialog(
              initialFilters: FilterState(minAltitude: 20.0, maxAltitude: 70.0),
              onApply: (_) {},
            ),
          ),
        ),
      );

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      final minAltSlider = sliders[0];
      // When maxAltitude is 70°, max is 65.0, so (65 - 10) / 11 = 5.0 (divisions must be 11, NOT 12)
      expect(minAltSlider.min, 10.0);
      expect(minAltSlider.max, 65.0);
      expect(minAltSlider.divisions, 11);
      expect((minAltSlider.max - minAltSlider.min) / minAltSlider.divisions!, 5.0);
    });

    testWidgets('Max altitude slider maintains step size of 5 when minAltitude is 50°', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FilterDialog(
              initialFilters: FilterState(minAltitude: 50.0, maxAltitude: 90.0),
              onApply: (_) {},
            ),
          ),
        ),
      );

      final sliders = tester.widgetList<Slider>(find.byType(Slider)).toList();
      final maxAltSlider = sliders[1];
      // When minAltitude is 50°, min is 55.0, so (90 - 55) / 7 = 5.0 (divisions must be 7, NOT 8)
      expect(maxAltSlider.min, 55.0);
      expect(maxAltSlider.max, 90.0);
      expect(maxAltSlider.divisions, 7);
      expect((maxAltSlider.max - maxAltSlider.min) / maxAltSlider.divisions!, 5.0);
    });
  });
}
