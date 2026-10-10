import 'package:flutter/material.dart';

import '../theme/astro_theme.dart';
import '../l10n/app_localizations.dart';
import '../models/observing_list.dart';

/// Reusable modal dialog for adding a target (from search, details sheet, or planner)
/// to an observing list with optional notes.
class AddTargetToListDialog extends StatefulWidget {
  final int targetId;
  final String targetDisplayName;
  final List<ObservingListModel> availableLists;
  final void Function(int listId, int dsoId, String notes) onAddToList;

  const AddTargetToListDialog({
    super.key,
    required this.targetId,
    required this.targetDisplayName,
    required this.availableLists,
    required this.onAddToList,
  });

  /// Static helper to display the dialog or show a snackbar if no lists exist.
  static void show({
    required BuildContext context,
    required int targetId,
    required String targetDisplayName,
    required List<ObservingListModel> availableLists,
    required void Function(int listId, int dsoId, String notes) onAddToList,
  }) {
    final l10n = AppLocalizations.of(context);
    if (availableLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.noObservingListsFound)),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AddTargetToListDialog(
        targetId: targetId,
        targetDisplayName: targetDisplayName,
        availableLists: availableLists,
        onAddToList: onAddToList,
      ),
    );
  }

  @override
  State<AddTargetToListDialog> createState() => _AddTargetToListDialogState();
}

class _AddTargetToListDialogState extends State<AddTargetToListDialog> {
  late int _selectedListId;
  late final TextEditingController _notesController;

  @override
  void initState() {
    super.initState();
    _selectedListId = widget.availableLists.first.id;
    _notesController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_notesController.text.isEmpty) {
      final l10n = AppLocalizations.of(context);
      _notesController.text = l10n.defaultListNotes;
    }
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _submit() {
    final l10n = AppLocalizations.of(context);
    widget.onAddToList(_selectedListId, widget.targetId, _notesController.text);
    Navigator.of(context).pop();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.addedToObservingListSuccess(widget.targetDisplayName))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);

    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        l10n.addToListDialogTitle(widget.targetDisplayName),
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<int>(
              initialValue: _selectedListId,
              decoration: InputDecoration(labelText: l10n.targetObservingListLabel),
              dropdownColor: palette.surface,
              items: widget.availableLists.map((l) {
                return DropdownMenuItem(
                  value: l.id,
                  child: Text(l.name, style: TextStyle(fontSize: 13, color: palette.textPrimary)),
                );
              }).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedListId = v);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              decoration: InputDecoration(labelText: l10n.sessionNotesLabel),
              style: TextStyle(
                color: palette.textPrimary,
              ),
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          child: Text(l10n.cancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.addBtn),
        ),
      ],
    );
  }
}
