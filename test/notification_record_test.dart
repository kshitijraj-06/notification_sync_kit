import 'package:flutter_test/flutter_test.dart';
import 'package:notification_sync_kit/notification_sync_kit.dart';

void main() {
  group('NotificationRecord', () {
    final record = NotificationRecord(
      id: 'com.example|42|1700000000000',
      packageName: 'com.example',
      title: 'Hello',
      text: 'World',
      timestampMillis: 1700000000000,
      hasRemoved: false,
      raw: {'id': 42, 'packageName': 'com.example'},
    );

    test('toJson contains all fields', () {
      final json = record.toJson();
      expect(json['id'], 'com.example|42|1700000000000');
      expect(json['packageName'], 'com.example');
      expect(json['title'], 'Hello');
      expect(json['text'], 'World');
      expect(json['timestampMillis'], 1700000000000);
      expect(json['hasRemoved'], false);
    });

    test('fromJson round-trips correctly', () {
      final decoded = NotificationRecord.fromJson(record.toJson());
      expect(decoded.id, record.id);
      expect(decoded.packageName, record.packageName);
      expect(decoded.title, record.title);
      expect(decoded.text, record.text);
      expect(decoded.timestampMillis, record.timestampMillis);
      expect(decoded.hasRemoved, record.hasRemoved);
    });

    test('encodeList / decodeList round-trips a list', () {
      final list = [record, record];
      final encoded = NotificationRecord.encodeList(list);
      final decoded = NotificationRecord.decodeList(encoded);
      expect(decoded.length, 2);
      expect(decoded.first.id, record.id);
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
    });
  });
}
