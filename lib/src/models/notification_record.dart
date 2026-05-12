import 'dart:convert';

class NotificationRecord {
  NotificationRecord({
    required this.id,
    required this.packageName,
    required this.title,
    required this.text,
    required this.timestampMillis,
    required this.hasRemoved,
    required this.raw,
  });

  final String id;
  final String packageName;
  final String title;
  final String text;
  final int timestampMillis;
  final bool hasRemoved;
  final Map<String, dynamic> raw;

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

  static String encodeList(List<NotificationRecord> records) {
    return jsonEncode(records.map((record) => record.toJson()).toList());
  }

  static List<NotificationRecord> decodeList(String data) {
    final parsed = jsonDecode(data);
    if (parsed is! List) {
      return const [];
    }
    return parsed
        .whereType<Map>()
        .map(
          (json) => NotificationRecord.fromJson(json.cast<String, dynamic>()),
        )
        .toList();
  }

  static String _toCleanString(Object? value) {
    if (value == null) {
      return '';
    }
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
