import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/notification_record.dart';

class NotificationUploader {
  NotificationUploader({required String endpoint}) : _endpoint = endpoint;

  String _endpoint;
  final http.Client _client = http.Client();

  void setEndpoint(String endpoint) {
    _endpoint = endpoint;
  }

  Future<bool> upload(NotificationRecord record) async {
    final uri = Uri.tryParse(_endpoint);
    if (uri == null) {
      return false;
    }
    try {
      final response = await _client.post(
        uri,
        headers: const <String, String>{'Content-Type': 'application/json'},
        body: jsonEncode(record.toJson()),
      );
      return response.statusCode >= 200 && response.statusCode < 300;
    } catch (_) {
      return false;
    }
  }

  void dispose() {
    _client.close();
  }
}
