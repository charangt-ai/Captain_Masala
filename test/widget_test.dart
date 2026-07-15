import 'package:flutter_test/flutter_test.dart';
import 'package:captain_masala/main.dart';

void main() {
  testWidgets('App loads splash screen test', (WidgetTester tester) async {
    await tester.pumpWidget(const CaptainMasalaApp());
    expect(find.byType(CaptainMasalaApp), findsOneWidget);
  });
}
