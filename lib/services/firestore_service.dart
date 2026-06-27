import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../models/hospital_document.dart';
import '../utils/sos_request_time.dart';
import 'onesignal_service.dart';

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ================= USER =================

  Future<void> createUser(Map<String, dynamic> data) async {
    await _db.collection('users').doc(data['uid']).set(data);
  }

  Future<Map<String, dynamic>?> getUser(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    return doc.data();
  }

  // ================= HOSPITAL =================

  Stream<DocumentSnapshot> getHospitalData(String uid) {
    return _db.collection('hospitals').doc(uid).snapshots();
  }

  Future<void> updateBloodUnit(
      String uid, String bloodType, int newValue) async {
    await _db.collection('hospitals').doc(uid).update({
      'inventory.$bloodType': newValue,
    });
  }

  // ================= REQUEST =================

  /// 🔥 CREATE REQUEST (FIXED COLLECTION)
  Future<void> createRequest({
    required String hospitalId,
    required String bloodType,
    required int units,
    required String priority,
    DateTime? requiredByAt,
    String? timeInputMode,
    String? timeInputLabel,
    required double lat,
    required double lng,
  }) async {

    // 🔥 Fetch hospital/user details
    final userDoc =
    await _db.collection('users').doc(hospitalId).get();

    final hospitalDoc =
    await _db.collection('hospitals').doc(hospitalId).get();

    final userData = userDoc.data();
    final hospitalData = hospitalDoc.data();

    final name =
        hospitalData?['hospitalName'] ??
            userData?['name'] ??
            "Unknown";

    final role = userData?['role'] ?? "hospital";
    final phone = hospitalData?['phone'] ?? userData?['phone'] ?? "";
    final address = hospitalData?['address'] ?? userData?['address'] ?? "";

    await _db.collection('sos_requests').add({
      'hospitalId': hospitalId,
      'userId': hospitalId, // 🔥 common field

      'name': name, // 🔥 IMPORTANT
      'role': role, // 🔥 IMPORTANT
      'phone': phone,
      'address': address,

      'bloodType': bloodType,
      'units': units,
      'priority': priority,
      if (requiredByAt != null) 'requiredByAt': Timestamp.fromDate(requiredByAt),
      if (timeInputMode != null && timeInputMode.isNotEmpty)
        'timeInputMode': timeInputMode,
      if (timeInputLabel != null && timeInputLabel.isNotEmpty)
        'timeInputLabel': timeInputLabel,

      'status': 'active',

      'createdAt': Timestamp.now(),

      'location': {
        'lat': lat,
        'lng': lng,
      }
    });
  }

  /// 🔥 GET REQUESTS (FIXED COLLECTION)
  Stream<QuerySnapshot> getHospitalRequests(String uid) {
    return _db
        .collection('sos_requests')
        .where('hospitalId', isEqualTo: uid)
        .snapshots();
  }

  // ================= PROFILE =================

  Future<void> updateHospitalProfile({
    required String uid,
    required String name,
    required String phone,
    required String address,
  }) async {
    await _db.collection('hospitals').doc(uid).update({
      'hospitalName': name,
      'phone': phone,
      'address': address,
    });
  }

  // ================= LOCATION =================

  Future<void> updateLocation({
    required String uid,
    required double lat,
    required double lng,
  }) async {
    await _db.collection('hospitals').doc(uid).update({
      'location': {
        'lat': lat,
        'lng': lng,
      }
    });
  }

  // ================= USER LOCATION =================

  Future<void> updateUserLocation({
    required String uid,
    required double lat,
    required double lng,
  }) async {
    await _db.collection('users').doc(uid).update({
      'location': {
        'lat': lat,
        'lng': lng,
      }
    });
  }

  // ================= DOCUMENT UPLOAD =================

  Future<HospitalDocument> uploadHospitalDocument({
    required PlatformFile pickedFile,
    required String uid,
    required String type,
    required String title,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = _sanitizeFileName(pickedFile.name);
    final mimeType = _contentTypeFor(fileName);
    final filePath = pickedFile.path?.trim();

    try {
      final fileBytes = await _readDocumentBytes(
        path: filePath,
        bytes: pickedFile.bytes,
      );

      await _writeHospitalDocumentChunks(
        uid: uid,
        type: type,
        bytes: fileBytes,
        onProgress: onProgress,
      );

      return HospitalDocument(
        type: type,
        title: title,
        fileName: fileName,
        contentType: mimeType,
        storagePath: 'firestore://hospitals/$uid/documentUploads/$type',
        downloadUrl: '',
        reviewStatus: HospitalDocument.pendingStatus,
        uploadedAt: DateTime.now(),
        reviewedAt: null,
      );
    } catch (error) {
      throw Exception(_readableUploadError(error));
    }
  }

  Future<Uint8List> _readDocumentBytes({
    required String? path,
    required Uint8List? bytes,
  }) async {
    if (bytes != null && bytes.isNotEmpty) {
      return bytes;
    }

    if (path != null && path.trim().isNotEmpty) {
      final file = File(path);
      if (file.existsSync()) {
        return await file.readAsBytes();
      }
    }

    throw Exception('Selected file data could not be read.');
  }

  Future<void> _writeHospitalDocumentChunks({
    required String uid,
    required String type,
    required Uint8List bytes,
    void Function(double progress)? onProgress,
  }) async {
    if (bytes.isEmpty) {
      throw Exception('Selected file data could not be read.');
    }

    final encoded = base64Encode(bytes);
    const chunkSize = 700000;
    final chunks = <String>[];

    for (var i = 0; i < encoded.length; i += chunkSize) {
      final end = (i + chunkSize < encoded.length)
          ? i + chunkSize
          : encoded.length;
      chunks.add(encoded.substring(i, end));
    }

    final uploadRoot = _db
        .collection('hospitals')
        .doc(uid)
        .collection('documentUploads')
        .doc(type);

    final existingChunks = await uploadRoot.collection('chunks').get();
    if (existingChunks.docs.isNotEmpty) {
      var deleteBatch = _db.batch();
      var deleteOps = 0;
      for (final doc in existingChunks.docs) {
        deleteBatch.delete(doc.reference);
        deleteOps++;
        if (deleteOps == 400) {
          await deleteBatch.commit();
          deleteBatch = _db.batch();
          deleteOps = 0;
        }
      }
      if (deleteOps > 0) {
        await deleteBatch.commit();
      }
    }

    await uploadRoot.set({
      'chunkCount': chunks.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (chunks.isEmpty) {
      onProgress?.call(1);
      return;
    }

    var batch = _db.batch();
    var ops = 0;
    for (var index = 0; index < chunks.length; index++) {
      final chunkRef = uploadRoot.collection('chunks').doc(
        index.toString().padLeft(5, '0'),
      );
      batch.set(chunkRef, {
        'index': index,
        'data': chunks[index],
      });
      ops++;
      if (ops == 300) {
        await batch.commit();
        batch = _db.batch();
        ops = 0;
      }
      onProgress?.call((index + 1) / chunks.length);
    }

    if (ops > 0) {
      await batch.commit();
    }

    onProgress?.call(1);
  }

  String _contentTypeFor(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    return 'application/octet-stream';
  }

  String _readableUploadError(Object? error) {
    if (error is FirebaseException) {
      final message = error.message?.trim();
      if (message != null && message.isNotEmpty) {
        return message;
      }
      return 'Upload failed with Firebase error: ${error.code}.';
    }

    final message = error?.toString().replaceFirst('Exception: ', '').trim();
    if (message != null && message.isNotEmpty) {
      return message;
    }

    return 'Upload failed. Please try again.';
  }

  Future<void> saveHospitalDocument({
    required String uid,
    required HospitalDocument document,
  }) async {
    await _db.collection('hospitals').doc(uid).set({
      'documents': FieldValue.arrayUnion([
        document.fileName.isNotEmpty ? document.fileName : document.type,
      ]),
      'documentsByType': {
        document.type.trim(): document.toMap(),
      },
    }, SetOptions(merge: true));
  }

  Future<HospitalDocument> uploadAndSaveHospitalDocument({
    required PlatformFile pickedFile,
    required String uid,
    required String type,
    required String title,
    void Function(double progress)? onProgress,
  }) async {
    final document = await uploadHospitalDocument(
      pickedFile: pickedFile,
      uid: uid,
      type: type,
      title: title,
      onProgress: onProgress,
    );
    await saveHospitalDocument(uid: uid, document: document);
    return document;
  }

  Map<String, HospitalDocument> parseHospitalDocuments(
    Map<String, dynamic> hospitalData,
  ) {
    final rawDocuments = hospitalData['documentsByType'];
    final documentMap = rawDocuments is Map
        ? _normalizeHospitalDocumentMapShape(
            Map<String, dynamic>.from(rawDocuments),
          )
        : <String, dynamic>{};

    if (documentMap.isEmpty) {
      final flattenedEntries = <String, dynamic>{};
      hospitalData.forEach((key, value) {
        if (key.toString().startsWith('documentsByType.')) {
          flattenedEntries[key.toString().replaceFirst('documentsByType.', '')] =
              value;
        }
      });

      if (flattenedEntries.isNotEmpty) {
        return HospitalDocument.fromDocumentMap(
          _normalizeHospitalDocumentMapShape(flattenedEntries),
        );
      }
    }

    return HospitalDocument.fromDocumentMap(documentMap);
  }

  Map<String, dynamic> _normalizeHospitalDocumentMapShape(
    Map<String, dynamic>? rawMap,
  ) {
    if (rawMap == null) return <String, dynamic>{};

    final normalized = <String, dynamic>{};

    rawMap.forEach((key, value) {
      if (key.contains('.')) {
        final parts = key.split('.');
        if (parts.length >= 2) {
          final documentType = parts.first.trim();
          final fieldName = parts.sublist(1).join('.').trim();
          if (documentType.isEmpty || fieldName.isEmpty) return;

          final existing =
              normalized[documentType] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(
                      normalized[documentType] as Map<String, dynamic>,
                    )
                  : <String, dynamic>{};
          existing[fieldName] = value;
          normalized[documentType] = existing;
          return;
        }
      }

      normalized[key] = value;
    });

    return normalized;
  }

  String _sanitizeFileName(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return 'document';
    return trimmed.replaceAll(RegExp(r'[\\/]'), '_');
  }

  Future<Uint8List?> readHospitalDocumentBytes({
    required String uid,
    required HospitalDocument document,
  }) async {
    if (document.storagePath.trim().isEmpty) {
      return null;
    }

    final chunksSnap = await _db
        .collection('hospitals')
        .doc(uid)
        .collection('documentUploads')
        .doc(document.type)
        .collection('chunks')
        .orderBy('index')
        .get();

    if (chunksSnap.docs.isEmpty) {
      return null;
    }

    final buffer = StringBuffer();
    for (final doc in chunksSnap.docs) {
      buffer.write((doc.data()['data'] ?? '').toString());
    }

    final raw = buffer.toString();
    if (raw.isEmpty) {
      return null;
    }

    return base64Decode(raw);
  }

  Future<void> requestDonationApproval({
    required String requestId,
    required String donorId,
  }) async {
    final requestRef = _db.collection('sos_requests').doc(requestId);
    final donorUserDoc = await _db.collection('users').doc(donorId).get();
    final donorHospitalDoc = await _db.collection('hospitals').doc(donorId).get();
    final donorUserData = donorUserDoc.data() ?? <String, dynamic>{};
    final donorHospitalData = donorHospitalDoc.data() ?? <String, dynamic>{};
    final donorName = donorHospitalData['hospitalName'] ??
        donorUserData['name'] ??
        donorUserData['hospitalName'] ??
        'Donor';
    final donorRole = donorUserData['role'] ?? 'user';

    Map<String, dynamic> requestData = {};

    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Request not found.');
      }

      requestData = requestSnap.data() ?? <String, dynamic>{};
      final status = (requestData['status'] ?? 'active').toString();
      final requesterId =
          (requestData['userId'] ?? requestData['hospitalId'] ?? '').toString();
      final pendingDonorId =
          (requestData['pendingDonorId'] ?? '').toString().trim();

      if (requesterId == donorId) {
        throw Exception('Cannot donate your own request.');
      }

      if (status != 'active') {
        throw Exception('This request is no longer active.');
      }

      if (isSosExpired(requestData)) {
        throw Exception('This request has expired.');
      }

      if (pendingDonorId.isNotEmpty) {
        if (pendingDonorId == donorId) {
          throw Exception('Your offer is already waiting for approval.');
        }
        throw Exception('Another donor is already waiting for approval.');
      }

      transaction.update(requestRef, {
        'approvalStatus': 'pending',
        'pendingDonorId': donorId,
        'pendingDonorName': donorName,
        'pendingDonorRole': donorRole,
        'pendingAt': FieldValue.serverTimestamp(),
      });
    });

    final requesterId =
        (requestData['userId'] ?? requestData['hospitalId'] ?? '').toString();
    final bloodType = (requestData['bloodType'] ?? 'blood').toString();

    await _sendUserNotification(
      receiverId: requesterId,
      title: 'Donation offer received',
      message: '$donorName wants to donate for your $bloodType request.',
      data: {
        'type': 'donation_offer',
        'requestId': requestId,
        'donorId': donorId,
      },
    );
  }

  Future<void> respondToDonationApproval({
    required String requestId,
    required bool accept,
  }) async {
    final requestRef = _db.collection('sos_requests').doc(requestId);
    Map<String, dynamic> requestData = {};

    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Request not found.');
      }

      requestData = requestSnap.data() ?? <String, dynamic>{};
      final status = (requestData['status'] ?? 'active').toString();
      final approvalStatus = (requestData['approvalStatus'] ?? '').toString();
      final pendingDonorId =
          (requestData['pendingDonorId'] ?? '').toString().trim();

      if (status != 'active') {
        throw Exception('This request is no longer active.');
      }

      if (isSosExpired(requestData)) {
        throw Exception('This request has expired.');
      }

      if (approvalStatus != 'pending' || pendingDonorId.isEmpty) {
        throw Exception('There is no pending donation offer to review.');
      }

      if (accept) {
        transaction.update(requestRef, {
          'approvalStatus': 'accepted',
          'acceptedDonorId': pendingDonorId,
          'acceptedDonorName': requestData['pendingDonorName'] ?? 'Donor',
          'acceptedDonorRole': requestData['pendingDonorRole'] ?? 'user',
          'acceptedAt': Timestamp.now(),
          'pendingDonorId': FieldValue.delete(),
          'pendingDonorName': FieldValue.delete(),
          'pendingDonorRole': FieldValue.delete(),
          'pendingAt': FieldValue.delete(),
        });
      } else {
        transaction.update(requestRef, {
          'approvalStatus': FieldValue.delete(),
          'pendingDonorId': FieldValue.delete(),
          'pendingDonorName': FieldValue.delete(),
          'pendingDonorRole': FieldValue.delete(),
          'pendingAt': FieldValue.delete(),
        });
      }
    });

    final donorId = (requestData['pendingDonorId'] ?? '').toString();
    final bloodType = (requestData['bloodType'] ?? 'blood').toString();

    if (accept) {
      await _sendUserNotification(
        receiverId: donorId,
        title: 'Donation offer accepted',
        message: 'Your donation offer for $bloodType has been accepted.',
        data: {
          'type': 'donation_offer_accepted',
          'requestId': requestId,
        },
      );
    } else {
      await _sendUserNotification(
        receiverId: donorId,
        title: 'Donation offer rejected',
        message: 'Your donation offer for $bloodType was not accepted.',
        data: {
          'type': 'donation_offer_rejected',
          'requestId': requestId,
        },
      );
    }
  }

  Future<void> completeApprovedDonation({
    required String requestId,
    required String donorId,
  }) async {
    final requestRef = _db.collection('sos_requests').doc(requestId);
    Map<String, dynamic> requestData = {};
    int donatedUnits = 1;
    String bloodType = 'blood';
    String donorRole = 'user';
    String donorName = 'Donor';
    String receiverId = '';
    String receiverRole = 'user';

    await _db.runTransaction((transaction) async {
      final requestSnap = await transaction.get(requestRef);
      if (!requestSnap.exists) {
        throw Exception('Request not found.');
      }

      requestData = requestSnap.data() ?? <String, dynamic>{};
      final status = (requestData['status'] ?? 'active').toString();
      final approvalStatus = (requestData['approvalStatus'] ?? '').toString();
      final acceptedDonorId =
          (requestData['acceptedDonorId'] ?? '').toString().trim();
      bloodType = (requestData['bloodType'] ?? 'blood').toString();
      donatedUnits = (requestData['units'] as num?)?.toInt() ?? 1;
      donorRole = (requestData['acceptedDonorRole'] ?? 'user').toString();
      donorName = (requestData['acceptedDonorName'] ?? 'Donor').toString();
      receiverId =
          (requestData['userId'] ?? requestData['hospitalId'] ?? '').toString();
      receiverRole = (requestData['role'] ?? 'user').toString();

      if (status != 'active') {
        throw Exception('This request is no longer active.');
      }

      if (isSosExpired(requestData)) {
        throw Exception('This request has expired.');
      }

      if (approvalStatus != 'accepted' || acceptedDonorId.isEmpty) {
        throw Exception('This request is not approved for donation yet.');
      }

      if (acceptedDonorId != donorId) {
        throw Exception('This request was approved for another donor.');
      }

      DocumentReference<Map<String, dynamic>>? donorHospitalRef;
      DocumentSnapshot<Map<String, dynamic>>? donorHospitalSnap;
      if (donorRole == 'hospital') {
        donorHospitalRef = _db.collection('hospitals').doc(donorId);
        donorHospitalSnap = await transaction.get(donorHospitalRef);
        if (!donorHospitalSnap.exists) {
          throw Exception('Donor hospital inventory not found.');
        }
      }

      DocumentReference<Map<String, dynamic>>? receiverHospitalRef;
      DocumentSnapshot<Map<String, dynamic>>? receiverHospitalSnap;
      if (receiverRole == 'hospital' && receiverId.isNotEmpty) {
        receiverHospitalRef = _db.collection('hospitals').doc(receiverId);
        receiverHospitalSnap = await transaction.get(receiverHospitalRef);
      }

      if (donorRole == 'hospital') {
        final donorHospitalData = donorHospitalSnap!.data() ?? {};
        final donorInventory =
            Map<String, dynamic>.from(donorHospitalData['inventory'] ?? {});
        final availableUnits = (donorInventory[bloodType] as num?)?.toInt() ?? 0;

        if (availableUnits < donatedUnits) {
          throw Exception(
            'Not enough $bloodType units in donor hospital inventory.',
          );
        }

        transaction.update(donorHospitalRef!, {
          'inventory.$bloodType': availableUnits - donatedUnits,
        });
      }

      if (receiverHospitalSnap?.exists == true) {
          final receiverHospitalData = receiverHospitalSnap!.data() ?? {};
          final receiverInventory =
              Map<String, dynamic>.from(receiverHospitalData['inventory'] ?? {});
          final currentUnits =
              (receiverInventory[bloodType] as num?)?.toInt() ?? 0;

          transaction.update(receiverHospitalRef!, {
            'inventory.$bloodType': currentUnits + donatedUnits,
          });
      }

      transaction.update(requestRef, {
        'status': 'completed',
        'fulfilledBy': acceptedDonorId,
        'fulfilledByName': requestData['acceptedDonorName'] ?? 'Donor',
        'fulfilledByRole': requestData['acceptedDonorRole'] ?? 'user',
        'fulfilledAt': Timestamp.now(),
      });
    });

    await _db.collection('donations').add({
      'donorId': donorId,
      'donorName': donorName,
      'donorRole': donorRole,
      'requestId': requestId,
      'receiverId': receiverId,
      'receiverName': requestData['name'] ?? 'Requester',
      'receiverRole': requestData['role'] ?? 'user',
      'bloodType': requestData['bloodType'],
      'units': donatedUnits,
      'createdAt': Timestamp.now(),
    });

    final donorUpdates = <String, dynamic>{
      'donations': FieldValue.increment(1),
      'livesSaved': FieldValue.increment(1),
      'lastDonationAt': Timestamp.now(),
    };
    if (donorRole == 'user') {
      donorUpdates['isAvailable'] = false;
    }
    await _db.collection('users').doc(donorId).set(
          donorUpdates,
          SetOptions(merge: true),
        );

    await _sendUserNotification(
      receiverId: receiverId,
      title: 'Donation completed',
      message: '$donorName completed the donation for your $bloodType request.',
      data: {
        'type': 'donation_completed',
        'requestId': requestId,
      },
    );
  }

  Future<void> _sendUserNotification({
    required String receiverId,
    required String title,
    required String message,
    Map<String, dynamic>? data,
  }) async {
    if (receiverId.trim().isEmpty) return;

    await _db.collection('notifications').add({
      'receiverId': receiverId,
      'title': title,
      'message': message,
      'createdAt': FieldValue.serverTimestamp(),
      'type': data?['type'] ?? 'general',
      'requestId': data?['requestId'],
      'donorId': data?['donorId'],
      'isRead': false,
    });

    final receiverDoc = await _db.collection('users').doc(receiverId).get();
    final playerId = receiverDoc.data()?['playerId'];
    final notificationsEnabled =
        (receiverDoc.data()?['settings']?['notificationsEnabled']) != false;

    if (playerId is String && playerId.isNotEmpty && notificationsEnabled) {
      await OneSignalService.sendNotification(
        playerIds: [playerId],
        title: title,
        message: message,
        data: data,
      );
    }
  }

  // ================= FCM TOKEN =================

  Future<void> updateUserToken(String uid, String token) async {
    await _db.collection('users').doc(uid).update({
      'fcmToken': token,
    });
  }
}
