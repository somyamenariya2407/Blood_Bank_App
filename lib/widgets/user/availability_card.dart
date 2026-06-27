import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AvailabilityCard extends StatelessWidget {
  const AvailabilityCard({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const SizedBox();
        }

        final data = snapshot.data!.data() as Map;
        bool isAvailable = data['isAvailable'] ?? true;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.black,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [

              // 🔴 TEXT PART
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text(
                      "Available to Donate",
                      style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16),
                    ),
                    SizedBox(height: 5),
                    Text(
                      "You’ll receive SOS alerts",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),

              // 🔘 SWITCH
              Switch(
                value: isAvailable,
                activeThumbColor: Colors.red,
                onChanged: (value) async {
                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({
                    'isAvailable': value,
                  });
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
