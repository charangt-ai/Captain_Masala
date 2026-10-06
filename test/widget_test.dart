import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:captain_masala/main.dart';
import 'package:captain_masala/core/services/database_service.dart';
import 'package:captain_masala/core/services/cart_service.dart';

void main() {
  testWidgets('App loads splash screen test', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DatabaseService()),
          ChangeNotifierProvider(create: (_) => CartService()),
        ],
        child: const CaptainMasalaApp(),
      ),
    );
    expect(find.byType(CaptainMasalaApp), findsOneWidget);
    await tester.pump(const Duration(seconds: 65));
  });
}
