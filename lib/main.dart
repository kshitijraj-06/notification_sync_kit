import 'dart:async';

import 'package:flutter/material.dart';

import 'src/models/notification_record.dart';
import 'src/services/interaction_detector.dart';
import 'src/services/notification_config.dart';
import 'src/services/notification_listener_controller.dart';
import 'src/services/notification_queue_store.dart';
import 'src/services/notification_sync_manager.dart';
import 'src/services/notification_uploader.dart';
import 'src/ui/notification_detail_page.dart';
import 'src/ui/settings_page.dart';

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
  late final NotificationConfig _config;
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
    // Load persisted config (URL + token).
    _config = NotificationConfig();
    await _config.init();

    _queueStore = NotificationQueueStore();
    await _queueStore.init();

    _uploader = NotificationUploader(
      endpoint: _config.endpoint,
      bearerToken: _config.token,
    );

    _syncManager = NotificationSyncManager(
      queueStore: _queueStore,
      uploader: _uploader,
      onSyncResult: (remaining, message) async {
        if (!mounted) return;
        setState(() => _status = message);
      },
    );

    // Set up interaction detection (requires Usage Access permission).
    _interactionDetector = InteractionDetector();
    if (!await _interactionDetector.hasPermission()) {
      await _interactionDetector.requestPermission();
    }

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
      _status = _config.isConfigured
          ? (accessGranted
                ? 'Listening — uploads instantly, retries every 30 s.'
                : 'Notification access is not granted.')
          : 'Tap ⚙ to configure your server endpoint and token.';
    });
  }

  /// Called by [SettingsPage] after the user saves new values. Applies the
  /// updated endpoint and token to the running uploader without restarting.
  void _onSettingsSaved() {
    _uploader.setEndpoint(_config.endpoint);
    _uploader.setBearerToken(_config.token);
    setState(() {
      _status = _config.isConfigured
          ? 'Settings updated — uploads active.'
          : 'Tap ⚙ to configure your server endpoint and token.';
    });
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            SettingsPage(config: _config, onSaved: _onSettingsSaved),
      ),
    );
  }

  /// Tries an instant upload. Falls back to local queue on failure.
  Future<void> _handleIncomingEvent(NotificationRecord record) async {
    String statusMsg;

    if (!_config.isConfigured) {
      await _queueStore.add(record);
      statusMsg = '⚙ No server configured — ${record.packageName} queued.';
    } else {
      final uploaded = await _uploader.upload(record);
      if (uploaded) {
        statusMsg = '✓ Uploaded ${record.packageName} to server';
      } else {
        await _queueStore.add(record);
        statusMsg = '⚠ Upload failed — ${record.packageName} queued for retry';
      }
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
      appBar: AppBar(
        title: const Text('Notification Capture'),
        actions: [
          IconButton(
            icon: Icon(
              Icons.settings,
              color: _config.isConfigured ? null : Colors.orange,
            ),
            tooltip: 'Server settings',
            onPressed: _openSettings,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Config status banner
            if (!_config.isConfigured)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange.shade200),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      color: Colors.orange.shade700,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Server not configured — tap ⚙ to add your endpoint and token.',
                        style: TextStyle(
                          color: Colors.orange.shade900,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

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
