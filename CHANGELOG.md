# Changelog

All notable changes to `notification_sync_kit` will be documented in this file.

The format follows [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## 0.1.0 — 2026-05-12

### Added
- `NotificationRecord` model with full JSON serialization (`toJson`, `fromJson`,
  `encodeList`, `decodeList`) and a `fromServiceEvent` factory.
- `NotificationListenerController` — wraps `notification_listener_service` and
  exposes incoming notifications as a typed `Stream<NotificationRecord>`.
- `NotificationQueueStore` — `SharedPreferences`-backed persistent queue with
  `add`, `readAll`, `count`, `removeById`, and `removeByIds`.
- `NotificationUploader` — HTTP POST with optional Bearer token auth,
  configurable endpoint, and graceful error handling.
- `NotificationSyncManager` — periodic (default 30 s) flush of queued records
  with automatic removal of successfully uploaded entries and retry of failures.
- `NotificationDetailPage` — optional Flutter widget to display a single
  `NotificationRecord` with normalized and raw JSON views.
- Barrel export at `lib/notification_sync_kit.dart` for a single import.
- Example app in `example/` demonstrating instant-upload + queue-fallback flow.
