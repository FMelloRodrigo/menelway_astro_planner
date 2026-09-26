import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/views/settings_dialog.dart';
import 'package:app/l10n/app_localizations.dart';

void main() {
  Widget buildTestWidget({
    required bool isRedNightMode,
    required VoidCallback onResetFilters,
    required VoidCallback onCleanAllData,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(
        body: Builder(
          builder: (context) => ElevatedButton(
            onPressed: () {
              showDialog(
                context: context,
                builder: (_) => SettingsDialog(
                  isRedNightMode: isRedNightMode,
                  onResetFilters: onResetFilters,
                  onCleanAllData: onCleanAllData,
                ),
              );
            },
            child: const Text('Open Settings'),
          ),
        ),
      ),
    );
  }

  testWidgets('SettingsDialog renders title, sections, and handles callbacks', (tester) async {
    bool resetCalled = false;
    bool cleanCalled = false;

    await tester.pumpWidget(
      buildTestWidget(
        isRedNightMode: false,
        onResetFilters: () {
          resetCalled = true;
        },
        onCleanAllData: () {
          cleanCalled = true;
        },
      ),
    );

    // Open settings window
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    // Verify window elements
    expect(find.text('Settings & Data'), findsOneWidget);
    expect(find.text('Target Filters'), findsOneWidget);
    expect(find.text('Target Display Limits'), findsOneWidget);
    expect(find.text('20 (Default)'), findsOneWidget);
    expect(find.text('Storage & Local Data'), findsOneWidget);
    expect(find.text('About Menelway'), findsWidgets);
    expect(find.text('Reset Target Filters'), findsOneWidget);

    // Verify description above About button is removed
    expect(find.text('Project story, background, and design philosophy.'), findsNothing);

    // Tap reset filters
    await tester.tap(find.text('Reset Target Filters'));
    await tester.pump();
    expect(resetCalled, isTrue);

    // Tap clean data (scroll into view if needed)
    final cleanFinder = find.text('Clean All Saved Data...');
    await tester.ensureVisible(cleanFinder);
    await tester.tap(cleanFinder);
    await tester.pumpAndSettle();
    expect(cleanCalled, isTrue);
  });

  testWidgets('SettingsDialog opens About window and displays project story', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isRedNightMode: false,
        onResetFilters: () {},
        onCleanAllData: () {},
      ),
    );

    // Open settings window
    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    // Scroll and tap About button in card (single About button in settings)
    final aboutBtn = find.byIcon(Icons.menu_book_rounded);
    await tester.ensureVisible(aboutBtn);
    await tester.tap(aboutBtn);
    await tester.pumpAndSettle();

    // Verify About window elements
    expect(find.text('MENELWAY'), findsOneWidget);
    expect(find.text('Story & Design Philosophy'), findsNothing); // Removed from title
    expect(find.text('Project Motivation and Goal'), findsOneWidget); // Renamed
    expect(find.text('Created by Rodrigo F. Mello'), findsOneWidget);
    expect(find.textContaining('This project was born out of personal necessity'), findsOneWidget);
    expect(find.text('Work 100% Offline'), findsOneWidget);
    expect(find.text('Easy Equipment Preview'), findsOneWidget);
    expect(find.textContaining('Skies/Heavens'), findsOneWidget);

    // Close About window via top-right close icon
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    // Still in Settings dialog
    expect(find.text('Settings & Data'), findsOneWidget);
  });

  testWidgets('SettingsDialog renders in red night mode without error', (tester) async {
    await tester.pumpWidget(
      buildTestWidget(
        isRedNightMode: true,
        onResetFilters: () {},
        onCleanAllData: () {},
      ),
    );

    await tester.tap(find.text('Open Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Settings & Data'), findsOneWidget);
    expect(find.byIcon(Icons.settings_suggest_rounded), findsOneWidget);
    expect(find.byIcon(Icons.close_rounded), findsOneWidget);

    // Open About in red night mode
    final aboutBtn = find.byIcon(Icons.menu_book_rounded);
    await tester.ensureVisible(aboutBtn);
    await tester.tap(aboutBtn);
    await tester.pumpAndSettle();

    expect(find.text('MENELWAY'), findsOneWidget);
    expect(find.text('Created by Rodrigo F. Mello'), findsOneWidget);

    // Close About window
    await tester.tap(find.byIcon(Icons.close_rounded).last);
    await tester.pumpAndSettle();

    // Close settings dialog via top-right close icon
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Target Filters'), findsNothing);
  });

  testWidgets('SettingsDialog updates ChoiceChip selection and highlight when tapped', (tester) async {
    int updatedLimit = -1;

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => SettingsDialog(
                    isRedNightMode: false,
                    maxTargets: 20,
                    onMaxTargetsChanged: (count) {
                      updatedLimit = count;
                    },
                    onResetFilters: () {},
                    onCleanAllData: () {},
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

    final defaultChip = tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '20 (Default)'));
    expect(defaultChip.selected, isTrue);

    final chip50Finder = find.widgetWithText(ChoiceChip, '50');
    expect(tester.widget<ChoiceChip>(chip50Finder).selected, isFalse);

    // Tap '50'
    await tester.tap(chip50Finder);
    await tester.pumpAndSettle();

    expect(updatedLimit, equals(50));
    expect(tester.widget<ChoiceChip>(chip50Finder).selected, isTrue);
    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '20 (Default)')).selected, isFalse);

    // Tap 'Reset Target Filters'
    await tester.tap(find.text('Reset Target Filters'));
    await tester.pumpAndSettle();

    expect(tester.widget<ChoiceChip>(find.widgetWithText(ChoiceChip, '20 (Default)')).selected, isTrue);
    expect(tester.widget<ChoiceChip>(chip50Finder).selected, isFalse);
  });
}
