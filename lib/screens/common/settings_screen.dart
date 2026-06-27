import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../services/app_preferences_service.dart';
import '../../utils/app_text.dart';

class SettingsScreen extends StatelessWidget {
  final String title;
  final String collectionName;
  final String documentId;

  const SettingsScreen({
    super.key,
    required this.title,
    required this.collectionName,
    required this.documentId,
  });

  Future<void> _updateSetting(String key, dynamic value) async {
    await FirebaseFirestore.instance
        .collection(collectionName)
        .doc(documentId)
        .set({
      'settings': {key: value},
    }, SetOptions(merge: true));

    if (collectionName == 'hospitals') {
      await FirebaseFirestore.instance.collection('users').doc(documentId).set({
        'settings': {key: value},
      }, SetOptions(merge: true));
    }
  }

  void _showPrivacyPolicy(BuildContext context) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppText.text(context, 'privacy_policy_title'),
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 12),
            Text(AppText.text(context, 'privacy_policy_text_1')),
            SizedBox(height: 8),
            Text(AppText.text(context, 'privacy_policy_text_2')),
            SizedBox(height: 8),
            Text(AppText.text(context, 'privacy_policy_text_3')),
          ],
        ),
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final messenger = ScaffoldMessenger.of(context);

    try {
      final changed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Change Password'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Current Password',
                    prefixIcon: Icon(Icons.lock_outline),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'New Password',
                    prefixIcon: Icon(Icons.lock_reset),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Confirm New Password',
                    prefixIcon: Icon(Icons.verified_user_outlined),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final newPassword = newPasswordController.text.trim();
                final confirmPassword = confirmPasswordController.text.trim();

                if (newPassword != confirmPassword) {
                  messenger.showSnackBar(
                    const SnackBar(
                      content: Text(
                        'New password and confirm password must match.',
                      ),
                    ),
                  );
                  return;
                }

                try {
                  final user = FirebaseAuth.instance.currentUser;
                  final email = user?.email?.trim();

                  if (user == null || email == null || email.isEmpty) {
                    throw Exception('Unable to verify the current account.');
                  }

                  if (currentPasswordController.text.trim().isEmpty) {
                    throw Exception('Please enter your current password.');
                  }

                  if (newPassword.length < 6) {
                    throw Exception(
                      'New password must be at least 6 characters long.',
                    );
                  }

                  final credential = EmailAuthProvider.credential(
                    email: email,
                    password: currentPasswordController.text.trim(),
                  );

                  await user.reauthenticateWithCredential(credential);
                  await user.updatePassword(newPassword);
                  if (!dialogContext.mounted) return;
                  Navigator.of(dialogContext).pop(true);
                } catch (e) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        e.toString().replaceFirst('Exception: ', '').trim(),
                      ),
                    ),
                  );
                }
              },
              child: const Text('Update'),
            ),
          ],
        ),
      );

      if (changed == true && context.mounted) {
        await Future<void>.delayed(Duration.zero);
        if (!context.mounted) return;
        await showDialog<void>(
          context: context,
          builder: (successDialogContext) => AlertDialog(
            title: const Text('Success'),
            content: const Text('Password updated successfully.'),
            actions: [
              TextButton(
                onPressed: () =>
                    Navigator.of(successDialogContext).pop(),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } finally {
      currentPasswordController.dispose();
      newPasswordController.dispose();
      confirmPasswordController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(title: Text(title)),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection(collectionName)
            .doc(documentId)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data!.data() as Map<String, dynamic>? ?? {};
          final settings = Map<String, dynamic>.from(data['settings'] ?? {});
          final notificationsEnabled =
              settings['notificationsEnabled'] != false;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x12000000),
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppText.text(context, 'preferences'),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    SizedBox(height: 6),
                    Text(
                      AppText.text(context, 'settings_summary'),
                      style: TextStyle(
                        color: theme.colorScheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.translate_outlined),
                      title: Text(AppText.text(context, 'change_language')),
                      subtitle:
                          Text(AppText.text(context, 'change_language_subtitle')),
                      trailing: ValueListenableBuilder<Locale>(
                        valueListenable: AppPreferencesService.locale,
                        builder: (context, locale, _) {
                          final languageCode =
                              AppPreferencesService.normalizeLanguageCode(
                            locale.languageCode,
                          );

                          return DropdownButton<String>(
                            value: languageCode,
                            underline: const SizedBox.shrink(),
                            items: [
                              DropdownMenuItem(
                                value: 'en',
                                child: Text(AppText.text(context, 'english')),
                              ),
                              DropdownMenuItem(
                                value: 'hi',
                                child: Text(AppText.text(context, 'hindi')),
                              ),
                            ],
                            onChanged: (value) async {
                              if (value == null) return;
                              final normalizedValue =
                                  AppPreferencesService.normalizeLanguageCode(
                                value,
                              );
                              await _updateSetting(
                                'languageCode',
                                normalizedValue,
                              );
                              AppPreferencesService.setLanguageCode(
                                normalizedValue,
                              );
                            },
                          );
                        },
                      ),
                    ),
                    const Divider(),
                    SwitchListTile(
                      value: notificationsEnabled,
                      contentPadding: EdgeInsets.zero,
                      title: Text(AppText.text(context, 'notifications')),
                      subtitle: Text(
                        AppText.text(context, 'notifications_subtitle'),
                      ),
                      onChanged: (value) async {
                        await _updateSetting('notificationsEnabled', value);
                      },
                    ),
                    const Divider(),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.lock_reset_outlined),
                      title: const Text('Change Password'),
                      subtitle: const Text(
                        'Update your login password securely.',
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showChangePasswordDialog(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              _SettingsCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppText.text(context, 'about_app'),
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.info_outline),
                      title: Text(AppText.text(context, 'version')),
                      subtitle: const Text('Blood Bank App 1.0.0'),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.privacy_tip_outlined),
                      title: Text(AppText.text(context, 'privacy_policy')),
                      subtitle:
                          Text(AppText.text(context, 'privacy_policy_subtitle')),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _showPrivacyPolicy(context),
                    ),
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const Icon(Icons.favorite_outline),
                      title: Text(AppText.text(context, 'purpose')),
                      subtitle: Text(AppText.text(context, 'purpose_subtitle')),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final Widget child;

  const _SettingsCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x12000000),
            blurRadius: 12,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: child,
    );
  }
}
