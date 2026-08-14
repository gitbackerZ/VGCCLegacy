import 'package:flutter_test/flutter_test.dart';
import 'package:pokemon_mb_companion/main.dart';

void main() {
  testWidgets('App loads successfully smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const MyApp());

    // Verify that MyApp builds without crashing.
    expect(find.byType(MyApp), findsOneWidget);
  });
}
