import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../models/inventory/raw_material.dart';
import '../models/inventory/purchase_entry.dart';
import '../models/inventory/raw_material_inventory.dart';
import '../models/inventory/material_issue.dart';
import '../repositories/inventory_repository.dart';
import '../exceptions/insufficient_stock_exception.dart';

class MockInventoryService implements InventoryRepository {
  // In-memory data store
  final List<RawMaterialInventory> _inventoryLedger = [];
  final List<MaterialIssue> _issues = [];
  final _uuid = const Uuid();

  @override
  Future<List<RawMaterial>> getActiveRawMaterials() async {
    // Return mock data for the dropdowns
    return [
      RawMaterial(id: 'rm-001', name: 'Turmeric', category: 'Core Spice', unit: 'kg', minimumStockLevel: 50.0),
      RawMaterial(id: 'rm-002', name: 'Black Pepper', category: 'Core Spice', unit: 'kg', minimumStockLevel: 20.0),
      RawMaterial(id: 'rm-003', name: 'Red Chilli', category: 'Core Spice', unit: 'kg', minimumStockLevel: 100.0),
    ];
  }

  // Feature 1: Load Stock (Inward)
  Future<void> loadStock(String rawMaterialId, String batchNumber, double quantity, String storageLocation) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    final existingIndex = _inventoryLedger.indexWhere(
        (item) => item.rawMaterialId == rawMaterialId && item.batchNumber == batchNumber);

    if (existingIndex != -1) {
      // Update existing
      final existing = _inventoryLedger[existingIndex];
      _inventoryLedger[existingIndex] = existing.copyWith(
        purchasedQuantity: existing.purchasedQuantity + quantity,
        availableStock: existing.availableStock + quantity,
      );
    } else {
      // Create new
      _inventoryLedger.add(
        RawMaterialInventory(
          id: _uuid.v4(),
          rawMaterialId: rawMaterialId,
          batchNumber: batchNumber,
          openingStock: 0,
          purchasedQuantity: quantity,
          issuedQuantity: 0,
          availableStock: quantity,
          storageLocation: storageLocation,
        ),
      );
    }
  }

  // Feature 2: Material Issue & Inventory Deduction (Outward)
  Future<void> issueMaterialForManufacturing(String targetProductId, List<IngredientIssueItem> ingredients) async {
    // Simulate network delay
    await Future.delayed(const Duration(milliseconds: 500));

    // 1. Validation Phase (All or nothing)
    for (var ingredient in ingredients) {
      final ledgerItem = _inventoryLedger.firstWhere(
        (item) => item.rawMaterialId == ingredient.rawMaterialId && item.batchNumber == ingredient.batchNumber,
        orElse: () => throw InsufficientStockException(
            'Batch ${ingredient.batchNumber} for material ${ingredient.rawMaterialId} not found in inventory.'),
      );

      if (ledgerItem.availableStock < ingredient.issueQuantity) {
        throw InsufficientStockException(
            'Insufficient stock for batch ${ingredient.batchNumber}. Available: ${ledgerItem.availableStock}, Required: ${ingredient.issueQuantity}');
      }
    }

    // 2. Deduction Phase (Transactional)
    for (var ingredient in ingredients) {
      final existingIndex = _inventoryLedger.indexWhere(
          (item) => item.rawMaterialId == ingredient.rawMaterialId && item.batchNumber == ingredient.batchNumber);
      
      final existing = _inventoryLedger[existingIndex];
      _inventoryLedger[existingIndex] = existing.copyWith(
        issuedQuantity: existing.issuedQuantity + ingredient.issueQuantity,
        availableStock: existing.availableStock - ingredient.issueQuantity,
      );
    }

    // 3. Log the issue
    final materialIssue = MaterialIssue(
      id: _uuid.v4(),
      productId: targetProductId,
      ingredientsIssued: ingredients,
      dateIssued: DateTime.now(),
      issuedByUserId: 'current_user',
    );
    
    _issues.add(materialIssue);
  }

  // Implementing remaining InventoryRepository methods with stubs
  @override
  Future<void> createPurchaseEntry(PurchaseEntry entry) async {
    await loadStock(entry.rawMaterialId, entry.batchNumber, entry.quantity, entry.storageLocation);
  }

  @override
  Future<void> issueMaterialToManufacturing(MaterialIssue issue) async {
    await issueMaterialForManufacturing(issue.productId, issue.ingredientsIssued);
  }

  @override
  Future<List<RawMaterialInventory>> getLowStockAlerts() async {
    // Simplified stub
    return _inventoryLedger.where((item) => item.availableStock < 10).toList();
  }

  @override
  Future<double> calculateBatchYield(String batchId) async => 95.0;

  @override
  Future<List<RawMaterialInventory>> getInventoryForMaterial(String rawMaterialId) async {
    return _inventoryLedger.where((item) => item.rawMaterialId == rawMaterialId).toList();
  }
}
