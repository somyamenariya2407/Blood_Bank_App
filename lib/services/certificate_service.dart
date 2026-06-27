import 'dart:io';
import 'dart:typed_data';

class CertificateService {
  static Future<String?> saveDonationCertificate({
    required String donorName,
    required String hospitalName,
    required String bloodType,
    required int units,
    required String donationDate,
  }) async {
    try {
      final safeDonor = _safeName(donorName);
      final safeHospital = _safeName(hospitalName);
      final fileName =
          'donation_certificate_${safeDonor}_to_$safeHospital.pdf';
      final certificateId = _buildCertificateId(
        donorName: donorName,
        hospitalName: hospitalName,
        donationDate: donationDate,
      );

      final downloadsDirectory = await _downloadsDirectory();
      if (downloadsDirectory == null) {
        return null;
      }

      final savePath = _uniqueFilePath(downloadsDirectory, fileName);
      final donationType = units > 1 ? 'Multi Unit' : 'Voluntary';
      final pdfBytes = _buildPdfBytes(
        donorName: donorName,
        hospitalName: hospitalName,
        bloodType: bloodType,
        units: units,
        donationDate: donationDate,
        donationType: donationType,
        certificateId: certificateId,
      );

      await File(savePath).writeAsBytes(pdfBytes, flush: true);
      return savePath;
    } catch (_) {
      return null;
    }
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

  static String _safeName(String value) {
    return value
        .trim()
        .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '')
        .toLowerCase();
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
    final content = StringBuffer()
      ..writeln('1 0 0 rg')
      ..writeln('40 770 180 24 re f')
      ..writeln('1 1 1 rg')
      ..writeln('BT /F2 16 Tf 56 777 Td (BLOOD BANK APP) Tj ET')
      ..writeln('1 0 0 rg')
      ..writeln('370 762 170 40 re f')
      ..writeln('1 1 1 rg')
      ..writeln('BT /F2 10 Tf 387 786 Td (CERTIFICATE ID) Tj ET')
      ..writeln(
        'BT /F2 13 Tf 388 772 Td (${_pdfText(certificateId)}) Tj ET',
      )
      ..writeln('0.75 0.03 0.09 rg')
      ..writeln('BT /F2 34 Tf 110 690 Td (BLOOD DONATION) Tj ET')
      ..writeln('0.12 0.12 0.12 rg')
      ..writeln('BT /F1 31 Tf 150 650 Td (CERTIFICATE) Tj ET')
      ..writeln('1 0 0 rg')
      ..writeln('165 612 250 26 re f')
      ..writeln('1 1 1 rg')
      ..writeln('BT /F2 14 Tf 205 620 Td (PROUDLY PRESENTED TO) Tj ET')
      ..writeln('0.75 0.03 0.09 rg')
      ..writeln(
        'BT /F2 32 Tf ${_centeredTextX(donorName, 32)} 560 Td (${_pdfText(donorName)}) Tj ET',
      )
      ..writeln('0.8 0.1 0.14 RG')
      ..writeln('110 542 m 250 542 l S')
      ..writeln('310 542 m 500 542 l S')
      ..writeln('0.75 0.03 0.09 rg')
      ..writeln('BT /F2 18 Tf 297 536 Td (♥) Tj ET')
      ..writeln('0.12 0.12 0.12 rg')
      ..writeln(
        'BT /F1 15 Tf 88 500 Td (In sincere appreciation for your selfless act of donating blood through the Blood Bank App.) Tj ET',
      )
      ..writeln(
        'BT /F1 15 Tf 106 478 Td (This donation supported ${_pdfText(hospitalName)} and helped save lives in the community.) Tj ET',
      )
      ..writeln('0.85 0.06 0.10 rg')
      ..writeln('68 400 108 78 re S')
      ..writeln('196 400 108 78 re S')
      ..writeln('324 400 108 78 re S')
      ..writeln('452 400 108 78 re S')
      ..writeln('0.75 0.03 0.09 rg')
      ..writeln('BT /F2 11 Tf 84 455 Td (DONATION DATE) Tj ET')
      ..writeln('BT /F2 11 Tf 224 455 Td (BLOOD GROUP) Tj ET')
      ..writeln('BT /F2 11 Tf 346 455 Td (RECIPIENT) Tj ET')
      ..writeln('BT /F2 11 Tf 478 455 Td (DONATION TYPE) Tj ET')
      ..writeln(
        'BT /F2 16 Tf ${_centeredBlockX(donationDate, 16, 68, 108)} 430 Td (${_pdfText(donationDate)}) Tj ET',
      )
      ..writeln(
        'BT /F2 18 Tf ${_centeredBlockX(bloodType, 18, 196, 108)} 428 Td (${_pdfText(bloodType)}) Tj ET',
      )
      ..writeln(
        'BT /F2 12 Tf ${_centeredBlockX(hospitalName, 12, 324, 108)} 432 Td (${_pdfText(hospitalName)}) Tj ET',
      )
      ..writeln(
        'BT /F2 14 Tf ${_centeredBlockX(donationType, 14, 452, 108)} 432 Td (${_pdfText(donationType)}) Tj ET',
      )
      ..writeln(
        'BT /F1 10 Tf ${_centeredBlockX('$units unit(s)', 10, 452, 108)} 415 Td (${_pdfText('$units unit(s)')}) Tj ET',
      )
      ..writeln('0.80 0.10 0.14 RG')
      ..writeln('110 352 360 34 re S')
      ..writeln('0.75 0.03 0.09 rg')
      ..writeln('BT /F2 12 Tf 124 364 Td (Every drop you give is a reason for someone to live.) Tj ET')
      ..writeln('0.80 0.10 0.14 rg')
      ..writeln('58 298 70 70 re S')
      ..writeln('BT /F2 10 Tf 66 332 Td (OFFICIAL) Tj ET')
      ..writeln('BT /F2 10 Tf 72 318 Td (SEAL) Tj ET')
      ..writeln('0 0 0 rg')
      ..writeln('BT /F1 24 Tf 222 286 Td (BloodLink Director) Tj ET')
      ..writeln('0.80 0.10 0.14 RG')
      ..writeln('205 278 m 385 278 l S')
      ..writeln('0.12 0.12 0.12 rg')
      ..writeln('BT /F1 13 Tf 215 258 Td (Director, Blood Services Division) Tj ET')
      ..writeln('BT /F1 13 Tf 245 240 Td (Blood Bank App) Tj ET')
      ..writeln('BT /F1 13 Tf 235 222 Td (Scan / verify by Certificate ID) Tj ET')
      ..writeln('1 0 0 rg')
      ..writeln('40 40 520 38 re f')
      ..writeln('1 1 1 rg')
      ..writeln('BT /F2 12 Tf 58 54 Td (SECURE. VERIFIED. TRUSTED.) Tj ET')
      ..writeln('BT /F2 12 Tf 235 54 Td (www.bloodbankapp.com) Tj ET')
      ..writeln('BT /F2 12 Tf 402 54 Td (24/7 HELPLINE: 1800-123-4567) Tj ET');

    final objects = <String>[
      '<< /Type /Catalog /Pages 2 0 R >>',
      '<< /Type /Pages /Kids [3 0 R] /Count 1 >>',
      '<< /Type /Page /Parent 2 0 R /MediaBox [0 0 595 842] /Resources << /Font << /F1 4 0 R /F2 5 0 R >> >> /Contents 6 0 R >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>',
      '<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica-Bold >>',
      '<< /Length ${content.toString().length} >>\nstream\n${content.toString()}endstream',
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

  static String _pdfText(String value) {
    return value
        .replaceAll(r'\', r'\\')
        .replaceAll('(', r'\(')
        .replaceAll(')', r'\)');
  }

  static String _centeredTextX(String text, double fontSize) {
    final approxWidth = text.length * fontSize * 0.52;
    final x = (595 - approxWidth) / 2;
    return x.toStringAsFixed(2);
  }

  static String _centeredBlockX(
    String text,
    double fontSize,
    double left,
    double width,
  ) {
    final approxWidth = text.length * fontSize * 0.5;
    final x = left + ((width - approxWidth) / 2);
    return x.toStringAsFixed(2);
  }

  static String _buildCertificateId({
    required String donorName,
    required String hospitalName,
    required String donationDate,
  }) {
    final donorCode = donorName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final hospitalCode =
        hospitalName.replaceAll(RegExp(r'[^A-Za-z0-9]'), '').toUpperCase();
    final dateCode = donationDate.replaceAll(RegExp(r'[^0-9]'), '');

    final donorPart = donorCode.padRight(4, 'X').substring(0, 4);
    final hospitalPart = hospitalCode.padRight(4, 'X').substring(0, 4);
    final datePart = dateCode.isEmpty ? '00000000' : dateCode.padRight(8, '0').substring(0, 8);

    return 'BBAPP-$datePart-$donorPart-$hospitalPart';
  }
}
