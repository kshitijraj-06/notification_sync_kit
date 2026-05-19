/// A Flutter package for capturing Android notifications, persisting them
/// to a local queue, and syncing them to your server via HTTP.
///
/// Each notification is enriched with GPS speed, coordinates, and driver
/// interaction type (OPENED / DISMISSED / REPLIED / IGNORED) before upload.
///
/// ## Quick start
///
/// ```dart
/// import 'package:notification_sync_kit/notification_sync_kit.dart';
///
/// // 1. Request Usage Access so interaction type can be detected.
/// final detector = InteractionDetector();
/// if (!await detector.hasPermission()) {
///   await detector.requestPermission();
/// }
///
/// // 2. Wire up the uploader and queue.
/// final uploader = NotificationUploader(
///   endpoint: 'https://api.example.com/notifications',
///   bearerToken: 'your-token',
/// );
/// final store = NotificationQueueStore();
/// await store.init();
///
/// // 3. Start listening — records are emitted once notifications are resolved.
/// final controller = NotificationListenerController(
///   interactionDetector: detector,
/// );
/// controller.events.listen((record) async {
///   final ok = await uploader.upload(record);
///   if (!ok) await store.add(record); // queue for retry
/// });
/// await controller.startIfGranted();
/// ```
library notification_sync_kit;

export 'src/logging.dart';
export 'src/models/notification_record.dart';
export 'src/services/interaction_detector.dart';
export 'src/services/notification_config.dart';
export 'src/services/notification_listener_controller.dart';
export 'src/services/notification_queue_store.dart';
export 'src/services/notification_sync_manager.dart';
export 'src/services/notification_uploader.dart';
export 'src/ui/notification_detail_page.dart';
export 'src/ui/settings_page.dart';
