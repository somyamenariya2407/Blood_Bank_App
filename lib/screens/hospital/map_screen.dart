import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/account_moderation_service.dart';
import '../../services/location_service.dart';
import '../../utils/sos_request_time.dart';
import '../../widgets/common/app_header_title.dart';

class MapScreen extends StatefulWidget {
  final double? targetLat;
  final double? targetLng;

  const MapScreen({super.key, this.targetLat, this.targetLng});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> with WidgetsBindingObserver {
  static const double _nearbyRadiusKm = 20;
  final MapController _mapController = MapController();
  LatLng? userLocation;
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
      if (!mounted) return;

      setState(() {
        userLocation = LatLng(pos.latitude, pos.longitude);
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
        userLocation = null;
        isLoading = false;
        locationError = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  void _handleLocationUpdate(Position pos) {
    if (!mounted) return;

    final nextLocation = LatLng(pos.latitude, pos.longitude);
    setState(() {
      userLocation = nextLocation;
      isLoading = false;
      locationError = null;
    });

    if (_mapController.camera.zoom > 0) {
      _currentZoom = _mapController.camera.zoom;
    }
    try {
      _mapController.move(nextLocation, _currentZoom);
    } catch (_) {}
  }

  double distanceTo(LatLng target) {
    if (userLocation == null) return 0;

    return Geolocator.distanceBetween(
          userLocation!.latitude,
          userLocation!.longitude,
          target.latitude,
          target.longitude,
        ) /
        1000;
  }

  bool isNearby(LatLng target) => distanceTo(target) <= _nearbyRadiusKm;

  Future<void> openDirections(LatLng target) async {
    final url =
        'https://www.google.com/maps/dir/?api=1&destination=${target.latitude},${target.longitude}';
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }

  Future<void> callPhone(String phone) async {
    final cleaned = phone.trim();
    if (cleaned.isEmpty) return;
    await launchUrl(Uri.parse('tel:$cleaned'));
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
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
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
    final hospitalName = (data['hospitalName'] ?? data['name'] ?? 'Hospital')
        .toString();
    final phone = (data['phone'] ?? '').toString();
    final addressParts = [
      (data['address'] ?? '').toString().trim(),
      (data['city'] ?? '').toString().trim(),
      (data['pincode'] ?? '').toString().trim(),
    ].where((part) => part.isNotEmpty).toList();
    final address = addressParts.join(', ');
    final distance = distanceTo(point).toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                      child: const Icon(
                        Icons.local_hospital,
                        color: Colors.red,
                      ),
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
                _infoLine(Icons.near_me_outlined, 'Distance', '$distance km'),
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
                const SizedBox(height: 4),
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
                        onPressed: phone.isEmpty ? null : () => callPhone(phone),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void showUserDetails(Map<String, dynamic> data, LatLng point) {
    final name = (data['name'] ?? 'User').toString();
    final phone = (data['phone'] ?? '').toString();
    final bloodGroup = (data['bloodGroup'] ?? '').toString();
    final distance = distanceTo(point).toStringAsFixed(2);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.75,
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
                        color: Colors.blue.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Icon(
                        Icons.person_pin_circle,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (bloodGroup.isNotEmpty)
                  _infoLine(Icons.bloodtype_outlined, 'Blood Group', bloodGroup),
                if (phone.isNotEmpty)
                  _infoLine(Icons.call_outlined, 'Phone', phone),
                _infoLine(Icons.near_me_outlined, 'Distance', '$distance km'),
                if (phone.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () => callPhone(phone),
                      icon: const Icon(Icons.call),
                      label: const Text('Call'),
                    ),
                  ),
                ],
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
    final initialPage = 0;
    final pageController = PageController(initialPage: initialPage);
    var currentPage = initialPage;

    return StatefulBuilder(
      builder: (context, setSheetState) {
        final distance = distanceTo(point).toStringAsFixed(2);

        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.82,
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
                        child: const Icon(
                          Icons.warning_amber,
                          color: Colors.orange,
                        ),
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
                        final requesterName = (data['name'] ?? 'Unknown')
                            .toString();
                        final phone = (data['phone'] ?? '').toString();
                        final requesterRole =
                            (data['role'] ?? 'user').toString().toLowerCase();
                        final canOpenHospital =
                            requesterRole == 'hospital' && hospitalData != null;

                        return SingleChildScrollView(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (canOpenHospital)
                                InkWell(
                                  borderRadius: BorderRadius.circular(16),
                                  onTap: () {
                                    Navigator.of(context).pop();
                                    showHospitalDetails(hospitalData, point);
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.red.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(16),
                                      border: Border.all(
                                        color: Colors.red.withValues(alpha: 0.18),
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(
                                          Icons.local_hospital,
                                          color: Colors.red,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                requesterName,
                                                style: const TextStyle(
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
                                          color: Colors.red,
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                              else
                                _infoLine(
                                  Icons.person_outline,
                                  'Requester',
                                  requesterName,
                                ),
                              const SizedBox(height: 14),
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
                                '$distance km',
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

  Widget _buildSosMarkerIcon(int count) {
    return const Icon(Icons.warning, color: Colors.orange, size: 30);
  }

  List<Marker> buildMarkers(
    List<QueryDocumentSnapshot> hospitals,
    List<QueryDocumentSnapshot> users,
    List<QueryDocumentSnapshot> sosDocs,
  ) {
    final markers = <Marker>[];
    final hospitalsById = <String, Map<String, dynamic>>{};

    if (userLocation != null) {
      markers.add(
        Marker(
          point: userLocation!,
          width: 40,
          height: 40,
          child: const Icon(Icons.person, color: Colors.blue, size: 30),
        ),
      );
    }

    for (final h in hospitals) {
      final data = h.data() as Map<String, dynamic>;
      hospitalsById[h.id] = data;
      final status = AccountModerationService.normalizeStatus(data['status']);
      if (status != AccountModerationService.activeStatus) continue;
      final loc = data['location'];

      if (loc != null) {
        final point = LatLng(
          (loc['lat'] as num).toDouble(),
          (loc['lng'] as num).toDouble(),
        );
        markers.add(
          Marker(
            point: point,
            width: 40,
            height: 40,
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
    }

    for (final u in users) {
      final data = u.data() as Map<String, dynamic>;
      if ((data['role'] ?? '').toString() != 'user') continue;
      final status = AccountModerationService.normalizeStatus(data['status']);
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
          width: 36,
          height: 36,
          child: GestureDetector(
            onTap: () => showUserDetails(data, point),
            child: const Icon(
              Icons.person_pin_circle,
              color: Colors.blue,
              size: 28,
            ),
          ),
        ),
      );
    }

    final groupedHospitalSos = <String, List<Map<String, dynamic>>>{};
    final groupedHospitalPoints = <String, LatLng>{};
    final singleSosEntries = <({Map<String, dynamic> data, LatLng point})>[];

    for (final s in sosDocs) {
      final data = s.data() as Map<String, dynamic>;
      final loc = data['location'];

      if (loc == null) continue;

      final point = LatLng(
        (loc['lat'] as num).toDouble(),
        (loc['lng'] as num).toDouble(),
      );
      if (!isNearby(point)) continue;

      final requesterRole = (data['role'] ?? 'user').toString().toLowerCase();
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
      final hospitalId = (requests.first['hospitalId'] ?? '').toString();
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
                borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
              ),
              builder: (_) => _buildSOSSheet(
                point: point,
                requests: requests,
                hospitalData: hospitalData,
              ),
            ),
            child: _buildSosMarkerIcon(requests.length),
          ),
        ),
      );
    }

    for (final entry in singleSosEntries) {
      markers.add(
        Marker(
          point: entry.point,
          width: 40,
          height: 40,
          child: GestureDetector(
            onTap: () => showSOSDetails(entry.data, entry.point),
            child: _buildSosMarkerIcon(1),
          ),
        ),
      );
    }

    if (widget.targetLat != null && widget.targetLng != null) {
      markers.add(
        Marker(
          point: LatLng(widget.targetLat!, widget.targetLng!),
          width: 50,
          height: 50,
          child: const Icon(Icons.location_pin, color: Colors.green, size: 40),
        ),
      );
    }

    return markers;
  }

  Widget _buildLocationError() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.location_off, size: 52, color: Colors.red),
              const SizedBox(height: 14),
              const Text(
                'Turn on location and allow permission to load the hospital map.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text(
                locationError ?? 'Location is required.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  ElevatedButton.icon(
                    onPressed: loadLocation,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await LocationService.openLocationSettings();
                    },
                    icon: const Icon(Icons.gps_fixed),
                    label: const Text('Location Settings'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      await LocationService.openAppSettings();
                    },
                    icon: const Icon(Icons.settings),
                    label: const Text('App Settings'),
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
    return Scaffold(
      appBar: AppBar(title: const AppHeaderTitle(title: 'Live Map')),
      body: Builder(
        builder: (context) {
          if (isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (userLocation == null) {
            return _buildLocationError();
          }

          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('hospitals').snapshots(),
            builder: (context, hospitalSnapshot) {
              if (!hospitalSnapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              return StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, userSnapshot) {
                  if (!userSnapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('sos_requests')
                        .where('status', isEqualTo: 'active')
                        .snapshots(),
                    builder: (context, sosSnapshot) {
                      if (!sosSnapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }

                      final markers = buildMarkers(
                        hospitalSnapshot.data!.docs,
                        userSnapshot.data!.docs,
                        sosSnapshot.data!.docs,
                      );

                      return FlutterMap(
                        mapController: _mapController,
                        options: MapOptions(
                          initialCenter: userLocation!,
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
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: loadLocation,
        child: const Icon(Icons.refresh),
      ),
    );
  }
}
