import 'package:flutter_test/flutter_test.dart';
import 'package:wtracker/history.dart';
import 'package:wtracker/main.dart';
import 'package:wtracker/state.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    final tweaks = Tweaks();
    final prefs = Prefs();
    final history = History();
    await tester.pumpWidget(WTrackerApp(
      tweaks: tweaks,
      prefs: prefs,
      history: history,
      wordmarks: const {},
      initialTab: 'dash',
    ));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
