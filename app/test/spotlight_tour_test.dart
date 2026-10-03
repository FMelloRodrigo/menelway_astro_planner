import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/widgets/spotlight_tour.dart';
import 'package:app/views/settings_dialog.dart';
import 'package:app/l10n/app_localizations.dart';

void main() {
  group('SpotlightTour Widget Tests', () {
    testWidgets('SpotlightTour advances through steps, supports back, and finishes', (tester) async {
      final key1 = GlobalKey();
      final key2 = GlobalKey();
      final key3 = GlobalKey();

      bool finished = false;
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Stack(
              children: [
                Positioned(top: 10, left: 10, child: SizedBox(key: key1, width: 100, height: 40)),
                Positioned(top: 10, right: 10, child: SizedBox(key: key2, width: 80, height: 40)),
                Positioned(top: 100, left: 10, child: SizedBox(key: key3, width: 60, height: 40)),
                Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () {
                      SpotlightTour.show(
                        context: ctx,
                        isRedNightMode: false,
                        steps: [
                          SpotlightTourStep(
                            targetKey: key1,
                            title: 'Step One Title',
                            description: 'Step One Description',
                            icon: Icons.location_on,
                          ),
                          SpotlightTourStep(
                            targetKey: key2,
                            title: 'Step Two Title',
                            description: 'Step Two Description',
                            icon: Icons.camera_alt,
                          ),
                          SpotlightTourStep(
                            targetKey: key3,
                            title: 'Step Three Title',
                            description: 'Step Three Description',
                            icon: Icons.tune,
                          ),
                        ],
                        onFinished: () => finished = true,
                        onSkipped: () => skipped = true,
                      );
                    },
                    child: const Text('Start Tour'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      // Start the tour
      await tester.tap(find.text('Start Tour'));
      await tester.pump(const Duration(milliseconds: 100));

      // Verify Step 1 is showing
      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Step One Title'), findsOneWidget);
      expect(find.text('Step One Description'), findsOneWidget);
      expect(find.text('← Back'), findsNothing); // No back button on first step
      expect(find.text('Next →'), findsOneWidget);

      // Advance to Step 2
      await tester.tap(find.text('Next →'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step 2 of 3'), findsOneWidget);
      expect(find.text('Step Two Title'), findsOneWidget);
      expect(find.text('← Back'), findsOneWidget);

      // Test going back to Step 1
      await tester.tap(find.text('← Back'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Step 1 of 3'), findsOneWidget);
      expect(find.text('Step One Title'), findsOneWidget);

      // Go to Step 2 then Step 3
      await tester.tap(find.text('Next →'));
      await tester.pump(const Duration(milliseconds: 100));
      await tester.tap(find.text('Next →'));
      await tester.pump(const Duration(milliseconds: 100));

      // Step 3 (final step)
      expect(find.text('Step 3 of 3'), findsOneWidget);
      expect(find.text('Step Three Title'), findsOneWidget);
      expect(find.text('Start Exploring'), findsOneWidget);

      // Finish the tour
      await tester.tap(find.text('Start Exploring'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(finished, isTrue);
      expect(skipped, isFalse);
      expect(find.text('Step 3 of 3'), findsNothing);
    });

    testWidgets('SpotlightTour handles Skip Tour', (tester) async {
      final key1 = GlobalKey();
      bool skipped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Column(
              children: [
                SizedBox(key: key1, width: 100, height: 40),
                Builder(
                  builder: (ctx) => ElevatedButton(
                    onPressed: () {
                      SpotlightTour.show(
                        context: ctx,
                        isRedNightMode: false,
                        steps: [
                          SpotlightTourStep(
                            targetKey: key1,
                            title: 'Step One Title',
                            description: 'Step One Description',
                            icon: Icons.location_on,
                          ),
                        ],
                        onSkipped: () => skipped = true,
                      );
                    },
                    child: const Text('Start Tour'),
                  ),
                ),
              ],
            ),
          ),
        ),
      );

      await tester.tap(find.text('Start Tour'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Skip Tour'), findsOneWidget);
      await tester.tap(find.text('Skip Tour'));
      await tester.pump(const Duration(milliseconds: 100));

      expect(skipped, isTrue);
      expect(find.text('Step 1 of 1'), findsNothing);
    });

    testWidgets('SettingsDialog renders Quick Tour card and triggers onReplayTour', (tester) async {
      bool replayed = false;

      await tester.binding.setSurfaceSize(const Size(1000, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          locale: const Locale('en'),
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: ctx,
                    builder: (_) => SettingsDialog(
                      isRedNightMode: false,
                      onResetFilters: () {},
                      onCleanAllData: () {},
                      onReplayTour: () {
                        replayed = true;
                      },
                    ),
                  );
                },
                child: const Text('Open Settings'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Settings'));
      await tester.pumpAndSettle();

      expect(find.text('Quick Tour & Guide'), findsOneWidget);
      expect(find.text('Replay Quick Tour'), findsOneWidget);

      await tester.ensureVisible(find.text('Replay Quick Tour'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Replay Quick Tour'));
      await tester.pumpAndSettle();

      expect(replayed, isTrue);
    });
  });
}
