import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../services/certificate_download_service.dart';
import '../../utils/name_resolver.dart';
import '../../widgets/common/app_header_title.dart';
import '../../widgets/common/scrollable_data_table.dart';

class DonationHistoryScreen extends StatelessWidget {
  final String title;
  final String donorId;
  final String donorName;
  final bool showCertificate;

  const DonationHistoryScreen({
    super.key,
    required this.title,
    required this.donorId,
    required this.donorName,
    this.showCertificate = false,
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
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: DonationHistoryContent(
          donorId: donorId,
          donorName: donorName,
          showCertificate: showCertificate,
          formatTimestamp: formatTimestamp,
        ),
      ),
    );
  }
}

class DonationHistoryContent extends StatelessWidget {
  final String donorId;
  final String donorName;
  final bool showCertificate;
  final String Function(dynamic value) formatTimestamp;

  const DonationHistoryContent({
    super.key,
    required this.donorId,
    required this.donorName,
    required this.showCertificate,
    required this.formatTimestamp,
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .where('donorId', isEqualTo: donorId)
          .snapshots(),
      builder: (context, snap) {
        if (snap.hasError) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Unable to load donation history right now.',
                textAlign: TextAlign.center,
              ),
            ),
          );
        }

        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final docs = [...snap.data!.docs]
          ..sort((a, b) {
            final aData = a.data() as Map<String, dynamic>;
            final bData = b.data() as Map<String, dynamic>;
            final aTimestamp = aData['createdAt'] as Timestamp?;
            final bTimestamp = bData['createdAt'] as Timestamp?;
            return (bTimestamp?.millisecondsSinceEpoch ?? 0)
                .compareTo(aTimestamp?.millisecondsSinceEpoch ?? 0);
          });
        if (docs.isEmpty) {
          return const ScrollableDataTable(
            columns: ['Date', 'Recipient', 'Blood', 'Units'],
            rows: [],
            height: 420,
            emptyLabel: 'No donations yet',
          );
        }

        return FutureBuilder<List<List<Widget>>>(
          future: Future.wait(
            docs.map((doc) async {
              final d = doc.data() as Map<String, dynamic>;
              final receiverId = d['receiverId']?.toString();
              final savedReceiverName = d['receiverName']?.toString();
              final receiverName = savedReceiverName != null &&
                      savedReceiverName.trim().isNotEmpty
                  ? savedReceiverName
                  : await NameResolver.userOrHospitalName(receiverId);

              final cells = <Widget>[
                Text(formatTimestamp(d['createdAt'])),
                Text(receiverName),
                Text(d['bloodType']?.toString() ?? 'N/A'),
                Text((d['units'] ?? 1).toString()),
              ];

              if (showCertificate) {
                cells.add(
                  ElevatedButton.icon(
                    onPressed: () async {
                      if (!context.mounted) return;
                      try {
                        final path =
                            await CertificateDownloadService.saveDonationCertificate(
                          donorName: donorName,
                          hospitalName: receiverName,
                          bloodType: d['bloodType']?.toString() ?? 'N/A',
                          units: d['units'] ?? 1,
                          donationDate: formatTimestamp(d['createdAt']),
                        );

                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              path == null
                                  ? 'Certificate saved. Check your Downloads folder.'
                                  : 'Certificate saved to Downloads successfully.',
                            ),
                          ),
                        );
                      } catch (e) {
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              e.toString().replaceFirst('Exception: ', ''),
                            ),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.download, size: 16),
                    label: const Text('Download'),
                  ),
                );
              }

              return cells;
            }),
          ),
          builder: (context, tableSnap) {
            if (tableSnap.hasError) {
              return const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'Unable to prepare donation history on this device.',
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }

            if (!tableSnap.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            return ScrollableDataTable(
              height: 420,
              columns: showCertificate
                  ? const [
                      'Date',
                      'Recipient',
                      'Blood',
                      'Units',
                      'Certificate',
                    ]
                  : const [
                      'Date',
                      'Recipient',
                      'Blood',
                      'Units',
                    ],
              rows: tableSnap.data!,
            );
          },
        );
      },
    );
  }
}
