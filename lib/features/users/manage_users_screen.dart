import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/app_user.dart';
import '../../core/theme.dart';
import 'user_profile_view_screen.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  bool _isLoading = false;
  List<AppUser> _pendingUsers = [];
  List<AppUser> _activeUsers = [];

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    
    try {
      final pending = await db.getPendingUsers();
      final active = await db.getActiveUsers();
      
      if (mounted) {
        setState(() {
          _pendingUsers = pending;
          _activeUsers = active;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading users: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _handleApprove(AppUser user) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.approveUser(user.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.email} approved!')));
    }
    _loadUsers();
  }

  Future<void> _handleReject(AppUser user) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.rejectUser(user.id);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${user.email} rejected!')));
    }
    _loadUsers();
  }

  Future<void> _showChangeRoleDialog(AppUser user) async {
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
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Role changed successfully!')),
                );
              }
              _loadUsers();
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveUsersList() {
    if (_activeUsers.isEmpty) {
      return const Center(child: Text('No active sellers or delivery men.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _activeUsers.length,
      itemBuilder: (context, index) {
        final user = _activeUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => UserProfileViewScreen(
                    user: user,
                    onRoleChanged: _loadUsers,
                  ),
                ),
              );
            },
            leading: CircleAvatar(
              backgroundColor: AppColors.primaryRed.withOpacity(0.1),
              child: Icon(
                user.role == 'delivery' ? Icons.local_shipping : Icons.storefront,
                color: AppColors.primaryRed,
              ),
            ),
            title: Text(user.name.isNotEmpty ? user.name : (user.username.isNotEmpty ? user.username : 'Unknown')),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.email),
                if (user.phoneNumber.isNotEmpty) Text(user.phoneNumber),
              ],
            ),
            trailing: Chip(
              label: Text(
                user.role.toUpperCase(),
                style: const TextStyle(fontSize: 10, color: Colors.white),
              ),
              backgroundColor: user.role == 'delivery' ? Colors.blue : AppColors.primaryRed,
            ),
          ),
        );
      },
    );
  }

  Widget _buildPendingUsersList() {
    if (_pendingUsers.isEmpty) {
      return const Center(child: Text('No pending approval requests.'));
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _pendingUsers.length,
      itemBuilder: (context, index) {
        final user = _pendingUsers[index];
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name.isNotEmpty ? user.name : 'No Name Provided', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                const SizedBox(height: 4),
                if (user.username.isNotEmpty) Text('Username: ${user.username}'),
                Text('Email: ${user.email}'),
                if (user.phoneNumber.isNotEmpty) Text('Phone: ${user.phoneNumber}'),
                if (user.requestedRole != null) ...[
                  const SizedBox(height: 4),
                  Text('Requested Role: ${user.requestedRole}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _handleReject(user),
                      icon: const Icon(Icons.close, color: AppColors.outOfStockAlert),
                      label: const Text('Reject', style: TextStyle(color: AppColors.outOfStockAlert)),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _handleApprove(user),
                      icon: const Icon(Icons.check),
                      label: const Text('Approve'),
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGreen),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sellers & Delivery', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          elevation: 0,
          actions: [
            IconButton(icon: const Icon(Icons.refresh, color: Colors.white), onPressed: _loadUsers),
          ],
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            labelStyle: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            unselectedLabelStyle: TextStyle(fontWeight: FontWeight.normal, fontSize: 14),
            tabs: [
              Tab(text: 'Active Users'),
              Tab(text: 'Approvals'),
            ],
          ),
        ),
        body: _isLoading 
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              children: [
                _buildActiveUsersList(),
                _buildPendingUsersList(),
              ],
            ),
      ),
    );
  }
}
