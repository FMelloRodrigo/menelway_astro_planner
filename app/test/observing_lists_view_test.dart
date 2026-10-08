import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:app/l10n/app_localizations.dart';
import 'package:app/models/observing_list.dart';
import 'package:app/views/observing_lists_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('Creating a new list does not throw TextEditingController used after being disposed', (tester) async {
    tester.view.physicalSize = const Size(720, 1600);
    tester.view.devicePixelRatio = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetViewInsets);

    List<ObservingListModel> lists = [];

    await tester.pumpWidget(
      buildTestableWidget(
        StatefulBuilder(
          builder: (context, setState) {
            return ObservingListsView(
              lists: lists,
              onCreateList: (name, desc, date) {
                setState(() {
                  lists = [
                    ...lists,
                    ObservingListModel(
                      id: 1,
                      name: name,
                      description: desc,
                      sessionDate: date,
                      createdAt: DateTime.now().millisecondsSinceEpoch,
                      items: [],
                    ),
                  ];
                });
              },
              onDeleteList: (_) {},
              onRemoveItem: (_, __) {},
            );
          },
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Tap to open the dialog
    final createBtn = find.byIcon(Icons.add_rounded).first;
    await tester.tap(createBtn);
    await tester.pumpAndSettle();

    // Simulate mobile keyboard appearing
    tester.view.viewInsets = const FakeViewPadding(bottom: 600);
    await tester.pump();

    // Find the name textfield and enter text
    final textFields = find.byType(TextField);
    expect(textFields, findsAtLeastNWidgets(3));

    // Focus and enter text
    await tester.enterText(textFields.at(0), 'Desert Star Party');
    await tester.pump();

    // Find the create button inside the dialog
    final submitBtn = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(FilledButton),
    );
    expect(submitBtn, findsOneWidget);

    await tester.tap(submitBtn);

    // Simulate mobile keyboard dismissing right as dialog pops
    tester.view.viewInsets = FakeViewPadding.zero;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    // Verify list was created and rendered without exception
    expect(find.text('Desert Star Party'), findsOneWidget);
  });
}
