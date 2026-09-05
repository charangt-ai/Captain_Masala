import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// removed firebase_auth
import '../../core/services/database_service.dart';
import '../../core/widgets/brand_logo.dart';
import '../dashboard/dashboard_screen.dart';
import '../seller/seller_main_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeIn),
    );

    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _navigateToNext();
    });
  }

  Future<void> _navigateToNext() async {
    final db = Provider.of<DatabaseService>(context, listen: false);

    // Step 1: Initialize DatabaseService (reads JWT token from storage)
    bool isAuth = false;
    try {
      isAuth = await db.init().timeout(const Duration(seconds: 5));
    } catch (_) {
      // Init timed out — proceed anyway
    }

    String? resolvedRole;

    if (isAuth && db.currentUserProfile != null) {
      resolvedRole = db.currentUserProfile!.role;
    }

    // Minimum splash duration for smooth UX
    await Future.delayed(const Duration(milliseconds: 1200));

    if (!mounted) return;

    if (resolvedRole != null && db.isLoggedIn && resolvedRole != 'network_error') {
      if (resolvedRole == 'seller' ||
          resolvedRole == 'salesperson' ||
          resolvedRole == 'delivery') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const SellerMainScreen()),
        );
      } else if (resolvedRole == 'pending') {
        // Pending users are not yet approved — go to login
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
      } else {
        // super_admin, admin
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: const Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CaptainMasalaLogo(size: 160),
              SizedBox(height: 48),
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
