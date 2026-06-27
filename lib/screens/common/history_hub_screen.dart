import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'completed_requests_screen.dart';
import 'donation_history_screen.dart';
import '../../widgets/common/app_header_title.dart';

class HistoryHubScreen extends StatefulWidget {
  final String title;
  final String requesterId;
  final String requestOwnerKey;
  final String donorId;
  final String donorName;
  final bool showCertificate;

  const HistoryHubScreen({
    super.key,
    required this.title,
    required this.requesterId,
    required this.requestOwnerKey,
    required this.donorId,
    required this.donorName,
    this.showCertificate = false,
  });

  @override
  State<HistoryHubScreen> createState() => _HistoryHubScreenState();
}

class _HistoryHubScreenState extends State<HistoryHubScreen> {
  int selectedTab = 0;

  String formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '-';
    final date = value.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<String> _loadDonorName() async {
    if (widget.donorName.trim().isNotEmpty &&
        widget.donorName != 'User' &&
        widget.donorName != 'Hospital') {
      return widget.donorName;
    }

    final userDoc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.donorId)
        .get();
    final userData = userDoc.data();
    final userName = userData?['name']?.toString().trim();
    if (userName != null && userName.isNotEmpty) {
      return userName;
    }

    final hospitalDoc = await FirebaseFirestore.instance
        .collection('hospitals')
        .doc(widget.donorId)
        .get();
    final hospitalData = hospitalDoc.data();
    final hospitalName = hospitalData?['hospitalName']?.toString().trim();
    if (hospitalName != null && hospitalName.isNotEmpty) {
      return hospitalName;
    }

    return widget.donorName;
  }

  Widget _tabButton(String label, int index, IconData icon) {
    final isSelected = selectedTab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFB71C1C) : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? const Color(0xFFB71C1C) : Colors.black12,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? Colors.white : Colors.black87,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isSelected ? Colors.white : Colors.black87,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        title: AppHeaderTitle(title: widget.title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                _tabButton('Completed Requests', 0, Icons.task_alt),
                const SizedBox(width: 10),
                _tabButton('Expired Requests', 1, Icons.timer_off_outlined),
                const SizedBox(width: 10),
                _tabButton('Donation History', 2, Icons.volunteer_activism),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: selectedTab == 0
                    ? CompletedRequestsContent(
                        key: const ValueKey('completed'),
                        requesterId: widget.requesterId,
                        requestOwnerKey: widget.requestOwnerKey,
                        formatTimestamp: formatTimestamp,
                      )
                    : selectedTab == 1
                        ? ExpiredRequestsContent(
                            key: const ValueKey('expired'),
                            viewerId: widget.requesterId,
                            formatTimestamp: formatTimestamp,
                          )
                        : FutureBuilder<String>(
                            key: const ValueKey('donations'),
                            future: _loadDonorName(),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(),
                                );
                              }

                              return DonationHistoryContent(
                                donorId: widget.donorId,
                                donorName: snapshot.data ?? widget.donorName,
                                showCertificate: widget.showCertificate,
                                formatTimestamp: formatTimestamp,
                              );
                            },
                          ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
