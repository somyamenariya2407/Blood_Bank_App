import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../widgets/common/app_header_title.dart';
import '../../widgets/hospital/inventory_grid.dart';
import '../../widgets/hospital/stats_card.dart';

class InventoryScreen extends StatelessWidget {
  final FirestoreService service = FirestoreService();

  InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[100],

      // 🔥 HEADER
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        titleSpacing: 16,
        title: StreamBuilder(
          stream: service.getHospitalData(uid),
          builder: (context, snapshot) {
            final isVerified = snapshot.data?['isVerified'] == true;

            return Row(
              children: [
                const Expanded(
                  child: AppHeaderTitle(
                    title: 'Blood Inventory',
                    subtitle: 'Hospital Portal',
                  ),
                ),
                if (isVerified)
                  Container(
                    margin: const EdgeInsets.only(left: 10),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 16),
                        SizedBox(width: 4),
                        Text(
                          "Verified",
                          style: TextStyle(color: Colors.green, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
        actions: const [],
      ),

      // 🔥 BODY
      body: StreamBuilder(
        stream: service.getHospitalData(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!;
          final inventory = data['inventory'] ?? {};

          int total = 0;
          int critical = 0;
          int expiring = 0; // 🔥 future use

          inventory.forEach((key, value) {
            int units = value ?? 0;
            total += units;

            if (units <= 5) critical++;

            // 🔥 placeholder for expiry logic later
            if (units > 0 && units <= 10) {
              expiring++;
            }
          });

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                // 🔴 STATS CARDS (3 CARDS NOW)
                Row(
                  children: [
                    Expanded(
                      child: StatsCard(
                        title: "Total",
                        value: total,
                        color: Colors.red,
                        icon: Icons.bloodtype,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatsCard(
                        title: "Critical",
                        value: critical,
                        color: Colors.orange,
                        icon: Icons.warning,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: StatsCard(
                        title: "Expiring",
                        value: expiring,
                        color: Colors.amber,
                        icon: Icons.timer,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                // 🔄 SYNC BUTTON (CORRECT POSITION)
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // 🔥 later refresh / re-fetch logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Synced")),
                      );
                    },
                    icon: const Icon(Icons.sync, size: 16),
                    label: const Text("Sync"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey[200],
                      foregroundColor: Colors.black,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // 🔴 INVENTORY GRID
                InventoryGrid(inventory: inventory),

              ],
            ),
          );
        },
      ),
    );
  }
}
