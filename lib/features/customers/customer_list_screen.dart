import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../core/models/customer.dart';
import '../../core/services/database_service.dart';
import '../../core/theme.dart';
import 'customer_detail_screen.dart';
import 'customer_form_dialog.dart';

class CustomerListScreen extends StatefulWidget {
  final bool isEmbedded;

  const CustomerListScreen({Key? key, this.isEmbedded = false}) : super(key: key);

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  String _searchQuery = '';
  String _selectedDistrict = 'All';

  final List<String> _districts = [
    'All',
    'Salem',
    'Namakkal',
    'Dharmapuri',
    'Krishnagiri',
    'Erode',
    'Coimbatore'
  ];

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);

    final filteredCustomers = db.customers.where((c) {
      final matchesSearch = c.shopName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.ownerName.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          c.mobileNumber.contains(_searchQuery);
      
      final matchesDistrict = _selectedDistrict == 'All' || c.district == _selectedDistrict;

      return matchesSearch && matchesDistrict;
    }).toList();

    Widget listBody = Column(
      children: [
        // Total customers summary
        Card(
          color: AppColors.primaryRed.withOpacity(0.05),
          elevation: 0,
          margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: AppColors.primaryRed.withOpacity(0.2)),
          ),
          child: ListTile(
            leading: const Icon(Icons.people, color: AppColors.primaryRed, size: 32),
            title: const Text('Total Customers', style: TextStyle(fontWeight: FontWeight.bold)),
            trailing: Text('${db.customers.length}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 24, color: AppColors.primaryRed)),
          ),
        ),
        // Search & Filter header
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'Search customer, owner, mobile...',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (val) => setState(() => _searchQuery = val),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Text('Filter District:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: SizedBox(
                      height: 40,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _districts.length,
                        itemBuilder: (ctx, idx) {
                          final district = _districts[idx];
                          final isSelected = _selectedDistrict == district;
                          return Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: ChoiceChip(
                              label: Text(district, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
                              selected: isSelected,
                              selectedColor: AppColors.primaryRed,
                              checkmarkColor: Colors.white,
                              onSelected: (selected) {
                                if (selected) {
                                  setState(() {
                                    _selectedDistrict = district;
                                  });
                                }
                              },
                            ),
                          );
                        },
                      ),
                    ),
                  )
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: filteredCustomers.isEmpty
              ? const Center(child: Text('No matching customers found.'))
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  itemCount: filteredCustomers.length,
                  itemBuilder: (ctx, idx) {
                    final c = filteredCustomers[idx];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryGreen.withOpacity(0.1),
                          backgroundImage: c.shopImageUrl.isNotEmpty 
                              ? (c.shopImageUrl.startsWith('http') 
                                  ? NetworkImage(c.shopImageUrl) 
                                  : FileImage(File(c.shopImageUrl))) as ImageProvider
                              : null,
                          child: c.shopImageUrl.isEmpty ? const Icon(Icons.storefront, color: AppColors.primaryGreen) : null,
                        ),
                        title: Text(c.shopName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${c.ownerName} • ${c.city}, ${c.district}'),
                        trailing: const Icon(Icons.chevron_right, color: AppColors.primaryRed),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => CustomerDetailScreen(customer: c)),
                          );
                        },
                      ),
                    );
                  },
                ),
        )
      ],
    );

    if (widget.isEmbedded) {
      return Scaffold(
        body: listBody,
        floatingActionButton: FloatingActionButton(
          onPressed: () => showCustomerFormDialog(context),
          backgroundColor: AppColors.primaryRed,
          foregroundColor: Colors.white,
          child: const Icon(Icons.person_add),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Customer Directory'),
      ),
      body: listBody,
      floatingActionButton: FloatingActionButton(
        onPressed: () => showCustomerFormDialog(context),
        backgroundColor: AppColors.primaryRed,
        foregroundColor: Colors.white,
        child: const Icon(Icons.person_add),
      ),
    );
  }
}
