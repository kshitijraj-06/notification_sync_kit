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
    final rawJson = pretty.convert(record.raw);

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
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Raw Data'),
            childrenPadding: const EdgeInsets.only(bottom: 16),
            children: [
              SelectableText(
                rawJson,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ],
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
