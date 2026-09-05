import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart';

void main() {
  testWidgets('App basic initialization test', (WidgetTester tester) async {
    await tester.pumpWidget(const AstroTargetsApp());
    expect(find.byType(AstroTargetsApp), findsOneWidget);
  });
}
