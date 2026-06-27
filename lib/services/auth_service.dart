import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';

import 'account_moderation_service.dart';
import 'location_service.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<User?> login(String email, String password) async {
    UserCredential? result;
    try {
      result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = result.user!.uid;
      try {
        final userDoc = await _db.collection('users').doc(uid).get();
        final userData = userDoc.data() ?? <String, dynamic>{};
        final status =
            AccountModerationService.normalizeStatus(userData['status']);

        if (AccountModerationService.isBlockedStatus(status)) {
          await _auth.signOut();
          throw Exception(
            status == AccountModerationService.rejectedStatus
                ? 'Your account has been rejected. Please contact the admin.'
                : 'Your account has been suspended. Please contact the admin.',
          );
        }
      } on FirebaseException catch (e) {
        debugPrint('Login profile check skipped: ${e.message}');
      }

      try {
        await saveOneSignalPlayerId(uid);
      } catch (e) {
        debugPrint('OneSignal sync skipped during login: $e');
      }
      return result.user;
    } catch (e) {
      if (result?.user != null) {
        await _auth.signOut();
      }
      rethrow;
    }
  }

  Future<void> saveOneSignalPlayerId(String uid) async {
    final playerId = OneSignal.User.pushSubscription.id;

    if (playerId != null && playerId.isNotEmpty) {
      await _db.collection('users').doc(uid).set({
        'playerId': playerId,
      }, SetOptions(merge: true));

      final userDoc = await _db.collection('users').doc(uid).get();
      final role = userDoc.data()?['role'];

      if (role == 'hospital') {
        await _db.collection('hospitals').doc(uid).set({
          'playerId': playerId,
        }, SetOptions(merge: true));
      }
    }
  }

  Future<void> registerUser({
    required String email,
    required String password,
    required String name,
    required String phone,
    required String bloodGroup,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await _db.collection('users').doc(result.user!.uid).set({
      'name': name,
      'phone': phone,
      'bloodGroup': bloodGroup,
      'email': email,
      'role': 'user',
      'status': AccountModerationService.activeStatus,
      'isAvailable': true,
      'lastDonationAt': null,
      'donations': 0,
      'livesSaved': 0,
      'createdAt': Timestamp.now(),
    });
  }

  Future<void> registerHospital({
    required String email,
    required String password,
    required String hospitalName,
    required String address,
    required String city,
    required String pincode,
    required String contactName,
    required String phone,
  }) async {
    final result = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    final uid = result.user!.uid;
    Map<String, double>? location;

    try {
      final pos = await LocationService.getCurrentLocation();
      location = {
        'lat': pos.latitude,
        'lng': pos.longitude,
      };
    } catch (_) {
      location = null;
    }

    final userData = {
      'name': hospitalName,
      'email': email,
      'role': 'hospital',
      'phone': phone,
      'address': address,
      'city': city,
      'pincode': pincode,
      'contactName': contactName,
      'isVerified': false,
      'status': AccountModerationService.activeStatus,
      'createdAt': Timestamp.now(),
    };

    if (location != null) {
      userData['location'] = location;
    }

    await _db.collection('users').doc(uid).set(userData);

    final hospitalData = {
      'hospitalName': hospitalName,
      'address': address,
      'city': city,
      'pincode': pincode,
      'contactName': contactName,
      'phone': phone,
      'email': email,
      'documents': [],
      'isVerified': false,
      'status': AccountModerationService.activeStatus,
      'inventory': {
        'A+': 0,
        'A-': 0,
        'B+': 0,
        'B-': 0,
        'O+': 0,
        'O-': 0,
        'AB+': 0,
        'AB-': 0,
      },
      'createdAt': Timestamp.now(),
    };

    if (location != null) {
      hospitalData['location'] = location;
      hospitalData['locationCapturedAt'] = Timestamp.now();
    }

    await _db.collection('hospitals').doc(uid).set(hospitalData);
  }

  Future<void> logout() async {
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      throw Exception('Please enter your email address.');
    }

    await _auth.sendPasswordResetEmail(email: trimmedEmail);
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final user = _auth.currentUser;
    final email = user?.email?.trim();

    if (user == null || email == null || email.isEmpty) {
      throw Exception('Unable to verify the current account.');
    }

    if (currentPassword.trim().isEmpty) {
      throw Exception('Please enter your current password.');
    }

    if (newPassword.trim().length < 6) {
      throw Exception('New password must be at least 6 characters long.');
    }

    final credential = EmailAuthProvider.credential(
      email: email,
      password: currentPassword.trim(),
    );

    await user.reauthenticateWithCredential(credential);
    await user.updatePassword(newPassword.trim());
  }
}
