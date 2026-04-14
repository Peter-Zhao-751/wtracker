import 'package:flutter_test/flutter_test.dart';

import 'package:wtracker/main.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const WTrackerApp());
    await tester.pumpAndSettle();

    expect(find.text('PROGRESS'), findsOneWidget);
  });
}
