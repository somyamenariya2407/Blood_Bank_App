import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../services/account_moderation_service.dart';

class UserManagementScreen extends StatelessWidget {
  const UserManagementScreen({super.key});

  /// 🔴 Suspend User
  Future<void> suspendUser(String id) async {
    await AccountModerationService().setUserStatus(
      uid: id,
      status: AccountModerationService.suspendedStatus,
    );
  }

  /// 🟢 Activate User
  Future<void> activateUser(String id) async {
    await AccountModerationService().setUserStatus(
      uid: id,
      status: AccountModerationService.activeStatus,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text("User Management"),
      ),

      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .where('role', isEqualTo: 'user')
            .snapshots(),
        builder: (context, snapshot) {

          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          var users = snapshot.data!.docs;

          if (users.isEmpty) {
            return const Center(child: Text("No users found"));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              var user = users[index];
              var data = user.data() as Map<String, dynamic>;

              String status =
                  AccountModerationService.normalizeStatus(data['status']);

              return Card(
                margin: const EdgeInsets.all(10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
                child: ListTile(
                  title: Text(data['name'] ?? "No Name"),
                  subtitle: Text(data['email'] ?? ""),

                  /// 🔹 STATUS BADGE
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      Chip(
                        label: Text(status),
                        backgroundColor: status == 'active'
                            ? Colors.green.shade100
                            : Colors.red.shade100,
                      ),

                      const SizedBox(width: 10),

                      /// 🔹 ACTION BUTTON
                      ElevatedButton(
                        onPressed: () async {
                          if (status == 'active') {
                            await suspendUser(user.id);
                          } else {
                            await activateUser(user.id);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: status == 'active'
                              ? Colors.red
                              : Colors.green,
                        ),
                        child: Text(
                          status == 'active' ? "Suspend" : "Activate",
                        ),
                      )
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
