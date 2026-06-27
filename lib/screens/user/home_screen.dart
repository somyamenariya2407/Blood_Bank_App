import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../utils/app_text.dart';
import '../../widgets/common/app_header_title.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,

      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          final userData = snapshot.data!;
          final name = userData['name'] ?? 'User';
          final blood = userData['bloodGroup'] ?? 'N/A';
          final isAvailable = userData['isAvailable'] ?? true;
          final donations = userData['donations'] ?? 0;
          final lives = userData['livesSaved'] ?? 0;
          final lastDonationAt = userData['lastDonationAt'] as Timestamp?;

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  HeaderSection(name: name, userId: userId),
                  const SizedBox(height: 20),

                  AvailabilityCard(
                    isAvailable: isAvailable,
                    lastDonationAt: lastDonationAt,
                  ),
                  const SizedBox(height: 20),

                  StatsRow(
                    blood: blood,
                    donations: donations.toString(),
                    lives: lives.toString(),
                  ),

                  const SizedBox(height: 20),

                  const BloodStockSection(),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

///////////////////////////////////////////////////////////
/// 🔴 HEADER
///////////////////////////////////////////////////////////

class HeaderSection extends StatelessWidget {
  final String name;
  final String userId;

  const HeaderSection({super.key, required this.name, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const AppLogoBadge(size: 46, radius: 14),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${AppText.text(context, 'welcome_back')} 👋',
                style: const TextStyle(color: Colors.grey),
              ),
              Text(
                name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),

        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('notifications')
              .where('receiverId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .snapshots(),
          builder: (context, snapshot) {
            final count = snapshot.data?.docs.length ?? 0;

            return GestureDetector(
              onTap: () => showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                ),
                builder: (_) => SafeArea(
                  child: FractionallySizedBox(
                    heightFactor: 0.72,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: NotificationsSection(userId: userId),
                    ),
                  ),
                ),
              ),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.notifications_none),
                  ),
                  if (count > 0)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: CircleAvatar(
                        radius: 9,
                        backgroundColor: Colors.red,
                        child: Text(
                          count > 9 ? "9+" : "$count",
                          style: const TextStyle(
                              color: Colors.white, fontSize: 10),
                        ),
                      ),
                    ),
                ],
              ),
            );
          },
        )
      ],
    );
  }
}

///////////////////////////////////////////////////////////
/// 🟢 AVAILABILITY CARD (FIXED)
///////////////////////////////////////////////////////////

class AvailabilityCard extends StatelessWidget {
  final bool isAvailable;
  final Timestamp? lastDonationAt;

  const AvailabilityCard({
    super.key,
    required this.isAvailable,
    required this.lastDonationAt,
  });

  static const int _cooldownDays = 1;

  bool get _isOnCooldown {
    if (lastDonationAt == null) return false;
    final lastDate = lastDonationAt!.toDate();
    return DateTime.now().difference(lastDate).inDays < _cooldownDays;
  }

  String get _lastDonationLabel {
    if (lastDonationAt == null) return '';
    final date = lastDonationAt!.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  String get _nextDonationLabel {
    if (lastDonationAt == null) return '';
    final nextDate = lastDonationAt!.toDate().add(const Duration(days: _cooldownDays));
    return '${nextDate.day}/${nextDate.month}/${nextDate.year}';
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF151515), Color(0xFF2A2A2A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  AppText.text(context, 'available_to_donate'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Switch(
                value: isAvailable,
                activeThumbColor: Colors.red,
                onChanged: (value) async {
                  if (value && _isOnCooldown) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          AppText.text(
                            context,
                            'cannot_turn_on_yet',
                            params: {'date': _lastDonationLabel},
                          ),
                        ),
                      ),
                    );
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(userId)
                        .update({'isAvailable': false});
                    return;
                  }

                  await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .update({'isAvailable': value});
                },
              )
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _isOnCooldown
                ? AppText.text(context, 'recovery_mode_message')
                : isAvailable
                    ? AppText.text(context, 'visible_to_nearby')
                    : AppText.text(context, 'requests_only_mode'),
            style: const TextStyle(color: Colors.white70),
          ),
          if (_isOnCooldown) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.white70, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppText.text(context, 'last_and_next_donation', params: {
                        'lastDate': _lastDonationLabel,
                        'nextDate': _nextDonationLabel,
                      }),
                      style: const TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////
/// 📊 STATS
///////////////////////////////////////////////////////////

class StatCard extends StatelessWidget {
  final String title;
  final String value;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withValues(alpha: 0.05),
          )
        ],
      ),
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          )
        ],
      ),
    );
  }
}

class StatsRow extends StatelessWidget {
  final String blood;
  final String donations;
  final String lives;

  const StatsRow({
    super.key,
    required this.blood,
    required this.donations,
    required this.lives,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: StatCard(title: AppText.text(context, 'blood'), value: blood)),
        const SizedBox(width: 10),
        Expanded(child: StatCard(title: AppText.text(context, 'donations'), value: donations)),
        const SizedBox(width: 10),
        Expanded(child: StatCard(title: AppText.text(context, 'lives'), value: lives)),
      ],
    );
  }
}

///////////////////////////////////////////////////////////
/// 🩸 BLOOD STOCK
///////////////////////////////////////////////////////////

class BloodStockSection extends StatelessWidget {
  const BloodStockSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          AppText.text(context, 'nearby_blood_stock'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('hospitals').snapshots(),
          builder: (context, snapshot) {
            final totals = <String, int>{
              "A+": 0,
              "A-": 0,
              "B+": 0,
              "B-": 0,
              "O+": 0,
              "O-": 0,
              "AB+": 0,
              "AB-": 0,
            };

            for (final doc in snapshot.data?.docs ?? []) {
              final data = doc.data() as Map<String, dynamic>;
              final inventory = data['inventory'];
              if (inventory is! Map) continue;

              for (final type in totals.keys) {
                totals[type] = totals[type]! + ((inventory[type] ?? 0) as num).toInt();
              }
            }

            final bloodData = totals.entries.map((entry) {
              final units = entry.value;
              final status = units <= 5
                  ? "critical"
                  : units <= 20
                      ? "low"
                      : "adequate";
              return {
                "type": entry.key,
                "units": units.toString(),
                "status": status,
              };
            }).toList();

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: bloodData.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.85,
              ),
              itemBuilder: (context, index) {
                final item = bloodData[index];
                return BloodCard(item: item);
              },
            );
          },
        )
      ],
    );
  }
}

class BloodCard extends StatelessWidget {
  final Map item;
  const BloodCard({super.key, required this.item});

  Color getStatusColor(String status) {
    switch (status) {
      case "critical":
        return Colors.red;
      case "low":
        return Colors.orange;
      default:
        return Colors.green;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withValues(alpha: 0.05),
          )
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            item["type"],
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 5),
          Text("${item["units"]} units"),
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: getStatusColor(item["status"]).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              item["status"],
              style: TextStyle(
                fontSize: 10,
                color: getStatusColor(item["status"]),
              ),
            ),
          )
        ],
      ),
    );
  }
}

///////////////////////////////////////////////////////////
/// 🔔 NOTIFICATIONS
///////////////////////////////////////////////////////////

class NotificationsSection extends StatelessWidget {
  final String userId;

  const NotificationsSection({super.key, required this.userId});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                "Recent Updates",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            TextButton(
              onPressed: () async {
                final docs = await FirebaseFirestore.instance
                    .collection('notifications')
                    .where('receiverId', isEqualTo: userId)
                    .where('isRead', isEqualTo: false)
                    .get();

                final batch = FirebaseFirestore.instance.batch();
                for (final doc in docs.docs) {
                  batch.update(doc.reference, {'isRead': true});
                }
                await batch.commit();
              },
              child: const Text("Mark all as read"),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('notifications')
                .where('receiverId', isEqualTo: userId)
                .limit(20)
                .snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text("Unable to load updates");
              }

              if (!snapshot.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: Colors.red),
                );
              }

              if (snapshot.data!.docs.isEmpty) {
                return const Text("No updates yet");
              }

              final docs = snapshot.data!.docs.toList()
                ..sort((a, b) {
                  final ad = (a.data() as Map)['createdAt'];
                  final bd = (b.data() as Map)['createdAt'];
                  if (ad is! Timestamp || bd is! Timestamp) return 0;
                  return bd.compareTo(ad);
                });

              return ListView.builder(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).viewPadding.bottom + 12,
                ),
                itemCount: docs.length,
                itemBuilder: (context, index) {
                  final doc = docs[index];
                  final data = doc.data() as Map;

                  return GestureDetector(
                    onTap: () => doc.reference.update({'isRead': true}),
                    child: UpdateCard(
                      title: (data['title'] ?? 'Notification').toString(),
                      subtitle: (data['message'] ?? '').toString(),
                      isRead: data['isRead'] == true,
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class UpdateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool isRead;

  const UpdateCard({
    super.key,
    required this.title,
    required this.subtitle,
    required this.isRead,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : Colors.red.shade50,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            blurRadius: 6,
            color: Colors.black.withValues(alpha: 0.05),
          )
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.notifications, color: Colors.red),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
