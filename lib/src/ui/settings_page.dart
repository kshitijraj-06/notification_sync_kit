import 'package:flutter/material.dart';

import '../services/notification_config.dart';

/// A page where the user can enter and save the server endpoint URL and
/// Bearer token. Changes are persisted immediately via [NotificationConfig]
/// and reported back to the parent via [onSaved].
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.config, required this.onSaved});

  /// The shared config instance — used to pre-fill current values and to
  /// persist changes when the user taps Save.
  final NotificationConfig config;

  /// Called after the user saves so the parent can re-apply the new values
  /// to the uploader.
  final VoidCallback onSaved;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _endpointCtrl;
  late final TextEditingController _tokenCtrl;
  bool _tokenObscured = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _endpointCtrl = TextEditingController(text: widget.config.endpoint);
    _tokenCtrl = TextEditingController(text: widget.config.token);
  }

  @override
  void dispose() {
    _endpointCtrl.dispose();
    _tokenCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final endpoint = _endpointCtrl.text.trim();
    final token = _tokenCtrl.text.trim();

    if (endpoint.isEmpty || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both endpoint and token are required.')),
      );
      return;
    }

    final uri = Uri.tryParse(endpoint);
    if (uri == null || !uri.hasScheme) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid URL.')),
      );
      return;
    }

    setState(() => _isSaving = true);
    await widget.config.setEndpoint(endpoint);
    await widget.config.setToken(token);
    setState(() => _isSaving = false);

    if (!mounted) return;
    widget.onSaved();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Settings saved.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Server Settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            'Configure where notifications are uploaded.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 24),

          // ── Endpoint ────────────────────────────────────────────────────
          Text('Endpoint URL', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _endpointCtrl,
            keyboardType: TextInputType.url,
            autocorrect: false,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'https://api.example.com/notifications',
            ),
          ),

          const SizedBox(height: 20),

          // ── Bearer token ────────────────────────────────────────────────
          Text('Bearer Token', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          TextField(
            controller: _tokenCtrl,
            obscureText: _tokenObscured,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              border: const OutlineInputBorder(),
              hintText: 'your-secret-token',
              suffixIcon: IconButton(
                icon: Icon(
                  _tokenObscured ? Icons.visibility : Icons.visibility_off,
                ),
                onPressed: () =>
                    setState(() => _tokenObscured = !_tokenObscured),
              ),
            ),
          ),

          const SizedBox(height: 32),

          // ── Save button ─────────────────────────────────────────────────
          FilledButton(
            onPressed: _isSaving ? null : _save,
            child: _isSaving
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Save'),
          ),
        ],
      ),
    );
  }
}
