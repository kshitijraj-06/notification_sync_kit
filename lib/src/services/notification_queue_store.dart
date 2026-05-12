import 'package:shared_preferences/shared_preferences.dart';

import '../models/notification_record.dart';

class NotificationQueueStore {
  static const String _historyKey = 'notification_history_v1';
  static const int _maxHistorySize = 1000;

  SharedPreferences? _prefs;

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
  }

  Future<List<NotificationRecord>> readAll() async {
    final data = _prefs!.getString(_historyKey);
    if (data == null || data.isEmpty) {
      return const [];
    }
    return NotificationRecord.decodeList(data);
  }

  Future<void> add(NotificationRecord record) async {
    final current = await readAll();
    final next = [record, ...current].take(_maxHistorySize).toList();
    await _prefs!.setString(_historyKey, NotificationRecord.encodeList(next));
  }

  Future<int> count() async {
    final current = await readAll();
    return current.length;
  }
}
