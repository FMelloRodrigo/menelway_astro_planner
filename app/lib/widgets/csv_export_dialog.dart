import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/astro_theme.dart';

/// Modal dialog displaying exported CSV text with monospace formatting and one-click clipboard copying.
class CsvExportDialog extends StatelessWidget {
  final String title;
  final String csvContent;
  final String copiedMessage;

  const CsvExportDialog({
    super.key,
    required this.title,
    required this.csvContent,
    required this.copiedMessage,
  });

  /// Presents the [CsvExportDialog] in a modal overlay.
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String csvContent,
    required String copiedMessage,
  }) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => CsvExportDialog(
        title: title,
        csvContent: csvContent,
        copiedMessage: copiedMessage,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AstroPalette.of(context);
    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        title,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: 540,
        child: SingleChildScrollView(
          child: SelectableText(
            csvContent,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 11,
              color: palette.textPrimary.withValues(alpha: 0.9),
            ),
          ),
        ),
      ),
      actions: [
        TextButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text("Copy CSV"),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: csvContent));
            Navigator.of(context).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(copiedMessage),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
        ),
        FilledButton(
          child: const Text("Done"),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }
}
