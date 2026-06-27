import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/hospital_document.dart';
import '../../services/account_moderation_service.dart';
import '../../services/firestore_service.dart';

class HospitalDetailScreen extends StatelessWidget {
  final String hospitalId;
  static final FirestoreService _service = FirestoreService();
  static final AccountModerationService _moderation =
      AccountModerationService();
  static const Map<String, String> _documentTitles = {
    'hospitalLicense': 'Hospital License',
    'idProof': 'ID Proof',
    'medicalCertificate': 'Registration Certificate',
  };

  const HospitalDetailScreen({super.key, required this.hospitalId});

  Future<void> verifyHospital(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await _moderation.approveHospital(hospitalId);

    await FirebaseFirestore.instance.collection('activities').add({
      'message': 'Hospital verified',
      'timestamp': Timestamp.now(),
    });

    messenger.showSnackBar(
      const SnackBar(content: Text('Hospital approved')),
    );

    navigator.pop();
  }

  Future<void> rejectHospital(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    await _moderation.setHospitalStatus(
      uid: hospitalId,
      status: AccountModerationService.rejectedStatus,
    );

    await FirebaseFirestore.instance.collection('activities').add({
      'message': 'Hospital rejected',
      'timestamp': Timestamp.now(),
    });

    messenger.showSnackBar(
      const SnackBar(content: Text('Hospital rejected')),
    );

    navigator.pop();
  }

  Future<void> toggleHospitalSuspension(
    BuildContext context, {
    required bool suspend,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    await _moderation.setHospitalStatus(
      uid: hospitalId,
      status: suspend
          ? AccountModerationService.suspendedStatus
          : AccountModerationService.activeStatus,
    );

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          suspend ? 'Hospital suspended' : 'Hospital activated',
        ),
      ),
    );
  }

  Future<void> openDocument(BuildContext context, HospitalDocument doc) async {
    if (doc.downloadUrl.trim().isNotEmpty) {
      final uri = Uri.parse(doc.downloadUrl);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
      return;
    }

    final bytes = await _service.readHospitalDocumentBytes(
      uid: hospitalId,
      document: doc,
    );
    if (!context.mounted) return;
    if (bytes == null || bytes.isEmpty) return;

    if (doc.isPdf) {
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(doc.title),
          content: Text(
            '${doc.fileName.isEmpty ? 'PDF uploaded successfully.' : doc.fileName}\n\nThis document is stored in Firestore fallback mode.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    doc.title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Image.memory(bytes),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.pop(dialogContext),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _updateDocumentStatus(
    BuildContext context, {
    required String documentType,
    required String status,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    await _moderation.setHospitalDocumentStatus(
      uid: hospitalId,
      documentType: documentType,
      status: status,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          status == HospitalDocument.verifiedStatus
              ? 'Document verified'
              : 'Document rejected',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(title: const Text('Hospital Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('hospitals')
            .doc(hospitalId)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.data() == null) {
            return const Center(child: Text('No data found'));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final name =
              (data['hospitalName'] ?? data['name'] ?? 'Unknown Hospital')
                  .toString();
          final address =
              '${data['address'] ?? ''}, ${data['city'] ?? ''}'.trim();
          final phone = (data['phone'] ?? 'No phone').toString();
          final email = (data['email'] ?? 'No email').toString();
          final docs = _service.parseHospitalDocuments(data).values.toList()
            ..sort((a, b) => a.title.compareTo(b.title));
          final isVerified = data['isVerified'] ?? false;
          final status = AccountModerationService.normalizeStatus(data['status']);
          final isSuspended =
              status == AccountModerationService.suspendedStatus;
          final isRejected = status == AccountModerationService.rejectedStatus;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [
                      BoxShadow(color: Colors.black12, blurRadius: 6),
                    ],
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.local_hospital,
                        color: Colors.red,
                        size: 30,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (isVerified)
                        const Icon(Icons.verified, color: Colors.blue),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isRejected
                        ? Colors.red.withValues(alpha: 0.12)
                        : isSuspended
                            ? Colors.orange.withValues(alpha: 0.12)
                            : Colors.green.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Status: ${status[0].toUpperCase()}${status.substring(1)}',
                    style: TextStyle(
                      color: isRejected
                          ? Colors.red
                          : isSuspended
                              ? Colors.orange.shade800
                              : Colors.green.shade800,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Address: $address'),
                      const SizedBox(height: 6),
                      Text('Phone: $phone'),
                      const SizedBox(height: 6),
                      Text('Email: $email'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Documents',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                if (docs.isEmpty)
                  const Text('No documents uploaded')
                else
                  SizedBox(
                    height: 380,
                    child: Scrollbar(
                      thumbVisibility: docs.length > 2,
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final title = doc.title;
                          final fileName = doc.fileName;
                          final docStatus =
                              HospitalDocument.normalizeReviewStatus(
                                doc.reviewStatus,
                              );
                          final statusColor =
                              docStatus == HospitalDocument.verifiedStatus
                                  ? Colors.green
                                  : docStatus ==
                                      HospitalDocument.rejectedStatus
                                  ? Colors.red
                                  : Colors.orange;
                          final statusLabel =
                              docStatus == HospitalDocument.verifiedStatus
                                  ? 'Verified'
                                  : docStatus ==
                                      HospitalDocument.rejectedStatus
                                  ? 'Rejected'
                                  : 'Pending Review';

                          return Container(
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      const Icon(
                                        Icons.description_outlined,
                                        color: Colors.red,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              title.isEmpty
                                                  ? (_documentTitles[doc.type] ??
                                                      doc.type)
                                                  : title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              fileName.trim().isEmpty
                                                  ? 'Uploaded document available. Tap view to open.'
                                                  : fileName,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                            const SizedBox(height: 8),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 4,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: statusColor.withValues(
                                                  alpha: 0.12,
                                                ),
                                                borderRadius:
                                                    BorderRadius.circular(999),
                                              ),
                                              child: Text(
                                                statusLabel,
                                                style: TextStyle(
                                                  color: statusColor,
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: [
                                      OutlinedButton.icon(
                                        onPressed:
                                            () => openDocument(context, doc),
                                        icon: Icon(
                                          doc.isPdf
                                              ? Icons.picture_as_pdf_outlined
                                              : Icons.visibility_outlined,
                                        ),
                                        label: const Text('View'),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed:
                                            () => _updateDocumentStatus(
                                              context,
                                              documentType: doc.type,
                                              status: HospitalDocument
                                                  .verifiedStatus,
                                            ),
                                        icon: const Icon(
                                          Icons.verified_outlined,
                                        ),
                                        label: const Text('Verify'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                      ElevatedButton.icon(
                                        onPressed:
                                            () => _updateDocumentStatus(
                                              context,
                                              documentType: doc.type,
                                              status: HospitalDocument
                                                  .rejectedStatus,
                                            ),
                                        icon: const Icon(Icons.close),
                                        label: const Text('Reject'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                          foregroundColor: Colors.white,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                const SizedBox(height: 25),
                if (isRejected)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => toggleHospitalSuspension(
                        context,
                        suspend: false,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Restore To Pending'),
                    ),
                  )
                else if (!isVerified)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => verifyHospital(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => rejectHospital(context),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Reject'),
                        ),
                      ),
                    ],
                  )
                else if (isSuspended)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => toggleHospitalSuspension(
                        context,
                        suspend: false,
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Activate'),
                    ),
                  )
                else
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Verified',
                          style: TextStyle(
                            color: Colors.blue,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      ElevatedButton(
                        onPressed: () => toggleHospitalSuspension(
                          context,
                          suspend: true,
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        child: const Text('Suspend'),
                      ),
                    ],
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
