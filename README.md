# notification_sync_kit

A Flutter package for **Android** that captures system notifications, persists them to a local queue, and syncs them to your server via HTTP — with Bearer token auth and automatic retry.

[![pub.dev](https://img.shields.io/pub/v/notification_sync_kit.svg)](https://pub.dev/packages/notification_sync_kit)
[![Platform](https://img.shields.io/badge/platform-android-green.svg)](https://pub.dev/packages/notification_sync_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Features

- 🔔 **Listen** to all Android notifications via `NotificationListenerService`
- 💾 **Queue** notifications locally in `SharedPreferences` (survives app restarts)
- 📡 **Upload** each notification as JSON to your HTTP endpoint with a Bearer token
- 🔄 **Retry** — failed uploads stay in the queue and are retried every 30 seconds
- ⚙️ **Configurable** endpoint and token at runtime — no rebuild needed
- 🧩 **Single import** — one barrel file exposes everything

---

## Platform support

| Android | iOS | Web |
|---------|-----|-----|
| ✅ | ❌ | ❌ |

This package depends on [`notification_listener_service`](https://pub.dev/packages/notification_listener_service), which is Android-only.

---

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  notification_sync_kit: ^0.1.0
```

Then run:

```sh
flutter pub get
```

### Android setup

In `AndroidManifest.xml`, add the notification listener permission inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE" />
```

And inside `<application>`:

```xml
<service
    android:name="com.amorenew.notificationlistener.NotificationListener"
    android:label="@string/app_name"
    android:exported="true"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

---

## Quick start

```dart
import 'package:notification_sync_kit/notification_sync_kit.dart';

// 1. Set up the local queue
final store = NotificationQueueStore();
await store.init();

// 2. Set up the uploader (Bearer token auth)
final uploader = NotificationUploader(
  endpoint: 'https://api.example.com/notifications',
  bearerToken: 'your-secret-token',
);

// 3. Listen for notifications
final controller = NotificationListenerController();
controller.events.listen((NotificationRecord record) async {
  // Try instant upload — fall back to queue on failure
  final ok = await uploader.upload(record);
  if (!ok) await store.add(record);
});
await controller.startIfGranted();

// 4. Retry queued records every 30 seconds
final syncManager = NotificationSyncManager(
  queueStore: store,
  uploader: uploader,
  onSyncResult: (remaining, message) async {
    print(message); // e.g. "All 3 queued record(s) synced."
  },
);
```

Don't forget to `dispose()` everything when done:

```dart
controller.dispose();
syncManager.dispose(); // also disposes the uploader
```

---

## Persisting config across restarts

Use `NotificationConfig` to save the endpoint and token in `SharedPreferences` so they survive app restarts:

```dart
final config = NotificationConfig();
await config.init();

// Save
await config.setEndpoint('https://api.example.com/notifications');
await config.setToken('your-secret-token');

// Read back
print(config.endpoint); // https://api.example.com/notifications
print(config.isConfigured); // true
```

Update the uploader at runtime without restarting:

```dart
uploader.setEndpoint(config.endpoint);
uploader.setBearerToken(config.token);
```

---

## NotificationRecord payload

Every notification is serialized to JSON with this shape:

```json
{
  "id": "com.whatsapp|123|1700000000000",
  "packageName": "com.whatsapp",
  "title": "Alice",
  "text": "Hey, are you free?",
  "timestampMillis": 1700000000000,
  "hasRemoved": false,
  "raw": {
    "id": 123,
    "packageName": "com.whatsapp",
    "title": "Alice",
    "content": "Hey, are you free?",
    "canReply": true,
    "hasRemoved": false,
    "haveExtraPicture": false
  }
}
```

---

## API reference

| Class | Purpose |
|---|---|
| `NotificationRecord` | Immutable notification snapshot with JSON serialization |
| `NotificationListenerController` | Wraps the Android listener, exposes a `Stream<NotificationRecord>` |
| `NotificationQueueStore` | `SharedPreferences`-backed persistent queue (add, readAll, removeByIds) |
| `NotificationUploader` | HTTP POST with Bearer token auth and graceful error handling |
| `NotificationSyncManager` | Periodic flush of queued records with automatic retry |
| `NotificationConfig` | Persists endpoint + token across app restarts |
| `NotificationDetailPage` | Optional Flutter widget to display a record's full JSON |
| `SettingsPage` | Optional Flutter UI for the user to enter endpoint + token |

Full API docs: [pub.dev/documentation/notification_sync_kit](https://pub.dev/documentation/notification_sync_kit/latest/)

---

## Example app

A complete working example is in the [`example/`](example/) directory.

---

## License

MIT — see [LICENSE](LICENSE)
