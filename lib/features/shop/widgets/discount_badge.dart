import 'package:flutter/material.dart';

class DiscountBadge extends StatelessWidget {
  final String discountText;
  
  const DiscountBadge({Key? key, required this.discountText}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFD84315), // Same as outOfStockAlert / Red from theme
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        discountText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
