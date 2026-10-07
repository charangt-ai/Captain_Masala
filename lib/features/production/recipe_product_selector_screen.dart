import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/database_service.dart';
import 'manage_recipes_screen.dart';

class RecipeProductSelectorScreen extends StatelessWidget {
  const RecipeProductSelectorScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context);
    final masterProducts = db.masterProducts;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Product for Recipe'),
        backgroundColor: Colors.teal[800],
      ),
      body: ListView.builder(
        itemCount: masterProducts.length,
        itemBuilder: (ctx, i) {
          final p = masterProducts[i];
          return ListTile(
            title: Text(p.name),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ManageRecipesScreen(product: p),
              ));
            },
          );
        },
      ),
    );
  }
}
