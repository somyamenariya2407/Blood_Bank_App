import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/account_moderation_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../utils/app_text.dart';
import '../common/history_hub_screen.dart';
import '../../widgets/common/dashboard_exit_guard.dart';
import 'inventory_screen.dart';
import 'map_screen.dart';
import 'request_screen.dart';
import 'status_screen.dart';

class HospitalDashboard extends StatefulWidget {
  const HospitalDashboard({super.key});

  @override
  State<HospitalDashboard> createState() => _HospitalDashboardState();
}

class _HospitalDashboardState extends State<HospitalDashboard> {
  int selectedIndex = 0;

  final FirestoreService service = FirestoreService();

  void _handleBlockedAccount(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    });
  }

  @override
  void initState() {
    super.initState();
    _initHospital();
  }

  Future<void> _initHospital() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      final email = FirebaseAuth.instance.currentUser?.email;

      if (uid == null) return;

      final hospitalRef = FirebaseFirestore.instance.collection('hospitals').doc(uid);
      final doc = await hospitalRef.get();
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final userData = userDoc.data() ?? <String, dynamic>{};
      final userStatus =
          AccountModerationService.normalizeStatus(userData['status']);
      if (AccountModerationService.isBlockedStatus(userStatus)) {
        return;
      }
      final data = doc.data() ?? <String, dynamic>{};
      final hasLocation = data['location'] is Map &&
          data['location']['lat'] != null &&
          data['location']['lng'] != null;

      if (!doc.exists) {
        await hospitalRef.set({
          'hospitalName': userData['name'] ?? '',
          'email': email ?? '',
          'phone': userData['phone'] ?? '',
          'address': userData['address'] ?? '',
          'city': userData['city'] ?? '',
          'pincode': userData['pincode'] ?? '',
          'contactName': userData['contactName'] ?? '',
          'isVerified': userData['isVerified'] == true,
          'status': AccountModerationService.activeStatus,
          'documents': [],
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
        });
      }

      if (!hasLocation) {
        try {
          final position = await LocationService.getCurrentLocation();
          final location = {
            'lat': position.latitude,
            'lng': position.longitude,
          };
          await hospitalRef.set({
            'location': location,
            'locationCapturedAt': Timestamp.now(),
          }, SetOptions(merge: true));
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'location': location,
          }, SetOptions(merge: true));
        } catch (e) {
          debugPrint('Hospital location bootstrap skipped: $e');
        }
      }
    } catch (e) {
      debugPrint('Hospital init error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final uid = currentUser.uid;
    final screens = <Widget>[
      InventoryScreen(),
      RequestScreen(),
      MapScreen(),
      HistoryHubScreen(
        title: 'Hospital History',
        requesterId: uid,
        requestOwnerKey: 'hospitalId',
        donorId: uid,
        donorName: 'Hospital',
        showCertificate: true,
      ),
      StatusScreen(),
    ];

    return DashboardExitGuard(
      currentIndex: selectedIndex,
      onGoHome: () => setState(() => selectedIndex = 0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final status = AccountModerationService.normalizeStatus(data['status']);
          if (AccountModerationService.isBlockedStatus(status)) {
            _handleBlockedAccount(context);
            return const Scaffold(
              body: Center(child: CircularProgressIndicator()),
            );
          }

          return Scaffold(
            body: IndexedStack(
              index: selectedIndex,
              children: screens,
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: selectedIndex,
              selectedItemColor: Colors.red,
              type: BottomNavigationBarType.fixed,
              onTap: (i) => setState(() => selectedIndex = i),
              items: [
                BottomNavigationBarItem(
                  icon: const Icon(Icons.inventory),
                  label: AppText.text(context, 'inventory'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.send),
                  label: AppText.text(context, 'requests'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.map),
                  label: AppText.text(context, 'map'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.history),
                  label: AppText.text(context, 'history'),
                ),
                BottomNavigationBarItem(
                  icon: const Icon(Icons.verified),
                  label: AppText.text(context, 'status'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

