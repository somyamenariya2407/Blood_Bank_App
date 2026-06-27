import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../utils/name_resolver.dart';

class AdminAnalyticsScreen extends StatelessWidget {
  const AdminAnalyticsScreen({super.key});

  ////////////////////////////////////////////////////////////
  Future<Map<String, int>> getAnalytics() async {
    final usersSnap =
    await FirebaseFirestore.instance.collection('users').get();

    final sosSnap = await FirebaseFirestore.instance
        .collection('sos_requests')
        .where('status', isEqualTo: 'active')
        .get();

    final donationSnap =
    await FirebaseFirestore.instance.collection('donations').get();

    int users = 0;
    int hospitals = 0;
    int verified = 0;
    int pending = 0;

    for (var doc in usersSnap.docs) {
      final data = doc.data();

      if (data['role'] == 'user') users++;

      if (data['role'] == 'hospital') {
        hospitals++;
        if (data['isVerified'] == true) {
          verified++;
        } else {
          pending++;
        }
      }
    }

    return {
      'users': users,
      'hospitals': hospitals,
      'verified': verified,
      'pending': pending,
      'sos': sosSnap.docs.length,
      'donations': donationSnap.docs.length,
    };
  }

  ////////////////////////////////////////////////////////////
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Analytics")),
      backgroundColor: Colors.grey.shade100,

      body: FutureBuilder<Map<String, int>>(
        future: getAnalytics(),
        builder: (context, snapshot) {

          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData) {
            return const Center(child: Text("No Data"));
          }

          final data = snapshot.data!;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [

                buildStats(data),

                const SizedBox(height: 20),

                buildPieChart(
                  "Users vs Hospitals",
                  data['users'] ?? 0,
                  data['hospitals'] ?? 0,
                ),

                const SizedBox(height: 20),

                buildPieChart(
                  "Verified vs Pending",
                  data['verified'] ?? 0,
                  data['pending'] ?? 0,
                ),

                const SizedBox(height: 20),

                buildBarChart(data),

                const SizedBox(height: 20),

                buildInsights(data),

                const SizedBox(height: 20),

                buildLiveSOSList(),

                const SizedBox(height: 20),

                buildDonationList(),
              ],
            ),
          );
        },
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  Widget buildStats(Map<String, int> data) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            statCard("Users", data['users'] ?? 0),
            statCard("Hospitals", data['hospitals'] ?? 0),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            statCard("SOS", data['sos'] ?? 0),
            statCard("Donations", data['donations'] ?? 0),
          ],
        ),
      ],
    );
  }

  ////////////////////////////////////////////////////////////
  Widget statCard(String title, int value) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text("$value",
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            Text(title, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// PIE CHART (SAFE)
  ////////////////////////////////////////////////////////////
  Widget buildPieChart(String title, int a, int b) {
    if (a == 0 && b == 0) {
      return const Text("No data for chart");
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          Expanded(
            child: PieChart(
              PieChartData(
                sections: [
                  PieChartSectionData(value: a.toDouble(), title: "$a"),
                  PieChartSectionData(value: b.toDouble(), title: "$b"),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  /// BAR CHART (SAFE)
  ////////////////////////////////////////////////////////////
  Widget buildBarChart(Map<String, int> data) {
    final sos = data['sos'] ?? 0;
    final donations = data['donations'] ?? 0;

    if (sos == 0 && donations == 0) {
      return const Text("No activity data");
    }

    return Container(
      height: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: BarChart(
        BarChartData(
          borderData: FlBorderData(show: false),
          barGroups: [
            BarChartGroupData(
              x: 0,
              barRods: [BarChartRodData(toY: sos.toDouble())],
            ),
            BarChartGroupData(
              x: 1,
              barRods: [BarChartRodData(toY: donations.toDouble())],
            ),
          ],
        ),
      ),
    );
  }

  ////////////////////////////////////////////////////////////
  Widget buildInsights(Map<String, int> data) {
    List<String> insights = [];

    if ((data['pending'] ?? 0) > 0) {
      insights.add("${data['pending']} hospitals pending");
    }

    if ((data['sos'] ?? 0) > 5) {
      insights.add("High SOS activity 🚨");
    }

    if ((data['donations'] ?? 0) > 10) {
      insights.add("Good donation rate ❤️");
    }

    if (insights.isEmpty) {
      insights.add("System stable ✅");
    }

    return Column(
      children: insights.map((e) => insightTile(e)).toList(),
    );
  }

  Widget buildLiveSOSList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('sos_requests')
          .where('status', isEqualTo: 'active')
          .limit(6)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return sectionList(
          title: "Live SOS Requests",
          emptyText: "No active SOS",
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return listTile(
              "${data['bloodType'] ?? 'N/A'} - ${data['units'] ?? 0} units",
              "${data['priority'] ?? 'medium'} priority - ${data['name'] ?? 'Requester'}",
              Icons.warning,
            );
          }).toList(),
        );
      },
    );
  }

  Widget buildDonationList() {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('donations')
          .orderBy('createdAt', descending: true)
          .limit(6)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];

        return sectionList(
          title: "Recent Donations",
          emptyText: "No donations yet",
          children: docs.map((doc) {
            final data = doc.data() as Map<String, dynamic>;
            return donationListTile(
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
    );
  }

  Widget donationListTile({
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

        return listTile(
          "$bloodType - $units unit",
          "$donorName to $receiverName",
          Icons.favorite,
        );
      },
    );
  }

  Widget sectionList({
    required String title,
    required String emptyText,
    required List<Widget> children,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          if (children.isEmpty) Text(emptyText) else ...children,
        ],
      ),
    );
  }

  Widget listTile(String title, String subtitle, IconData icon) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: Colors.red),
      title: Text(title),
      subtitle: Text(subtitle),
    );
  }

  ////////////////////////////////////////////////////////////
  Widget insightTile(String text) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.info, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
