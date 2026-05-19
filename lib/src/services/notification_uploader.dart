import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../models/notification_record.dart';

final _log = Logger('notification_sync_kit.uploader');

/// Uploads individual [NotificationRecord]s to a remote HTTP endpoint as JSON.
///
/// Every request includes a `Content-Type: application/json` header. If a
/// [bearerToken] is provided it is sent as `Authorization: Bearer <token>`.
///
/// ```dart
/// final uploader = NotificationUploader(
///   endpoint: 'https://api.example.com/notifications',
///   bearerToken: 'my-secret-token',
/// );
/// final success = await uploader.upload(record);
/// ```
class NotificationUploader {
  /// Creates an uploader targeting [endpoint].
  ///
  /// [httpClient] is exposed for testing — leave it null in production and an
  /// internal [http.Client] will be created automatically.
  NotificationUploader({
    required String endpoint,
    String? bearerToken,
    http.Client? httpClient,
  }) : _endpoint = endpoint,
       _bearerToken = bearerToken,
       _client = httpClient ?? http.Client();

  String _endpoint;
  String? _bearerToken;
  final http.Client _client;

  /// Updates the target endpoint URL at runtime.
  void setEndpoint(String endpoint) {
    _log.fine('Endpoint updated to $endpoint.');
    _endpoint = endpoint;
  }

  /// Updates the Bearer token used for authentication at runtime.
  void setBearerToken(String token) {
    _log.fine('Bearer token updated.');
    _bearerToken = token;
  }

  Map<String, String> get _headers => <String, String>{
    'Content-Type': 'application/json',
    if (_bearerToken != null && _bearerToken!.isNotEmpty)
      'Authorization': 'Bearer $_bearerToken',
  };

  /// POSTs [record] as JSON to the configured endpoint.
  ///
  /// Returns `true` if the server responded with a 2xx status code.
  /// Returns `false` on any network error or non-2xx response.
  Future<bool> upload(NotificationRecord record) async {
    final uri = Uri.tryParse(_endpoint);
    if (uri == null) {
      _log.warning('Invalid endpoint URL: "$_endpoint". Upload skipped.');
      return false;
    }

    _log.fine('Uploading ${record.id} to $_endpoint.');

    try {
      final response = await _client.post(
        uri,
        headers: _headers,
        body: jsonEncode(record.toJson()),
      );

      final success = response.statusCode >= 200 && response.statusCode < 300;

      if (success) {
        _log.fine(
          'Upload succeeded for ${record.id} (HTTP ${response.statusCode}).',
        );
      } else {
        _log.warning(
          'Upload failed for ${record.id} '
          '(HTTP ${response.statusCode}). Will retry.',
        );
      }

      return success;
    } catch (e) {
      _log.warning('Network error uploading ${record.id}: $e. Will retry.');
      return false;
    }
  }

  /// Closes the underlying HTTP client.
  void dispose() {
    _log.fine('Disposing NotificationUploader.');
    _client.close();
  }
}
