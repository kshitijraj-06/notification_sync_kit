import 'dart:convert';

/// The action taken by the driver in response to a notification.
enum InteractionType {
  /// Notification was never interacted with (auto-cleared or still pending).
  ignored,

  /// Notification was swiped away or cleared from the notification shade.
  dismissed,

  /// The driver tapped the notification and opened the app.
  /// Requires UsageStatsManager integration to detect reliably.
  opened,

  /// The driver replied directly from the notification shade.
  /// Requires reply-action tracking to detect reliably.
  replied;

  /// Serialises to an uppercase string for JSON storage.
  String toJson() => name.toUpperCase();

  /// Deserialises from a JSON string; falls back to [ignored] on unknown values.
  static InteractionType fromJson(String? value) {
    return InteractionType.values.firstWhere(
      (e) => e.name.toUpperCase() == (value ?? '').toUpperCase(),
      orElse: () => InteractionType.ignored,
    );
  }
}

/// An immutable snapshot of a single Android notification event, enriched
/// with driver-context data for behaviour analysis.
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
    required this.canReply,
    required this.haveExtraPicture,
    this.speedKmph,
    this.latitude,
    this.longitude,
    this.interactionType = InteractionType.ignored,
    this.interactionDelayMs,
  });

  // ─── Core notification fields ───────────────────────────────────────────────

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

  /// Whether the notification supports a direct-reply action.
  /// Useful for distinguishing a text message the driver could have replied
  /// to inline vs. a passive alert.
  final bool canReply;

  /// Whether the notification carried an image payload (e.g. a WhatsApp photo).
  /// A driver responding to a picture message represents a higher distraction
  /// risk than responding to plain text.
  final bool haveExtraPicture;

  // ─── Driver behaviour fields ────────────────────────────────────────────────

  /// Vehicle speed in km/h at the moment the notification arrived.
  /// `null` if location was unavailable.
  final double? speedKmph;

  /// Device latitude at the moment the notification arrived.
  /// `null` if location was unavailable.
  final double? latitude;

  /// Device longitude at the moment the notification arrived.
  /// `null` if location was unavailable.
  final double? longitude;

  /// How the driver responded to this notification.
  /// Defaults to [InteractionType.ignored] until a removal event is observed.
  final InteractionType interactionType;

  /// Milliseconds between the notification arriving and the driver acting on it.
  /// `null` if the notification was never removed while the app was running.
  final int? interactionDelayMs;

  // ─── Factories ─────────────────────────────────────────────────────────────

  /// Creates a [NotificationRecord] from a live service event object.
  ///
  /// Driver-context fields ([speedKmph], [latitude], [longitude],
  /// [interactionType], [interactionDelayMs]) are not set here; use
  /// [copyWith] to attach them once they are known.
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
      canReply: event.canReply == true,
      haveExtraPicture: event.haveExtraPicture == true,
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
      canReply: json['canReply'] as bool? ?? false,
      haveExtraPicture: json['haveExtraPicture'] as bool? ?? false,
      speedKmph: (json['speedKmph'] as num?)?.toDouble(),
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      interactionType:
          InteractionType.fromJson(json['interactionType'] as String?),
      interactionDelayMs: json['interactionDelayMs'] as int?,
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
      'canReply': canReply,
      'haveExtraPicture': haveExtraPicture,
      'speedKmph': speedKmph,
      'latitude': latitude,
      'longitude': longitude,
      'interactionType': interactionType.toJson(),
      'interactionDelayMs': interactionDelayMs,
    };
  }

  /// Returns a copy of this record with the specified fields replaced.
  NotificationRecord copyWith({
    bool? hasRemoved,
    double? speedKmph,
    double? latitude,
    double? longitude,
    InteractionType? interactionType,
    int? interactionDelayMs,
  }) {
    return NotificationRecord(
      id: id,
      packageName: packageName,
      title: title,
      text: text,
      timestampMillis: timestampMillis,
      hasRemoved: hasRemoved ?? this.hasRemoved,
      canReply: canReply,
      haveExtraPicture: haveExtraPicture,
      speedKmph: speedKmph ?? this.speedKmph,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      interactionType: interactionType ?? this.interactionType,
      interactionDelayMs: interactionDelayMs ?? this.interactionDelayMs,
    );
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
}
