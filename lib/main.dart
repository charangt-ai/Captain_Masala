import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/database_service.dart';
import 'core/services/cart_service.dart';
import 'core/theme.dart';
import 'features/auth/splash_screen.dart';
void main() async {
  runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();

    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => DatabaseService()),
          ChangeNotifierProvider(create: (_) => CartService()),
        ],
        child: const CaptainMasalaApp(),
      ),
    );
  }, (error, stack) {
    debugPrint('Uncaught asynchronous error: $error');
    debugPrint('Stack trace: $stack');
    // Here you would typically log to Firebase Crashlytics if available
  });
}

class CaptainMasalaApp extends StatelessWidget {
  const CaptainMasalaApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Captain Masala',
      theme: AppTheme.lightTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
