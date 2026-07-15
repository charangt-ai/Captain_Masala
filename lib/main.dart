import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/services/database_service.dart';
import 'core/services/cart_service.dart';
import 'core/theme.dart';
import 'features/auth/splash_screen.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DatabaseService()),
        ChangeNotifierProvider(create: (_) => CartService()),
      ],
      child: const CaptainMasalaApp(),
    ),
  );
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
