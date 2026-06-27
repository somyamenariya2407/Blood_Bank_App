import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../utils/name_resolver.dart';
import '../../utils/sos_request_time.dart';
import '../../widgets/common/app_header_title.dart';

class CompletedRequestsScreen extends StatelessWidget {
  final String title;
  final String requesterId;
  final String requestOwnerKey;

  const CompletedRequestsScreen({
    super.key,
    required this.title,
    required this.requesterId,
    required this.requestOwnerKey,
  });

  String formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '-';
    final date = value.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xffF5F5F5),
      appBar: AppBar(
        title: AppHeaderTitle(title: title),
      ),
      body: CompletedRequestsContent(
        requesterId: requesterId,
        requestOwnerKey: requestOwnerKey,
        formatTimestamp: formatTimestamp,
      ),
    );
  }
}

class CompletedRequestsContent extends StatelessWidget {
  final String requesterId;
  final String requestOwnerKey;
  final String Function(dynamic value) formatTimestamp;

  const CompletedRequestsContent({
    super.key,
    required this.requesterId,
    required this.requestOwnerKey,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sos_requests').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['status'] == 'completed' &&
              data[requestOwnerKey]?.toString() == requesterId;
        }).toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp =
                (aData['fulfilledAt'] ?? aData['createdAt']) as Timestamp?;
            final bTimestamp =
                (bData['fulfilledAt'] ?? bData['createdAt']) as Timestamp?;
            return (bTimestamp?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTimestamp?.millisecondsSinceEpoch ?? 0);
          });

        if (docs.isEmpty) {
          return const Center(child: Text('No completed requests'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final completedById =
                data['fulfilledBy']?.toString() ?? data['donatedBy']?.toString();
            final savedName = data['fulfilledByName']?.toString().trim() ?? '';

            return FutureBuilder<String>(
              future: savedName.isNotEmpty
                  ? Future.value(savedName)
                  : NameResolver.userOrHospitalName(completedById),
              builder: (context, snap) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.shade50,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Text(
                              'Completed',
                              style: TextStyle(
                                color: Colors.green,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${data['bloodType'] ?? 'N/A'} - ${data['units'] ?? 0} units',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Priority: ${data['priority'] ?? 'medium'}'),
                      Text('Requester: ${data['name'] ?? 'Unknown'}'),
                      Text('Donated by: ${snap.data ?? 'Loading...'}'),
                      Text(
                        'Completed on: ${formatTimestamp(data['fulfilledAt'])}',
                      ),
                    ],
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}

class ExpiredRequestsContent extends StatelessWidget {
  final String viewerId;
  final String Function(dynamic value) formatTimestamp;

  const ExpiredRequestsContent({
    super.key,
    required this.viewerId,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance.collection('sos_requests').snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status'] ?? '').toString().toLowerCase();
          return status != 'completed' && isSosExpired(data);
        }).toList()
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp =
                (aData['requiredByAt'] ?? aData['createdAt']) as Timestamp?;
            final bTimestamp =
                (bData['requiredByAt'] ?? bData['createdAt']) as Timestamp?;
            return (bTimestamp?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTimestamp?.millisecondsSinceEpoch ?? 0);
          });

        if (docs.isEmpty) {
          return const Center(child: Text('No expired requests'));
        }

        return ListView(
          padding: const EdgeInsets.all(12),
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            final requesterId =
                (data['userId'] ?? data['hospitalId'] ?? '').toString();
            final isOwnRequest = requesterId == viewerId;
            final phone = (data['phone'] ?? '').toString().trim();
            final location = data['location'] as Map<String, dynamic>?;
            final lat = (location?['lat'] as num?)?.toDouble();
            final lng = (location?['lng'] as num?)?.toDouble();
            final requesterRole =
                (data['role'] ?? 'user').toString().toLowerCase();
            final requesterType =
                requesterRole == 'hospital' ? 'Hospital' : 'User';
            final requesterLabel = isOwnRequest
                ? 'My Request'
                : (data['name']?.toString().trim().isNotEmpty ?? false)
                    ? data['name'].toString().trim()
                    : requesterType;
            final accentColor = isOwnRequest
                ? const Color(0xFFB71C1C)
                : const Color(0xFF1565C0);
            final accentBackground = isOwnRequest
                ? const Color(0xFFFDECEC)
                : const Color(0xFFEAF3FF);
            final acceptedDonorId =
                data['acceptedDonorId']?.toString().trim() ?? '';
            final fulfilledById =
                data['fulfilledBy']?.toString().trim() ?? acceptedDonorId;
            final savedDonorName =
                data['acceptedDonorName']?.toString().trim().isNotEmpty == true
                    ? data['acceptedDonorName'].toString().trim()
                    : data['fulfilledByName']?.toString().trim() ?? '';

            return FutureBuilder<String>(
              future: fulfilledById.isEmpty
                  ? Future.value(savedDonorName)
                  : savedDonorName.isNotEmpty
                      ? Future.value(savedDonorName)
                      : NameResolver.userOrHospitalName(fulfilledById),
              builder: (context, donorSnap) {
                final donorName = donorSnap.data?.trim() ?? '';

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: accentBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: accentColor.withValues(alpha: 0.20)),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              isOwnRequest ? 'My Request' : 'Expired',
                              style: TextStyle(
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${data['bloodType'] ?? 'N/A'} - ${data['units'] ?? 0} units',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text('Priority: ${data['priority'] ?? 'medium'}'),
                      Text('Requester: $requesterLabel'),
                      if (!isOwnRequest) Text('Requester type: $requesterType'),
                      if (donorName.isNotEmpty) Text('Last donor: $donorName'),
                      Text(
                        'Expired on: ${formatTimestamp(data['requiredByAt'])}',
                      ),
                      if (!isOwnRequest && (phone.isNotEmpty || (lat != null && lng != null))) ...[
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            if (lat != null && lng != null)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final url =
                                        'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
                                    await launchUrl(
                                      Uri.parse(url),
                                      mode: LaunchMode.externalApplication,
                                    );
                                  },
                                  icon: const Icon(Icons.navigation_outlined),
                                  label: const Text('Navigate'),
                                ),
                              ),
                            if (lat != null && lng != null && phone.isNotEmpty)
                              const SizedBox(width: 10),
                            if (phone.isNotEmpty)
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    await launchUrl(Uri.parse('tel:$phone'));
                                  },
                                  icon: const Icon(Icons.call_outlined),
                                  label: const Text('Call'),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
          }).toList(),
        );
      },
    );
  }
}
