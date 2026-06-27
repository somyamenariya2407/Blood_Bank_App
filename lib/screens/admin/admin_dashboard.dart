import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../services/app_config_service.dart';
import '../../utils/name_resolver.dart';
import '../../widgets/common/dashboard_exit_guard.dart';
import 'admin_analytics_screen.dart';
import 'hospital_management_screen.dart';
import 'user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int currentIndex = 0;

  void logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Logout"),
        content: const Text("Do you really want to logout?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Logout"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  final List<Widget> screens = [
    const DashboardHome(),
    const UserManagementScreen(),
    const HospitalManagementScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return DashboardExitGuard(
      currentIndex: currentIndex,
      onGoHome: () => setState(() => currentIndex = 0),
      child: Scaffold(
        backgroundColor: Colors.grey.shade100,
        appBar: currentIndex == 0
            ? AppBar(
                title: const Text("BloodLink Admin"),
                actions: [
                  const Padding(
                    padding: EdgeInsets.only(right: 10),
                    child: Chip(label: Text("Admin")),
                  ),
                  IconButton(
                    icon: const Icon(Icons.logout),
                    onPressed: logout,
                  )
                ],
              )
            : null,
        body: screens[currentIndex],
        bottomNavigationBar: BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => setState(() => currentIndex = index),
          selectedItemColor: const Color(0xFFB71C1C),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: "Dashboard"),
            BottomNavigationBarItem(icon: Icon(Icons.people), label: "Users"),
            BottomNavigationBarItem(icon: Icon(Icons.local_hospital), label: "Hospitals"),
          ],
        ),
      ),
    );
  }
}

////////////////////////////////////////////////////////////
/// 🔥 DASHBOARD HOME (UPGRADED)
////////////////////////////////////////////////////////////
class DashboardHome extends StatelessWidget {
  const DashboardHome({super.key});

  Future<Map<String, int>> getCounts() async {
    final users = await FirebaseFirestore.instance.collection('users').get();

    final sos = await FirebaseFirestore.instance
        .collection('sos_requests')
        .where('status', isEqualTo: 'active')
        .get();

    final donations =
    await FirebaseFirestore.instance.collection('donations').get();

    int totalUsers = 0;
    int hospitals = 0;
    int pending = 0;
    int activeDonors = 0;

    for (var doc in users.docs) {
      final data = doc.data();

      if (data['role'] == 'user') {
        totalUsers++;
        if (data['isAvailable'] == true) activeDonors++;
      }

      if (data['role'] == 'hospital') {
        hospitals++;
        if (data['isVerified'] != true) pending++;
      }
    }

    return {
      'users': totalUsers,
      'hospitals': hospitals,
      'pending': pending,
      'sos': sos.docs.length,
      'donations': donations.docs.length,
      'activeDonors': activeDonors,
    };
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, int>>(
      future: getCounts(),
      builder: (context, snapshot) {

        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        final data = snapshot.data!;

        return SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [

              ////////////////////////////////////////////////////
              /// 🔥 KPI CARDS
              ////////////////////////////////////////////////////
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  kpi("Users", data['users'].toString(), Icons.people),
                  kpi("Hospitals", data['hospitals'].toString(), Icons.local_hospital),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  kpi("Pending", data['pending'].toString(), Icons.pending),
                  kpi("SOS", data['sos'].toString(), Icons.warning),
                ],
              ),

              const SizedBox(height: 12),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  kpi("Donations", data['donations'].toString(), Icons.favorite),
                  kpi("Active", data['activeDonors'].toString(), Icons.online_prediction),
                ],
              ),

              const SizedBox(height: 20),

              ////////////////////////////////////////////////////
              /// 🔥 ALERT CARD
              ////////////////////////////////////////////////////
              if (data['pending']! > 0)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.hourglass_bottom, color: Colors.white),
                      const SizedBox(width: 10),

                      Expanded(
                        child: Text(
                          "${data['pending']} hospitals waiting approval",
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),

                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const HospitalManagementScreen(),
                            ),
                          );
                        },
                        child: const Text("Review"),
                      )
                    ],
                  ),
                ),

              const SizedBox(height: 20),

              ////////////////////////////////////////////////////
              /// 🔥 QUICK ACTIONS
              ////////////////////////////////////////////////////
              quickTile(context, "User Management", Icons.people, const UserManagementScreen()),
              quickTile(context, "Hospital Management", Icons.local_hospital, const HospitalManagementScreen()),
              quickTile(context, "Analytics", Icons.bar_chart, const AdminAnalyticsScreen()),

              const SizedBox(height: 14),
              _buildSosRadiusCard(context),

              const SizedBox(height: 20),

              ////////////////////////////////////////////////////
              /// 🔥 LIVE ACTIVITY (REAL DATA)
              ////////////////////////////////////////////////////
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Live SOS Requests",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('sos_requests')
                    .where('status', isEqualTo: 'active')
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {

                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Text("No active SOS");
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      return activityTile(
                        "${data['bloodType'] ?? 'N/A'} - ${data['units'] ?? 0} units - ${data['priority'] ?? 'medium'}\n${data['name'] ?? 'Requester'}",
                      );
                    }).toList(),
                  );
                },
              ),

              const SizedBox(height: 20),

              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Recent Donations",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 10),

              StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance
                    .collection('donations')
                    .orderBy('createdAt', descending: true)
                    .limit(5)
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final docs = snapshot.data!.docs;

                  if (docs.isEmpty) {
                    return const Text("No donations yet");
                  }

                  return Column(
                    children: docs.map((doc) {
                      final data = doc.data() as Map<String, dynamic>;

                      return donationActivityTile(
                        bloodType: data['bloodType']?.toString() ?? 'N/A',
                        units: data['units'] ?? 1,
                        donorId: data['donorId']?.toString(),
                        receiverId: data['receiverId']?.toString(),
                        donorName: data['donorName']?.toString(),
                        receiverName: data['receiverName']?.toString(),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  ////////////////////////////////////////////////////////////
  Widget kpi(String title, String value, IconData icon) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, color: const Color(0xFFB71C1C)),
            const SizedBox(height: 8),
            Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  Widget quickTile(BuildContext context, String title, IconData icon, Widget screen) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, color: const Color(0xFFB71C1C)),
            const SizedBox(width: 10),
            Expanded(child: Text(title)),
            const Icon(Icons.arrow_forward_ios, size: 16)
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  Widget activityTile(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.circle, size: 8),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  Widget _buildSosRadiusCard(BuildContext context) {
    return StreamBuilder<double>(
      stream: AppConfigService.sosRadiusKmStream(),
      builder: (context, snapshot) {
        final radiusKm =
            snapshot.data ?? AppConfigService.defaultSosRadiusKm;

        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.radar, color: Color(0xFFB71C1C)),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Text(
                      'SOS Radius Control',
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: () => _showSosRadiusDialog(context, radiusKm),
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Change'),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                'Nearby SOS alerts are currently sent within ${radiusKm.toStringAsFixed(radiusKm.truncateToDouble() == radiusKm ? 0 : 1)} km.',
                style: const TextStyle(color: Colors.black54, height: 1.35),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _showSosRadiusDialog(
    BuildContext context,
    double currentRadiusKm,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final controller = TextEditingController(
      text: currentRadiusKm.toStringAsFixed(
        currentRadiusKm.truncateToDouble() == currentRadiusKm ? 0 : 1,
      ),
    );

    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Set SOS Radius'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Enter the nearby distance in kilometers for SOS alerts and nearby SOS lists.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: controller,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Radius in km',
                hintText: '20',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final parsed = double.tryParse(controller.text.trim());
              if (parsed == null) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Please enter a valid distance.'),
                  ),
                );
                return;
              }

              await AppConfigService.updateSosRadiusKm(parsed);
              if (!context.mounted) return;
              Navigator.pop(context, true);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (saved == true && context.mounted) {
      messenger.showSnackBar(
        const SnackBar(content: Text('SOS radius updated successfully.')),
      );
    }
  }

  Widget donationActivityTile({
    required String bloodType,
    required dynamic units,
    required String? donorId,
    required String? receiverId,
    String? donorName,
    String? receiverName,
  }) {
    return FutureBuilder<List<String>>(
      future: Future.wait([
        donorName != null && donorName.trim().isNotEmpty
            ? Future.value(donorName)
            : NameResolver.userOrHospitalName(donorId),
        receiverName != null && receiverName.trim().isNotEmpty
            ? Future.value(receiverName)
            : NameResolver.userOrHospitalName(receiverId),
      ]),
      builder: (context, snapshot) {
        final donorName = snapshot.data?[0] ?? "Loading...";
        final receiverName = snapshot.data?[1] ?? "Loading...";

        return activityTile(
          "$bloodType - $units unit donated\n$donorName to $receiverName",
        );
      },
    );
  }
}

