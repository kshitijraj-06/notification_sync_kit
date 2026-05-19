import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_record.dart';

final _log = Logger('notification_sync_kit.store');

/// A persistent local queue for [NotificationRecord] objects backed by
/// [SharedPreferences].
///
/// Records are stored newest-first and the list is capped at [_maxHistorySize]
/// entries to prevent unbounded growth. Call [init] before any other method.
class NotificationQueueStore {
  static const String _historyKey = 'notification_history_v1';
  static const int _maxHistorySize = 1000;

  SharedPreferences? _prefs;

  /// Initializes the store by loading [SharedPreferences].
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final existing = await count();
    _log.fine('QueueStore initialized — $existing record(s) in queue.');
  }

  /// Returns all stored [NotificationRecord]s, newest first.
  Future<List<NotificationRecord>> readAll() async {
    final data = _prefs!.getString(_historyKey);
    if (data == null || data.isEmpty) return const [];
    return NotificationRecord.decodeList(data);
  }

  /// Prepends [record] to the queue. If the queue exceeds the maximum size,
  /// the oldest records are dropped.
  Future<void> add(NotificationRecord record) async {
    final current = await readAll();
    final wasCapped = current.length >= _maxHistorySize;
    final next = [record, ...current].take(_maxHistorySize).toList();
    await _prefs!.setString(_historyKey, NotificationRecord.encodeList(next));

    if (wasCapped) {
      _log.warning(
        'Queue cap ($_maxHistorySize) reached — oldest record dropped. '
        'Consider increasing sync frequency.',
      );
    } else {
      _log.fine('Queued ${record.id} (queue size: ${next.length}).');
    }
  }

  /// Returns the number of records currently in the queue.
  Future<int> count() async {
    final current = await readAll();
    return current.length;
  }

  /// Removes the record with the given [id].
  Future<void> removeById(String id) async {
    final current = await readAll();
    final next = current.where((r) => r.id != id).toList();
    await _prefs!.setString(_historyKey, NotificationRecord.encodeList(next));
    _log.fine('Removed $id from queue (queue size: ${next.length}).');
  }

  /// Removes all records whose [NotificationRecord.id] is in [ids].
  Future<void> removeByIds(Iterable<String> ids) async {
    final idSet = ids.toSet();
    final current = await readAll();
    final next = current.where((r) => !idSet.contains(r.id)).toList();
    await _prefs!.setString(_historyKey, NotificationRecord.encodeList(next));
    _log.fine(
      'Removed ${idSet.length} record(s) from queue '
      '(queue size: ${next.length}).',
    );
  }
}
