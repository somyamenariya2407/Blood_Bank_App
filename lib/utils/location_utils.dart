import 'dart:math';

// 🔥 Calculate distance between two points (in KM)
double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    ) {
  const double R = 6371; // Earth radius in km

  double dLat = _deg2rad(lat2 - lat1);
  double dLon = _deg2rad(lon2 - lon1);

  double a =
      sin(dLat / 2) * sin(dLat / 2) +
          cos(_deg2rad(lat1)) *
              cos(_deg2rad(lat2)) *
              sin(dLon / 2) *
              sin(dLon / 2);

  double c = 2 * atan2(sqrt(a), sqrt(1 - a));

  return R * c;
}

// 🔥 Convert degrees to radians
double _deg2rad(double deg) {
  return deg * (pi / 180);
}

// 🔥 Check if user is within radius (KM)
bool isNearby(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
    double radiusKm,
    ) {
  double distance = calculateDistance(lat1, lon1, lat2, lon2);

  return distance <= radiusKm;
}