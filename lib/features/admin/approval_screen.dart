import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/app_user.dart';
import '../../core/theme.dart';

class ApprovalScreen extends StatefulWidget {
  const ApprovalScreen({Key? key}) : super(key: key);

  @override
  State<ApprovalScreen> createState() => _ApprovalScreenState();
}

class _ApprovalScreenState extends State<ApprovalScreen> {
  bool _isLoading = true;
  List<AppUser> _pendingUsers = [];

  @override
  void initState() {
    super.initState();
    _fetchPendingUsers();
  }

  Future<void> _fetchPendingUsers() async {
    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);
    _pendingUsers = await db.getPendingUsers();
    setState(() => _isLoading = false);
  }

  Future<void> _approveUser(AppUser user) async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    await db.approveUser(user.id);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${user.email} approved successfully!'),
        backgroundColor: AppColors.primaryGreen,
      ),
    );
    _fetchPendingUsers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Approvals'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _pendingUsers.isEmpty
              ? const Center(child: Text('No pending approval requests.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _pendingUsers.length,
                  itemBuilder: (context, index) {
                    final user = _pendingUsers[index];
                    return Card(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.orangeAccent,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(user.email, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text(
                          user.requestedRole != null 
                            ? 'Requested Role: ${user.requestedRole}' 
                            : 'Status: Pending Approval',
                          style: TextStyle(
                            color: user.requestedRole != null ? Colors.orange : Colors.grey,
                            fontWeight: user.requestedRole != null ? FontWeight.w600 : FontWeight.normal,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () {
                                final db = Provider.of<DatabaseService>(context, listen: false);
                                db.rejectUser(user.id);
                                _fetchPendingUsers();
                              },
                            ),
                            ElevatedButton(
                          onPressed: () => _approveUser(user),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primaryGreen,
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
