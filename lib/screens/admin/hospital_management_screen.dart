import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/account_moderation_service.dart';
import '../../services/firestore_service.dart';
import 'hospital_detail_screen.dart';

class HospitalManagementScreen extends StatefulWidget {
  const HospitalManagementScreen({super.key});

  @override
  State<HospitalManagementScreen> createState() =>
      _HospitalManagementScreenState();
}

class _HospitalManagementScreenState
    extends State<HospitalManagementScreen> {
  final FirestoreService _service = FirestoreService();

  bool showVerified = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,

      appBar: AppBar(
        title: const Text("Hospital Management"),
      ),

      body: Column(
        children: [

          /////////////////////////////////////////////
          // 🔥 TOGGLE
          /////////////////////////////////////////////
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: toggleBtn("Pending", false)),
                const SizedBox(width: 10),
                Expanded(child: toggleBtn("Verified", true)),
              ],
            ),
          ),

          /////////////////////////////////////////////
          // 🔥 LIST
          /////////////////////////////////////////////
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('hospitals')
                  .snapshots(),
              builder: (context, snapshot) {

                if (snapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(
                      child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("No hospitals found 😕"),
                  );
                }

                var hospitals = snapshot.data!.docs;

                /// 🔥 FILTER (MAIN FIX)
                hospitals = hospitals.where((doc) {
                  final data =
                      doc.data() as Map<String, dynamic>? ?? {};

                  final role = data['role'] ?? 'hospital';
                  final isVerified = data['isVerified'] ?? false;
                  final status =
                      AccountModerationService.normalizeStatus(data['status']);

                  if (role != 'hospital') return false;
                  if (status == AccountModerationService.rejectedStatus) {
                    return false;
                  }

                  return showVerified ? isVerified : !isVerified;
                }).toList();

                if (hospitals.isEmpty) {
                  return Center(
                    child: Text(
                      showVerified
                          ? "No verified hospitals yet"
                          : "No pending requests",
                    ),
                  );
                }

                return ListView.builder(
                  itemCount: hospitals.length,
                  itemBuilder: (context, index) {

                    final hospital = hospitals[index];
                    final data =
                        hospital.data() as Map<String, dynamic>? ?? {};

                    final name = data['hospitalName']
                        ?? data['name']
                        ?? "Unknown Hospital";

                    final email =
                        data['email'] ?? "No email";

                    final isVerified =
                        data['isVerified'] ?? false;
                    final status =
                        AccountModerationService.normalizeStatus(data['status']);

                    final docCount = _service.parseHospitalDocuments(data).length;

                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black12,
                              blurRadius: 6)
                        ],
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.local_hospital,
                              color: Colors.red, size: 30),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment:
                                  CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  email,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Documents: $docCount",
                                  style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: status ==
                                          AccountModerationService
                                              .suspendedStatus
                                      ? Colors.orange.withValues(alpha: 0.2)
                                      : isVerified
                                          ? Colors.green.withValues(alpha: 0.2)
                                          : Colors.orange.withValues(alpha: 0.2),
                                  borderRadius:
                                      BorderRadius.circular(20),
                                ),
                                child: Text(
                                  status == AccountModerationService.suspendedStatus
                                      ? "Suspended"
                                      : isVerified
                                          ? "Verified"
                                          : "Pending",
                                  style: TextStyle(
                                    color: status ==
                                            AccountModerationService
                                                .suspendedStatus
                                        ? Colors.orange
                                        : isVerified
                                            ? Colors.green
                                            : Colors.orange,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 6),
                              IconButton(
                                constraints: const BoxConstraints(),
                                padding: EdgeInsets.zero,
                                icon: const Icon(Icons.visibility),
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          HospitalDetailScreen(
                                            hospitalId:
                                                hospital.id,
                                          ),
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /////////////////////////////////////////////
  // 🔥 TOGGLE BUTTON
  /////////////////////////////////////////////
  Widget toggleBtn(String text, bool value) {
    return GestureDetector(
      onTap: () {
        setState(() {
          showVerified = value;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: showVerified == value
              ? Colors.red
              : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.red),
        ),
        child: Center(
          child: Text(
            text,
            style: TextStyle(
              color: showVerified == value
                  ? Colors.white
                  : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}
