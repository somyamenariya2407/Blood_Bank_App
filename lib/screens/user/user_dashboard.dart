import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../common/history_hub_screen.dart';
import '../../services/account_moderation_service.dart';
import '../../utils/app_text.dart';
import '../../widgets/common/dashboard_exit_guard.dart';
import 'home_screen.dart';
import 'profile_screen.dart';
import 'sos_screen.dart';

class UserDashboard extends StatefulWidget {
  const UserDashboard({super.key});

  @override
  State<UserDashboard> createState() => _UserDashboardState();
}

class _UserDashboardState extends State<UserDashboard> {
  int _selectedIndex = 0;

  void _handleBlockedAccount(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await FirebaseAuth.instance.signOut();
      if (!context.mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final userId = currentUser.uid;
    final theme = Theme.of(context);
    final screens = <Widget>[
      const HomeScreen(),
      const SOSScreen(),
      HistoryHubScreen(
        title: 'User History',
        requesterId: userId,
        requestOwnerKey: 'userId',
        donorId: userId,
        donorName: 'User',
        showCertificate: true,
      ),
      const ProfileScreen(),
    ];

    return DashboardExitGuard(
      currentIndex: _selectedIndex,
      onGoHome: () => setState(() => _selectedIndex = 0),
      child: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
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
            backgroundColor: theme.scaffoldBackgroundColor,
            body: IndexedStack(
              index: _selectedIndex,
              children: screens,
            ),
            bottomNavigationBar: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    blurRadius: 15,
                    color: Colors.black.withValues(alpha: 0.08),
                    offset: const Offset(0, 5),
                  )
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: BottomNavigationBar(
                  currentIndex: _selectedIndex,
                  onTap: _onItemTapped,
                  selectedItemColor: theme.colorScheme.primary,
                  unselectedItemColor: theme.colorScheme.onSurfaceVariant,
                  elevation: 0,
                  backgroundColor: theme.colorScheme.surface,
                  type: BottomNavigationBarType.fixed,
                  items: [
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.home_outlined),
                      activeIcon: const Icon(Icons.home),
                      label: AppText.text(context, 'home'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.warning_amber_outlined),
                      activeIcon: const Icon(Icons.warning),
                      label: AppText.text(context, 'sos'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.history_outlined),
                      activeIcon: const Icon(Icons.history),
                      label: AppText.text(context, 'history'),
                    ),
                    BottomNavigationBarItem(
                      icon: const Icon(Icons.person_outline),
                      activeIcon: const Icon(Icons.person),
                      label: AppText.text(context, 'profile'),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
