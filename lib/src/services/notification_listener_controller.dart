import 'dart:async';

import 'package:notification_listener_service/notification_listener_service.dart';

import '../models/notification_record.dart';

class NotificationListenerController {
  final StreamController<NotificationRecord> _controller =
      StreamController<NotificationRecord>.broadcast();
  StreamSubscription<dynamic>? _sourceSub;

  Stream<NotificationRecord> get events => _controller.stream;

  Future<bool> isAccessGranted() async {
    return NotificationListenerService.isPermissionGranted();
  }

  Future<void> startIfGranted() async {
    if (await isAccessGranted()) {
      _startForwarding();
    }
  }

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

  void dispose() {
    _sourceSub?.cancel();
    _controller.close();
  }
}
