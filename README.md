# notification_sync_kit

A Flutter package for **Android** that captures system notifications, enriches them with GPS speed, location, and driver interaction type, then persists and syncs them to your server via HTTP.

[![pub.dev](https://img.shields.io/pub/v/notification_sync_kit.svg)](https://pub.dev/packages/notification_sync_kit)
[![Platform](https://img.shields.io/badge/platform-android-green.svg)](https://pub.dev/packages/notification_sync_kit)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

---

## Features

- 🔔 **Listen** to Android notifications via `NotificationListenerService`
- 📍 **GPS enrichment** — speed (km/h), latitude, longitude captured at notification arrival
- 🧠 **Interaction detection** — classifies each notification as `OPENED`, `DISMISSED`, `REPLIED`, or `IGNORED` using Android's `UsageStatsManager`
- 💾 **Queue** notifications locally in `SharedPreferences` (survives app restarts)
- 📡 **Upload** each notification as JSON to your HTTP endpoint with Bearer token auth
- 🔄 **Retry** — failed uploads stay in the queue and are retried every 30 seconds
- ⚙️ **Configurable** endpoint and token at runtime — no rebuild needed
- 🧩 **Single import** — one barrel file exposes everything

---

## Platform support

| Android | iOS | Web |
|---------|-----|-----|
| ✅ | ❌ | ❌ |

---

## Installation

```yaml
dependencies:
  notification_sync_kit: ^0.2.0
```

```sh
flutter pub get
```

---

## Android setup

### 1. AndroidManifest.xml

Add inside `<manifest>`:

```xml
<uses-permission android:name="android.permission.INTERNET" />

<!-- For GPS enrichment -->
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION" />
<uses-permission android:name="android.permission.ACCESS_COARSE_LOCATION" />

<!-- For interaction detection (OPENED / REPLIED / DISMISSED / IGNORED) -->
<uses-permission android:name="android.permission.PACKAGE_USAGE_STATS"
    tools:ignore="ProtectedPermissions" />
```

Add inside `<application>`:

```xml
<service
    android:name="notification.listener.service.NotificationListener"
    android:permission="android.permission.BIND_NOTIFICATION_LISTENER_SERVICE"
    android:exported="true"
    android:label="notifications">
    <intent-filter>
        <action android:name="android.service.notification.NotificationListenerService" />
    </intent-filter>
</service>
```

### 2. MainActivity.kt

Add a `MethodChannel` for `UsageStatsManager` in your `MainActivity`. The channel name must match `InteractionDetector.defaultChannelName` (`"notification_sync_kit/usage_stats"`):

```kotlin
import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.os.Process
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    companion object {
        private const val CHANNEL = "notification_sync_kit/usage_stats"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "hasUsageStatsPermission" -> result.success(hasUsageStatsPermission())
                    "requestUsageStatsPermission" -> {
                        startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS))
                        result.success(null)
                    }
                    "wasAppOpenedRecently" -> {
                        val pkg = call.argument<String>("packageName") ?: ""
                        val ms = (call.argument<Int>("withinMs") ?: 3000).toLong()
                        result.success(wasAppOpenedRecently(pkg, ms))
                    }
                    else -> result.notImplemented()
                }
            }
    }

    private fun hasUsageStatsPermission(): Boolean {
        val appOps = getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        return appOps.checkOpNoThrow(
            AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), packageName
        ) == AppOpsManager.MODE_ALLOWED
    }

    private fun wasAppOpenedRecently(packageName: String, withinMs: Long): Boolean {
        if (!hasUsageStatsPermission()) return false
        val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val now = System.currentTimeMillis()
        val events = usm.queryEvents(now - withinMs, now)
        val event = UsageEvents.Event()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            if (event.packageName == packageName &&
                event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) return true
        }
        return false
    }
}
```

---

## Quick start

```dart
import 'package:notification_sync_kit/notification_sync_kit.dart';

// 1. Request Usage Access for interaction detection
final detector = InteractionDetector();
if (!await detector.hasPermission()) {
  await detector.requestPermission(); // opens Android Settings
}

// 2. Set up the local queue
final store = NotificationQueueStore();
await store.init();

// 3. Set up the uploader
final uploader = NotificationUploader(
  endpoint: 'https://api.example.com/notifications',
  bearerToken: 'your-secret-token',
);

// 4. Start listening — records are emitted once each notification is resolved
final controller = NotificationListenerController(
  interactionDetector: detector,
);
controller.events.listen((NotificationRecord record) async {
  final ok = await uploader.upload(record);
  if (!ok) await store.add(record); // queue for retry
});
await controller.startIfGranted();

// 5. Retry queued records every 30 seconds
final syncManager = NotificationSyncManager(
  queueStore: store,
  uploader: uploader,
  onSyncResult: (remaining, message) async => print(message),
);
```

Don't forget to `dispose()` when done:

```dart
controller.dispose();
syncManager.dispose();
```

---

## Logging

The package uses the standard [`logging`](https://pub.dev/packages/logging) package with a hierarchical logger per component. Logging is **silent by default** — call the setup helper once at startup to enable it:

```dart
import 'package:notification_sync_kit/notification_sync_kit.dart';

// Verbose — all operations (good for development)
setupNotificationSyncKitLogging(level: Level.ALL);

// Warnings only — failures and soft errors (good for production)
setupNotificationSyncKitLogging(level: Level.WARNING);

// With timestamps
setupNotificationSyncKitLogging(level: Level.ALL, includeTimestamp: true);

// Silence completely
setupNotificationSyncKitLogging(level: Level.OFF);
```

You can also target individual components:

```dart
Logger('notification_sync_kit.uploader').level = Level.WARNING;
Logger('notification_sync_kit.detector').level = Level.OFF;
```

### Logger hierarchy

| Logger | Component |
|---|---|
| `notification_sync_kit` | Root — covers all sub-loggers |
| `notification_sync_kit.controller` | NotificationListenerController |
| `notification_sync_kit.detector` | InteractionDetector |
| `notification_sync_kit.uploader` | NotificationUploader |
| `notification_sync_kit.sync` | NotificationSyncManager |
| `notification_sync_kit.store` | NotificationQueueStore |

### Sample output (`Level.ALL`)

```
FINE notification_sync_kit.controller: Notification access granted — starting listener.
FINE notification_sync_kit.controller: Notification posted: com.whatsapp|42 — sampling GPS.
FINE notification_sync_kit.controller: GPS sampled for com.whatsapp|42: 58.3 km/h @ (28.6139, 77.2090).
FINE notification_sync_kit.controller: Notification removed: com.whatsapp|42 — resolving.
FINE notification_sync_kit.detector: Detecting interaction for com.whatsapp (delay: 4.2 s, canReply: true).
FINE notification_sync_kit.detector: UsageStats query for com.whatsapp (within 3000ms): false.
FINE notification_sync_kit.detector: com.whatsapp → DISMISSED.
FINE notification_sync_kit.controller: Resolved com.whatsapp|42 → DISMISSED in 4.2 s.
FINE notification_sync_kit.uploader: Uploading com.whatsapp|42|1747612800000 to https://api.example.com/notifications.
FINE notification_sync_kit.uploader: Upload succeeded for com.whatsapp|42|1747612800000 (HTTP 200).
WARNING notification_sync_kit.uploader: Upload failed for com.whatsapp|43|... (HTTP 503). Will retry.
FINE notification_sync_kit.store: Queued com.whatsapp|43|... (queue size: 1).
FINE notification_sync_kit.sync: Sync tick: flushing 1 record(s).
FINE notification_sync_kit.sync: All 1 queued record(s) synced.
```

---

## NotificationRecord JSON payload

```json
{
  "id": "com.whatsapp|42|1747612800000",
  "packageName": "com.whatsapp",
  "title": "Alice",
  "text": "Hey, are you free?",
  "timestampMillis": 1747612800000,
  "hasRemoved": true,
  "canReply": true,
  "haveExtraPicture": false,
  "speedKmph": 58.3,
  "latitude": 28.613945,
  "longitude": 77.209006,
  "interactionType": "DISMISSED",
  "interactionDelayMs": 4200
}
```

### Interaction types

| Value | Meaning |
|---|---|
| `OPENED` | Driver tapped the notification — detected via `UsageStatsManager` |
| `DISMISSED` | Driver swiped it away |
| `REPLIED` | Inline reply (heuristic: `canReply=true`, removed quickly, app not opened) |
| `IGNORED` | Notification sat unread for > 5 minutes |

---

## API reference

| Class | Purpose |
|---|---|
| `NotificationRecord` | Immutable notification snapshot with JSON serialization |
| `InteractionType` | Enum: `ignored`, `dismissed`, `opened`, `replied` |
| `InteractionDetector` | Classifies driver interaction using `UsageStatsManager` |
| `NotificationListenerController` | Wraps the Android listener, exposes `Stream<NotificationRecord>` |
| `NotificationQueueStore` | `SharedPreferences`-backed persistent queue |
| `NotificationUploader` | HTTP POST with Bearer token auth |
| `NotificationSyncManager` | Periodic flush of queued records with retry |
| `NotificationConfig` | Persists endpoint + token across app restarts |
| `NotificationDetailPage` | Flutter widget to display a record's full detail |
| `SettingsPage` | Flutter UI for entering endpoint + token |

---

## Example app

A complete working example is in the [`example/`](example/) directory.

---

## License

MIT — see [LICENSE](LICENSE)
