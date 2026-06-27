import 'package:flutter/material.dart';
import '../../constants/blood_types.dart';
import 'blood_card.dart';

class InventoryGrid extends StatelessWidget {
  final Map inventory;

  const InventoryGrid({super.key, required this.inventory});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      itemCount: bloodTypes.length,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.9,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) {
        final type = bloodTypes[index];
        final units = inventory[type] ?? 0;

        return BloodCard(
          type: type,
          units: units,
        );
      },
    );
  }
}