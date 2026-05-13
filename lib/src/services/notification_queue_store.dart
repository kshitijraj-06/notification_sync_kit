import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_record.dart';

/// A persistent local queue for [NotificationRecord] objects backed by
/// [SharedPreferences].
///
/// Records are stored newest-first and the list is capped at [_maxHistorySize]
/// entries to prevent unbounded growth. Call [init] before any other method.
///
/// ```dart
/// final store = NotificationQueueStore();
/// await store.init();
/// await store.add(record);
/// final all = await store.readAll();
/// ```
class NotificationQueueStore {
  static const String _historyKey = 'notification_history_v1';
  static const int _maxHistorySize = 1000;

  SharedPreferences? _prefs;

  /// Initializes the store by loading [SharedPreferences]. Must be called once
  /// before any read/write operation.
  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
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
    final next = [record, ...current].take(_maxHistorySize).toList();
    await _prefs!.setString(_historyKey, NotificationRecord.encodeList(next));
  }

  /// Returns the number of records currently in the queue.
  Future<int> count() async {
    final current = await readAll();
    return current.length;
  }

  /// Removes the record with the given [id]. No-op if [id] is not found.
  Future<void> removeById(String id) async {
    final current = await readAll();
    final next = current.where((r) => r.id != id).toList();
    await _prefs!.setString(_historyKey, NotificationRecord.encodeList(next));
  }

  /// Removes all records whose [NotificationRecord.id] is contained in [ids].
  /// Useful for bulk-removing records that have been successfully uploaded.
  Future<void> removeByIds(Iterable<String> ids) async {
    final idSet = ids.toSet();
    final current = await readAll();
    final next = current.where((r) => !idSet.contains(r.id)).toList();
    await _prefs!.setString(_historyKey, NotificationRecord.encodeList(next));
  }
}
