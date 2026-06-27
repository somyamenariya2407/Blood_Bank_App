import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/hospital_document.dart';

class AccountModerationService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  static const String activeStatus = 'active';
  static const String suspendedStatus = 'suspended';
  static const String rejectedStatus = 'rejected';

  static String normalizeStatus(Object? rawStatus) {
    final status = rawStatus?.toString().trim().toLowerCase();
    if (status == null || status.isEmpty) return activeStatus;
    return status;
  }

  static bool isBlockedStatus(Object? rawStatus) {
    final status = normalizeStatus(rawStatus);
    return status == suspendedStatus || status == rejectedStatus;
  }

  Future<void> setUserStatus({
    required String uid,
    required String status,
  }) async {
    await _db.collection('users').doc(uid).set({
      'status': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (isBlockedStatus(status)) {
      await _suspendRequests(ownerField: 'userId', ownerId: uid, status: status);
    }
  }

  Future<void> approveHospital(String uid) async {
    await _db.collection('hospitals').doc(uid).set({
      'isVerified': true,
      'status': activeStatus,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _db.collection('users').doc(uid).set({
      'isVerified': true,
      'status': activeStatus,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setHospitalStatus({
    required String uid,
    required String status,
  }) async {
    final hospitalUpdates = <String, dynamic>{
      'status': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (status == rejectedStatus) {
      hospitalUpdates['isVerified'] = false;
      hospitalUpdates['rejectedAt'] = FieldValue.serverTimestamp();
    }

    await _db.collection('hospitals').doc(uid).set(
          hospitalUpdates,
          SetOptions(merge: true),
        );

    final userUpdates = <String, dynamic>{
      'status': status,
      'statusUpdatedAt': FieldValue.serverTimestamp(),
    };
    if (status == rejectedStatus) {
      userUpdates['isVerified'] = false;
    }

    await _db.collection('users').doc(uid).set(
          userUpdates,
          SetOptions(merge: true),
        );

    if (isBlockedStatus(status)) {
      await _suspendRequests(
        ownerField: 'hospitalId',
        ownerId: uid,
        status: status,
      );
    }
  }

  Future<void> setHospitalDocumentStatus({
    required String uid,
    required String documentType,
    required String status,
  }) async {
    final normalizedStatus = HospitalDocument.normalizeReviewStatus(status);
    await _db.collection('hospitals').doc(uid).set({
      'documentsByType': {
        documentType: {
          'reviewStatus': normalizedStatus,
          'reviewedAt': FieldValue.serverTimestamp(),
        },
      },
    }, SetOptions(merge: true));
  }

  Future<void> _suspendRequests({
    required String ownerField,
    required String ownerId,
    required String status,
  }) async {
    final snapshot = await _db
        .collection('sos_requests')
        .where(ownerField, isEqualTo: ownerId)
        .where('status', isEqualTo: 'active')
        .get();

    if (snapshot.docs.isEmpty) return;

    final batch = _db.batch();
    for (final doc in snapshot.docs) {
      batch.update(doc.reference, {
        'status': suspendedStatus,
        'accountStatus': status,
        'suspendedAt': FieldValue.serverTimestamp(),
        'approvalStatus': FieldValue.delete(),
        'pendingDonorId': FieldValue.delete(),
        'pendingDonorName': FieldValue.delete(),
        'pendingDonorRole': FieldValue.delete(),
        'pendingAt': FieldValue.delete(),
        'acceptedDonorId': FieldValue.delete(),
        'acceptedDonorName': FieldValue.delete(),
        'acceptedDonorRole': FieldValue.delete(),
        'acceptedAt': FieldValue.delete(),
      });
    }
    await batch.commit();
  }
}
