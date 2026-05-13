import 'dart:async';

import 'notification_queue_store.dart';
import 'notification_uploader.dart';

/// Periodically flushes queued [NotificationRecord]s to the server.
///
/// On each [interval] tick, [flushPending] reads all locally stored records,
/// attempts to upload each one via [NotificationUploader], and removes
/// successfully uploaded records from [NotificationQueueStore]. Records that
/// fail to upload stay in the queue and are retried on the next tick.
///
/// ```dart
/// final syncManager = NotificationSyncManager(
///   queueStore: store,
///   uploader: uploader,
///   onSyncResult: (remaining, message) async {
///     print(message); // e.g. "All 3 queued record(s) synced."
///   },
/// );
/// // ... later:
/// syncManager.dispose();
/// ```
class NotificationSyncManager {
  /// Creates a [NotificationSyncManager] and starts the periodic timer.
  ///
  /// - [queueStore] — the local persistent queue to flush.
  /// - [uploader] — responsible for sending each record to the server.
  /// - [onSyncResult] — called after every flush with the number of records
  ///   still pending and a human-readable status message.
  /// - [interval] — how often to attempt a flush. Defaults to 30 seconds.
  NotificationSyncManager({
    required NotificationQueueStore queueStore,
    required NotificationUploader uploader,
    required Future<void> Function(int remaining, String message) onSyncResult,
    Duration interval = const Duration(seconds: 30),
  }) : _queueStore = queueStore,
       _uploader = uploader,
       _onSyncResult = onSyncResult {
    _timer = Timer.periodic(interval, (_) {
      unawaited(flushPending());
    });
  }

  final NotificationQueueStore _queueStore;
  final NotificationUploader _uploader;
  final Future<void> Function(int remaining, String message) _onSyncResult;
  bool _isSyncing = false;
  Timer? _timer;

  /// Uploads all queued records to the server right now.
  ///
  /// Re-entrant calls while a flush is already in progress are silently
  /// ignored. Successfully uploaded records are removed from the queue;
  /// failed ones remain for the next retry.
  Future<void> flushPending() async {
    if (_isSyncing) return;
    _isSyncing = true;
    try {
      final pending = await _queueStore.readAll();
      if (pending.isEmpty) return;

      final uploaded = <String>[];
      for (final record in pending) {
        final ok = await _uploader.upload(record);
        if (ok) uploaded.add(record.id);
      }

      if (uploaded.isNotEmpty) {
        await _queueStore.removeByIds(uploaded);
      }

      final remaining = pending.length - uploaded.length;
      final message = uploaded.isEmpty
          ? 'Sync failed — $remaining record(s) still pending.'
          : remaining == 0
          ? 'All ${uploaded.length} queued record(s) synced.'
          : 'Synced ${uploaded.length}, $remaining still pending.';

      await _onSyncResult(remaining, message);
    } finally {
      _isSyncing = false;
    }
  }

  /// Cancels the periodic timer and disposes the [NotificationUploader].
  /// Always call this when the manager is no longer needed.
  void dispose() {
    _timer?.cancel();
    _uploader.dispose();
  }
}
