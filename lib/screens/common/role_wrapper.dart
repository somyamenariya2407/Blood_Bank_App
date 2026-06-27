import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/account_moderation_service.dart';
import '../../services/app_preferences_service.dart';

// Import your dashboards
import '../auth/login_screen.dart';
import '../user/user_dashboard.dart';
import '../hospital/hospital_dashboard.dart';
import '../admin/admin_dashboard.dart';

class RoleWrapper extends StatelessWidget {
  const RoleWrapper({super.key});

  Future<Map<String, dynamic>> _loadOrRepairUserData(User user) async {
    final firestore = FirebaseFirestore.instance;
    final userRef = firestore.collection('users').doc(user.uid);
    final userDoc = await userRef.get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    if (userData.isNotEmpty) {
      return userData;
    }

    final hospitalDoc =
        await firestore.collection('hospitals').doc(user.uid).get();
    final hospitalData = hospitalDoc.data() ?? <String, dynamic>{};

    if (hospitalData.isNotEmpty) {
      final repairedHospitalUserData = <String, dynamic>{
        'name': hospitalData['hospitalName'] ?? hospitalData['name'] ?? '',
        'email': hospitalData['email'] ?? user.email ?? '',
        'role': 'hospital',
        'phone': hospitalData['phone'] ?? '',
        'address': hospitalData['address'] ?? '',
        'city': hospitalData['city'] ?? '',
        'pincode': hospitalData['pincode'] ?? '',
        'contactName': hospitalData['contactName'] ?? '',
        'isVerified': hospitalData['isVerified'] == true,
        'status': AccountModerationService.normalizeStatus(
          hospitalData['status'],
        ),
        'createdAt': hospitalData['createdAt'] ?? Timestamp.now(),
      };

      if (hospitalData['location'] != null) {
        repairedHospitalUserData['location'] = hospitalData['location'];
      }

      await userRef.set(repairedHospitalUserData, SetOptions(merge: true));
      return repairedHospitalUserData;
    }

    final email = user.email?.trim() ?? '';
    final fallbackName =
        (user.displayName?.trim().isNotEmpty ?? false)
            ? user.displayName!.trim()
            : (email.contains('@') ? email.split('@').first : 'User');

    final repairedUserData = <String, dynamic>{
      'name': fallbackName,
      'email': email,
      'phone': '',
      'bloodGroup': '',
      'role': 'user',
      'status': AccountModerationService.activeStatus,
      'isAvailable': true,
      'lastDonationAt': null,
      'donations': 0,
      'livesSaved': 0,
      'createdAt': Timestamp.now(),
    };

    await userRef.set(repairedUserData, SetOptions(merge: true));
    return repairedUserData;
  }

  void _signOutBlockedUser(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FirebaseAuth.instance.signOut();
    });
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;

    // If not logged in → go to login
    if (user == null) {
      return const LoginScreen();
    }

    return FutureBuilder<Map<String, dynamic>>(
      future: _loadOrRepairUserData(user),
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data!;
        final status = AccountModerationService.normalizeStatus(data['status']);
        if (AccountModerationService.isBlockedStatus(status)) {
          _signOutBlockedUser(context);
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        AppPreferencesService.syncPreferencesFromData(data);
        String role = data['role'];

        // 🔥 ROLE BASED NAVIGATION
        if (role == 'user') {
          return const UserDashboard();
        }
        else if (role == 'hospital') {
          return const HospitalDashboard();
        }
        else if (role == 'admin') {
          return const AdminDashboard();
        }
        else {
          return const Scaffold(
            body: Center(child: Text("Invalid Role")),
          );
        }
      },
    );
  }
}
