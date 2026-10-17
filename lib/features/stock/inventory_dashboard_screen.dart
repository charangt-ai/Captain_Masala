import 'package:flutter/material.dart';
import 'raw_material_stock_screen.dart';
import '../production/production_plan_list_screen.dart';
import '../production/material_issue_screen.dart';
import '../production/quality_control_screen.dart';
import '../production/finished_goods_screen.dart';
import '../production/batch_costing_screen.dart';
import '../production/recipe_product_selector_screen.dart';
import '../admin/manufacturing_process_screen.dart';
import '../production/stock_approval_screen.dart';
class InventoryDashboardScreen extends StatelessWidget {
  const InventoryDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text('Manufacturing & Inventory Hub'),
        backgroundColor: Colors.red[800],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
        children: [
          // STAGE 1: PROCUREMENT & MASTER DATA
          _buildStageHeader(
            '1. Procurement & Formulations',
            'Raw materials stock, vendor suppliers & master spice recipes',
            Icons.inventory_outlined,
            Colors.teal,
          ),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              _buildModernCard(
                context,
                title: 'Raw Material Stock',
                subtitle: 'Warehouse inventory',
                icon: Icons.category,
                accentColor: Colors.orange.shade800,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RawMaterialStockScreen()));
                },
              ),
              _buildModernCard(
                context,
                title: 'Master Recipes',
                subtitle: 'Formulations & BOM',
                icon: Icons.menu_book,
                accentColor: Colors.teal.shade700,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const RecipeProductSelectorScreen()));
                },
              ),
              _buildModernCard(
                context,
                title: 'Purchase Entry',
                subtitle: 'Inward lot arrivals',
                icon: Icons.add_shopping_cart,
                accentColor: Colors.green.shade700,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Purchase Inward Entry module is opening...')),
                  );
                },
              ),
              _buildModernCard(
                context,
                title: 'Suppliers',
                subtitle: 'Vendor directory & GST',
                icon: Icons.local_shipping,
                accentColor: Colors.blue.shade700,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Supplier Management module is opening...')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // STAGE 2: FACTORY SHOP FLOOR & PROCESSING
          _buildStageHeader(
            '2. Factory Production Floor',
            'Shift schedules, spice milling & processing yield losses',
            Icons.precision_manufacturing_outlined,
            Colors.purple,
          ),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              _buildModernCard(
                context,
                title: 'Production Planning',
                subtitle: 'Daily batches schedule',
                icon: Icons.calendar_month,
                accentColor: Colors.purple.shade700,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProductionPlanListScreen()));
                },
              ),
              _buildModernCard(
                context,
                title: 'Material Issue',
                subtitle: 'Outward to milling unit',
                icon: Icons.outbox,
                accentColor: Colors.deepPurple.shade700,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const MaterialIssueScreen()));
                },
              ),
              _buildModernCard(
                context,
                title: 'Manufacturing Yield',
                subtitle: 'Roasting & grinding logs',
                icon: Icons.factory,
                accentColor: Colors.blueGrey.shade800,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ManufacturingProcessScreen()));
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // STAGE 3: QUALITY CONTROL & PACKAGING ALLOCATION
          _buildStageHeader(
            '3. Quality, Bulk & Packaging',
            'Laboratory checks, bulk storage & packaging allocation',
            Icons.verified_outlined,
            Colors.indigo,
          ),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              _buildModernCard(
                context,
                title: 'Quality Control',
                subtitle: 'QC lab approvals',
                icon: Icons.verified,
                accentColor: Colors.amber.shade900,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const QualityControlScreen()));
                },
              ),
              _buildModernCard(
                context,
                title: 'Finished Goods',
                subtitle: 'Bulk powder batches',
                icon: Icons.inventory_2,
                accentColor: Colors.indigo.shade700,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const FinishedGoodsScreen()));
                },
              ),
              _buildModernCard(
                context,
                title: 'Stock Approvals',
                subtitle: 'Retail packaging sign-off',
                icon: Icons.gavel,
                accentColor: Colors.redAccent.shade700,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const StockApprovalScreen()));
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // STAGE 4: FINANCIAL AUDITING & COSTING
          _buildStageHeader(
            '4. Financial & Margin Analysis',
            'Executive per-kg batch costing & profitability',
            Icons.analytics_outlined,
            Colors.brown,
          ),
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.15,
            children: [
              _buildModernCard(
                context,
                title: 'Batch Costing',
                subtitle: 'Per-KG cost & margins',
                icon: Icons.request_quote,
                accentColor: Colors.brown.shade800,
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => const BatchCostingScreen()));
                },
              ),
            ],
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildStageHeader(String title, String subtitle, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color accentColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Card(
        elevation: 1.5,
        shadowColor: Colors.black12,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 26, color: accentColor),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
