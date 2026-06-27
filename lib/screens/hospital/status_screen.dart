import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/hospital_document.dart';
import '../common/settings_screen.dart';
import '../../services/firestore_service.dart';
import '../../utils/app_text.dart';
import '../../widgets/common/app_header_title.dart';

class StatusScreen extends StatefulWidget {
  const StatusScreen({super.key});

  @override
  State<StatusScreen> createState() => _StatusScreenState();
}

class _StatusScreenState extends State<StatusScreen> {
  final service = FirestoreService();

  final nameController = TextEditingController();
  final phoneController = TextEditingController();
  final addressController = TextEditingController();
  final emailController = TextEditingController();

  bool isEditing = false;
  String? uploadingDocKey;
  double? uploadProgress;

  static const List<_DocumentType> _requiredDocuments = [
    _DocumentType(
      key: 'hospitalLicense',
      title: 'Hospital License',
      icon: Icons.local_hospital_outlined,
    ),
    _DocumentType(
      key: 'idProof',
      title: 'ID Proof',
      icon: Icons.badge_outlined,
    ),
    _DocumentType(
      key: 'medicalCertificate',
      title: 'Registration Certificate',
      icon: Icons.description_outlined,
    ),
  ];

  @override
  void dispose() {
    nameController.dispose();
    phoneController.dispose();
    addressController.dispose();
    emailController.dispose();
    super.dispose();
  }

  Future<void> _uploadDoc(_DocumentType documentType) async {
    if (uploadingDocKey != null) return;

    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
      allowMultiple: false,
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return;
    }

    final selectedFile = picked.files.single;
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final hasReadablePath =
        selectedFile.path != null && selectedFile.path!.trim().isNotEmpty;
    final hasReadableBytes =
        selectedFile.bytes != null && selectedFile.bytes!.isNotEmpty;

    if (!hasReadablePath && !hasReadableBytes) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Selected file could not be read. Please choose it again.'),
        ),
      );
      return;
    }

    try {
      if (mounted) {
        setState(() => uploadingDocKey = documentType.key);
      }

      await service.uploadAndSaveHospitalDocument(
        pickedFile: selectedFile,
        uid: uid,
        type: documentType.key,
        title: documentType.title,
        onProgress: (progress) {
          if (!mounted) return;
          setState(() => uploadProgress = progress);
        },
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${documentType.title} uploaded successfully'),
        ),
      );
    } catch (e) {
      final message = e.toString().replaceFirst('Exception: ', '').trim();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            message.isEmpty ? 'Upload failed. Please try again.' : message,
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          uploadingDocKey = null;
          uploadProgress = null;
        });
      }
    }
  }

  Future<void> _viewDocument(HospitalDocument document) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final bytes = await service.readHospitalDocumentBytes(
      uid: uid,
      document: document,
    );

    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to load this document right now.')),
      );
      return;
    }

    if (document.isPdf) {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: Text(document.title),
          content: Text(
            document.fileName.isEmpty
                ? 'PDF uploaded successfully.'
                : document.fileName,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    document.title,
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
                    onPressed: () => Navigator.pop(context),
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF4F7FB),
      appBar: AppBar(
        title: AppHeaderTitle(title: AppText.text(context, 'hospital_profile')),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF132238),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    title: AppText.text(context, 'hospital_settings'),
                    collectionName: 'hospitals',
                    documentId: uid,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: service.getHospitalData(uid),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final name = data['hospitalName'] ?? '';
          final email = data['email'] ?? '';
          final phone = data['phone'] ?? '';
          final address = data['address'] ?? '';
          final verified = data['isVerified'] ?? false;
          final documents = service.parseHospitalDocuments(data);
          final uploadedCount = documents.values
              .where(
                (doc) => doc.hasFile,
              )
              .length;
          final pendingCount = _requiredDocuments.length - uploadedCount;
          final completionRatio = _requiredDocuments.isEmpty
              ? 0.0
              : uploadedCount / _requiredDocuments.length;

          if (!isEditing) {
            nameController.text = name;
            phoneController.text = phone;
            addressController.text = address;
          }
          emailController.text = email;

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: verified
                          ? const [Color(0xFF0E7C66), Color(0xFF35A98E)]
                          : const [Color(0xFF9D1C2F), Color(0xFFD94B5F)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1F19324A),
                        blurRadius: 24,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.18),
                              ),
                            ),
                            child: const Icon(
                              Icons.local_hospital_rounded,
                              color: Colors.white,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: Text(
                                    verified
                                        ? 'Account verified'
                                        : 'Verification in progress',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  name.toString().trim().isEmpty
                                      ? 'Hospital Profile'
                                      : name.toString(),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 24,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  verified
                                      ? 'Your hospital is approved and ready for trusted coordination across the platform.'
                                      : 'Complete the required document uploads below to finish your verification review smoothly.',
                                  style: const TextStyle(
                                    color: Color(0xFFF7FAFF),
                                    height: 1.45,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Expanded(
                                  child: Text(
                                    'Verification progress',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Text(
                                  '$uploadedCount/${_requiredDocuments.length} completed',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(999),
                              child: LinearProgressIndicator(
                                minHeight: 10,
                                value: completionRatio,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.20),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _miniStatCard(
                        title: 'Docs Uploaded',
                        value: '$uploadedCount/${_requiredDocuments.length}',
                        color: const Color(0xFFB71C1C),
                        icon: Icons.upload_file_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _miniStatCard(
                        title: 'Review Status',
                        value: verified ? 'Verified' : 'Pending',
                        color: verified
                            ? const Color(0xFF0E7C66)
                            : const Color(0xFFD97706),
                        icon: verified
                            ? Icons.verified_outlined
                            : Icons.pending_actions_outlined,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _miniStatCard(
                        title: 'Pending Docs',
                        value: '$pendingCount',
                        color: const Color(0xFF2563EB),
                        icon: Icons.assignment_late_outlined,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _miniStatCard(
                        title: 'Contact Email',
                        value: email.toString().trim().isEmpty ? 'Not set' : 'Active',
                        color: const Color(0xFF7C3AED),
                        icon: Icons.alternate_email_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1419324A),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECEC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(
                              Icons.folder_open_rounded,
                              color: Color(0xFFB71C1C),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  AppText.text(context, 'documents'),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: Color(0xFF132238),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                const Text(
                                  'Keep your verification files updated for faster review.',
                                  style: TextStyle(
                                    color: Color(0xFF667085),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F7FA),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              '$uploadedCount ready',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF344054),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Text(
                          'Upload each required file once. You can replace any document later without affecting the rest of your profile.',
                          style: TextStyle(
                            color: Color(0xFF475467),
                            height: 1.45,
                          ),
                        ),
                      ),
                      if (!verified && documents.isEmpty) ...[
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF4E5),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: const Color(0xFFFDBA74)),
                          ),
                          child: const Text(
                            'Please upload the required documents to complete verification.',
                            style: TextStyle(
                              color: Color(0xFF9A3412),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 360,
                        child: Scrollbar(
                          thumbVisibility: true,
                          child: ListView.separated(
                            itemCount: _requiredDocuments.length,
                            separatorBuilder:
                                (_, _) => const SizedBox(height: 4),
                            itemBuilder: (context, index) {
                              final documentType = _requiredDocuments[index];
                              return docCard(
                                documentType: documentType,
                                uploadedData: documents[documentType.key],
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(22),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x1419324A),
                        blurRadius: 20,
                        offset: Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: const [
                                Text(
                                  'Hospital Details',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 18,
                                    color: Color(0xFF132238),
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Manage your public profile information shown in the app.',
                                  style: TextStyle(
                                    color: Color(0xFF667085),
                                    height: 1.35,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          if (!isEditing)
                            OutlinedButton.icon(
                              onPressed: () => setState(() => isEditing = true),
                              icon: const Icon(Icons.edit_outlined),
                              label: Text(AppText.text(context, 'edit_profile')),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: const Color(0xFFB71C1C),
                                side: const BorderSide(
                                  color: Color(0xFFE4E7EC),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      TextField(
                        controller: nameController,
                        enabled: isEditing,
                        decoration: _fieldDecoration('Hospital Name'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: phoneController,
                        enabled: isEditing,
                        decoration: _fieldDecoration('Phone'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: addressController,
                        enabled: isEditing,
                        decoration: _fieldDecoration('Address'),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: emailController,
                        enabled: false,
                        decoration: _fieldDecoration('Email'),
                      ),
                      if (isEditing) ...[
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton(
                                onPressed: () async {
                                  final messenger = ScaffoldMessenger.of(context);
                                  await service.updateHospitalProfile(
                                    uid: uid,
                                    name: nameController.text,
                                    phone: phoneController.text,
                                    address: addressController.text,
                                  );

                                  if (!mounted) return;
                                  setState(() => isEditing = false);
                                  messenger.showSnackBar(
                                    const SnackBar(content: Text('Profile updated')),
                                  );
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFFB71C1C),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(AppText.text(context, 'save')),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () {
                                  setState(() => isEditing = false);
                                },
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF344054),
                                  side: const BorderSide(
                                    color: Color(0xFFD0D5DD),
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                ),
                                child: Text(AppText.text(context, 'cancel')),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (_) => AlertDialog(
                          title: Text(AppText.text(context, 'logout')),
                          content: const Text('Do you really want to logout?'),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(context, false),
                              child: Text(AppText.text(context, 'cancel')),
                            ),
                            ElevatedButton(
                              onPressed: () => Navigator.pop(context, true),
                              child: Text(AppText.text(context, 'logout')),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await FirebaseAuth.instance.signOut();
                        if (!mounted) return;
                        if (!context.mounted) return;
                        Navigator.pushReplacementNamed(context, '/login');
                      }
                    },
                    icon: const Icon(Icons.logout),
                    label: Text(AppText.text(context, 'logout')),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFB42318),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget docCard({
    required _DocumentType documentType,
    required HospitalDocument? uploadedData,
  }) {
    final isUploaded = uploadedData?.hasFile ?? false;
    final uploadedName = uploadedData?.fileName.trim() ?? '';
    final isUploading = uploadingDocKey == documentType.key;
    final progress = isUploading ? uploadProgress : null;
    final reviewStatus = HospitalDocument.normalizeReviewStatus(
      uploadedData?.reviewStatus ?? HospitalDocument.pendingStatus,
    );
    final reviewColor =
        reviewStatus == HospitalDocument.verifiedStatus
            ? Colors.green
            : reviewStatus == HospitalDocument.rejectedStatus
                ? Colors.red
                : Colors.orange;
    final reviewLabel =
        reviewStatus == HospitalDocument.verifiedStatus
            ? 'Verified'
            : reviewStatus == HospitalDocument.rejectedStatus
                ? 'Rejected'
                : 'Pending Review';

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFCFE),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE6EAF0)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final uploadButton = ElevatedButton.icon(
              onPressed: isUploading ? null : () => _uploadDoc(documentType),
              icon: isUploading
                  ? const SizedBox(
                      height: 16,
                      width: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(isUploaded ? Icons.sync : Icons.upload_file),
              label: Text(
                isUploading
                    ? 'Uploading...'
                    : (isUploaded ? 'Replace' : 'Upload'),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: isUploaded
                    ? const Color(0xFF0E7C66)
                    : const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            );
            final viewButton = OutlinedButton.icon(
              onPressed:
                  isUploaded && uploadedData != null
                      ? () => _viewDocument(uploadedData)
                      : null,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('View'),
            );

            final details = Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    documentType.title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (isUploaded) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: reviewColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        reviewLabel,
                        style: TextStyle(
                          color: reviewColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 4),
                  Text(
                    isUploaded
                        ? (uploadedName.isEmpty
                            ? 'Uploaded successfully'
                            : uploadedName)
                        : 'Upload JPG, PNG or PDF',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isUploaded
                          ? const Color(0xFF0E7C66)
                          : const Color(0xFF667085),
                    ),
                  ),
                  if (progress != null) ...[
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: progress == 0 ? null : progress),
                    const SizedBox(height: 4),
                    Text(
                      'Uploading ${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Color(0xFF667085),
                      ),
                    ),
                  ],
                ],
              ),
            );

            if (constraints.maxWidth < 420) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        backgroundColor: const Color(0xFFFDECEC),
                        foregroundColor: const Color(0xFFB71C1C),
                        child: Icon(documentType.icon),
                      ),
                      const SizedBox(width: 12),
                      details,
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(child: uploadButton),
                      if (isUploaded) ...[
                        const SizedBox(width: 10),
                        Expanded(child: viewButton),
                      ],
                    ],
                  ),
                ],
              );
            }

            return Row(
              children: [
                CircleAvatar(
                  backgroundColor: const Color(0xFFFDECEC),
                  foregroundColor: const Color(0xFFB71C1C),
                  child: Icon(documentType.icon),
                ),
                const SizedBox(width: 12),
                details,
                const SizedBox(width: 12),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    uploadButton,
                    if (isUploaded) ...[
                      const SizedBox(height: 8),
                      viewButton,
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _miniStatCard({
    required String title,
    required String value,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1419324A),
            blurRadius: 18,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF667085),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _fieldDecoration(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: const Color(0xFFF8FAFC),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 16,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFD0D5DD)),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFFE4E7EC)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFFB71C1C),
          width: 1.4,
        ),
      ),
    );
  }
}

class _DocumentType {
  final String key;
  final String title;
  final IconData icon;

  const _DocumentType({
    required this.key,
    required this.title,
    required this.icon,
  });
}
