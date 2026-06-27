import 'package:cloud_firestore/cloud_firestore.dart';

class AppConfigService {
  static const double defaultSosRadiusKm = 20;

  static DocumentReference<Map<String, dynamic>> get _sosConfigRef =>
      FirebaseFirestore.instance.collection('app_config').doc('sos');

  static double normalizeSosRadius(Object? value) {
    final radius = value is num ? value.toDouble() : defaultSosRadiusKm;
    if (radius < 1) return 1;
    if (radius > 500) return 500;
    return radius;
  }

  static Stream<double> sosRadiusKmStream() {
    return _sosConfigRef.snapshots().map((doc) {
      final data = doc.data();
      return normalizeSosRadius(data?['radiusKm']);
    });
  }

  static Future<double> getSosRadiusKm() async {
    final doc = await _sosConfigRef.get();
    return normalizeSosRadius(doc.data()?['radiusKm']);
  }

  static Future<void> updateSosRadiusKm(double radiusKm) async {
    await _sosConfigRef.set({
      'radiusKm': normalizeSosRadius(radiusKm),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
