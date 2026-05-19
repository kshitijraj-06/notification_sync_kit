import 'package:flutter_test/flutter_test.dart';
import 'package:notification_sync_kit/notification_sync_kit.dart';

NotificationRecord _baseRecord() => NotificationRecord(
      id: 'com.example|42|1700000000000',
      packageName: 'com.example',
      title: 'Hello',
      text: 'World',
      timestampMillis: 1700000000000,
      hasRemoved: false,
      canReply: false,
      haveExtraPicture: false,
    );

void main() {
  group('NotificationRecord', () {
    test('toJson contains all core fields', () {
      final json = _baseRecord().toJson();
      expect(json['id'], 'com.example|42|1700000000000');
      expect(json['packageName'], 'com.example');
      expect(json['title'], 'Hello');
      expect(json['text'], 'World');
      expect(json['timestampMillis'], 1700000000000);
      expect(json['hasRemoved'], false);
      expect(json['canReply'], false);
      expect(json['haveExtraPicture'], false);
    });

    test('toJson contains driver behaviour fields', () {
      final record = NotificationRecord(
        id: 'com.whatsapp|1|0',
        packageName: 'com.whatsapp',
        title: 'John',
        text: 'Hey',
        timestampMillis: 0,
        hasRemoved: true,
        canReply: true,
        haveExtraPicture: true,
        speedKmph: 60.5,
        latitude: 28.6,
        longitude: 77.2,
        interactionType: InteractionType.opened,
        interactionDelayMs: 3000,
      );
      final json = record.toJson();
      expect(json['canReply'], true);
      expect(json['haveExtraPicture'], true);
      expect(json['speedKmph'], 60.5);
      expect(json['latitude'], 28.6);
      expect(json['longitude'], 77.2);
      expect(json['interactionType'], 'OPENED');
      expect(json['interactionDelayMs'], 3000);
    });

    test('fromJson round-trips correctly', () {
      final record = _baseRecord();
      final decoded = NotificationRecord.fromJson(record.toJson());
      expect(decoded.id, record.id);
      expect(decoded.packageName, record.packageName);
      expect(decoded.title, record.title);
      expect(decoded.text, record.text);
      expect(decoded.timestampMillis, record.timestampMillis);
      expect(decoded.hasRemoved, record.hasRemoved);
      expect(decoded.canReply, record.canReply);
      expect(decoded.haveExtraPicture, record.haveExtraPicture);
    });

    test('fromJson round-trips driver behaviour fields', () {
      final record = NotificationRecord(
        id: 'a',
        packageName: 'com.x',
        title: 'T',
        text: 'B',
        timestampMillis: 1000,
        hasRemoved: true,
        canReply: true,
        haveExtraPicture: false,
        speedKmph: 45.0,
        latitude: 12.34,
        longitude: 56.78,
        interactionType: InteractionType.dismissed,
        interactionDelayMs: 1500,
      );
      final decoded = NotificationRecord.fromJson(record.toJson());
      expect(decoded.speedKmph, 45.0);
      expect(decoded.latitude, 12.34);
      expect(decoded.longitude, 56.78);
      expect(decoded.interactionType, InteractionType.dismissed);
      expect(decoded.interactionDelayMs, 1500);
    });

    test('encodeList / decodeList round-trips a list', () {
      final list = [_baseRecord(), _baseRecord()];
      final encoded = NotificationRecord.encodeList(list);
      final decoded = NotificationRecord.decodeList(encoded);
      expect(decoded.length, 2);
      expect(decoded.first.id, _baseRecord().id);
    });

    test('decodeList returns empty list for invalid JSON', () {
      expect(NotificationRecord.decodeList('not-json'), isEmpty);
      expect(NotificationRecord.decodeList('{}'), isEmpty);
    });

    test('fromJson fills defaults for missing keys', () {
      final r = NotificationRecord.fromJson({});
      expect(r.id, '');
      expect(r.packageName, '');
      expect(r.title, '');
      expect(r.text, '');
      expect(r.timestampMillis, 0);
      expect(r.hasRemoved, false);
      expect(r.canReply, false);
      expect(r.haveExtraPicture, false);
      expect(r.speedKmph, isNull);
      expect(r.latitude, isNull);
      expect(r.longitude, isNull);
      expect(r.interactionType, InteractionType.ignored);
      expect(r.interactionDelayMs, isNull);
    });

    test('copyWith updates only specified fields', () {
      final record = _baseRecord();
      final copy = record.copyWith(
        hasRemoved: true,
        interactionType: InteractionType.opened,
        interactionDelayMs: 2000,
        speedKmph: 80.0,
      );
      expect(copy.hasRemoved, true);
      expect(copy.interactionType, InteractionType.opened);
      expect(copy.interactionDelayMs, 2000);
      expect(copy.speedKmph, 80.0);
      // Unchanged fields are preserved
      expect(copy.id, record.id);
      expect(copy.packageName, record.packageName);
      expect(copy.canReply, record.canReply);
    });
  });

  group('InteractionType', () {
    test('toJson returns uppercase name', () {
      expect(InteractionType.ignored.toJson(), 'IGNORED');
      expect(InteractionType.dismissed.toJson(), 'DISMISSED');
      expect(InteractionType.opened.toJson(), 'OPENED');
      expect(InteractionType.replied.toJson(), 'REPLIED');
    });

    test('fromJson parses uppercase strings', () {
      expect(InteractionType.fromJson('IGNORED'), InteractionType.ignored);
      expect(InteractionType.fromJson('DISMISSED'), InteractionType.dismissed);
      expect(InteractionType.fromJson('OPENED'), InteractionType.opened);
      expect(InteractionType.fromJson('REPLIED'), InteractionType.replied);
    });

    test('fromJson is case-insensitive', () {
      expect(InteractionType.fromJson('opened'), InteractionType.opened);
      expect(InteractionType.fromJson('Dismissed'), InteractionType.dismissed);
    });

    test('fromJson falls back to ignored for unknown values', () {
      expect(InteractionType.fromJson(null), InteractionType.ignored);
      expect(InteractionType.fromJson(''), InteractionType.ignored);
      expect(InteractionType.fromJson('UNKNOWN'), InteractionType.ignored);
    });
  });
}
