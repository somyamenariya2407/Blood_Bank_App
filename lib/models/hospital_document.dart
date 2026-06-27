import 'package:cloud_firestore/cloud_firestore.dart';

class HospitalDocument {
  static const String pendingStatus = 'pending';
  static const String verifiedStatus = 'verified';
  static const String rejectedStatus = 'rejected';

  final String type;
  final String title;
  final String fileName;
  final String contentType;
  final String storagePath;
  final String downloadUrl;
  final String reviewStatus;
  final DateTime? uploadedAt;
  final DateTime? reviewedAt;

  const HospitalDocument({
    required this.type,
    required this.title,
    required this.fileName,
    required this.contentType,
    required this.storagePath,
    required this.downloadUrl,
    required this.reviewStatus,
    required this.uploadedAt,
    required this.reviewedAt,
  });

  bool get hasFile =>
      downloadUrl.trim().isNotEmpty ||
      storagePath.trim().isNotEmpty;

  bool get isPdf => contentType.toLowerCase().contains('pdf');

  bool get isVerified => reviewStatus == verifiedStatus;

  bool get isRejected => reviewStatus == rejectedStatus;

  factory HospitalDocument.fromMap(
    String type,
    Map<String, dynamic> map, {
    String? fallbackTitle,
  }) {
    final uploadedAtRaw = map['uploadedAt'] ?? map['updatedAt'];
    final reviewedAtRaw = map['reviewedAt'];
    return HospitalDocument(
      type: type,
      title: (map['title'] ?? fallbackTitle ?? type).toString(),
      fileName: (map['fileName'] ?? '').toString(),
      contentType: (map['contentType'] ?? _inferContentType(map)).toString(),
      storagePath: (map['storagePath'] ?? '').toString(),
      downloadUrl: (map['downloadUrl'] ?? map['url'] ?? '').toString(),
      reviewStatus: normalizeReviewStatus(map['reviewStatus']),
      uploadedAt: _toDateTime(uploadedAtRaw),
      reviewedAt: _toDateTime(reviewedAtRaw),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'title': title,
      'fileName': fileName,
      'contentType': contentType,
      'storagePath': storagePath,
      'downloadUrl': downloadUrl,
      'url': downloadUrl,
      'reviewStatus': reviewStatus,
      'uploadedAt': uploadedAt == null ? FieldValue.serverTimestamp() : Timestamp.fromDate(uploadedAt!),
      'reviewedAt': reviewedAt == null ? null : Timestamp.fromDate(reviewedAt!),
    };
  }

  static Map<String, HospitalDocument> fromDocumentMap(
    Map<String, dynamic>? rawMap,
  ) {
    final docs = <String, HospitalDocument>{};
    if (rawMap == null) return docs;

    rawMap.forEach((key, value) {
      if (value is Map<String, dynamic>) {
        final doc = HospitalDocument.fromMap(key, value);
        if (doc.hasFile) {
          docs[key] = doc;
        }
      } else if (value is Map) {
        final normalized = Map<String, dynamic>.from(value);
        final doc = HospitalDocument.fromMap(key, normalized);
        if (doc.hasFile) {
          docs[key] = doc;
        }
      } else if (value is String && value.trim().isNotEmpty) {
        docs[key] = HospitalDocument(
          type: key,
          title: key,
          fileName: '',
          contentType: _inferContentType({'url': value}),
          storagePath: '',
          downloadUrl: value,
          reviewStatus: pendingStatus,
          uploadedAt: null,
          reviewedAt: null,
        );
      }
    });

    return docs;
  }

  static Map<String, dynamic> normalizeDocumentMapShape(
    Map<String, dynamic>? rawMap,
  ) {
    if (rawMap == null) return <String, dynamic>{};

    final normalized = <String, dynamic>{};

    rawMap.forEach((key, value) {
      if (key.contains('.')) {
        final parts = key.split('.');
        if (parts.length >= 2) {
          final documentType = parts.first.trim();
          final fieldName = parts.sublist(1).join('.').trim();
          if (documentType.isEmpty || fieldName.isEmpty) return;

          final existing =
              normalized[documentType] is Map<String, dynamic>
                  ? Map<String, dynamic>.from(
                      normalized[documentType] as Map<String, dynamic>,
                    )
                  : <String, dynamic>{};
          existing[fieldName] = value;
          normalized[documentType] = existing;
          return;
        }
      }

      normalized[key] = value;
    });

    return normalized;
  }

  static DateTime? _toDateTime(Object? value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  static String normalizeReviewStatus(Object? value) {
    final status = value?.toString().trim().toLowerCase();
    if (status == verifiedStatus || status == rejectedStatus) {
      return status!;
    }
    return pendingStatus;
  }

  static String _inferContentType(Map<String, dynamic> map) {
    final name = (map['fileName'] ?? map['downloadUrl'] ?? map['url'] ?? '')
        .toString()
        .toLowerCase();
    if (name.endsWith('.pdf')) return 'application/pdf';
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.jpg') || name.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    return 'application/octet-stream';
  }
}
