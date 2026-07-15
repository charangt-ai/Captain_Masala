import 'package:flutter/material.dart';
import '../../core/models/app_user.dart';
import '../../core/theme.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';

class UserProfileViewScreen extends StatelessWidget {
  final AppUser user;
  final VoidCallback onRoleChanged;

  const UserProfileViewScreen({Key? key, required this.user, required this.onRoleChanged}) : super(key: key);

  Future<void> _showChangeRoleDialog(BuildContext context) async {
    String newRole = user.role == 'delivery' ? 'seller' : 'delivery';
    
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change Role'),
        content: Text('Change ${user.name.isNotEmpty ? user.name : user.email}\'s role from ${user.role.toUpperCase()} to ${newRole.toUpperCase()}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final db = Provider.of<DatabaseService>(context, listen: false);
              await db.changeUserRole(user.id, newRole);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Role changed successfully!')),
              );
              onRoleChanged();
              Navigator.pop(context);
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${user.name.isNotEmpty ? user.name : user.username} Profile'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const CircleAvatar(
              radius: 50,
              backgroundColor: AppColors.primaryRed,
              child: Icon(Icons.person, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 24),
            _buildInfoCard('Name', user.name.isNotEmpty ? user.name : 'N/A', Icons.badge),
            _buildInfoCard('Username', user.username.isNotEmpty ? user.username : 'N/A', Icons.account_circle),
            _buildInfoCard('Email', user.email, Icons.email),
            _buildInfoCard('Phone', user.phoneNumber.isNotEmpty ? user.phoneNumber : 'N/A', Icons.phone),
            _buildInfoCard('Role', user.role.toUpperCase(), Icons.security),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Change Role'),
              onPressed: () => _showChangeRoleDialog(context),
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(50),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard(String title, String value, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppColors.primaryRed),
        title: Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        subtitle: Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
      ),
    );
  }
}
