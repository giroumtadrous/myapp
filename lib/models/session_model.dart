import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SessionDocument {
  final String name;
  final String url;
  final String? type;

  const SessionDocument({required this.name, required this.url, this.type});
}

class SessionModel {
  final String id;
  final String tutorId;
  final String studentId;
  final String subject;
  final DateTime dateTime;
  final String status;
  final String roomName;
  final String notes;
  final int durationMinutes;
  final List<SessionDocument> documents;
  final String? meetLink;
  final String? paymentId;
  final double amount;
  final int slotCount;
  final List<String> reservedSlots;
  final String? tutorName; // populated after join with tutors collection
  final String? studentName;
  final String? tutorPhotoUrl;
  final String? refundStatus;
  final bool? refundDone;
  final DateTime? refundProcessedAt;
  final DateTime? refundedAt;

  const SessionModel({
    required this.id,
    required this.tutorId,
    required this.studentId,
    required this.subject,
    required this.dateTime,
    required this.status,
    required this.roomName,
    this.notes = '',
    this.durationMinutes = 60,
    this.documents = const [],
    this.meetLink,
    this.paymentId,
    this.amount = 0,
    this.slotCount = 1,
    this.reservedSlots = const [],
    this.tutorName,
    this.studentName,
    this.tutorPhotoUrl,
    this.refundStatus,
    this.refundDone,
    this.refundProcessedAt,
    this.refundedAt,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dt = _parseDateTime(data);

    return SessionModel(
      id: doc.id,
      tutorId: (data['tutorId'] ?? data['tutorID'] ?? '').toString(),
      studentId: (data['studentId'] ?? data['studentID'] ?? '').toString(),
      subject: (data['subject'] ?? '').toString(),
      dateTime: dt,
      status: (data['status'] ?? 'pending').toString(),
      roomName: (data['roomName'] ?? '').toString(),
      notes: (data['notes'] ?? data['note'] ?? '').toString(),
      durationMinutes: _toDurationMinutes(data),
      documents: _toDocuments(
        data['documents'] ?? data['uploadedDocuments'] ?? data['attachments'],
      ),
      meetLink: data['meetLink']?.toString(),
      paymentId: data['paymentId']?.toString(),
      amount:
          (data['hourlyRate'] as num?)?.toDouble() ??
          (data['amount'] as num?)?.toDouble() ??
          0,
      slotCount: _toSlotCount(data),
      reservedSlots: _toReservedSlots(data),
      refundStatus: (data['refundStatus'] ?? data['refund_status'])?.toString(),
      refundDone: _toNullableBool(data['refundDone'] ?? data['refund_done']),
      refundProcessedAt: _toDateTime(
        data['refundProcessedAt'] ?? data['refund_processed_at'],
      ),
      refundedAt: _toDateTime(data['refundedAt'] ?? data['refunded_at']),
    );
  }

  static DateTime _parseDateTime(Map<String, dynamic> data) {
    final rawDate = data['dateTime'] ?? data['sessionDateTime'] ?? data['date'];

    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    if (rawDate is String && rawDate.trim().isNotEmpty) {
      final normalizedDate = rawDate.trim();
      final timeRaw = _extractStartTime(
        (data['time'] ?? data['timeDisplay'] ?? '').toString().trim(),
      );
      final parsedTime = _parseTimeOfDay(timeRaw);
      final parsedIso = DateTime.tryParse(normalizedDate);
      if (parsedIso != null) {
        // If the date string has no explicit time but time is stored separately,
        // merge both so upcoming/past filters classify sessions correctly.
        final hasTimeInsideDate = RegExp(r'T\d{1,2}:').hasMatch(normalizedDate);
        if (!hasTimeInsideDate && timeRaw.isNotEmpty) {
          return DateTime(
            parsedIso.year,
            parsedIso.month,
            parsedIso.day,
            parsedTime.hour,
            parsedTime.minute,
          );
        }
        return parsedIso;
      }

      // Try a few common date formats used by older documents.
      final dateFormats = <DateFormat>[
        DateFormat('yyyy-MM-dd'),
        DateFormat('yyyy/MM/dd'),
        DateFormat('MM/dd/yyyy'),
        DateFormat('dd/MM/yyyy'),
      ];

      for (final formatter in dateFormats) {
        try {
          final parsedDate = formatter.parseStrict(normalizedDate);
          return DateTime(
            parsedDate.year,
            parsedDate.month,
            parsedDate.day,
            parsedTime.hour,
            parsedTime.minute,
          );
        } catch (_) {}
      }
    }

    return DateTime.now();
  }

  static String _extractStartTime(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';

    final rangeSplit = trimmed.split(RegExp(r'\s*-\s*|\|'));
    return rangeSplit.first.trim();
  }

  static DateTime _parseTimeOfDay(String value) {
    if (value.isEmpty) {
      return DateTime(1970, 1, 1, 0, 0);
    }

    final formats = <DateFormat>[
      DateFormat('HH:mm'),
      DateFormat('HH:mm:ss'),
      DateFormat.jm(),
    ];

    for (final formatter in formats) {
      try {
        final parsed = formatter.parseStrict(value);
        return DateTime(1970, 1, 1, parsed.hour, parsed.minute);
      } catch (_) {}
    }

    return DateTime(1970, 1, 1, 0, 0);
  }

  SessionModel copyWith({
    String? tutorName,
    String? studentName,
    String? tutorPhotoUrl,
    String? refundStatus,
    bool? refundDone,
    DateTime? refundProcessedAt,
    DateTime? refundedAt,
  }) {
    return SessionModel(
      id: id,
      tutorId: tutorId,
      studentId: studentId,
      subject: subject,
      dateTime: dateTime,
      status: status,
      roomName: roomName,
      notes: notes,
      durationMinutes: durationMinutes,
      documents: documents,
      meetLink: meetLink,
      paymentId: paymentId,
      amount: amount,
      slotCount: slotCount,
      reservedSlots: reservedSlots,
      tutorName: tutorName ?? this.tutorName,
      studentName: studentName ?? this.studentName,
      tutorPhotoUrl: tutorPhotoUrl ?? this.tutorPhotoUrl,
      refundStatus: refundStatus ?? this.refundStatus,
      refundDone: refundDone ?? this.refundDone,
      refundProcessedAt: refundProcessedAt ?? this.refundProcessedAt,
      refundedAt: refundedAt ?? this.refundedAt,
    );
  }

  static int _toDurationMinutes(Map<String, dynamic> data) {
    final dynamic value =
        data['durationMinutes'] ?? data['duration'] ?? data['durationMins'];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;

      final embedded = RegExp(r'\d+').firstMatch(value);
      if (embedded != null) {
        final extracted = int.tryParse(embedded.group(0)!);
        if (extracted != null) return extracted;
      }
    }
    return 60;
  }

  static int _toSlotCount(Map<String, dynamic> data) {
    final dynamic value = data['slotCount'];
    if (value is num) return value.toInt().clamp(1, 24);
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed.clamp(1, 24);

      final embedded = RegExp(r'\d+').firstMatch(value);
      if (embedded != null) {
        final extracted = int.tryParse(embedded.group(0)!);
        if (extracted != null) return extracted.clamp(1, 24);
      }
    }

    final duration = _toDurationMinutes(data);
    final inferred = (duration / 60).round();
    return inferred < 1 ? 1 : inferred;
  }

  static List<String> _toReservedSlots(Map<String, dynamic> data) {
    final dynamic value = data['reservedSlots'];
    if (value is! List) {
      final time = (data['time'] ?? '').toString().trim();
      return time.isEmpty ? const [] : <String>[time];
    }

    return value
        .map((entry) => entry.toString().trim())
        .where((entry) => entry.isNotEmpty)
        .toList();
  }

  static bool? _toNullableBool(dynamic value) {
    if (value == null) return null;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized.isEmpty) return null;
    if (normalized == 'true' || normalized == 'yes' || normalized == 'done') {
      return true;
    }
    if (normalized == 'false' ||
        normalized == 'no' ||
        normalized == 'pending') {
      return false;
    }
    return null;
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String && value.trim().isNotEmpty) {
      return DateTime.tryParse(value.trim());
    }
    return null;
  }

  static List<SessionDocument> _toDocuments(dynamic raw) {
    if (raw is! List) return const [];

    return raw
        .map((item) {
          if (item is String) {
            final trimmed = item.trim();
            if (trimmed.isEmpty) return null;
            return SessionDocument(name: 'Document', url: trimmed);
          }

          if (item is Map<String, dynamic>) {
            final url = (item['url'] ?? item['downloadUrl'] ?? '').toString();
            if (url.trim().isEmpty) return null;

            final name = (item['name'] ?? item['fileName'] ?? 'Document')
                .toString();
            final type = item['type']?.toString();

            return SessionDocument(name: name, url: url, type: type);
          }

          return null;
        })
        .whereType<SessionDocument>()
        .toList();
  }
}
