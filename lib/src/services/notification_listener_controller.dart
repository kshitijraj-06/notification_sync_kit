import 'dart:async';

import 'package:notification_listener_service/notification_listener_service.dart';

import '../models/notification_record.dart';

/// Controls the Android notification listener lifecycle and exposes incoming
/// notifications as a typed [Stream] of [NotificationRecord].
///
/// Typical usage:
/// ```dart
/// final controller = NotificationListenerController();
/// controller.events.listen((record) {
///   print('New notification from ${record.packageName}');
/// });
/// await controller.startIfGranted();
/// ```
class NotificationListenerController {
  final StreamController<NotificationRecord> _controller =
      StreamController<NotificationRecord>.broadcast();
  StreamSubscription<dynamic>? _sourceSub;

  /// Broadcast stream of [NotificationRecord] objects. Each event corresponds
  /// to a notification being posted or removed on the device.
  Stream<NotificationRecord> get events => _controller.stream;

  /// Returns `true` if the app currently holds the
  /// `BIND_NOTIFICATION_LISTENER_SERVICE` permission.
  Future<bool> isAccessGranted() async {
    return NotificationListenerService.isPermissionGranted();
  }

  /// Starts forwarding notification events only if access has already been
  /// granted. Does nothing if the permission is not yet granted.
  Future<void> startIfGranted() async {
    if (await isAccessGranted()) {
      _startForwarding();
    }
  }

  /// Opens the system settings screen to request notification listener access,
  /// then starts forwarding if the user grants it.
  ///
  /// Returns `true` if access was granted.
  Future<bool> requestAccess() async {
    final granted = await NotificationListenerService.requestPermission();
    if (granted) {
      _startForwarding();
    }
    return granted;
  }

  void _startForwarding() {
    _sourceSub ??= NotificationListenerService.notificationsStream.listen((
      event,
    ) {
      _controller.add(NotificationRecord.fromServiceEvent(event));
    });
  }

  /// Cancels the notification stream subscription and closes the internal
  /// broadcast controller. Call this in your widget's `dispose()`.
  void dispose() {
    _sourceSub?.cancel();
    _controller.close();
  }
}
