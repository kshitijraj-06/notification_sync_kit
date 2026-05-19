import 'dart:async';

import 'package:logging/logging.dart';

import 'notification_queue_store.dart';
import 'notification_uploader.dart';

final _log = Logger('notification_sync_kit.sync');

/// Periodically flushes queued [NotificationRecord]s to the server.
///
/// On each [interval] tick, [flushPending] reads all locally stored records,
/// attempts to upload each one via [NotificationUploader], and removes
/// successfully uploaded records from [NotificationQueueStore]. Records that
/// fail to upload stay in the queue and are retried on the next tick.
class NotificationSyncManager {
  NotificationSyncManager({
    required NotificationQueueStore queueStore,
    required NotificationUploader uploader,
    required Future<void> Function(int remaining, String message) onSyncResult,
    Duration interval = const Duration(seconds: 30),
  }) : _queueStore = queueStore,
       _uploader = uploader,
       _onSyncResult = onSyncResult {
    _log.fine('SyncManager started (interval: ${interval.inSeconds} s).');
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
  /// ignored.
  Future<void> flushPending() async {
    if (_isSyncing) {
      _log.fine('Sync already in progress — skipping tick.');
      return;
    }
    _isSyncing = true;
    try {
      final pending = await _queueStore.readAll();
      if (pending.isEmpty) {
        _log.fine('Sync tick: queue is empty, nothing to upload.');
        return;
      }

      _log.fine('Sync tick: flushing ${pending.length} record(s).');

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

      if (remaining > 0) {
        _log.warning(message);
      } else {
        _log.fine(message);
      }

      await _onSyncResult(remaining, message);
    } finally {
      _isSyncing = false;
    }
  }

  /// Cancels the periodic timer and disposes the [NotificationUploader].
  void dispose() {
    _log.fine('Disposing NotificationSyncManager.');
    _timer?.cancel();
    _uploader.dispose();
  }
}
