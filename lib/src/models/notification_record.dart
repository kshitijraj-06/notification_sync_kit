import 'dart:convert';

/// An immutable snapshot of a single Android notification event.
///
/// Instances are created either from a live [NotificationListenerService]
/// event (via [NotificationRecord.fromServiceEvent]) or deserialized from
/// stored JSON (via [NotificationRecord.fromJson]).
class NotificationRecord {
  /// Creates a [NotificationRecord] with all required fields.
  NotificationRecord({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    required this.timestampMillis,
    required this.hasRemoved,
    required this.raw,
  });

  /// A composite unique identifier: `"<packageName>|<eventId>|<timestampMillis>"`.
  final String id;

  /// The Android package name of the app that posted the notification
  /// (e.g. `"com.whatsapp"`).
  final String packageName;

  /// The notification title. Empty string if the notification had no title.
  final String title;

  /// The notification body text. Empty string if the notification had no body.
  final String text;

  /// Unix timestamp (milliseconds since epoch) of when this record was created.
  final int timestampMillis;

  /// Whether this event represents a notification being *removed* rather than
  /// posted. `true` = dismissed/removed, `false` = posted.
  final bool hasRemoved;

  /// The raw key/value payload received from the notification listener service.
  final Map<String, dynamic> raw;

  // ─── Factories ─────────────────────────────────────────────────────────────

  /// Creates a [NotificationRecord] from a live service event object.
  ///
  /// The [event] is the dynamic object emitted by
  /// `NotificationListenerService.notificationsStream`.
  factory NotificationRecord.fromServiceEvent(dynamic event) {
    final packageName = _toCleanString(event.packageName);
    final title = _toCleanString(event.title);
    final content = _toCleanString(event.content);
    final hasRemoved = event.hasRemoved == true;
    final eventId = event.id?.toString() ?? '';
    final now = DateTime.now().millisecondsSinceEpoch;
    final id = '$packageName|$eventId|$now';

    return NotificationRecord(
      id: id,
      packageName: packageName,
      title: title,
      text: content,
      timestampMillis: now,
      hasRemoved: hasRemoved,
      raw: _rawPayload(event),
    );
  }

  /// Deserializes a [NotificationRecord] from a JSON map.
  factory NotificationRecord.fromJson(Map<String, dynamic> json) {
    return NotificationRecord(
      id: json['id'] as String? ?? '',
      packageName: json['packageName'] as String? ?? '',
      title: json['title'] as String? ?? '',
      text: json['text'] as String? ?? '',
      timestampMillis: json['timestampMillis'] as int? ?? 0,
      hasRemoved: json['hasRemoved'] as bool? ?? false,
      raw:
          (json['raw'] as Map?)?.cast<String, dynamic>() ?? <String, dynamic>{},
    );
  }

  // ─── Serialization ─────────────────────────────────────────────────────────

  /// Serializes this record to a JSON-compatible map.
  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'id': id,
      'packageName': packageName,
      'title': title,
      'text': text,
      'timestampMillis': timestampMillis,
      'hasRemoved': hasRemoved,
      'raw': raw,
    };
  }

  /// Encodes a list of records to a JSON string suitable for storage.
  static String encodeList(List<NotificationRecord> records) {
    return jsonEncode(records.map((record) => record.toJson()).toList());
  }

  /// Decodes a list of records from a JSON string produced by [encodeList].
  /// Returns an empty list if [data] is malformed or not valid JSON.
  static List<NotificationRecord> decodeList(String data) {
    try {
      final parsed = jsonDecode(data);
      if (parsed is! List) return const [];
      return parsed
          .whereType<Map>()
          .map(
            (json) => NotificationRecord.fromJson(json.cast<String, dynamic>()),
          )
          .toList();
    } on FormatException {
      return const [];
    }
  }

  // ─── Helpers ───────────────────────────────────────────────────────────────

  static String _toCleanString(Object? value) {
    if (value == null) return '';
    return value.toString().trim();
  }

  static Map<String, dynamic> _rawPayload(dynamic event) {
    return <String, dynamic>{
      'id': event.id,
      'packageName': event.packageName,
      'title': event.title,
      'content': event.content,
      'canReply': event.canReply,
      'hasRemoved': event.hasRemoved,
      'haveExtraPicture': event.haveExtraPicture,
    };
  }
}
