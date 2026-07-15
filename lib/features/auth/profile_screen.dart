import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import 'login_screen.dart';
import '../profile/edit_profile_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({Key? key}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {

  void _handleLogout() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: _handleLogout,
            tooltip: 'Logout',
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Company Info Card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: AppColors.primaryRed.withOpacity(0.1),
                          radius: 28,
                          child: const Icon(Icons.business_rounded, color: AppColors.primaryRed, size: 28),
                        ),
                        const SizedBox(width: 16),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Captain Masala & Spices',
                                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Pure Spices... Perfect Taste!',
                                style: TextStyle(fontStyle: FontStyle.italic, color: AppColors.primaryGreen),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const Divider(height: 32),
                    const Text(
                      'HEAD OFFICE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textLight, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    const Text('3/238B, Puthur Itteri Road,\nNethimedu, Salem - 636002'),
                    const SizedBox(height: 16),
                    const Text(
                      'WEBSITE',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.textLight, letterSpacing: 1),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'captainmasala.in',
                      style: TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Profile Actions
            ElevatedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EditProfileScreen()),
                );
              },
              icon: const Icon(Icons.edit),
              label: const Text('Edit Profile Details'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryRed,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
