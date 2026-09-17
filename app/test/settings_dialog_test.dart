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
    expect(find.text('Storage & Local Data'), findsOneWidget);
    expect(find.text('Reset Target Filters'), findsOneWidget);
    expect(find.text('Clean All Saved Data...'), findsOneWidget);

    // Tap reset filters
    await tester.tap(find.text('Reset Target Filters'));
    await tester.pump();
    expect(resetCalled, isTrue);

    // Tap clean data
    await tester.tap(find.text('Clean All Saved Data...'));
    await tester.pumpAndSettle();
    expect(cleanCalled, isTrue);
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

    // Close dialog
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pumpAndSettle();
    expect(find.text('Target Filters'), findsNothing);
  });
}
