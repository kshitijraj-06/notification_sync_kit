import 'package:flutter/services.dart';
import 'package:logging/logging.dart';

import '../models/notification_record.dart';

final _log = Logger('notification_sync_kit.detector');

/// Detects how a driver interacted with a notification using Android's
/// [UsageStatsManager] and timing heuristics.
///
/// ## How each type is determined
///
/// | Type        | Signal                                                           |
/// |-------------|------------------------------------------------------------------|
/// | `OPENED`    | The notifying app moved to foreground within 3 s of removal     |
/// | `REPLIED`   | `canReply = true`, removed in < 15 s, app did *not* open        |
/// | `IGNORED`   | Notification sat unread for > 5 minutes before removal          |
/// | `DISMISSED` | None of the above — driver swiped it away                       |
///
/// ## Permission
///
/// OPENED detection requires **Usage Access** (`PACKAGE_USAGE_STATS`), a
/// special Android permission the user must grant manually in Settings.
/// Call [hasPermission] on startup and [requestPermission] if needed.
/// The detector degrades gracefully to `DISMISSED` when permission is absent.
///
/// ## Channel name
///
/// The default channel name is [defaultChannelName]. Your `MainActivity.kt`
/// must register a `MethodChannel` with the same name. If you need a custom
/// name (e.g. to avoid conflicts in a multi-package app), pass it via the
/// [channelName] constructor parameter and update your `MainActivity.kt` to
/// match.
///
/// ```dart
/// final detector = InteractionDetector();
///
/// if (!await detector.hasPermission()) {
///   await detector.requestPermission(); // opens Android Settings
/// }
///
/// final type = await detector.detect(
///   packageName: record.packageName,
///   canReply: record.canReply,
///   interactionDelayMs: delay,
/// );
/// ```
class InteractionDetector {
  /// The default MethodChannel name used to communicate with the native
  /// Android side. Your `MainActivity.kt` must register a channel with this
  /// exact name unless you override it via [channelName].
  static const defaultChannelName = 'notification_sync_kit/usage_stats';

  /// Creates an [InteractionDetector].
  ///
  /// [channelName] — override the MethodChannel name if needed. Must match
  /// the channel name registered in your `MainActivity.kt`.
  InteractionDetector({String channelName = defaultChannelName})
      : _channel = MethodChannel(channelName);

  final MethodChannel _channel;

  static const _usageStatsDelay = Duration(milliseconds: 1500);
  static const _lookbackMs = 3000;
  static const _ignoredThresholdMs = 5 * 60 * 1000; // 5 minutes
  static const _replyWindowMs = 15000; // 15 seconds

  // ── Permission helpers ────────────────────────────────────────────────────

  /// Returns `true` if the app has been granted Usage Access permission.
  Future<bool> hasPermission() async {
    try {
      final granted =
          await _channel.invokeMethod<bool>('hasUsageStatsPermission') ?? false;
      _log.fine('Usage Access permission: $granted.');
      return granted;
    } on PlatformException catch (e) {
      _log.warning('hasUsageStatsPermission channel error: $e');
      return false;
    }
  }

  /// Opens the system Usage Access settings screen so the user can grant
  /// permission. Does not wait for the result — call [hasPermission] again
  /// after the user returns to the app.
  Future<void> requestPermission() async {
    _log.fine('Opening Usage Access settings.');
    try {
      await _channel.invokeMethod<void>('requestUsageStatsPermission');
    } on PlatformException catch (e) {
      _log.warning('requestUsageStatsPermission channel error: $e');
    }
  }

  // ── Detection ─────────────────────────────────────────────────────────────

  /// Determines the [InteractionType] for a notification that has just been
  /// removed.
  Future<InteractionType> detect({
    required String packageName,
    required bool canReply,
    required int interactionDelayMs,
  }) async {
    _log.fine(
      'Detecting interaction for $packageName '
      '(delay: ${(interactionDelayMs / 1000).toStringAsFixed(1)} s, '
      'canReply: $canReply).',
    );

    // IGNORED: notification sat unread far beyond normal glance time.
    if (interactionDelayMs > _ignoredThresholdMs) {
      _log.fine(
        '$packageName → IGNORED '
        '(delay ${(interactionDelayMs / 1000).toStringAsFixed(0)} s '
        '> ${_ignoredThresholdMs ~/ 60000} min threshold).',
      );
      return InteractionType.ignored;
    }

    // Wait briefly so the OS can register any foreground event.
    await Future<void>.delayed(_usageStatsDelay);

    // OPENED: the notifying app came to the foreground after removal.
    final appOpened = await _wasAppOpenedRecently(packageName);
    if (appOpened) {
      _log.fine('$packageName → OPENED (app moved to foreground).');
      return InteractionType.opened;
    }

    // REPLIED (heuristic): canReply=true, quick removal, no app open.
    if (canReply && interactionDelayMs <= _replyWindowMs) {
      _log.fine(
        '$packageName → REPLIED (heuristic: canReply=true, '
        'delay ${(interactionDelayMs / 1000).toStringAsFixed(1)} s '
        '<= ${_replyWindowMs / 1000} s window).',
      );
      return InteractionType.replied;
    }

    _log.fine('$packageName → DISMISSED.');
    return InteractionType.dismissed;
  }

  // ── Private ───────────────────────────────────────────────────────────────

  Future<bool> _wasAppOpenedRecently(String packageName) async {
    try {
      final result = await _channel.invokeMethod<bool>(
            'wasAppOpenedRecently',
            {'packageName': packageName, 'withinMs': _lookbackMs},
          ) ??
          false;
      _log.fine(
        'UsageStats query for $packageName '
        '(within ${_lookbackMs}ms): $result.',
      );
      return result;
    } on PlatformException catch (e) {
      _log.warning(
        'wasAppOpenedRecently channel error for $packageName: $e. '
        'Falling back to DISMISSED.',
      );
      return false;
    }
  }
}
