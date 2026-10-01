import '../models/inventory/raw_material.dart';
import '../models/inventory/purchase_entry.dart';
import '../models/inventory/raw_material_inventory.dart';
import '../models/inventory/material_issue.dart';

/// Core Inventory Repository Interface
abstract class InventoryRepository {
  /// Fetches all active raw materials
  Future<List<RawMaterial>> getActiveRawMaterials();

  /// Adds a new purchase entry and updates the RawMaterialInventory automatically
  Future<void> createPurchaseEntry(PurchaseEntry entry);

  /// Issues material to manufacturing and deducts from inventory using FIFO or Batch logic
  Future<void> issueMaterialToManufacturing(MaterialIssue issue);

  /// Returns a list of materials where available stock is <= minimum stock level
  Future<List<RawMaterialInventory>> getLowStockAlerts();

  /// Calculates and returns the yield percentage for a given manufacturing batch ID
  Future<double> calculateBatchYield(String batchId);
  
  /// Fetches the inventory ledger for a specific raw material
  Future<List<RawMaterialInventory>> getInventoryForMaterial(String rawMaterialId);
}
