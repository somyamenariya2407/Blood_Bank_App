import 'package:cloud_firestore/cloud_firestore.dart';

const List<String> sosQuickTimeOptions = <String>[
  '5 min',
  '10 min',
  '15 min',
  '30 min',
  '1 hr',
  '3 hr',
  '6 hr',
  '12 hr',
  '1 day',
  '2 days',
];

class SosDeadlineSelection {
  final DateTime deadline;
  final String mode;
  final String label;

  const SosDeadlineSelection({
    required this.deadline,
    required this.mode,
    required this.label,
  });
}

SosDeadlineSelection resolveSosDeadline({
  required String presetLabel,
  required String customInput,
  DateTime? pickedDateTime,
  DateTime? now,
}) {
  final referenceNow = now ?? DateTime.now();
  final trimmedCustomInput = customInput.trim();

  if (pickedDateTime != null) {
    if (!pickedDateTime.isAfter(referenceNow)) {
      throw const FormatException('Please choose a future date and time.');
    }
    return SosDeadlineSelection(
      deadline: pickedDateTime,
      mode: 'datetime',
      label: formatSosAbsoluteDateTime(pickedDateTime),
    );
  }

  if (trimmedCustomInput.isNotEmpty) {
    final duration = parseSosDurationInput(trimmedCustomInput);
    if (duration == null || duration.inSeconds <= 0) {
      throw const FormatException(
        'Enter custom time like 45 min, 2 hr, or 3 days.',
      );
    }
    return SosDeadlineSelection(
      deadline: referenceNow.add(duration),
      mode: 'custom',
      label: trimmedCustomInput,
    );
  }

  final duration = parseSosDurationInput(presetLabel);
  if (duration == null || duration.inSeconds <= 0) {
    throw const FormatException('Please choose a valid required time.');
  }

  return SosDeadlineSelection(
    deadline: referenceNow.add(duration),
    mode: 'preset',
    label: presetLabel,
  );
}

Duration? parseSosDurationInput(String input) {
  final normalized = input.trim().toLowerCase();
  if (normalized.isEmpty) return null;

  final match = RegExp(r'^(\d+)\s*([a-z]+)$').firstMatch(
    normalized.replaceAll(' ', ''),
  );

  if (match == null) return null;

  final value = int.tryParse(match.group(1) ?? '');
  final unit = match.group(2) ?? '';
  if (value == null || value <= 0) return null;

  if (<String>{
    'm',
    'min',
    'mins',
    'mn',
    'mns',
    'minute',
    'minutes',
  }.contains(unit)) {
    return Duration(minutes: value);
  }

  if (<String>{'h', 'hr', 'hrs', 'hour', 'hours'}.contains(unit)) {
    return Duration(hours: value);
  }

  if (<String>{'d', 'day', 'days'}.contains(unit)) {
    return Duration(days: value);
  }

  return null;
}

DateTime? sosRequiredByDate(Map<String, dynamic> data) {
  final value = data['requiredByAt'];
  if (value is Timestamp) return value.toDate();
  return null;
}

bool isSosExpired(Map<String, dynamic> data, {DateTime? now}) {
  final deadline = sosRequiredByDate(data);
  if (deadline == null) return false;
  return !(deadline.isAfter(now ?? DateTime.now()));
}

String formatSosRemaining(DateTime deadline, {DateTime? now}) {
  final diff = deadline.difference(now ?? DateTime.now());
  if (diff.inSeconds <= 0) return 'Expired';

  final days = diff.inDays;
  final hours = diff.inHours.remainder(24);
  final minutes = diff.inMinutes.remainder(60);
  final seconds = diff.inSeconds.remainder(60);

  if (days > 0) {
    return '${days}d ${hours}h ${minutes}m';
  }

  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

String formatSosAbsoluteDateTime(DateTime dateTime) {
  final hour = dateTime.hour % 12 == 0 ? 12 : dateTime.hour % 12;
  final minute = dateTime.minute.toString().padLeft(2, '0');
  final meridiem = dateTime.hour >= 12 ? 'PM' : 'AM';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year} $hour:$minute $meridiem';
}
