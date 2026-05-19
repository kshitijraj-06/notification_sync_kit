import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/notification_record.dart';

class NotificationDetailPage extends StatelessWidget {
  const NotificationDetailPage({super.key, required this.record});

  final NotificationRecord record;

  @override
  Widget build(BuildContext context) {
    final pretty = const JsonEncoder.withIndent('  ');
    final normalizedJson = pretty.convert(record.toJson());

    final speedText = record.speedKmph != null
        ? '${record.speedKmph!.toStringAsFixed(1)} km/h'
        : 'Unavailable';

    final locationText =
        (record.latitude != null && record.longitude != null)
            ? '${record.latitude!.toStringAsFixed(6)}, '
                '${record.longitude!.toStringAsFixed(6)}'
            : 'Unavailable';

    final delayText = record.interactionDelayMs != null
        ? '${(record.interactionDelayMs! / 1000).toStringAsFixed(1)} s'
        : 'Unavailable';

    return Scaffold(
      appBar: AppBar(title: const Text('Notification Detail')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            record.title.isEmpty ? '(No title)' : record.title,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Text(record.packageName),
          const SizedBox(height: 16),

          // ── Core fields ──────────────────────────────────────────────────
          _SectionHeader(label: 'Notification'),
          _InfoRow(
            label: 'Status',
            value: record.hasRemoved ? 'Removed' : 'Posted',
          ),
          _InfoRow(
            label: 'Timestamp',
            value: DateTime.fromMillisecondsSinceEpoch(
              record.timestampMillis,
            ).toLocal().toString(),
          ),
          _InfoRow(label: 'Notification ID', value: record.id),

          const SizedBox(height: 16),

          // ── Driver context fields ────────────────────────────────────────
          _SectionHeader(label: 'Driver Context'),
          _InfoRow(label: 'Speed', value: speedText),
          _InfoRow(label: 'Location', value: locationText),
          _InfoRow(
            label: 'Interaction',
            value: record.interactionType.name.toUpperCase(),
          ),
          _InfoRow(label: 'Response Time', value: delayText),
          _InfoRow(
            label: 'Can Reply',
            value: record.canReply ? 'Yes' : 'No',
          ),
          _InfoRow(
            label: 'Has Picture',
            value: record.haveExtraPicture ? 'Yes' : 'No',
          ),

          const SizedBox(height: 16),

          // ── JSON view ────────────────────────────────────────────────────
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Normalized JSON'),
            childrenPadding: const EdgeInsets.only(bottom: 16),
            children: [
              SelectableText(
                normalizedJson,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        label,
        style: Theme.of(context)
            .textTheme
            .labelLarge
            ?.copyWith(color: Theme.of(context).colorScheme.primary),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
