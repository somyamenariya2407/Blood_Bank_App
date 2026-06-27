import 'dart:async';

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/firestore_service.dart';
import '../../services/app_config_service.dart';
import '../../services/location_service.dart';
import '../../services/onesignal_service.dart';
import '../../services/account_moderation_service.dart';
import '../../utils/app_text.dart';
import '../../utils/helpers.dart';
import '../../utils/sos_request_time.dart';
import '../../widgets/common/app_header_title.dart';

//////////////////////////////////////////////////////////////
// MAIN SCREEN
//////////////////////////////////////////////////////////////

class SOSScreen extends StatefulWidget {
  const SOSScreen({super.key});

  @override
  State<SOSScreen> createState() => _SOSScreenState();
}

class _SOSScreenState extends State<SOSScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              const AppHeaderTitle(title: 'SOS Center'),
              const SizedBox(height: 12),
              const SOSMapFrame(),
              const SizedBox(height: 15),
              const Expanded(
                child: RequestView(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// class _SOSHeader extends StatelessWidget {
//   final ThemeData theme;
//
//   const _SOSHeader({required this.theme});
//
//   @override
//   Widget build(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(18),
//       decoration: BoxDecoration(
//         gradient: const LinearGradient(
//           colors: [Color(0xFFB71C1C), Color(0xFFD64B4B)],
//           begin: Alignment.topLeft,
//           end: Alignment.bottomRight,
//         ),
//         borderRadius: BorderRadius.circular(24),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: const [
//           Text(
//             'SOS Center',
//             style: TextStyle(
//               color: Colors.white,
//               fontSize: 22,
//               fontWeight: FontWeight.w800,
//             ),
//           ),
//           SizedBox(height: 6),
//           Text(
//             'Track nearby emergency requests, send your own SOS, and respond quickly when you are able to donate.',
//             style: TextStyle(color: Colors.white70, height: 1.35),
//           ),
//         ],
//       ),
//     );
//   }
// }

//////////////////////////////////////////////////////////////
// MAP
//////////////////////////////////////////////////////////////

class SOSMapFrame extends StatelessWidget {
  const SOSMapFrame({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      height: 220,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          const Positioned.fill(child: SOSMap()),
          Positioned(
            left: 14,
            top: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.emergency, color: Colors.white, size: 16),
                  SizedBox(width: 8),
                  Text(
                    'Nearby SOS Map',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Material(
              color: theme.colorScheme.surface,
              shape: const CircleBorder(),
              elevation: 3,
              child: IconButton(
                tooltip: "Fullscreen",
                icon: const Icon(Icons.fullscreen),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FullscreenSOSMapPage(),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class FullscreenSOSMapPage extends StatelessWidget {
  const FullscreenSOSMapPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            const Positioned.fill(child: SOSMap()),
            Positioned(
              top: 12,
              right: 12,
              child: Material(
                color: Colors.white,
                shape: const CircleBorder(),
                elevation: 4,
                child: IconButton(
                  tooltip: "Minimize",
                  icon: const Icon(Icons.fullscreen_exit),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SOSMap extends StatefulWidget {
  const SOSMap({super.key});

  @override
  State<SOSMap> createState() => _SOSMapState();
}

class _SOSMapState extends State<SOSMap> with WidgetsBindingObserver {
  final MapController _mapController = MapController();
  LatLng? userPosition;
  bool isLoading = true;
  String? locationError;
  double _currentZoom = 13;
  StreamSubscription<Position>? _locationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    loadLocation();
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      loadLocation();
    } else if (state == AppLifecycleState.paused) {
      _locationSubscription?.pause();
    }
  }

  Future<void> loadLocation() async {
    await _locationSubscription?.cancel();
    _locationSubscription = null;

    if (mounted) {
      setState(() {
        isLoading = true;
        locationError = null;
      });
    }

    try {
      final pos = await LocationService.getCurrentLocation();
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set(_locationPayload(pos), SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        userPosition = LatLng(pos.latitude, pos.longitude);
        isLoading = false;
        locationError = null;
      });

      _locationSubscription = LocationService.getLocationStream().listen(
        _handleLocationUpdate,
        onError: (_) {},
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        userPosition = null;
        isLoading = false;
        locationError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Map<String, dynamic> _locationPayload(Position pos) {
    return {
      'location': {
        'lat': pos.latitude,
        'lng': pos.longitude,
      },
    };
  }

  Future<void> _handleLocationUpdate(Position pos) async {
    if (!mounted) return;

    final nextPosition = LatLng(pos.latitude, pos.longitude);
    setState(() {
      userPosition = nextPosition;
      isLoading = false;
      locationError = null;
    });

    if (_mapController.camera.zoom > 0) {
      _currentZoom = _mapController.camera.zoom;
    }
    try {
      _mapController.move(nextPosition, _currentZoom);
    } catch (_) {}

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(FirebaseAuth.instance.currentUser!.uid)
          .set(_locationPayload(pos), SetOptions(merge: true));
    } catch (_) {}
  }

  bool _isNearby(LatLng point, double radiusKm) {
    if (userPosition == null) return false;

    return Geolocator.distanceBetween(
              userPosition!.latitude,
              userPosition!.longitude,
              point.latitude,
              point.longitude,
            ) /
            1000 <=
        radiusKm;
  }

  Future<void> callPhone(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return;
    await launchUrl(Uri.parse('tel:$cleaned'));
  }

  Future<void> openDirections(LatLng target) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Widget _infoLine(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: Colors.black54),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void showHospitalDetails(Map<String, dynamic> data, LatLng point) {
    final hospitalName =
        (data['hospitalName'] ?? data['name'] ?? 'Hospital').toString();
    final phone = (data['phone'] ?? '').toString();
    final address = (data['address'] ?? '').toString().trim();
    final distance = Geolocator.distanceBetween(
          userPosition!.latitude,
          userPosition!.longitude,
          point.latitude,
          point.longitude,
        ) /
        1000;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.local_hospital, color: Colors.red),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        hospitalName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (address.isNotEmpty)
                  _infoLine(Icons.location_on_outlined, 'Address', address),
                if (phone.isNotEmpty)
                  _infoLine(Icons.call_outlined, 'Phone', phone),
                _infoLine(
                  Icons.near_me_outlined,
                  'Distance',
                  '${distance.toStringAsFixed(2)} km',
                ),
                if (data['isVerified'] == true)
                  Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Verified Hospital',
                          style: TextStyle(
                            color: Colors.green,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => openDirections(point),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate'),
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => callPhone(phone),
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showRegisteredUserDetails(Map<String, dynamic> data, LatLng point) {
    final userName = (data['name'] ?? 'User').toString();
    final phone = (data['phone'] ?? '').toString();
    final address = (data['address'] ?? '').toString().trim();
    final distance = Geolocator.distanceBetween(
          userPosition!.latitude,
          userPosition!.longitude,
          point.latitude,
          point.longitude,
        ) /
        1000;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(Icons.person, color: Colors.blue),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        userName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (address.isNotEmpty)
                  _infoLine(Icons.location_on_outlined, 'Address', address),
                if (phone.isNotEmpty)
                  _infoLine(Icons.call_outlined, 'Phone', phone),
                _infoLine(
                  Icons.near_me_outlined,
                  'Distance',
                  '${distance.toStringAsFixed(2)} km',
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () => openDirections(point),
                        icon: const Icon(Icons.navigation),
                        label: const Text('Navigate'),
                      ),
                    ),
                    if (phone.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () => callPhone(phone),
                          icon: const Icon(Icons.call),
                          label: const Text('Call'),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showSOSDetails(Map<String, dynamic> data, LatLng point) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _buildSOSSheet(
        point: point,
        requests: [data],
      ),
    );
  }

  Widget _buildSOSSheet({
    required LatLng point,
    required List<Map<String, dynamic>> requests,
    Map<String, dynamic>? hospitalData,
  }) {
    final pageController = PageController();
    var currentPage = 0;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        final distance = Geolocator.distanceBetween(
              userPosition!.latitude,
              userPosition!.longitude,
              point.latitude,
              point.longitude,
            ) /
            1000;

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.78,
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(Icons.warning_amber, color: Colors.orange),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          requests.length > 1 ? 'SOS Requests' : 'SOS Request',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      if (requests.length > 1)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            '${currentPage + 1}/${requests.length}',
                            style: const TextStyle(
                              color: Colors.orange,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Flexible(
                    child: PageView.builder(
                      controller: pageController,
                      itemCount: requests.length,
                      onPageChanged: (index) {
                        setSheetState(() {
                          currentPage = index;
                        });
                      },
                      itemBuilder: (context, index) {
                        final data = requests[index];
                        final phone = (data['phone'] ?? '').toString();
                        final requesterName = (data['name'] ?? 'Unknown')
                            .toString();
                        final requesterRole =
                            (data['role'] ?? 'user').toString().toLowerCase();
                        final requesterIcon = requesterRole == 'hospital'
                            ? Icons.local_hospital_outlined
                            : Icons.person_outline;
                        final requesterTypeLabel =
                            requesterRole == 'hospital' ? 'Hospital' : 'User';
                        final canOpenHospital =
                            requesterRole == 'hospital' && hospitalData != null;

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (canOpenHospital)
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    showHospitalDetails(hospitalData, point);
                                  },
                                  child: Container(
                                    margin: const EdgeInsets.only(bottom: 12),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(
                                              alpha: 0.10,
                                            ),
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                          child: const Icon(
                                            Icons.local_hospital_outlined,
                                            color: Color(0xFFB71C1C),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                requesterName,
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              const Text(
                                                'Tap to view hospital details',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.black54,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Icon(
                                          Icons.chevron_right,
                                          color: Color(0xFFB71C1C),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey.withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(10),
                                        decoration: BoxDecoration(
                                          color: Colors.red.withValues(
                                            alpha: 0.10,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(12),
                                        ),
                                        child: Icon(
                                          requesterIcon,
                                          color: const Color(0xFFB71C1C),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            const Text(
                                              'Requester',
                                              style: TextStyle(
                                                fontSize: 12,
                                                color: Colors.black54,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              requesterName,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w700,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 6,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.orange.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius:
                                              BorderRadius.circular(999),
                                        ),
                                        child: Text(
                                          requesterTypeLabel,
                                          style: const TextStyle(
                                            color: Colors.orange,
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              _infoLine(
                                Icons.bloodtype_outlined,
                                'Blood Needed',
                                '${data['bloodType'] ?? 'N/A'} - ${data['units'] ?? 0} units',
                              ),
                              _infoLine(
                                Icons.priority_high,
                                'Priority',
                                '${data['priority'] ?? 'medium'}'.toUpperCase(),
                              ),
                              Builder(
                                builder: (context) {
                                  final deadline = sosRequiredByDate(data);
                                  if (deadline == null &&
                                      (data['timeInputLabel'] ?? '').toString().trim().isEmpty) {
                                    return const SizedBox.shrink();
                                  }
                                  return _infoLine(
                                    isSosExpired(data)
                                        ? Icons.timer_off_outlined
                                        : Icons.timer_outlined,
                                    'Required In',
                                    deadline == null
                                        ? (data['timeInputLabel'] ?? '').toString()
                                        : (isSosExpired(data)
                                            ? 'Expired'
                                            : formatSosRemaining(deadline)),
                                  );
                                },
                              ),
                              if (phone.isNotEmpty)
                                _infoLine(Icons.call_outlined, 'Phone', phone),
                              _infoLine(
                                Icons.near_me_outlined,
                                'Distance',
                                '${distance.toStringAsFixed(2)} km',
                              ),
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: () => openDirections(point),
                                      icon: const Icon(Icons.navigation),
                                      label: const Text('Navigate'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: ElevatedButton.icon(
                                      onPressed: phone.isEmpty
                                          ? null
                                          : () => callPhone(phone),
                                      icon: const Icon(Icons.call),
                                      label: const Text('Call'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  if (requests.length > 1) ...[
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        requests.length,
                        (index) => AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: currentPage == index ? 18 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: currentPage == index
                                ? Colors.orange
                                : Colors.orange.withValues(alpha: 0.25),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSosMarkerIcon({
    required int count,
    required bool isHospitalRequest,
  }) {
    final markerColor =
        isHospitalRequest ? const Color(0xFFB71C1C) : Colors.orange;

    return Icon(Icons.warning, color: markerColor, size: 28);
  }

  Widget _buildLocationError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 46, color: Colors.red),
              const SizedBox(height: 12),
              const Text(
                'Turn on location and allow permission to load the SOS map.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                locationError ?? 'Location is required.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: loadLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      LocationService.openLocationSettings();
                    },
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Location Settings'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (userPosition == null) {
      return _buildLocationError();
    }

    return StreamBuilder<double>(
      stream: AppConfigService.sosRadiusKmStream(),
      builder: (context, hospitalSnap) {
        final radiusKm =
            hospitalSnap.data ?? AppConfigService.defaultSosRadiusKm;

        return StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('hospitals').snapshots(),
          builder: (context, hospitalsSnapshot) {
            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('users').snapshots(),
              builder: (context, usersSnapshot) {
                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('sos_requests')
                      .where('status', isEqualTo: 'active')
                      .snapshots(),
                  builder: (context, sosSnap) {
                    final markers = <Marker>[
                      Marker(
                        point: userPosition!,
                        child: const Icon(Icons.my_location, color: Colors.blue),
                      ),
                    ];
                    final hospitalsById = <String, Map<String, dynamic>>{};

                    for (final doc in hospitalsSnapshot.data?.docs ?? []) {
                      final data = doc.data() as Map<String, dynamic>;
                      hospitalsById[doc.id] = data;
                      final status =
                          AccountModerationService.normalizeStatus(data['status']);
                      if (status != AccountModerationService.activeStatus) continue;
                      final loc = data['location'];
                      if (loc == null) continue;

                      final point = LatLng(
                        (loc['lat'] as num).toDouble(),
                        (loc['lng'] as num).toDouble(),
                      );

                      markers.add(
                        Marker(
                          point: point,
                          child: GestureDetector(
                            onTap: () => showHospitalDetails(data, point),
                            child: const Icon(
                              Icons.local_hospital,
                              color: Colors.red,
                              size: 30,
                            ),
                          ),
                        ),
                      );
                    }

                    for (final doc in usersSnapshot.data?.docs ?? []) {
                      final data = doc.data() as Map<String, dynamic>;
                      if (doc.id == FirebaseAuth.instance.currentUser?.uid) continue;
                      final role = (data['role'] ?? 'user').toString().toLowerCase();
                      if (role != 'user') continue;

                      final loc = data['location'];
                      if (loc == null) continue;

                      final point = LatLng(
                        (loc['lat'] as num).toDouble(),
                        (loc['lng'] as num).toDouble(),
                      );
                      if (!_isNearby(point, radiusKm)) continue;

                      markers.add(
                        Marker(
                          point: point,
                          child: GestureDetector(
                            onTap: () => showRegisteredUserDetails(data, point),
                            child: const Icon(
                              Icons.person_pin_circle,
                              color: Colors.blue,
                              size: 24,
                            ),
                          ),
                        ),
                      );
                    }

                    final groupedHospitalSos = <String, List<Map<String, dynamic>>>{};
                    final groupedHospitalPoints = <String, LatLng>{};
                    final singleSosEntries = <({Map<String, dynamic> data, LatLng point})>[];

                    for (final doc in sosSnap.data?.docs ?? []) {
                      final data = doc.data() as Map<String, dynamic>;
                      final loc = data['location'];
                      if (loc == null) continue;
                      final requesterRole =
                          (data['role'] ?? 'user').toString().toLowerCase();

                      final point = LatLng(
                        (loc['lat'] as num).toDouble(),
                        (loc['lng'] as num).toDouble(),
                      );
                      if (!_isNearby(point, radiusKm)) continue;

                      final hospitalId = (data['hospitalId'] ?? '').toString();
                      if (requesterRole == 'hospital' && hospitalId.isNotEmpty) {
                        final key = '$hospitalId:${point.latitude},${point.longitude}';
                        groupedHospitalSos.putIfAbsent(key, () => []).add(data);
                        groupedHospitalPoints[key] = point;
                        continue;
                      }

                      singleSosEntries.add((data: data, point: point));
                    }

                    for (final entry in groupedHospitalSos.entries) {
                      final requests = entry.value;
                      final point = groupedHospitalPoints[entry.key]!;
                      requests.sort((a, b) {
                        final aCreated = a['createdAt'];
                        final bCreated = b['createdAt'];
                        if (aCreated is Timestamp && bCreated is Timestamp) {
                          return bCreated.compareTo(aCreated);
                        }
                        if (aCreated is Timestamp) return -1;
                        if (bCreated is Timestamp) return 1;
                        return 0;
                      });
                      final hospitalId =
                          (requests.first['hospitalId'] ?? '').toString();
                      final hospitalData = hospitalsById[hospitalId];

                      markers.add(
                        Marker(
                          point: point,
                          width: 48,
                          height: 48,
                          child: GestureDetector(
                            onTap: () => showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                  top: Radius.circular(18),
                                ),
                              ),
                              builder: (_) => _buildSOSSheet(
                                point: point,
                                requests: requests,
                                hospitalData: hospitalData,
                              ),
                            ),
                            child: _buildSosMarkerIcon(
                              count: requests.length,
                              isHospitalRequest: true,
                            ),
                          ),
                        ),
                      );
                    }

                    for (final entry in singleSosEntries) {
                      final requesterRole =
                          (entry.data['role'] ?? 'user').toString().toLowerCase();
                      markers.add(
                        Marker(
                          point: entry.point,
                          child: GestureDetector(
                            onTap: () => showSOSDetails(entry.data, entry.point),
                            child: _buildSosMarkerIcon(
                              count: 1,
                              isHospitalRequest: requesterRole == 'hospital',
                            ),
                          ),
                        ),
                      );
                    }

                    return FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: userPosition!,
                        initialZoom: 13,
                        onPositionChanged: (position, hasGesture) {
                          final zoom = position.zoom;
                          if (zoom != null) {
                            _currentZoom = zoom;
                          }
                        },
                      ),
                      children: [
                        TileLayer(
                          urlTemplate:
                              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                          userAgentPackageName: 'com.example.blood_bank_app',
                        ),
                        MarkerLayer(markers: markers),
                      ],
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

//////////////////////////////////////////////////////////////
// REQUEST VIEW
//////////////////////////////////////////////////////////////

class RequestView extends StatefulWidget {
  const RequestView({super.key});

  @override
  State<RequestView> createState() => _RequestViewState();
}

class _RequestViewState extends State<RequestView> {
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

  @override
  void dispose() {
    _clockTimer?.cancel();
    customTimeController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _clockTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _now = DateTime.now());
    });
  }

  void _showMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
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

  Future<void> sendSOS() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      _showMessage('Location is off. Please turn it on to send SOS.');
      return;
    }

    Position pos;
    try {
      pos = await LocationService.getCurrentLocation();
    } catch (e) {
      _showMessage(e.toString().replaceFirst('Exception: ', ''));
      return;
    }

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
      final userDoc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = userDoc.data();

      await FirebaseFirestore.instance.collection('sos_requests').add({
        'userId': uid,
        'name': data?['name'] ?? 'User',
        'phone': data?['phone'] ?? '',
        'address': data?['address'] ?? '',
        'role': data?['role'] ?? 'user',
        'bloodType': selectedBlood,
        'units': units,
        'priority': priority,
        if (deadlineSelection != null)
          'requiredByAt': Timestamp.fromDate(deadlineSelection.deadline),
        if (deadlineSelection != null) 'timeInputMode': deadlineSelection.mode,
        if (deadlineSelection != null)
          'timeInputLabel': deadlineSelection.label,
        'status': 'active',
        'location': {
          'lat': pos.latitude,
          'lng': pos.longitude,
        },
        'createdAt': Timestamp.now(),
      });

      await sendNotification(
        name: data?['name'] ?? 'User',
        lat: pos.latitude,
        lng: pos.longitude,
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

  Future<void> sendNotification({
    required String name,
    required double lat,
    required double lng,
    SosDeadlineSelection? deadlineSelection,
  }) async {
    final nearbyRadiusKm = await AppConfigService.getSosRadiusKm();
    final currentUid = FirebaseAuth.instance.currentUser!.uid;
    final playerIds = <String>{};
    final receiverIds = <String>{};

    final hospitals = await FirebaseFirestore.instance
        .collection('hospitals')
        .get();

    for (final h in hospitals.docs) {
      final d = h.data();
      final playerId = d['playerId'];
      final isVerified = d['isVerified'] ?? false;
      final status = AccountModerationService.normalizeStatus(d['status']);
      final hospitalLoc = d['location'];
      final hospitalLat = (hospitalLoc?['lat'] as num?)?.toDouble();
      final hospitalLng = (hospitalLoc?['lng'] as num?)?.toDouble();
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(h.id)
          .get();
      final notificationsEnabled =
          (userDoc.data()?['settings']?['notificationsEnabled']) != false;

      if (h.id != currentUid &&
          status == AccountModerationService.activeStatus &&
          isVerified == true &&
          notificationsEnabled == true &&
          playerId is String &&
          playerId.isNotEmpty &&
          hospitalLat != null &&
          hospitalLng != null &&
          Geolocator.distanceBetween(lat, lng, hospitalLat, hospitalLng) / 1000 <=
              nearbyRadiusKm) {
        playerIds.add(playerId);
        receiverIds.add(h.id);
      }
    }

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
          notificationsEnabled == true &&
          playerId is String &&
          playerId.isNotEmpty &&
          userLat != null &&
          userLng != null &&
          Geolocator.distanceBetween(lat, lng, userLat, userLng) / 1000 <=
              nearbyRadiusKm &&
          blood is String &&
          isCompatible(blood, selectedBlood)) {
        playerIds.add(playerId);
        receiverIds.add(user.id);
      }
    }

    if (playerIds.isEmpty) return;

    final timeLine = deadlineSelection == null
        ? ''
        : deadlineSelection.mode == 'datetime'
            ? '\nRequired by ${deadlineSelection.label}'
            : '\nNeeded within ${deadlineSelection.label}';
    final notificationMessage =
        '$units units - $priority priority$timeLine\nRequested by $name';

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

  Widget toggleBtn(String text, int index) {
    final theme = Theme.of(context);
    final isSelected = selectedTab == index;
    return Expanded(
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        margin: EdgeInsets.only(right: index == 0 ? 8 : 0),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFFB71C1C)
              : theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected
                ? const Color(0xFFB71C1C)
                : theme.colorScheme.outlineVariant,
          ),
          boxShadow: isSelected
              ? const [
                  BoxShadow(color: Color(0x1AB71C1C), blurRadius: 12),
                ]
              : null,
        ),
        child: TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
            foregroundColor:
                isSelected ? Colors.white : theme.colorScheme.onSurface,
          ),
          onPressed: () => setState(() => selectedTab = index),
          child: Text(
            text,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final theme = Theme.of(context);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              toggleBtn('My Requests', 0),
              toggleBtn('Donate Nearby', 1),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: selectedTab == 0
                ? _RequestTab(
                    userId: uid,
                    selectedBlood: selectedBlood,
                    priority: priority,
                    units: units,
                    selectedTimePreset: selectedTimePreset,
                    customTimeController: customTimeController,
                    selectedRequiredBy: selectedRequiredBy,
                    isTimeFormVisible: isTimeFormVisible,
                    currentTime: _now,
                    isSending: isSending,
                    onBloodChanged: (value) => setState(() => selectedBlood = value),
                    onPriorityChanged: (value) => setState(() => priority = value),
                    onUnitsChanged: (value) => setState(() => units = value),
                    onTimePresetChanged: (value) => setState(() => selectedTimePreset = value),
                    onCustomTimeChanged: () => setState(() {}),
                    onPickDateTime: _pickRequiredByDateTime,
                    onClearDateTime: () => setState(() => selectedRequiredBy = null),
                    onToggleTimeForm: _toggleTimeForm,
                    deadlinePreview: _currentDeadlinePreview(),
                    onSend: sendSOS,
                 )
              : DonateView(userId: uid, currentTime: _now),
        ),
      ],
    );
  }
}

class _RequestTab extends StatelessWidget {
  final String userId;
  final String selectedBlood;
  final String priority;
  final int units;
  final String selectedTimePreset;
  final TextEditingController customTimeController;
  final DateTime? selectedRequiredBy;
  final bool isTimeFormVisible;
  final DateTime currentTime;
  final bool isSending;
  final ValueChanged<String> onBloodChanged;
  final ValueChanged<String> onPriorityChanged;
  final ValueChanged<int> onUnitsChanged;
  final ValueChanged<String> onTimePresetChanged;
  final VoidCallback onCustomTimeChanged;
  final VoidCallback onPickDateTime;
  final VoidCallback onClearDateTime;
  final VoidCallback onToggleTimeForm;
  final String deadlinePreview;
  final VoidCallback onSend;

  const _RequestTab({
    required this.userId,
    required this.selectedBlood,
    required this.priority,
    required this.units,
    required this.selectedTimePreset,
    required this.customTimeController,
    required this.selectedRequiredBy,
    required this.isTimeFormVisible,
    required this.currentTime,
    required this.isSending,
    required this.onBloodChanged,
    required this.onPriorityChanged,
    required this.onUnitsChanged,
    required this.onTimePresetChanged,
    required this.onCustomTimeChanged,
    required this.onPickDateTime,
    required this.onClearDateTime,
    required this.onToggleTimeForm,
    required this.deadlinePreview,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              children: [
                ////////////////////////////////////////////////////////////
                // FORM CARD
                ////////////////////////////////////////////////////////////

                Container(
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: theme.colorScheme.outlineVariant),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Create Emergency Request',
                        style: TextStyle(
                            fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),

                      ////////////////////////////////////////////////////////////
                      // DROPDOWNS
                      ////////////////////////////////////////////////////////////

                        Column(
                          children: [
                            DropdownButtonFormField<String>(
                              initialValue: selectedBlood,
                              decoration: const InputDecoration(
                                labelText: 'Blood Group',
                                prefixIcon: Icon(Icons.bloodtype_outlined),
                              ),
                              items: [
                                'A+',
                                'A-',
                                'B+',
                                'B-',
                                'AB+',
                                'AB-',
                                'O+',
                                'O-'
                              ]
                                  .map((e) => DropdownMenuItem(
                                  value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) => onBloodChanged(val!),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              initialValue: priority,
                              decoration: const InputDecoration(
                                labelText: 'Priority',
                                prefixIcon: Icon(Icons.priority_high),
                              ),
                              items: ['low', 'medium', 'high']
                                  .map((e) => DropdownMenuItem(
                                  value: e, child: Text(e)))
                                  .toList(),
                              onChanged: (val) => onPriorityChanged(val!),
                            ),
                          ],
                        ),

                      const SizedBox(height: 16),

                      ////////////////////////////////////////////////////////////
                      // UNITS SECTION
                      ////////////////////////////////////////////////////////////

                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerLowest,
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
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    constraints:
                                    const BoxConstraints(minWidth: 148),
                                    decoration: BoxDecoration(
                                      color: theme.colorScheme.surface,
                                      borderRadius:
                                      BorderRadius.circular(14),
                                      border:
                                      Border.all(
                                        color: theme.colorScheme.outlineVariant,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          onPressed: () {
                                            if (units > 1) {
                                              onUnitsChanged(units - 1);
                                            }
                                          },
                                          icon: const Icon(Icons.remove),
                                        ),
                                        Text(
                                          '$units',
                                          style: const TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        IconButton(
                                          onPressed: () =>
                                              onUnitsChanged(units + 1),
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
                              onTap: onToggleTimeForm,
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
                                      : theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: isTimeFormVisible
                                        ? const Color(0xFFEDC7C7)
                                        : theme.colorScheme.outlineVariant,
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
                                          : theme.colorScheme.onSurfaceVariant,
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
                                            : theme.colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),
                      if (isTimeFormVisible) ...[
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surface,
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: theme.colorScheme.outlineVariant,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Row(
                                children: [
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
                              Text(
                                'Choose a quick time, type your own, or pick an exact deadline.',
                                style: TextStyle(
                                  color: theme.colorScheme.onSurfaceVariant,
                                  height: 1.3,
                                ),
                              ),
                              const SizedBox(height: 10),
                              DropdownButtonFormField<String>(
                                initialValue: selectedTimePreset,
                                decoration: const InputDecoration(
                                  labelText: 'Quick Select',
                                  prefixIcon: Icon(Icons.timer_outlined),
                                ),
                                items: sosQuickTimeOptions
                                    .map(
                                      (option) => DropdownMenuItem<String>(
                                        value: option,
                                        child: Text(option),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (val) {
                                  if (val == null) return;
                                  onTimePresetChanged(val);
                                },
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: customTimeController,
                                decoration: InputDecoration(
                                  labelText: 'Custom Time',
                                  hintText: 'Example: 45 min, 2 hr, 3 days',
                                  prefixIcon:
                                      const Icon(Icons.edit_calendar_outlined),
                                  suffixIcon:
                                      customTimeController.text.trim().isEmpty
                                      ? null
                                      : IconButton(
                                          onPressed: () {
                                            customTimeController.clear();
                                            onCustomTimeChanged();
                                          },
                                          icon: const Icon(Icons.close),
                                        ),
                                ),
                                onChanged: (_) => onCustomTimeChanged(),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: onPickDateTime,
                                      icon: const Icon(Icons.event_outlined),
                                      label: Text(
                                        selectedRequiredBy == null
                                            ? 'Pick Date & Time'
                                            : formatSosAbsoluteDateTime(
                                                selectedRequiredBy!,
                                              ),
                                      ),
                                    ),
                                  ),
                                  if (selectedRequiredBy != null) ...[
                                    const SizedBox(width: 8),
                                    IconButton(
                                      onPressed: onClearDateTime,
                                      icon: const Icon(Icons.close),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 10),
                              Text(
                                deadlinePreview,
                                style: const TextStyle(
                                  color: Color(0xFF8A5A00),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                      ],

                      ////////////////////////////////////////////////////////////
                      // BUTTON
                      ////////////////////////////////////////////////////////////

                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: isSending ? null : onSend,
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                            const Color(0xFFB71C1C),
                            foregroundColor: Colors.white,
                            padding:
                            const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(
                              borderRadius:
                              BorderRadius.circular(16),
                            ),
                          ),
                          icon: isSending
                              ? const SizedBox(
                            height: 18,
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
                ),

                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Text(
                      AppText.text(context, 'your_active_requests'),
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                ////////////////////////////////////////////////////////////
                // LIST (NOW SAFE - NO OVERFLOW)
                ////////////////////////////////////////////////////////////

                NearbySOSList(
                  userId: userId,
                  onlyOwn: true,
                  currentTime: currentTime,
                ),
                // Rebuilt by the parent clock to keep request timers fresh.
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class DonateView extends StatelessWidget {
  final String userId;
  final DateTime currentTime;

  const DonateView({super.key, required this.userId, required this.currentTime});

  @override
  Widget build(BuildContext context) {
    return NearbySOSList(userId: userId, onlyOwn: false, currentTime: currentTime);
  }
}

class NearbySOSList extends StatelessWidget {
  final String userId;
  final bool onlyOwn;
  final DateTime currentTime;

  const NearbySOSList({
    super.key,
    required this.userId,
    required this.onlyOwn,
    required this.currentTime,
  });

  static const int _cooldownDays = 1;

  bool _canDonateNow(Timestamp? lastDonationAt) {
    if (lastDonationAt == null) return true;
    return DateTime.now().difference(lastDonationAt.toDate()).inDays >=
        _cooldownDays;
  }

  String _nextDonationDate(Timestamp? timestamp) {
    if (timestamp == null) return 'unknown date';
    final nextDate = timestamp.toDate().add(const Duration(days: _cooldownDays));
    return '${nextDate.day}/${nextDate.month}/${nextDate.year}';
  }

  double _distanceInKm(
    Map<String, dynamic> data,
    Map<String, dynamic>? userData,
  ) {
    final myLoc = userData?['location'];
    final myLat = (myLoc?['lat'] as num?)?.toDouble();
    final myLng = (myLoc?['lng'] as num?)?.toDouble();
    final reqLoc = data['location'];
    final reqLat = (reqLoc?['lat'] as num?)?.toDouble();
    final reqLng = (reqLoc?['lng'] as num?)?.toDouble();

    if (myLat == null || myLng == null || reqLat == null || reqLng == null) {
      return double.infinity;
    }

    return Geolocator.distanceBetween(myLat, myLng, reqLat, reqLng) / 1000;
  }

  void _showDonationBlockedMessage(
    BuildContext context, {
    required bool isAvailable,
    required Timestamp? lastDonationAt,
  }) {
    final nextDonationLabel = _nextDonationDate(lastDonationAt);
    final message = !isAvailable
        ? '${AppText.text(context, 'request_visible_cannot_donate')} ${AppText.text(context, 'next_donation_active', params: {'date': nextDonationLabel})}'
        : AppText.text(
            context,
            'cooldown_block_message',
            params: {'date': nextDonationLabel},
          );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Widget _buildDeadlineStatus(Map<String, dynamic> data) {
    final deadline = sosRequiredByDate(data);
    final initialExpired = isSosExpired(data, now: currentTime);
    final label = (data['timeInputLabel'] ?? '').toString().trim();

    if (deadline == null) {
      if (label.isEmpty) return const SizedBox.shrink();
      return Text(
        'Required within: $label',
        style: TextStyle(
          color: initialExpired ? Colors.black54 : const Color(0xFF8A5A00),
          fontWeight: FontWeight.w600,
        ),
      );
    }

    final expired = isSosExpired(data, now: currentTime);
    return Text(
      expired
          ? 'Time left: Expired'
          : 'Time left: ${formatSosRemaining(deadline, now: currentTime)}',
      style: TextStyle(
        color: expired ? Colors.black54 : const Color(0xFF8A5A00),
        fontWeight: FontWeight.w700,
      ),
    );
  }

  Future<void> _offerDonation(BuildContext context, String id) async {
    try {
      await FirestoreService().requestDonationApproval(
        requestId: id,
        donorId: FirebaseAuth.instance.currentUser!.uid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.text(context, 'offer_sent'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _respondToDonationOffer(
    BuildContext context, {
    required String requestId,
    required bool accept,
  }) async {
    try {
      await FirestoreService().respondToDonationApproval(
        requestId: requestId,
        accept: accept,
      );
      if (!context.mounted) return;
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
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  Future<void> _completeDonation(
    BuildContext context, {
    required String requestId,
  }) async {
    try {
      await FirestoreService().completeApprovedDonation(
        requestId: requestId,
        donorId: FirebaseAuth.instance.currentUser!.uid,
      );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppText.text(context, 'donation_completed_title'))),
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
      );
    }
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('users').doc(userId).snapshots(),
      builder: (context, userSnapshot) {
        final userData = userSnapshot.data?.data() as Map<String, dynamic>?;
        final donorBlood = userData?['bloodGroup'];
        final isAvailable = userData?['isAvailable'] ?? true;
        final lastDonationAt = userData?['lastDonationAt'] as Timestamp?;
        final canDonateNow = _canDonateNow(lastDonationAt);

        if (!onlyOwn && !userSnapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }

        return StreamBuilder<double>(
          stream: AppConfigService.sosRadiusKmStream(),
          builder: (context, radiusSnapshot) {
            final nearbyRadiusKm =
                radiusSnapshot.data ?? AppConfigService.defaultSosRadiusKm;

            return StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('sos_requests')
                  .where('status', isEqualTo: 'active')
                  .snapshots(),
              builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final requesterId = data['userId'] ?? data['hospitalId'];
              final requestedBlood = data['bloodType'] ?? data['bloodGroup'];
              final distance = _distanceInKm(data, userData);
              final isExpired = isSosExpired(data, now: currentTime);

              if (onlyOwn) {
                return data['userId'] == userId && !isExpired;
              }
              if (isExpired) return false;
              if (requesterId == userId) return false;
              if (donorBlood is! String || requestedBlood is! String) {
                return false;
              }

              return distance <= nearbyRadiusKm &&
                  isCompatible(donorBlood, requestedBlood);
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

            if (docs.isEmpty) {
              return Center(
                child: Text(
                  onlyOwn
                      ? AppText.text(context, 'no_active_requests')
                      : AppText.text(context, 'no_compatible_requests'),
                ),
              );
            }

            final list = docs.map((doc) {
                final data = doc.data() as Map<String, dynamic>;
                final phone = (data['phone'] ?? '').toString();
                final address = (data['address'] ?? '').toString();
                final requesterRole = (data['role'] ?? '').toString();
                final requesterRoleNormalized = requesterRole.toLowerCase();
                final requesterName = (data['name'] ?? 'Unknown').toString();
                final requestLocation = data['location'] as Map<String, dynamic>?;
                final requestLat = (requestLocation?['lat'] as num?)?.toDouble();
                final requestLng = (requestLocation?['lng'] as num?)?.toDouble();
                final VoidCallback? navigateToRequest;
                if (requestLat != null && requestLng != null) {
                  final lat = requestLat;
                  final lng = requestLng;
                  navigateToRequest = () => openMap(lat, lng);
                } else {
                  navigateToRequest = null;
                }
                final requesterIcon = requesterRoleNormalized == 'hospital'
                    ? Icons.local_hospital_outlined
                    : Icons.person_outline;
                final requesterTypeLabel =
                    requesterRoleNormalized == 'hospital' ? 'Hospital' : 'User';
                final isOwn = (data['userId'] ?? data['hospitalId']) == userId;
                final pendingDonorId = (data['pendingDonorId'] ?? '').toString();
                final pendingDonorName =
                    (data['pendingDonorName'] ?? 'Donor').toString();
                final approvalStatus =
                    (data['approvalStatus'] ?? '').toString();
                final isPending =
                    approvalStatus == 'pending' && pendingDonorId.isNotEmpty;
                final isCurrentUserPendingDonor = pendingDonorId == userId;
                final acceptedDonorId =
                    (data['acceptedDonorId'] ?? '').toString();
                final acceptedDonorName =
                    (data['acceptedDonorName'] ?? 'Donor').toString();
                final isAccepted =
                    approvalStatus == 'accepted' && acceptedDonorId.isNotEmpty;
                final isCurrentUserAcceptedDonor =
                    acceptedDonorId == userId;
                final isExpired = isSosExpired(data, now: currentTime);

                return Container(
                  margin: const EdgeInsets.only(bottom: 14),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(
                      color: isOwn
                          ? const Color(0x55B71C1C)
                          : theme.colorScheme.outlineVariant,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 18,
                        offset: const Offset(0, 10),
                      )
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${data['bloodType'] ?? data['bloodGroup'] ?? 'N/A'} - ${data['units']} units',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFFB71C1C),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFDECEC),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              requesterIcon,
                              color: const Color(0xFFB71C1C),
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  requesterName,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  requesterTypeLabel,
                                  style: TextStyle(
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (requesterRole.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${AppText.text(context, 'type')}: $requesterRole'),
                      ],
                      if (phone.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${AppText.text(context, 'phone')}: $phone'),
                      ],
                      if (address.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${AppText.text(context, 'address')}: $address'),
                      ],
                      const SizedBox(height: 4),
                      Text('${AppText.text(context, 'priority')}: ${data['priority'] ?? 'medium'}'),
                      const SizedBox(height: 4),
                      _buildDeadlineStatus(data),
                      if (!onlyOwn) ...[
                        const SizedBox(height: 10),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: navigateToRequest,
                                icon: const Icon(Icons.navigation_outlined),
                                label: Text(AppText.text(context, 'navigate')),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: OutlinedButton.icon(
                                onPressed: phone.isEmpty ? null : () => callPhone(phone),
                                icon: const Icon(Icons.call_outlined),
                                label: Text(AppText.text(context, 'call')),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (!onlyOwn) ...[
                        const SizedBox(height: 10),
                        if (!isExpired)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: (!isAvailable || !canDonateNow)
                                  ? Colors.orange.withValues(alpha: 0.12)
                                  : Colors.green.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Text(
                              (!isAvailable || !canDonateNow)
                                  ? AppText.text(context, 'request_visible_cannot_donate')
                                  : AppText.text(context, 'eligible_to_respond'),
                              style: TextStyle(
                                color: (!isAvailable || !canDonateNow)
                                    ? Colors.orange.shade800
                                    : Colors.green.shade800,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                      ],
                      const SizedBox(height: 10),
                      if (!onlyOwn)
                        Column(
                          children: [
                            if (isExpired) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
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
                            ] else if (isAccepted && isCurrentUserAcceptedDonor) ...[
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
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
                              const SizedBox(height: 8),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () => _completeDonation(
                                    context,
                                    requestId: doc.id,
                                  ),
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
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    if (!isAvailable || !canDonateNow) {
                                      _showDonationBlockedMessage(
                                        context,
                                        isAvailable: isAvailable,
                                        lastDonationAt: lastDonationAt,
                                      );
                                      return;
                                    }
                                    if (isPending || isAccepted) return;
                                    _offerDonation(context, doc.id);
                                  },
                                  icon: const Icon(Icons.volunteer_activism),
                                  label: Text(
                                    isPending
                                        ? AppText.text(
                                            context,
                                            isCurrentUserPendingDonor
                                                ? 'waiting_for_approval'
                                                : 'awaiting_other_donor',
                                          )
                                        : isAccepted
                                            ? AppText.text(
                                                context,
                                                'awaiting_other_donor',
                                              )
                                            : AppText.text(
                                                context,
                                                'donate_blood',
                                              ),
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
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Text(
                                  isCurrentUserPendingDonor
                                      ? AppText.text(
                                          context,
                                          'waiting_for_approval',
                                        )
                                      : AppText.text(context, 'offer_waiting'),
                                  style: TextStyle(
                                    color: Colors.orange.shade800,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                            if (!isExpired && isAccepted && !isCurrentUserAcceptedDonor) ...[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 10,
                                ),
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
                      if (onlyOwn && isOwn) ...[
                        Text(
                          isExpired ? 'Expired' : AppText.text(context, 'request_live'),
                          style: TextStyle(
                            color: isExpired ? Colors.black54 : Colors.green,
                          ),
                        ),
                        if (!isExpired && isPending) ...[
                          const SizedBox(height: 10),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
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
                                        onPressed: () =>
                                            _respondToDonationOffer(
                                          context,
                                          requestId: doc.id,
                                          accept: true,
                                        ),
                                        child: Text(
                                          AppText.text(
                                            context,
                                            'accept_donation',
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: OutlinedButton(
                                        onPressed: () =>
                                            _respondToDonationOffer(
                                          context,
                                          requestId: doc.id,
                                          accept: false,
                                        ),
                                        child: Text(
                                          AppText.text(
                                            context,
                                            'reject_donation',
                                          ),
                                        ),
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
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
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
              }).toList();

            return ListView.separated(
              shrinkWrap: onlyOwn,
              physics: onlyOwn
                  ? const NeverScrollableScrollPhysics()
                  : const AlwaysScrollableScrollPhysics(),
              itemCount: list.length,
              separatorBuilder: (context, index) => const SizedBox(height: 0),
              itemBuilder: (context, index) => list[index],
            );
              },
            );
          },
        );
      },
    );
  }
}
