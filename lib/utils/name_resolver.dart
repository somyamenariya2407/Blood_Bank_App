import 'package:cloud_firestore/cloud_firestore.dart';

class NameResolver {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  static Future<String> userOrHospitalName(String? id) async {
    if (id == null || id.trim().isEmpty) return "Unknown";

    final userDoc = await _db.collection('users').doc(id).get();
    final userData = userDoc.data();
    if (userData != null) {
      final name = userData['name'] ?? userData['hospitalName'];
      if (name is String && name.trim().isNotEmpty) return name;
    }

    final hospitalDoc = await _db.collection('hospitals').doc(id).get();
    final hospitalData = hospitalDoc.data();
    if (hospitalData != null) {
      final name = hospitalData['hospitalName'] ?? hospitalData['name'];
      if (name is String && name.trim().isNotEmpty) return name;
    }

    return "Unknown";
  }
}
