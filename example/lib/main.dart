import 'dart:async';

import 'package:flutter/material.dart';
import 'package:notification_sync_kit/notification_sync_kit.dart';

// ─── YOUR CONFIG ────────────────────────────────────────────────────────────
// Replace these two values before running.
const String _kEndpoint = 'https://your-api.example.com/notifications';
const String _kBearerToken = 'YOUR_BEARER_TOKEN_HERE';
// ────────────────────────────────────────────────────────────────────────────

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const NotificationCaptureApp());
}

class NotificationCaptureApp extends StatelessWidget {
  const NotificationCaptureApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Notification Capture',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
      ),
      home: const NotificationHomePage(),
    );
  }
}

class NotificationHomePage extends StatefulWidget {
  const NotificationHomePage({super.key});

  @override
  State<NotificationHomePage> createState() => _NotificationHomePageState();
}

class _NotificationHomePageState extends State<NotificationHomePage> {
  late final NotificationQueueStore _queueStore;
  late final InteractionDetector _interactionDetector;
  late final NotificationListenerController _listenerController;
  late final NotificationUploader _uploader;
  late final NotificationSyncManager _syncManager;

  StreamSubscription<NotificationRecord>? _listenerSub;
  List<NotificationRecord> _recent = const [];
  bool _accessGranted = false;
  bool _isLoading = true;
  String _status = 'Starting...';

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    _queueStore = NotificationQueueStore();
    await _queueStore.init();

    // Set up interaction detection (requires Usage Access permission).
    _interactionDetector = InteractionDetector();
    if (!await _interactionDetector.hasPermission()) {
      await _interactionDetector.requestPermission();
    }

    _uploader = NotificationUploader(
      endpoint: _kEndpoint,
      bearerToken: _kBearerToken,
    );

    _syncManager = NotificationSyncManager(
      queueStore: _queueStore,
      uploader: _uploader,
      onSyncResult: (remaining, message) async {
        if (!mounted) return;
        setState(() => _status = message);
      },
    );

    _listenerController = NotificationListenerController(
      interactionDetector: _interactionDetector,
    );

    final storedNotifications = await _queueStore.readAll();
    _listenerSub = _listenerController.events.listen(_handleIncomingEvent);
    await _listenerController.startIfGranted();

    final accessGranted = await _listenerController.isAccessGranted();

    if (!mounted) return;
    setState(() {
      _recent = storedNotifications;
      _accessGranted = accessGranted;
      _isLoading = false;
      _status = accessGranted
          ? 'Listening — will upload instantly, queue retries every 30 s.'
          : 'Notification access is not granted.';
    });
  }

  /// Try to upload immediately. If it fails, save to the local queue so the
  /// [NotificationSyncManager] can retry it on the next 30-second tick.
  Future<void> _handleIncomingEvent(NotificationRecord record) async {
    final uploaded = await _uploader.upload(record);

    String statusMsg;
    if (uploaded) {
      statusMsg = '✓ Uploaded ${record.packageName} to server';
    } else {
      await _queueStore.add(record);
      statusMsg = '⚠ Upload failed — ${record.packageName} queued for retry';
    }

    final storedNotifications = await _queueStore.readAll();
    if (!mounted) return;
    setState(() {
      _recent = storedNotifications;
      _status = statusMsg;
    });
  }

  Future<void> _requestAccess() async {
    setState(() => _status = 'Opening notification access settings...');
    final granted = await _listenerController.requestAccess();
    if (!mounted) return;
    setState(() {
      _accessGranted = granted;
      _status = granted
          ? 'Access granted. Capture is active.'
          : 'Access still not granted.';
    });
  }

  Future<void> _refreshAccess() async {
    final granted = await _listenerController.isAccessGranted();
    if (!mounted) return;
    setState(() {
      _accessGranted = granted;
      _status = granted ? 'Access confirmed.' : 'Access is still disabled.';
    });
  }

  @override
  void dispose() {
    _listenerSub?.cancel();
    _listenerController.dispose();
    _syncManager.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Capture')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _accessGranted ? 'Access: Granted' : 'Access: Not Granted',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _requestAccess,
                  child: const Text('Grant Access'),
                ),
                OutlinedButton(
                  onPressed: _refreshAccess,
                  child: const Text('Refresh Access'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(_status, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            Text(
              'Local queue (pending / failed uploads).',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _recent.isEmpty
                  ? const Center(child: Text('No notifications queued.'))
                  : ListView.builder(
                      itemCount: _recent.length,
                      itemBuilder: (context, index) {
                        final item = _recent[index];
                        return Card(
                          child: ListTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) =>
                                    NotificationDetailPage(record: item),
                              ),
                            ),
                            dense: true,
                            title: Text(
                              item.title.isEmpty ? '(No title)' : item.title,
                            ),
                            subtitle: Text(
                              '${item.packageName}\n${item.text}',
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            ),
                            isThreeLine: true,
                            trailing: Text(
                              item.hasRemoved ? 'Removed' : 'Posted',
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
