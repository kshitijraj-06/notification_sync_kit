import 'dart:async';

import 'package:geolocator/geolocator.dart';
import 'package:logging/logging.dart';
import 'package:notification_listener_service/notification_listener_service.dart';

import '../models/notification_record.dart';
import 'interaction_detector.dart';

final _log = Logger('notification_sync_kit.controller');

/// Holds the in-flight state for a notification that has been posted but
/// not yet removed.
class _PendingEntry {
  _PendingEntry({required this.record, this.position});

  final NotificationRecord record;
  final Position? position;
}

/// Controls the Android notification listener lifecycle, enriches each event
/// with driver-context data (GPS, interaction type, delay), and exposes
/// resolved notifications as a typed [Stream] of [NotificationRecord].
///
/// **Lifecycle:**
/// 1. A notification is *posted* → GPS is sampled and the event is held in a
///    pending map.
/// 2. A notification is *removed* → [InteractionDetector] determines whether
///    the driver opened, replied, dismissed, or ignored the notification; then
///    the completed, enriched record is emitted.
/// 3. If the app restarts mid-flight (pending map lost), the removal event is
///    emitted as-is with no enrichment.
///
/// ```dart
/// final detector = InteractionDetector();
/// if (!await detector.hasPermission()) await detector.requestPermission();
///
/// final controller = NotificationListenerController(
///   interactionDetector: detector,
/// );
/// controller.events.listen((record) {
///   print('${record.packageName} — ${record.interactionType}');
/// });
/// await controller.startIfGranted();
/// ```
class NotificationListenerController {
  NotificationListenerController({InteractionDetector? interactionDetector})
      : _interactionDetector = interactionDetector ?? InteractionDetector();

  final InteractionDetector _interactionDetector;

  final StreamController<NotificationRecord> _controller =
      StreamController<NotificationRecord>.broadcast();
  StreamSubscription<dynamic>? _sourceSub;

  /// Pending notifications: key = `"<packageName>|<eventId>"`.
  final Map<String, _PendingEntry> _pending = {};

  /// Broadcast stream of fully resolved [NotificationRecord] objects.
  Stream<NotificationRecord> get events => _controller.stream;

  Future<bool> isAccessGranted() async {
    return NotificationListenerService.isPermissionGranted();
  }

  Future<void> startIfGranted() async {
    if (await isAccessGranted()) {
      _log.fine('Notification access granted — starting listener.');
      _startForwarding();
    } else {
      _log.warning('Notification access not granted — listener not started.');
    }
  }

  Future<bool> requestAccess() async {
    _log.fine('Requesting notification listener access.');
    final granted = await NotificationListenerService.requestPermission();
    if (granted) {
      _log.fine('Access granted — starting listener.');
      _startForwarding();
    } else {
      _log.warning('Notification access request denied.');
    }
    return granted;
  }

  void _startForwarding() {
    _sourceSub ??=
        NotificationListenerService.notificationsStream.listen((event) async {
      await _handleEvent(event);
    });
  }

  Future<void> _handleEvent(dynamic event) async {
    final packageName = (event.packageName as Object?)?.toString().trim() ?? '';
    final eventId = event.id?.toString() ?? '';
    final pendingKey = '$packageName|$eventId';
    final hasRemoved = event.hasRemoved == true;

    if (!hasRemoved) {
      // ── Notification posted ──────────────────────────────────────────────
      _log.fine('Notification posted: $pendingKey — sampling GPS.');
      final position = await _getCurrentPosition();

      if (position != null) {
        final speedKmph = position.speed * 3.6;
        _log.fine(
          'GPS sampled for $pendingKey: '
          '${speedKmph.toStringAsFixed(1)} km/h '
          '@ (${position.latitude.toStringAsFixed(4)}, '
          '${position.longitude.toStringAsFixed(4)}).',
        );
      } else {
        _log.warning('GPS unavailable for $pendingKey — location will be null.');
      }

      final record = NotificationRecord.fromServiceEvent(event);
      _pending[pendingKey] = _PendingEntry(record: record, position: position);
    } else {
      // ── Notification removed ─────────────────────────────────────────────
      _log.fine('Notification removed: $pendingKey — resolving.');
      final entry = _pending.remove(pendingKey);
      final now = DateTime.now().millisecondsSinceEpoch;

      if (entry != null) {
        final delayMs = now - entry.record.timestampMillis;
        _log.fine(
          'Detecting interaction for $pendingKey '
          '(delay: ${(delayMs / 1000).toStringAsFixed(1)} s, '
          'canReply: ${entry.record.canReply}).',
        );

        final interactionType = await _interactionDetector.detect(
          packageName: entry.record.packageName,
          canReply: entry.record.canReply,
          interactionDelayMs: delayMs,
        );

        _log.fine(
          'Resolved $pendingKey → ${interactionType.name.toUpperCase()} '
          'in ${(delayMs / 1000).toStringAsFixed(1)} s.',
        );

        final pos = entry.position;
        final resolved = entry.record.copyWith(
          hasRemoved: true,
          speedKmph: pos != null ? pos.speed * 3.6 : null,
          latitude: pos?.latitude,
          longitude: pos?.longitude,
          interactionType: interactionType,
          interactionDelayMs: delayMs,
        );
        _controller.add(resolved);
      } else {
        _log.warning(
          'No pending entry for $pendingKey — '
          'app may have restarted mid-flight. Emitting raw removal record.',
        );
        _controller.add(NotificationRecord.fromServiceEvent(event));
      }
    }
  }

  Future<Position?> _getCurrentPosition() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _log.warning('Location services are disabled.');
        return null;
      }

      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        _log.warning('Location permission is $permission.');
        return null;
      }

      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      _log.warning('GPS fix failed: $e');
      return null;
    }
  }

  void dispose() {
    _log.fine('Disposing NotificationListenerController.');
    _sourceSub?.cancel();
    _controller.close();
  }
}
