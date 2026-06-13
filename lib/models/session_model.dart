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
  // Group session fields
  final String type; // "solo" | "group" | "sos"
  final int maxStudents;
  final int currentStudents;
  final double pricePerStudent;
  final List<String> studentIds;

  // New fields
  final String? cancelledBy; // "student" | "tutor" | null
  final DateTime? cancelledAt;
  final String? cancellationReason;
  final double? refundAmount;
  final String? disputeReason;
  final DateTime? disputedAt;
  final String? disputeStatus; // "open" | "resolved" | null
  final String? disputeResolution; // "full_credits" | "partial_credits" | "no_refund" | null
  final DateTime? disputeResolvedAt;
  final double? disputeRefundAmount;
  final bool? noShowReported;
  final DateTime? noShowReportedAt;

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
    this.type = 'solo',
    this.maxStudents = 1,
    this.currentStudents = 1,
    this.pricePerStudent = 0,
    this.studentIds = const [],
    this.cancelledBy,
    this.cancelledAt,
    this.cancellationReason,
    this.refundAmount,
    this.disputeReason,
    this.disputedAt,
    this.disputeStatus,
    this.disputeResolution,
    this.disputeResolvedAt,
    this.disputeRefundAmount,
    this.noShowReported,
    this.noShowReportedAt,
  });

  factory SessionModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final dt = _parseDateTime(data);
    final parsedAmount =
        (data['hourlyRate'] as num?)?.toDouble() ??
        (data['amount'] as num?)?.toDouble() ??
        0;
    final parsedMaxStudents = (data['maxStudents'] as num?)?.toInt() ?? 1;
    final parsedStudentId = (data['studentId'] ?? data['studentID'] ?? '').toString();
    final rawStudentIds = data['studentIds'];
    final parsedStudentIds = rawStudentIds is List
        ? rawStudentIds.map((e) => e.toString()).toList()
        : (parsedStudentId.isNotEmpty ? [parsedStudentId] : <String>[]);

    return SessionModel(
      id: doc.id,
      tutorId: (data['tutorId'] ?? data['tutorID'] ?? '').toString(),
      studentId: parsedStudentId,
      subject: (data['subject'] ?? '').toString(),
      dateTime: dt,
      status: (data['status'] ?? 'pending').toString(),
      roomName: (data['roomName'] ?? '').toString(),
      notes: (data['notes'] ?? data['note'] ?? '').toString(),
      durationMinutes: _toDurationMinutes(data),
      documents: _toDocuments(
        data['documents'] ?? data['uploadedDocuments'] ?? data['attachments'],
      ),
      meetLink: () {
        final link = data['meetLink']?.toString();
        if (link == null || link.contains('meet.ffmuc.net') || link.contains('jitsi')) return null;
        return link;
      }(),
      paymentId: data['paymentId']?.toString(),
      amount: parsedAmount,
      slotCount: _toSlotCount(data),
      reservedSlots: _toReservedSlots(data),
      refundStatus: (data['refundStatus'] ?? data['refund_status'] ?? data['refundStatus'])?.toString(),
      refundDone: _toNullableBool(data['refundDone'] ?? data['refund_done']),
      refundProcessedAt: _toDateTime(
        data['refundProcessedAt'] ?? data['refund_processed_at'],
      ),
      refundedAt: _toDateTime(data['refundedAt'] ?? data['refunded_at']),
      type: (data['type'] ?? 'solo').toString(),
      maxStudents: parsedMaxStudents < 1 ? 1 : parsedMaxStudents,
      currentStudents: (data['currentStudents'] as num?)?.toInt() ?? parsedStudentIds.length,
      pricePerStudent: (data['pricePerStudent'] as num?)?.toDouble() ??
          (parsedMaxStudents > 0 ? parsedAmount / parsedMaxStudents : parsedAmount),
      studentIds: parsedStudentIds,
      cancelledBy: data['cancelledBy']?.toString(),
      cancelledAt: _toDateTime(data['cancelledAt']),
      cancellationReason: data['cancellationReason']?.toString(),
      refundAmount: (data['refundAmount'] as num?)?.toDouble(),
      disputeReason: data['disputeReason']?.toString(),
      disputedAt: _toDateTime(data['disputedAt']),
      disputeStatus: data['disputeStatus']?.toString(),
      disputeResolution: data['disputeResolution']?.toString(),
      disputeResolvedAt: _toDateTime(data['disputeResolvedAt']),
      disputeRefundAmount: (data['disputeRefundAmount'] as num?)?.toDouble(),
      noShowReported: _toNullableBool(data['noShowReported']),
      noShowReportedAt: _toDateTime(data['noShowReportedAt']),
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
    String? type,
    int? maxStudents,
    int? currentStudents,
    double? pricePerStudent,
    List<String>? studentIds,
    String? cancelledBy,
    DateTime? cancelledAt,
    String? cancellationReason,
    double? refundAmount,
    String? disputeReason,
    DateTime? disputedAt,
    String? disputeStatus,
    String? disputeResolution,
    DateTime? disputeResolvedAt,
    double? disputeRefundAmount,
    bool? noShowReported,
    DateTime? noShowReportedAt,
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
      type: type ?? this.type,
      maxStudents: maxStudents ?? this.maxStudents,
      currentStudents: currentStudents ?? this.currentStudents,
      pricePerStudent: pricePerStudent ?? this.pricePerStudent,
      studentIds: studentIds ?? this.studentIds,
      cancelledBy: cancelledBy ?? this.cancelledBy,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancellationReason: cancellationReason ?? this.cancellationReason,
      refundAmount: refundAmount ?? this.refundAmount,
      disputeReason: disputeReason ?? this.disputeReason,
      disputedAt: disputedAt ?? this.disputedAt,
      disputeStatus: disputeStatus ?? this.disputeStatus,
      disputeResolution: disputeResolution ?? this.disputeResolution,
      disputeResolvedAt: disputeResolvedAt ?? this.disputeResolvedAt,
      disputeRefundAmount: disputeRefundAmount ?? this.disputeRefundAmount,
      noShowReported: noShowReported ?? this.noShowReported,
      noShowReportedAt: noShowReportedAt ?? this.noShowReportedAt,
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
