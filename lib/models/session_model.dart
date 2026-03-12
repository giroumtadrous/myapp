import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class SessionDocument {
  final String name;
  final String url;
  final String? type;

  const SessionDocument({
    required this.name,
    required this.url,
    this.type,
  });
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
  final String? tutorName; // populated after join with tutors collection
  final String? studentName;
  final String? tutorPhotoUrl;

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
    this.tutorName,
    this.studentName,
    this.tutorPhotoUrl,
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
      roomName: (data['roomName'] ?? data['jitsiRoomName'] ?? '').toString(),
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
    );
  }

  static DateTime _parseDateTime(Map<String, dynamic> data) {
    final rawDate = data['dateTime'] ?? data['sessionDateTime'] ?? data['date'];

    if (rawDate is Timestamp) {
      return rawDate.toDate();
    }

    if (rawDate is String && rawDate.trim().isNotEmpty) {
      final normalizedDate = rawDate.trim();
      final parsedIso = DateTime.tryParse(normalizedDate);
      if (parsedIso != null) return parsedIso;

      final timeRaw = (data['time'] ?? data['timeDisplay'] ?? '00:00')
          .toString()
          .trim();
      final parsedTime = _parseTimeOfDay(timeRaw);

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
      tutorName: tutorName ?? this.tutorName,
      studentName: studentName ?? this.studentName,
      tutorPhotoUrl: tutorPhotoUrl ?? this.tutorPhotoUrl,
    );
  }

  static int _toDurationMinutes(Map<String, dynamic> data) {
    final dynamic value =
        data['durationMinutes'] ?? data['duration'] ?? data['durationMins'];
    if (value is num) return value.toInt();
    if (value is String) {
      final parsed = int.tryParse(value.trim());
      if (parsed != null) return parsed;
    }
    return 60;
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
