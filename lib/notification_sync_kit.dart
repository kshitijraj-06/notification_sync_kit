/// A Flutter package for capturing Android notifications, persisting them
/// to a local queue, and syncing them to your server via HTTP.
///
/// ## Quick start
///
/// ```dart
/// import 'package:notification_sync_kit/notification_sync_kit.dart';
///
/// final uploader = NotificationUploader(
///   endpoint: 'https://api.example.com/notifications',
///   bearerToken: 'your-token',
/// );
///
/// final store = NotificationQueueStore();
/// await store.init();
///
/// final controller = NotificationListenerController();
/// controller.events.listen((record) async {
///   final ok = await uploader.upload(record);
///   if (!ok) await store.add(record); // queue for retry
/// });
/// await controller.startIfGranted();
/// ```
library notification_sync_kit;

export 'src/models/notification_record.dart';
export 'src/services/notification_config.dart';
export 'src/services/notification_listener_controller.dart';
export 'src/services/notification_queue_store.dart';
export 'src/services/notification_sync_manager.dart';
export 'src/services/notification_uploader.dart';
export 'src/ui/notification_detail_page.dart';
export 'src/ui/settings_page.dart';
