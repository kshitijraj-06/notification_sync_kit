import 'dart:async';

import 'notification_queue_store.dart';
import 'notification_uploader.dart';

class NotificationSyncManager {
  NotificationSyncManager({
    required NotificationQueueStore queueStore,
    required NotificationUploader uploader,
    required Future<void> Function(int pending, String message) onSyncResult,
  }) : _queueStore = queueStore,
       _uploader = uploader,
       _onSyncResult = onSyncResult {
    _timer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(flushPending());
    });
  }

  final NotificationQueueStore _queueStore;
  final NotificationUploader _uploader;
  final Future<void> Function(int pending, String message) _onSyncResult;
  bool _isSyncing = false;
  Timer? _timer;

  Future<void> flushPending() async {
    if (_isSyncing) {
      return;
    }
    _isSyncing = true;
    try {
      final pending = await _queueStore.count();
      await _onSyncResult(pending, 'Local storage mode is active.');
    } finally {
      _isSyncing = false;
    }
  }

  void dispose() {
    _timer?.cancel();
    _uploader.dispose();
  }
}
