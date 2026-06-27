import 'dart:io';
import 'dart:typed_data';

class CertificateDownloadService {
  static Future<String?> saveDonationCertificate({
    required String donorName,
    required String hospitalName,
    required String bloodType,
    required int units,
    required String donationDate,
  }) async {
    final safeDonor = _safeName(donorName);
    final safeHospital = _safeName(hospitalName);
    final certificateId = _buildCertificateId(
      donorName: donorName,
      hospitalName: hospitalName,
      donationDate: donationDate,
    );
    final fileName = 'donation_certificate_${safeDonor}_to_$safeHospital.pdf';
    final donationType = units > 1 ? 'Multi Unit' : 'Voluntary';

    final savePath = await _resolveSavePath(fileName);
    if (savePath == null || savePath.trim().isEmpty) {
      throw Exception('Unable to access the Downloads folder on this device.');
    }

    final pdfBytes = _buildPdfBytes(
      donorName: donorName,
      hospitalName: hospitalName,
      bloodType: bloodType,
      units: units,
      donationDate: donationDate,
      donationType: donationType,
      certificateId: certificateId,
    );

    final outputFile = File(savePath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsBytes(pdfBytes, flush: true);
    return outputFile.path;
  }

  static Future<String?> _resolveSavePath(String fileName) async {
    final downloadsDirectory = await _downloadsDirectory();
    if (downloadsDirectory == null) {
      return null;
    }

    return _uniqueFilePath(downloadsDirectory, fileName);
  }

  static Future<Directory?> _downloadsDirectory() async {
    final candidates = <String>[];

    if (Platform.isAndroid) {
      candidates.addAll(const [
        '/storage/emulated/0/Download',
        '/sdcard/Download',
      ]);
    } else if (Platform.isWindows) {
      final userProfile = Platform.environment['USERPROFILE'];
      if (userProfile != null && userProfile.trim().isNotEmpty) {
        candidates.add('$userProfile${Platform.pathSeparator}Downloads');
      }
    } else {
      final home = Platform.environment['HOME'];
      if (home != null && home.trim().isNotEmpty) {
        candidates.add('$home${Platform.pathSeparator}Downloads');
      }
    }

    for (final path in candidates) {
      final directory = Directory(path);
      if (await directory.exists()) {
        return directory;
      }
    }

    if (Platform.isIOS) {
      final fallback = Directory(
        '${Directory.systemTemp.path}${Platform.pathSeparator}blood_bank_downloads',
      );
      await fallback.create(recursive: true);
      return fallback;
    }

    return null;
  }

  static String _uniqueFilePath(Directory directory, String fileName) {
    final dotIndex = fileName.lastIndexOf('.');
    final baseName = dotIndex > 0 ? fileName.substring(0, dotIndex) : fileName;
    final extension = dotIndex > 0 ? fileName.substring(dotIndex) : '';

    var candidate =
        '${directory.path}${Platform.pathSeparator}$baseName$extension';
    var counter = 1;

    while (File(candidate).existsSync()) {
      candidate =
          '${directory.path}${Platform.pathSeparator}$baseName($counter)$extension';
      counter++;
    }

    return candidate;
  }

  static Uint8List _buildPdfBytes({
    required String donorName,
    required String hospitalName,
    required String bloodType,
    required int units,
    required String donationDate,
    required String donationType,
    required String certificateId,
  }) {
    final issueDate = _formatIssueDate();

    final content = StringBuffer()
      ..writeln('1 1 1 rg')
      ..writeln('0 0 595 842 re f')
      ..writeln('0.98 0.96 0.93 rg')
      ..writeln('36 36 523 770 re f')
      ..writeln('0.72 0.08 0.10 RG')
      ..writeln('3 w')
      ..writeln('36 36 523 770 re S')
      ..writeln('0.86 0.78 0.62 RG')
      ..writeln('1 w')
      ..writeln('50 50 495 742 re S')
      ..writeln('0.72 0.08 0.10 rg')
      ..writeln('62 748 152 24 re f')
      ..writeln('1 1 1 rg')
      ..writeln('BT /F2 15 Tf 76 764 Td (BLOOD BANK APP) Tj ET')
      ..writeln('0.22 0.22 0.22 rg')
      ..writeln('BT /F1 11 Tf 384 764 Td (Certificate ID) Tj ET')
      ..writeln('BT /F1 10 Tf 347 746 Td (${_pdfText(certificateId)}) Tj ET')
      ..writeln('BT /F1 10 Tf 415 728 Td (Issued: ${_pdfText(issueDate)}) Tj ET')
      ..writeln('0.72 0.08 0.10 rg')
      ..writeln('BT /F2 18 Tf 240 688 Td (CERTIFICATE OF) Tj ET')
      ..writeln('BT /F2 34 Tf 122 646 Td (BLOOD DONATION) Tj ET')
      ..writeln('0.72 0.08 0.10 RG')
      ..writeln('1 w')
      ..writeln('182 632 m 413 632 l S')
      ..writeln('0.32 0.32 0.32 rg')
      ..writeln('BT /F1 13 Tf 188 602 Td (This certificate is proudly presented to) Tj ET')
      ..writeln('0.72 0.08 0.10 rg')
      ..writeln(
        'BT /F2 27 Tf ${_centeredTextX(donorName, 27)} 554 Td (${_pdfText(donorName)}) Tj ET',
      )
      ..writeln('0.78 0.67 0.50 RG')
      ..writeln('1 w')
      ..writeln('132 540 m 463 540 l S')
      ..writeln('0.18 0.18 0.18 rg')
      ..writeln(
        'BT /F1 14 Tf 86 496 Td (In recognition of donating ${_pdfText('$units unit${units > 1 ? 's' : ''}')} of ${_pdfText(bloodType)} blood for community care.) Tj ET',
      )
      ..writeln(
        'BT /F1 14 Tf 102 472 Td (Your generous contribution supported ${_pdfText(hospitalName)} and helped save lives.) Tj ET',
      )
      ..writeln('0.92 0.89 0.83 rg')
      ..writeln('76 332 443 104 re f')
      ..writeln('0.78 0.67 0.50 RG')
      ..writeln('1 w')
      ..writeln('76 332 443 104 re S')
      ..writeln('186 332 m 186 436 l S')
      ..writeln('297 332 m 297 436 l S')
      ..writeln('408 332 m 408 436 l S')
      ..writeln('0.72 0.08 0.10 rg')
      ..writeln('BT /F2 11 Tf 98 410 Td (DONATION DATE) Tj ET')
      ..writeln('BT /F2 11 Tf 221 410 Td (BLOOD GROUP) Tj ET')
      ..writeln('BT /F2 11 Tf 332 410 Td (RECIPIENT) Tj ET')
      ..writeln('BT /F2 11 Tf 430 410 Td (DONATION TYPE) Tj ET')
      ..writeln('0.16 0.16 0.16 rg')
      ..writeln(
        'BT /F2 15 Tf ${_centeredBlockX(donationDate, 15, 76, 110)} 372 Td (${_pdfText(donationDate)}) Tj ET',
      )
      ..writeln(
        'BT /F2 18 Tf ${_centeredBlockX(bloodType, 18, 186, 111)} 370 Td (${_pdfText(bloodType)}) Tj ET',
      )
      ..writeln(
        'BT /F2 11 Tf ${_centeredBlockX(hospitalName, 11, 297, 111)} 374 Td (${_pdfText(hospitalName)}) Tj ET',
      )
      ..writeln(
        'BT /F2 11 Tf ${_centeredBlockX(donationType, 11, 408, 111)} 374 Td (${_pdfText(donationType)}) Tj ET',
      )
      ..writeln(
        'BT /F1 10 Tf ${_centeredBlockX('$units unit(s)', 10, 408, 111)} 356 Td (${_pdfText('$units unit(s)')}) Tj ET',
      )
      ..writeln('0.32 0.32 0.32 rg')
      ..writeln('BT /F1 13 Tf 154 298 Td (Every drop you give carries hope, healing and life.) Tj ET')
      ..writeln('0.72 0.08 0.10 RG')
      ..writeln('1 w')
      ..writeln('92 248 88 88 re S')
      ..writeln('102 258 68 68 re S')
      ..writeln('0.72 0.08 0.10 rg')
      ..writeln('BT /F2 11 Tf 110 304 Td (OFFICIAL) Tj ET')
      ..writeln('BT /F2 11 Tf 126 288 Td (SEAL) Tj ET')
      ..writeln('BT /F2 10 Tf 112 272 Td (BLOOD BANK APP) Tj ET')
      ..writeln('0.18 0.18 0.18 rg')
      ..writeln('BT /F1 22 Tf 204 246 Td (Blood Services Director) Tj ET')
      ..writeln('0.72 0.08 0.10 RG')
      ..writeln('198 236 m 396 236 l S')
      ..writeln('0.18 0.18 0.18 rg')
      ..writeln('BT /F1 12 Tf 233 216 Td (Issued by Blood Bank App) Tj ET')
      ..writeln('BT /F1 11 Tf 191 198 Td (Verify authenticity with the certificate ID above.) Tj ET')
      ..writeln('0.72 0.08 0.10 rg')
      ..writeln('36 36 523 24 re f')
      ..writeln('1 1 1 rg')
      ..writeln('BT /F2 10 Tf 70 45 Td (SECURE) Tj ET')
      ..writeln('BT /F2 10 Tf 256 45 Td (VERIFIED) Tj ET')
      ..writeln('BT /F2 10 Tf 450 45 Td (HONORED) Tj ET');

    final stream = content.toString();
    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
      '<< /Length ${stream.length} >>\nstream\n$stream\nendstream',
    ];

    final buffer = StringBuffer('%PDF-1.4\n');
    final offsets = <int>[];

    for (var i = 0; i < objects.length; i++) {
      offsets.add(buffer.toString().length);
      buffer.write('${i + 1} 0 obj\n${objects[i]}\nendobj\n');
    }

    final xrefStart = buffer.toString().length;
    buffer.write('xref\n0 ${objects.length + 1}\n');
    buffer.write('0000000000 65535 f \n');
    for (final offset in offsets) {
      buffer.write('${offset.toString().padLeft(10, '0')} 00000 n \n');
    }
    buffer.write(
      'trailer << /Size ${objects.length + 1} /Root 1 0 R >>\nstartxref\n$xrefStart\n%%EOF',
    );

    return Uint8List.fromList(buffer.toString().codeUnits);
  }

  static String _safeName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
  }

  static String _pdfText(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)')
        .replaceAll('\n', ' ')
        .replaceAll('\r', ' ');
  }

  static String _centeredTextX(String text, double fontSize) {
    final approxWidth = text.length * fontSize * 0.50;
    final x = (595 - approxWidth) / 2;
    return x.toStringAsFixed(2);
  }

  static String _centeredBlockX(
    String text,
    double fontSize,
    double left,
    double width,
  ) {
    final approxWidth = text.length * fontSize * 0.48;
    final x = left + ((width - approxWidth) / 2);
    return x.toStringAsFixed(2);
  }

  static String _buildCertificateId({
    required String donorName,
    required String hospitalName,
    required String donationDate,
  }) {
    final donorCode =
        donorName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final hospitalCode =
        hospitalName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final dateCode = donationDate.replaceAll(RegExp(r'[^0-9]'), '');

    final donorPart = donorCode.padRight(4, 'X').substring(0, 4);
    final hospitalPart = hospitalCode.padRight(4, 'X').substring(0, 4);
    final datePart = dateCode.isEmpty
        ? '00000000'
        : dateCode.padRight(8, '0').substring(0, 8);

    return 'BBAPP-$datePart-$donorPart-$hospitalPart';
  }

  static String _formatIssueDate() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year}';
  }
}
