import 'package:logging/logging.dart';

/// Enables console logging for the entire `notification_sync_kit` package.
///
/// Call this once during app startup — before creating any kit services — to
/// see log output in your terminal or IDE console.
///
/// **[level]** controls the minimum severity to print. Common values:
/// - `Level.ALL` / `Level.FINE` — verbose: every operation logged
/// - `Level.WARNING` — only failures and soft errors (recommended for production)
/// - `Level.SEVERE` — only unexpected errors
///
/// **[includeTimestamp]** — prefix each log line with the current time.
///
/// ```dart
/// // Show all logs from the kit in development:
/// setupNotificationSyncKitLogging(level: Level.ALL);
///
/// // Warnings-only in production:
/// setupNotificationSyncKitLogging(level: Level.WARNING);
///
/// // Silence the kit completely:
/// setupNotificationSyncKitLogging(level: Level.OFF);
/// ```
///
/// If you need fine-grained control per component, you can attach listeners
/// directly to individual loggers instead:
///
/// ```dart
/// Logger('notification_sync_kit.uploader').onRecord.listen(myHandler);
/// Logger('notification_sync_kit.detector').level = Level.OFF;
/// ```
///
/// ## Logger hierarchy
///
/// | Logger name                        | Component                        |
/// |------------------------------------|----------------------------------|
/// | `notification_sync_kit`            | Root — covers all sub-loggers    |
/// | `notification_sync_kit.controller` | NotificationListenerController   |
/// | `notification_sync_kit.detector`   | InteractionDetector              |
/// | `notification_sync_kit.uploader`   | NotificationUploader             |
/// | `notification_sync_kit.sync`       | NotificationSyncManager          |
/// | `notification_sync_kit.store`      | NotificationQueueStore           |
void setupNotificationSyncKitLogging({
  Level level = Level.ALL,
  bool includeTimestamp = false,
}) {
  // Ensure the root logger passes records down to child loggers.
  Logger.root.level = Level.ALL;

  final kitLogger = Logger('notification_sync_kit');
  kitLogger.level = level;

  kitLogger.onRecord.listen((record) {
    final time = includeTimestamp ? '[${record.time}] ' : '';
    final prefix = '$time${record.level.name} ${record.loggerName}';
    // ignore: avoid_print
    print('$prefix: ${record.message}');
    if (record.error != null) {
      // ignore: avoid_print
      print('  error: ${record.error}');
    }
    if (record.stackTrace != null) {
      // ignore: avoid_print
      print('  stackTrace: ${record.stackTrace}');
    }
  });
}
