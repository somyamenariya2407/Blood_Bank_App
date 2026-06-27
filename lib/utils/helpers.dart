import 'package:geolocator/geolocator.dart';

double calculateDistance(
  double lat1,
  double lon1,
  double lat2,
  double lon2,
) {
  return Geolocator.distanceBetween(lat1, lon1, lat2, lon2) / 1000;
}

bool isCompatible(String donor, String required) {
  final Map<String, List<String>> map = {
    "O-": ["ALL"],
    "O+": ["ALL"],
    "B-": ["ALL"],
    "A+": ["ALL"],
    "A-": ["ALL"],
    "B+": ["ALL"],
    "AB-": ["ALL"],
    "AB+": ["ALL"],
  };

  final compatibleDonors = map[required];
  if (compatibleDonors == null) return donor == required;

  if (compatibleDonors.contains("ALL")) return true;
  return compatibleDonors.contains(donor);
}
