import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:async';

import '../../services/app_config_service.dart';
import '../../services/firestore_service.dart';
import '../../services/location_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/account_moderation_service.dart';
import '../../utils/app_text.dart';
import '../../utils/helpers.dart';
import '../../utils/sos_request_time.dart';
import '../../widgets/common/app_header_title.dart';

class RequestScreen extends StatefulWidget {
  const RequestScreen({super.key});

  @override
  State<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends State<RequestScreen> {
  final FirestoreService service = FirestoreService();

  String selectedBlood = 'A+';
  String priority = 'medium';
  int units = 1;
  int selectedTab = 0;
  bool isSending = false;
  bool isTimeFormVisible = false;
  String selectedTimePreset = sosQuickTimeOptions[3];
  final TextEditingController customTimeController = TextEditingController();
  DateTime? selectedRequiredBy;
  Timer? _clockTimer;
  DateTime _now = DateTime.now();

  double? myLat;
  double? myLng;

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<bool> _ensureLocationReadyForSOS() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Location is off. Please turn it on to send SOS.');
      return false;
    }

    try {
      await LocationService.getCurrentLocation();
      return true;
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    loadMyLocation();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clockTimer?.cancel();
    customTimeController.dispose();
    super.dispose();
  }

  Future<void> _pickRequiredByDateTime() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: selectedRequiredBy?.isAfter(now) == true
          ? selectedRequiredBy!
          : now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );
    if (pickedDate == null || !mounted) return;

    final pickedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(
        selectedRequiredBy?.isAfter(now) == true
            ? selectedRequiredBy!
            : now.add(const Duration(minutes: 30)),
      ),
    );
    if (pickedTime == null || !mounted) return;

    setState(() {
      selectedRequiredBy = DateTime(
        pickedDate.year,
        pickedDate.month,
        pickedDate.day,
        pickedTime.hour,
        pickedTime.minute,
      );
    });
  }

  SosDeadlineSelection? _resolveDeadlineSelection({bool showError = false}) {
    if (!isTimeFormVisible) return null;
    try {
      return resolveSosDeadline(
        presetLabel: selectedTimePreset,
        customInput: customTimeController.text,
        pickedDateTime: selectedRequiredBy,
      );
    } on FormatException catch (error) {
      if (showError) {
        _showMessage(error.message.toString());
      }
      return null;
    }
  }

  String _currentDeadlinePreview() {
    final selection = _resolveDeadlineSelection();
    if (selection == null) return 'No time limit will be added.';
    if (selection.mode == 'datetime') {
      return 'Required by ${selection.label}';
    }
    return 'Required within ${selection.label}';
  }

  void _toggleTimeForm() {
    setState(() {
      if (isTimeFormVisible) {
        isTimeFormVisible = false;
        customTimeController.clear();
        selectedRequiredBy = null;
        selectedTimePreset = sosQuickTimeOptions[3];
      } else {
        isTimeFormVisible = true;
      }
    });
  }

  Future<Map<String, double>?> _ensureHospitalLocation(String uid) async {
    final hospitalRef = FirebaseFirestore.instance.collection('hospitals').doc(uid);
    final doc = await hospitalRef.get();
    final loc = doc.data()?['location'];

    final lat = (loc?['lat'] as num?)?.toDouble();
    final lng = (loc?['lng'] as num?)?.toDouble();
    if (lat != null && lng != null) {
      return {
        'lat': lat,
        'lng': lng,
      };
    }

    try {
      final position = await LocationService.getCurrentLocation();
      final fixedLocation = {
        'lat': position.latitude,
        'lng': position.longitude,
      };

      await hospitalRef.set({
        'location': fixedLocation,
        'locationCapturedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'location': fixedLocation,
      }, SetOptions(merge: true));

      return fixedLocation;
    } catch (_) {
      return null;
    }
  }

  Future<void> loadMyLocation() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final loc = await _ensureHospitalLocation(uid);
    if (loc == null) return;

    myLat = loc['lat'];
    myLng = loc['lng'];

    if (!mounted) return;
    setState(() {});
  }

  double calculateDistance(double lat, double lng) {
    if (myLat == null || myLng == null) return 0;

    return Geolocator.distanceBetween(
          myLat!,
          myLng!,
          lat,
          lng,
        ) /
        1000;
  }

  bool isWithinNearbyRadius(double lat, double lng, double radiusKm) {
    return calculateDistance(lat, lng) <= radiusKm;
  }

  Future<void> openMap(double lat, double lng) async {
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> callPhone(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return;
    await launchUrl(Uri.parse('tel:$cleaned'));
  }

  Future<void> donate(String requestId, Map<String, dynamic> data) async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    if (uid == data['hospitalId']) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.text(context, 'own_request_donate_error'))),
      );
      return;
    }

    try {
      await service.requestDonationApproval(
        requestId: requestId,
        donorId: uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.text(context, 'offer_sent'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _respondToDonationOffer({
    required String requestId,
    required bool accept,
  }) async {
    try {
      await service.respondToDonationApproval(
        requestId: requestId,
        accept: accept,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppText.text(
              context,
              accept ? 'offer_accepted' : 'offer_rejected',
            ),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _completeDonation({
    required String requestId,
  }) async {
    try {
      await service.completeApprovedDonation(
        requestId: requestId,
        donorId: FirebaseAuth.instance.currentUser!.uid,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.text(context, 'donation_completed_title'))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> confirmSOS(String uid) async {
    final canSendSOS = await _ensureLocationReadyForSOS();
    if (!canSendSOS) return;

    if (!mounted) return;
    final deadlineSelection = _resolveDeadlineSelection(showError: true);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(AppText.text(context, 'confirm_sos')),
        content: Text(
          '${AppText.text(context, 'blood')}: $selectedBlood\n${AppText.text(context, 'units_needed')}: $units\n${AppText.text(context, 'priority')}: $priority${deadlineSelection == null ? '' : '\nTime: ${deadlineSelection.label}'}',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(AppText.text(context, 'cancel')),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(AppText.text(context, 'send_sos_alert')),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (confirm != true) return;

    setState(() => isSending = true);

    try {
      final doc = await FirebaseFirestore.instance.collection('hospitals').doc(uid).get();

      final data = doc.data();
      final loc = await _ensureHospitalLocation(uid);

      if (loc == null) {
        _showMessage('Hospital location not found');
        return;
      }

      final lat = loc['lat']!;
      final lng = loc['lng']!;

      await service.createRequest(
        hospitalId: uid,
        bloodType: selectedBlood,
        units: units,
        priority: priority,
        requiredByAt: deadlineSelection?.deadline,
        timeInputMode: deadlineSelection?.mode,
        timeInputLabel: deadlineSelection?.label,
        lat: lat,
        lng: lng,
      );

      await sendSmartSOSNotification(
        hospitalName: data?['hospitalName'] ?? 'Hospital',
        lat: lat,
        lng: lng,
        deadlineSelection: deadlineSelection,
      );

      if (!mounted) return;
      _showMessage('SOS sent');
    } finally {
      if (mounted) {
        setState(() => isSending = false);
      }
    }
  }

  Future<void> sendSmartSOSNotification({
    required String hospitalName,
    required double lat,
    required double lng,
    SosDeadlineSelection? deadlineSelection,
  }) async {
    final nearbyRadiusKm = await AppConfigService.getSosRadiusKm();
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final playerIds = <String>{};
    final receiverIds = <String>{};

    final users = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'user')
        .get();

    for (final user in users.docs) {
      final d = user.data();
      final playerId = d['playerId'];
      final blood = d['bloodGroup'];
      final status = AccountModerationService.normalizeStatus(d['status']);
      final notificationsEnabled =
          (d['settings']?['notificationsEnabled']) != false;
      final userLoc = d['location'];
      final userLat = (userLoc?['lat'] as num?)?.toDouble();
      final userLng = (userLoc?['lng'] as num?)?.toDouble();

      if (user.id != currentUid &&
          status == AccountModerationService.activeStatus &&
          playerId is String &&
          playerId.isNotEmpty &&
          notificationsEnabled == true &&
          blood is String &&
          userLat != null &&
          userLng != null &&
          Geolocator.distanceBetween(lat, lng, userLat, userLng) / 1000 <=
              nearbyRadiusKm &&
          isCompatible(blood, selectedBlood)) {
        playerIds.add(playerId);
        receiverIds.add(user.id);
      }
    }

    final hospitals = await FirebaseFirestore.instance
        .collection('hospitals')
        .get();

    for (final hospital in hospitals.docs) {
      final d = hospital.data();
      final playerId = d['playerId'];
      final isVerified = d['isVerified'] ?? false;
      final status = AccountModerationService.normalizeStatus(d['status']);
      final hospitalLoc = d['location'];
      final hospitalLat = (hospitalLoc?['lat'] as num?)?.toDouble();
      final hospitalLng = (hospitalLoc?['lng'] as num?)?.toDouble();
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(hospital.id)
          .get();
      final notificationsEnabled =
          (userDoc.data()?['settings']?['notificationsEnabled']) != false;

      if (hospital.id == currentUid) continue;

      if (isVerified == true &&
          status == AccountModerationService.activeStatus &&
          notificationsEnabled == true &&
          playerId is String &&
          playerId.isNotEmpty &&
          hospitalLat != null &&
          hospitalLng != null &&
          Geolocator.distanceBetween(lat, lng, hospitalLat, hospitalLng) / 1000 <=
              nearbyRadiusKm) {
        playerIds.add(playerId);
        receiverIds.add(hospital.id);
      }
    }

    if (playerIds.isEmpty) return;

    final timeLine = deadlineSelection == null
        ? ''
        : deadlineSelection.mode == 'datetime'
            ? '\nRequired by ${deadlineSelection.label}'
            : '\nNeeded within ${deadlineSelection.label}';
    final notificationMessage =
        '$units units - $priority priority$timeLine\nHospital: $hospitalName';

    await OneSignalService.sendNotification(
      playerIds: playerIds.toList(),
      title: 'SOS: $selectedBlood Blood Needed',
      message: notificationMessage,
      data: {
        'type': 'sos',
        'lat': lat,
        'lng': lng,
      },
    );

    final batch = FirebaseFirestore.instance.batch();
    for (final receiverId in receiverIds) {
      batch.set(FirebaseFirestore.instance.collection('notifications').doc(), {
        'receiverId': receiverId,
        'title': 'SOS: $selectedBlood Blood Needed',
        'message': notificationMessage,
        'createdAt': FieldValue.serverTimestamp(),
        'type': 'sos',
        'isRead': false,
      });
    }
    await batch.commit();
  }

  String formatTimestamp(dynamic value) {
    if (value is! Timestamp) return '-';
    final date = value.toDate();
    return '${date.day}/${date.month}/${date.year}';
  }

  Widget _buildDeadlineStatus(Map<String, dynamic> data) {
    final deadline = sosRequiredByDate(data);
    final baseColor = isSosExpired(data, now: _now)
        ? Colors.grey.shade700
        : const Color(0xFF8A5A00);

    if (deadline == null) {
      final label = (data['timeInputLabel'] ?? '').toString().trim();
      if (label.isEmpty) return const SizedBox.shrink();
      return _metaPill(Icons.timer_outlined, label, color: baseColor);
    }

    final expired = isSosExpired(data, now: _now);
    final text = expired
        ? 'Expired'
        : 'Time left ${formatSosRemaining(deadline, now: _now)}';
    return _metaPill(
      expired ? Icons.timer_off_outlined : Icons.timer_outlined,
      text,
      color: expired ? Colors.grey.shade700 : const Color(0xFF8A5A00),
    );
  }

  Widget buildForm(String uid) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppText.text(context, 'create_emergency_request'),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          // const Text(
          //   'Send an urgent blood request to nearby compatible donors and hospitals.',
          //   style: TextStyle(
          //     color: Colors.black54,
          //     height: 1.35,
          //   ),
          // ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedBlood,
                  decoration: InputDecoration(
                    labelText: AppText.text(context, 'blood_group'),
                    prefixIcon: const Icon(Icons.bloodtype_outlined),
                  ),
                  items: ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => selectedBlood = val!),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: InputDecoration(
                    labelText: AppText.text(context, 'priority'),
                    prefixIcon: const Icon(Icons.priority_high),
                  ),
                  items: ['low', 'medium', 'high']
                      .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                      .toList(),
                  onChanged: (val) => setState(() => priority = val!),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8F4F4),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        AppText.text(context, 'units_needed'),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        constraints: const BoxConstraints(minWidth: 148),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: Row(
                          children: [
                            IconButton(
                              onPressed: () {
                                if (units > 1) setState(() => units--);
                              },
                              icon: const Icon(Icons.remove),
                            ),
                            Text(
                              '$units',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            IconButton(
                              onPressed: () => setState(() => units++),
                              icon: const Icon(Icons.add),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 14),
                InkWell(
                  onTap: _toggleTimeForm,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    width: 82,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isTimeFormVisible
                          ? const Color(0xFFFCEAEA)
                          : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isTimeFormVisible
                            ? const Color(0xFFEDC7C7)
                            : Colors.black12,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 22,
                          color: isTimeFormVisible
                              ? const Color(0xFFB71C1C)
                              : Colors.black54,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Set Time',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isTimeFormVisible
                                ? const Color(0xFFB71C1C)
                                : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (isTimeFormVisible) ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFFFFFBFA),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFE9D7D3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: const [
                      Icon(
                        Icons.timer_outlined,
                        size: 18,
                        color: Color(0xFFB71C1C),
                      ),
                      SizedBox(width: 8),
                      Text(
                        'Blood Required Within',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choose a quick time, type your own, or pick an exact deadline.',
                    style: TextStyle(color: Colors.black54, height: 1.3),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: selectedTimePreset,
                    decoration: const InputDecoration(
                      labelText: 'Quick Select',
                      prefixIcon: Icon(Icons.timer_outlined),
                    ),
                    items: sosQuickTimeOptions
                        .map((option) => DropdownMenuItem<String>(
                              value: option,
                              child: Text(option),
                            ))
                        .toList(),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => selectedTimePreset = value);
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: customTimeController,
                    decoration: InputDecoration(
                      labelText: 'Custom Time',
                      hintText: 'Example: 45 min, 2 hr, 3 days',
                      prefixIcon: const Icon(Icons.edit_calendar_outlined),
                      suffixIcon: customTimeController.text.trim().isEmpty
                          ? null
                          : IconButton(
                              onPressed: () => setState(
                                () => customTimeController.clear(),
                              ),
                              icon: const Icon(Icons.close),
                            ),
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _pickRequiredByDateTime,
                          icon: const Icon(Icons.event_outlined),
                          label: Text(
                            selectedRequiredBy == null
                                ? 'Pick Date & Time'
                                : formatSosAbsoluteDateTime(selectedRequiredBy!),
                          ),
                        ),
                      ),
                      if (selectedRequiredBy != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () => setState(() => selectedRequiredBy = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _currentDeadlinePreview(),
                    style: const TextStyle(
                      color: Color(0xFF8A5A00),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: isSending ? null : () => confirmSOS(uid),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFB71C1C),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              icon: isSending
                  ? const SizedBox(
                      height: 16,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(
                isSending
                    ? AppText.text(context, 'sending')
                    : AppText.text(context, 'send_sos_alert'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget buildTabButton(String text, int index) {
    final isSelected = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          margin: EdgeInsets.only(right: index == 0 ? 10 : 0),
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFFB71C1C) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? const Color(0xFFB71C1C) : Colors.black12,
            ),
            boxShadow: const [
              BoxShadow(
                color: Color(0x12000000),
                blurRadius: 10,
                offset: Offset(0, 5),
              ),
            ],
          ),
          child: Center(
            child: Text(
              text,
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget buildActiveCard(
    String requestId,
    Map<String, dynamic> data,
    String distance,
    String uid,
  ) {
    final isOwn = uid == data['hospitalId'];
    final phone = (data['phone'] ?? '').toString();
    final address = (data['address'] ?? '').toString();
    final requesterRole = (data['role'] ?? '').toString();
    final lat = data['location']?['lat'];
    final lng = data['location']?['lng'];
    final pendingDonorId = (data['pendingDonorId'] ?? '').toString();
    final pendingDonorName = (data['pendingDonorName'] ?? 'Donor').toString();
    final approvalStatus = (data['approvalStatus'] ?? '').toString();
    final isPending = approvalStatus == 'pending' && pendingDonorId.isNotEmpty;
    final isCurrentHospitalPendingDonor = pendingDonorId == uid;
    final acceptedDonorId = (data['acceptedDonorId'] ?? '').toString();
    final acceptedDonorName = (data['acceptedDonorName'] ?? 'Donor').toString();
    final isAccepted =
        approvalStatus == 'accepted' && acceptedDonorId.isNotEmpty;
    final isCurrentHospitalAcceptedDonor = acceptedDonorId == uid;
    final isExpired = isSosExpired(data, now: _now);
    final navigateLabel = AppText.text(context, 'navigate');
    final callLabel = AppText.text(context, 'call');

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: isOwn ? const Color(0x1FB71C1C) : Colors.black12,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFCEAEA),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${data['bloodType'] ?? 'N/A'}',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFFB71C1C),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _metaPill(Icons.monitor_heart_outlined,
                        '${data['units'] ?? 0} units'),
                    _metaPill(
                      Icons.bolt,
                      '${data['priority'] ?? 'medium'}'.toUpperCase(),
                      color:
                          _priorityColor((data['priority'] ?? 'medium').toString()),
                    ),
                    _metaPill(Icons.near_me_outlined, '$distance km'),
                    _buildDeadlineStatus(data),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '${data['name'] ?? 'Requester'}',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (requesterRole.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              requesterRole == 'hospital'
                  ? AppText.text(context, 'hospital_request')
                  : AppText.text(context, 'user_request'),
              style: const TextStyle(color: Colors.black54),
            ),
          ],
          if (phone.isNotEmpty) ...[
            const SizedBox(height: 10),
            _detailRow(Icons.call_outlined, phone),
          ],
          if (address.isNotEmpty) ...[
            const SizedBox(height: 8),
            _detailRow(Icons.location_on_outlined, address),
          ],
          const SizedBox(height: 14),
          if (!isOwn && lat != null && lng != null)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => openMap(
                          (lat as num).toDouble(),
                          (lng as num).toDouble(),
                        ),
                        icon: const Icon(Icons.navigation_outlined),
                        label: Text(
                          navigateLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: phone.isEmpty ? null : () => callPhone(phone),
                        icon: const Icon(Icons.call_outlined),
                        label: Text(
                          callLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                if (isExpired) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.grey.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Text(
                      'Expired',
                      style: TextStyle(
                        color: Colors.black54,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ] else if (isAccepted && isCurrentHospitalAcceptedDonor) ...[
                  const SizedBox(height: 14),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.verified, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            AppText.text(context, 'approved_to_donate'),
                            style: TextStyle(
                              color: Colors.green.shade800,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => _completeDonation(requestId: requestId),
                      icon: const Icon(Icons.check_circle_outline),
                      label: Text(AppText.text(context, 'complete_donation')),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: (isPending || isAccepted)
                          ? null
                          : () => donate(requestId, data),
                      icon: const Icon(Icons.volunteer_activism),
                      label: Text(
                        isPending
                            ? AppText.text(
                                context,
                                isCurrentHospitalPendingDonor
                                    ? 'waiting_for_approval'
                                    : 'awaiting_other_donor',
                              )
                            : isAccepted
                                ? AppText.text(context, 'awaiting_other_donor')
                                : AppText.text(context, 'donate_blood'),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFB71C1C),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
                if (!isExpired && isPending) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      isCurrentHospitalPendingDonor
                          ? AppText.text(context, 'waiting_for_approval')
                          : AppText.text(context, 'offer_waiting'),
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (!isExpired && isAccepted && !isCurrentHospitalAcceptedDonor) ...[
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      '${AppText.text(context, 'approved_donor')}: $acceptedDonorName',
                      style: TextStyle(
                        color: Colors.orange.shade800,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          if (isOwn) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isExpired
                    ? Colors.grey.withValues(alpha: 0.12)
                    : const Color(0xFFF4FBF4),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                isExpired ? 'Expired' : AppText.text(context, 'request_live'),
                style: TextStyle(
                  color: isExpired ? Colors.black54 : Colors.green,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            if (!isExpired && isPending) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${AppText.text(context, 'pending_donor')}: $pendingDonorName',
                      style: TextStyle(
                        color: Colors.orange.shade900,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () => _respondToDonationOffer(
                              requestId: requestId,
                              accept: true,
                            ),
                            child:
                                Text(AppText.text(context, 'accept_donation')),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => _respondToDonationOffer(
                              requestId: requestId,
                              accept: false,
                            ),
                            child:
                                Text(AppText.text(context, 'reject_donation')),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
            if (!isExpired && isAccepted) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(
                  '${AppText.text(context, 'approved_donor')}: $acceptedDonorName',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget buildCompletedCard(
    Map<String, dynamic> data,
    String completedByName,
  ) {
    return Container(
      margin: const EdgeInsets.all(10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${data['bloodType'] ?? 'N/A'} - ${data['units'] ?? 0} units',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Colors.red,
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Completed',
                  style: TextStyle(
                    color: Colors.green,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text('Priority: ${data['priority'] ?? 'medium'}'),
          Text('Requested by: ${data['name'] ?? 'Hospital'}'),
          Text('Donated by: $completedByName'),
          Text('Completed on: ${formatTimestamp(data['fulfilledAt'])}'),
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String text, {Color color = const Color(0xFFB71C1C)}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: Colors.black54),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.black87,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }

  Color _priorityColor(String priorityValue) {
    switch (priorityValue.toLowerCase()) {
      case 'high':
        return const Color(0xFFD84315);
      case 'low':
        return const Color(0xFF2E7D32);
      default:
        return const Color(0xFFB26A00);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const AppHeaderTitle(title: 'SOS Hub'),
        backgroundColor: const Color(0xFFF5F5F5),
        surfaceTintColor: Colors.transparent,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                buildTabButton(AppText.text(context, 'my_requests'), 0),
                buildTabButton(AppText.text(context, 'donate_nearby'), 1),
              ],
            ),
          ),
          Expanded(
            child: StreamBuilder<double>(
              stream: AppConfigService.sosRadiusKmStream(),
              builder: (context, radiusSnapshot) {
                final nearbyRadiusKm =
                    radiusSnapshot.data ?? AppConfigService.defaultSosRadiusKm;

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sos_requests')
                      .snapshots(),
                  builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final docs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final status = data['status'] ?? 'active';
                  final isExpired = isSosExpired(data, now: _now);

                  if (selectedTab == 0) {
                    return status == 'active' &&
                        !isExpired &&
                        data['hospitalId'] == uid;
                  }

                  if (selectedTab == 1) {
                    if (data['hospitalId'] == uid) return false;

                    final lat = (data['location']?['lat'] as num?)?.toDouble();
                    final lng = (data['location']?['lng'] as num?)?.toDouble();
                    if (lat == null || lng == null) return false;
                    if (myLat == null || myLng == null) return false;

                    return status == 'active' &&
                        !isExpired &&
                        isWithinNearbyRadius(lat, lng, nearbyRadiusKm);
                  }

                  return false;
                }).toList()
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    final aCreated = aData['createdAt'];
                    final bCreated = bData['createdAt'];
                    if (aCreated is Timestamp && bCreated is Timestamp) {
                      return bCreated.compareTo(aCreated);
                    }
                    if (aCreated is Timestamp) return -1;
                    if (bCreated is Timestamp) return 1;
                    return 0;
                  });

                return ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
                  children: [
                    if (selectedTab == 0) ...[
                      buildForm(uid),
                      const SizedBox(height: 16),
                    ],
                    if (docs.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          selectedTab == 0
                              ? AppText.text(context, 'no_active_requests_yet')
                              : AppText.text(context, 'no_nearby_requests'),
                          style: const TextStyle(color: Colors.black54),
                        ),
                      )
                    else
                      ...docs.map((doc) {
                        final data = doc.data() as Map<String, dynamic>;

                        final lat = data['location']?['lat'];
                        final lng = data['location']?['lng'];
                        final distance = lat != null && lng != null
                            ? calculateDistance(
                                (lat as num).toDouble(),
                                (lng as num).toDouble(),
                              ).toStringAsFixed(2)
                            : '0';

                        return buildActiveCard(doc.id, data, distance, uid);
                      }),
                  ],
                );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
