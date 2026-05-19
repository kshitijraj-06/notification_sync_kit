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
      canReply: true,
      haveExtraPicture: false,
      speedKmph: 55.0,
      interactionType: InteractionType.dismissed,
      interactionDelayMs: 800,
    );
    final encoded = NotificationRecord.encodeList([original]);
    final decoded = NotificationRecord.decodeList(encoded);

    expect(decoded.length, 1);
    expect(decoded.first.id, 'abc');
    expect(decoded.first.packageName, 'com.example.app');
    expect(decoded.first.canReply, true);
    expect(decoded.first.speedKmph, 55.0);
    expect(decoded.first.interactionType, InteractionType.dismissed);
    expect(decoded.first.interactionDelayMs, 800);
  });
}
