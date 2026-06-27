import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../constants/blood_types.dart';
import '../common/settings_screen.dart';
import '../../utils/app_text.dart';
import '../../widgets/common/app_header_title.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  ({String label, Color color, IconData icon}) _donorStatus(int donations) {
    if (donations >= 10) {
      return (
        label: 'Gold',
        color: const Color(0xFFD4A017),
        icon: Icons.workspace_premium,
      );
    }
    if (donations >= 5) {
      return (
        label: 'Silver',
        color: const Color(0xFF7D8A97),
        icon: Icons.military_tech,
      );
    }
    if (donations >= 1) {
      return (
        label: 'Bronze',
        color: const Color(0xFF9C5F3C),
        icon: Icons.verified_outlined,
      );
    }
    return (
      label: 'Starter',
      color: const Color(0xFF4E7A5D),
      icon: Icons.eco_outlined,
    );
  }

  Future<void> confirmLogout(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(AppText.text(context, 'logout')),
        content: const Text('Do you really want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppText.text(context, 'cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: Text(AppText.text(context, 'logout')),
          ),
        ],
      ),
    );

    if (result == true) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: AppHeaderTitle(title: AppText.text(context, 'my_profile')),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(
                    title: AppText.text(context, 'user_settings'),
                    collectionName: 'users',
                    documentId: userId,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.red),
            );
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;
          final name = data['name'] ?? 'User';
          final blood = data['bloodGroup'] ?? 'N/A';
          final donations = (data['donations'] as num?)?.toInt() ?? 0;
          final donorStatus = _donorStatus(donations);

          return SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.red, Colors.red.shade300],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: Colors.white,
                          child: Text(
                            name[0],
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            blood,
                            style: const TextStyle(
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Member since ${data['createdAt'] != null ? (data['createdAt'] as Timestamp).toDate().year : ''}',
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (_) => EditProfileDialog(data: data),
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: Colors.red,
                              ),
                              child: Text(AppText.text(context, 'edit_profile')),
                            ),
                            const SizedBox(width: 10),
                            // OutlinedButton.icon(
                            //   onPressed: () {
                            //     Navigator.push(
                            //       context,
                            //       MaterialPageRoute(
                            //         builder: (_) => SettingsScreen(
                            //           title: 'User Settings',
                            //           collectionName: 'users',
                            //           documentId: userId,
                            //         ),
                            //       ),
                            //     );
                            //   },
                            //   style: OutlinedButton.styleFrom(
                            //     foregroundColor: Colors.white,
                            //     side: const BorderSide(color: Colors.white70),
                            //   ),
                            //   icon: const Icon(Icons.settings_outlined),
                            //   label: const Text('Settings'),
                            // ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Your Stats',
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        StatItem(
                          icon: Icons.bloodtype,
                          title: donations.toString(),
                          subtitle: 'Donations',
                          color: Colors.red,
                        ),
                        StatItem(
                          icon: donorStatus.icon,
                          title: donorStatus.label,
                          subtitle: 'Status',
                          color: donorStatus.color,
                        ),
                        StatItem(
                          icon: Icons.calendar_today,
                          title: data['lastDonationAt'] is Timestamp
                              ? '${(data['lastDonationAt'] as Timestamp).toDate().day}/${(data['lastDonationAt'] as Timestamp).toDate().month}'
                              : 'None',
                          subtitle: 'Last',
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  SectionCard(
                    title: 'Contact Info',
                    child: Column(
                      children: [
                        InfoTile(Icons.phone, data['phone'] ?? '', 'Phone'),
                        InfoTile(Icons.email, data['email'] ?? '', 'Email'),
                        InfoTile(Icons.location_on, data['address'] ?? '', 'Address'),
                        InfoTile(Icons.location_on, data['pincode'] ?? '', 'Pincode'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: ListTile(
                      leading: const Icon(Icons.logout, color: Colors.red),
                      title: Text(AppText.text(context, 'logout')),
                      onTap: () => confirmLogout(context),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class EditProfileDialog extends StatefulWidget {
  final Map<String, dynamic> data;

  const EditProfileDialog({super.key, required this.data});

  @override
  State<EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends State<EditProfileDialog> {
  late TextEditingController name;
  late TextEditingController phone;
  late TextEditingController address;
  late TextEditingController pincode;
  late String selectedBloodGroup;

  @override
  void initState() {
    super.initState();
    name = TextEditingController(text: widget.data['name']);
    phone = TextEditingController(text: widget.data['phone']);
    address = TextEditingController(text: widget.data['address']);
    pincode = TextEditingController(text: widget.data['pincode']);
    final currentBloodGroup = (widget.data['bloodGroup'] ?? '').toString();
    selectedBloodGroup = bloodTypes.contains(currentBloodGroup)
        ? currentBloodGroup
        : bloodTypes.first;
  }

  @override
  void dispose() {
    name.dispose();
    phone.dispose();
    address.dispose();
    pincode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      title: const Text('Edit Profile'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: name, decoration: const InputDecoration(labelText: 'Name')),
            TextField(controller: phone, decoration: const InputDecoration(labelText: 'Phone')),
            TextField(controller: address, decoration: const InputDecoration(labelText: 'Address')),
            TextField(controller: pincode, decoration: const InputDecoration(labelText: 'Pincode')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: selectedBloodGroup,
              decoration: InputDecoration(
                labelText: AppText.text(context, 'blood_group'),
              ),
              items: bloodTypes
                  .map(
                    (bloodType) => DropdownMenuItem<String>(
                      value: bloodType,
                      child: Text(bloodType),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  selectedBloodGroup = value;
                });
              },
            ),
          ],
        ),
      ),
      actions: [
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () async {
            await FirebaseFirestore.instance.collection('users').doc(uid).update({
              'name': name.text,
              'phone': phone.text,
              'address': address.text,
              'pincode': pincode.text,
              'bloodGroup': selectedBloodGroup,
            });

            if (!context.mounted) return;
            Navigator.pop(context);
          },
          child: Text(AppText.text(context, 'save')),
        )
      ],
    );
  }
}

class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
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
          Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class StatItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const StatItem({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        CircleAvatar(
          backgroundColor: color.withValues(alpha: 0.2),
          child: Icon(icon, color: color),
        ),
        const SizedBox(height: 6),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        Text(subtitle, style: const TextStyle(color: Colors.grey)),
      ],
    );
  }
}

class InfoTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;

  const InfoTile(this.icon, this.value, this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Colors.grey.shade200,
        child: Icon(icon),
      ),
      title: Text(value),
      subtitle: Text(label),
    );
  }
}
