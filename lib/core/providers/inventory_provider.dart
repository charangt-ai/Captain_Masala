import 'package:flutter/material.dart';
import '../models/inventory/raw_material.dart';
import '../models/inventory/purchase_entry.dart';
import '../models/inventory/raw_material_inventory.dart';
import '../models/inventory/material_issue.dart';
import '../repositories/inventory_repository.dart';

class InventoryProvider with ChangeNotifier {
  final InventoryRepository _repository;

  InventoryProvider(this._repository);

  List<RawMaterial> _rawMaterials = [];
  List<RawMaterialInventory> _lowStockAlerts = [];
  bool _isLoading = false;
  String? _errorMessage;

  List<RawMaterial> get rawMaterials => _rawMaterials;
  List<RawMaterialInventory> get lowStockAlerts => _lowStockAlerts;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> fetchActiveRawMaterials() async {
    _setLoading(true);
    try {
      _rawMaterials = await _repository.getActiveRawMaterials();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> fetchLowStockAlerts() async {
    _setLoading(true);
    try {
      _lowStockAlerts = await _repository.getLowStockAlerts();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  Future<void> createPurchase(PurchaseEntry entry) async {
    _setLoading(true);
    try {
      await _repository.createPurchaseEntry(entry);
      // Refresh alerts after purchase
      await fetchLowStockAlerts();
      _errorMessage = null;
    } catch (e) {
      _errorMessage = e.toString();
    }
    _setLoading(false);
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }
}
