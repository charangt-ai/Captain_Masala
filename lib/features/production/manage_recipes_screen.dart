import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import '../../core/models/master_product.dart';
import '../../core/models/inventory/raw_material.dart';
import '../../core/models/recipe.dart';

class ManageRecipesScreen extends StatefulWidget {
  final MasterProduct product;

  const ManageRecipesScreen({Key? key, required this.product}) : super(key: key);

  @override
  State<ManageRecipesScreen> createState() => _ManageRecipesScreenState();
}

class _ManageRecipesScreenState extends State<ManageRecipesScreen> {
  bool _isLoading = true;
  Recipe? _currentRecipe;
  final TextEditingController _batchSizeController = TextEditingController(text: "100");
  
  List<RecipeIngredient> _ingredients = [];
  
  @override
  void initState() {
    super.initState();
    _loadRecipe();
  }

  Future<void> _loadRecipe() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final recipeData = await db.fetchRecipe(widget.product.id);
    
    if (mounted) {
      if (recipeData != null) {
        setState(() {
          _currentRecipe = Recipe.fromJson(recipeData);
          _batchSizeController.text = _currentRecipe!.baseBatchSize.toString();
          _ingredients = List.from(_currentRecipe!.ingredients);
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _addIngredient(RawMaterial rm) {
    if (_ingredients.any((i) => i.rawMaterialId == rm.id)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Material already added to recipe.')),
      );
      return;
    }

    setState(() {
      _ingredients.add(RecipeIngredient(
        rawMaterialId: rm.id,
        rawMaterialName: rm.name,
        requiredQuantity: 0,
      ));
    });
  }

  void _updateQuantity(int index, String val) {
    final qty = double.tryParse(val) ?? 0.0;
    setState(() {
      _ingredients[index] = RecipeIngredient(
        rawMaterialId: _ingredients[index].rawMaterialId,
        rawMaterialName: _ingredients[index].rawMaterialName,
        requiredQuantity: qty,
      );
    });
  }

  Future<void> _saveRecipe() async {
    if (_ingredients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Add at least one ingredient')));
      return;
    }
    
    final batchSize = double.tryParse(_batchSizeController.text) ?? 0;
    if (batchSize <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid batch size')));
      return;
    }

    setState(() => _isLoading = true);
    final db = Provider.of<DatabaseService>(context, listen: false);

    final recipeData = {
      'productId': widget.product.id,
      'baseBatchSize': batchSize,
      'type': 'MULTI_INGREDIENT',
      'ingredients': _ingredients.map((i) => i.toJson()).toList(),
    };

    final success = await db.saveRecipe(recipeData);
    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Recipe saved successfully!')));
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to save recipe.')));
      }
    }
  }

  void _showAddMaterialDialog() {
    final db = Provider.of<DatabaseService>(context, listen: false);
    final materials = db.rawMaterials;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Select Raw Material'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: materials.length,
            itemBuilder: (ctx, idx) {
              final rm = materials[idx];
              return ListTile(
                title: Text(rm.name),
                subtitle: Text('In Stock: ${rm.currentStock} kg'),
                onTap: () {
                  Navigator.pop(ctx);
                  _addIngredient(rm);
                },
              );
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Recipe: ${widget.product.name}'),
        backgroundColor: Colors.teal[800],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _batchSizeController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Base Batch Size (kg)',
                      border: OutlineInputBorder(),
                      helperText: 'Standard production output for this recipe',
                    ),
                  ),
                  const SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Ingredients (Bill of Materials)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add),
                        label: const Text('Add Material'),
                        onPressed: _showAddMaterialDialog,
                      )
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: _ingredients.isEmpty
                        ? const Center(child: Text('No ingredients added yet.'))
                        : ListView.builder(
                            itemCount: _ingredients.length,
                            itemBuilder: (ctx, i) {
                              final item = _ingredients[i];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(item.rawMaterialName, style: const TextStyle(fontWeight: FontWeight.bold))),
                                      Expanded(
                                        flex: 1,
                                        child: TextFormField(
                                          initialValue: item.requiredQuantity > 0 ? item.requiredQuantity.toString() : '',
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                          decoration: const InputDecoration(
                                            labelText: 'Qty (kg)',
                                            isDense: true,
                                          ),
                                          onChanged: (val) => _updateQuantity(i, val),
                                        ),
                                      ),
                                      IconButton(
                                        icon: const Icon(Icons.delete, color: Colors.red),
                                        onPressed: () {
                                          setState(() => _ingredients.removeAt(i));
                                        },
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _saveRecipe,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.teal[800]),
                      child: const Text('Save Recipe', style: TextStyle(fontSize: 16, color: Colors.white)),
                    ),
                  )
                ],
              ),
            ),
    );
  }
}
