import 'package:flutter_test/flutter_test.dart';

import 'package:notification_sync_kit/notification_sync_kit.dart';

void main() {
  test('NotificationRecord list serialization round-trip', () {
    final original = NotificationRecord(
      id: 'abc',
      packageName: 'com.example.app',
      title: 'Hello',
      text: 'World',
      timestampMillis: 123,
      hasRemoved: false,
      raw: const <String, dynamic>{'k': 'v'},
    );
    final encoded = NotificationRecord.encodeList([original]);
    final decoded = NotificationRecord.decodeList(encoded);

    expect(decoded.length, 1);
    expect(decoded.first.id, 'abc');
    expect(decoded.first.packageName, 'com.example.app');
  });
}
