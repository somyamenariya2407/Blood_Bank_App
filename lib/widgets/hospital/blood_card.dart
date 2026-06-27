import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../services/firestore_service.dart';
import '../../utils/inventory_utils.dart';

class BloodCard extends StatelessWidget {
  final String type;
  final int units;

  const BloodCard({super.key, required this.type, required this.units});

  @override
  Widget build(BuildContext context) {
    final status = getStatus(units);
    final color = getStatusColor(status);

    final uid = FirebaseAuth.instance.currentUser!.uid;
    final service = FirestoreService();

    // 🔥 fake max for UI (later dynamic)
    int maxUnits = 100;
    double progress = units / maxUnits;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // 🔥 TOP STRIP (STATUS)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18)),
            ),
            child: Center(
              child: Text(
                status,
                style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                    fontSize: 12),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // 🔥 BLOOD TYPE
                Row(
                  children: [
                    Icon(
                      Icons.bloodtype,
                      color: color,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      type,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 8),

                // 🔥 UNITS
                Text(
                  "$units / $maxUnits",
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 8),

                // 🔥 PROGRESS BAR
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress > 1 ? 1 : progress,
                    minHeight: 6,
                    backgroundColor: Colors.grey[300],
                    color: color,
                  ),
                ),

                const SizedBox(height: 10),

                // 🔥 BUTTONS
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _circleButton(
                      icon: Icons.remove,
                      color: Colors.red,
                      onTap: () {
                        if (units > 0) {
                          service.updateBloodUnit(uid, type, units - 1);
                        }
                      },
                    ),
                    _circleButton(
                      icon: Icons.add,
                      color: Colors.green,
                      onTap: () {
                        service.updateBloodUnit(uid, type, units + 1);
                      },
                    ),
                  ],
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _circleButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 34,
        width: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color, size: 18),
      ),
    );
  }
}
