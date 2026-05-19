import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:notification_sync_kit/notification_sync_kit.dart';

NotificationRecord _record() => NotificationRecord(
      id: 'com.test|1|0',
      packageName: 'com.test',
      title: 'Test',
      text: 'Body',
      timestampMillis: 0,
      hasRemoved: false,
      canReply: false,
      haveExtraPicture: false,
    );

void main() {
  group('NotificationUploader', () {
    test('returns true on 200 response', () async {
      final uploader = NotificationUploader(
        endpoint: 'https://test.example.com/notifications',
        httpClient: MockClient((_) async => http.Response('ok', 200)),
      );
      expect(await uploader.upload(_record()), isTrue);
      uploader.dispose();
    });

    test('returns true on 201 response', () async {
      final uploader = NotificationUploader(
        endpoint: 'https://test.example.com/notifications',
        httpClient: MockClient((_) async => http.Response('created', 201)),
      );
      expect(await uploader.upload(_record()), isTrue);
      uploader.dispose();
    });

    test('returns false on 500 response', () async {
      final uploader = NotificationUploader(
        endpoint: 'https://test.example.com/notifications',
        httpClient: MockClient((_) async => http.Response('error', 500)),
      );
      expect(await uploader.upload(_record()), isFalse);
      uploader.dispose();
    });

    test('returns false on 401 response', () async {
      final uploader = NotificationUploader(
        endpoint: 'https://test.example.com/notifications',
        httpClient: MockClient((_) async => http.Response('unauthorized', 401)),
      );
      expect(await uploader.upload(_record()), isFalse);
      uploader.dispose();
    });

    test('returns false on network exception', () async {
      final uploader = NotificationUploader(
        endpoint: 'https://test.example.com/notifications',
        httpClient: MockClient((_) async => throw Exception('no network')),
      );
      expect(await uploader.upload(_record()), isFalse);
      uploader.dispose();
    });

    test('returns false for an invalid endpoint URL', () async {
      final uploader = NotificationUploader(endpoint: 'not a url');
      expect(await uploader.upload(_record()), isFalse);
      uploader.dispose();
    });

    test('sends Authorization header when bearerToken is provided', () async {
      http.Request? captured;
      final uploader = NotificationUploader(
        endpoint: 'https://test.example.com/notifications',
        bearerToken: 'my-secret-token',
        httpClient: MockClient((req) async {
          captured = req;
          return http.Response('ok', 200);
        }),
      );
      await uploader.upload(_record());
      expect(captured?.headers['Authorization'], 'Bearer my-secret-token');
      uploader.dispose();
    });

    test(
      'does NOT send Authorization header when bearerToken is absent',
      () async {
        http.Request? captured;
        final uploader = NotificationUploader(
          endpoint: 'https://test.example.com/notifications',
          httpClient: MockClient((req) async {
            captured = req;
            return http.Response('ok', 200);
          }),
        );
        await uploader.upload(_record());
        expect(captured?.headers.containsKey('Authorization'), isFalse);
        uploader.dispose();
      },
    );

    test('sends correct JSON body', () async {
      http.Request? captured;
      final uploader = NotificationUploader(
        endpoint: 'https://test.example.com/notifications',
        httpClient: MockClient((req) async {
          captured = req;
          return http.Response('ok', 200);
        }),
      );
      await uploader.upload(_record());
      expect(captured?.body, contains('"packageName":"com.test"'));
      expect(captured?.body, contains('"interactionType"'));
      uploader.dispose();
    });
  });
}
