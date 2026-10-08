import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/observing_list.dart';
import '../services/csv_export_service.dart';
import '../theme/astro_theme.dart';

class ObservingListsView extends StatefulWidget {
  final List<ObservingListModel> lists;
  final void Function(String name, String description, String date) onCreateList;
  final void Function(int listId) onDeleteList;
  final void Function(int listId, int dsoId) onRemoveItem;

  const ObservingListsView({
    super.key,
    required this.lists,
    required this.onCreateList,
    required this.onDeleteList,
    required this.onRemoveItem,
  });

  @override
  State<ObservingListsView> createState() => _ObservingListsViewState();
}

class _ObservingListsViewState extends State<ObservingListsView> {
  int? _expandedListId;

  void _showCreateDialog() {
    showDialog(
      context: context,
      builder: (ctx) => CreateObservingListDialog(
        onCreateList: widget.onCreateList,
      ),
    );
  }

  void _exportListCsv(ObservingListModel list) {
    final csv = CsvExportService.exportObservingListCsv(list);
    CsvExportService.showCsvDialog(
      context,
      title: "Exported CSV: ${list.name}",
      csvContent: csv,
      copiedMessage: "CSV copied to clipboard",
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: palette.accent,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: Text(l10n.createNewList),
        onPressed: _showCreateDialog,
      ),
      body: widget.lists.isEmpty
          ? Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.playlist_play_rounded, size: 56, color: palette.textTertiary),
                    const SizedBox(height: 12),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 440),
                      child: Text(
                        l10n.emptyObservingLists,
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16, color: palette.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      icon: const Icon(Icons.add_rounded),
                      label: Text(l10n.createNewList),
                      style: FilledButton.styleFrom(backgroundColor: palette.accent),
                      onPressed: _showCreateDialog,
                    ),
                  ],
                ),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: widget.lists.length,
              itemBuilder: (context, index) {
                final list = widget.lists[index];
                final isExpanded = _expandedListId == list.id;

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(
                      color: palette.border,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: palette.accent.withValues(alpha: 0.15),
                          child: Icon(Icons.event_note_rounded, color: palette.accent, size: 20),
                        ),
                        title: Text(
                          list.name,
                          style: TextStyle(fontWeight: FontWeight.w700, color: palette.textPrimary),
                        ),
                        subtitle: Text(
                          "${list.sessionDate.isNotEmpty ? '${list.sessionDate} • ' : ''}${l10n.listItemsPlannedCount(list.items.length)}",
                          style: TextStyle(color: palette.textSecondary, fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.file_download_outlined, size: 20),
                              tooltip: l10n.exportCsvFramingTooltip,
                              onPressed: () => _exportListCsv(list),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              tooltip: l10n.deleteListTooltip,
                              onPressed: () => widget.onDeleteList(list.id),
                            ),
                            IconButton(
                              icon: Icon(
                                isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                              ),
                              onPressed: () {
                                setState(() {
                                  _expandedListId = isExpanded ? null : list.id;
                                });
                              },
                            ),
                          ],
                        ),
                      ),
                      if (isExpanded) ...[
                        const Divider(height: 1),
                        if (list.items.isEmpty)
                          Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(
                              l10n.noTargetsInList,
                              style: TextStyle(color: palette.textTertiary, fontSize: 12),
                            ),
                          )
                        else
                          ListView.separated(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: list.items.length,
                            separatorBuilder: (_, index) => const Divider(height: 1, indent: 16),
                            itemBuilder: (ctx, itemIdx) {
                              final item = list.items[itemIdx];
                              return ListTile(
                                dense: true,
                                title: Text(
                                  item.displayName,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: palette.textPrimary,
                                  ),
                                ),
                                subtitle: Text(
                                  "${item.objectType} in ${item.constellation}${item.notes.isNotEmpty ? ' • Notes: ${item.notes}' : ''}",
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 11,
                                  ),
                                ),
                                trailing: IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 18),
                                  color: Colors.red.withValues(alpha: 0.7),
                                  onPressed: () => widget.onRemoveItem(list.id, item.dsoId),
                                ),
                              );
                            },
                          ),
                      ],
                    ],
                  ),
                );
              },
            ),
    );
  }
}

class CreateObservingListDialog extends StatefulWidget {
  final void Function(String name, String description, String date) onCreateList;

  const CreateObservingListDialog({
    super.key,
    required this.onCreateList,
  });

  @override
  State<CreateObservingListDialog> createState() => _CreateObservingListDialogState();
}

class _CreateObservingListDialogState extends State<CreateObservingListDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descController = TextEditingController();
    _dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _nameController.text.trim();
    if (name.isNotEmpty) {
      widget.onCreateList(
        name,
        _descController.text.trim(),
        _dateController.text.trim(),
      );
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);

    return AlertDialog(
      backgroundColor: palette.surface,
      title: Text(
        l10n.createNewList,
        style: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
        ),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              decoration: InputDecoration(
                labelText: "${l10n.listName} (e.g. Bortle 4 Trip)",
              ),
              style: TextStyle(
                color: palette.textPrimary,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _descController,
              decoration: InputDecoration(
                labelText: "${l10n.listDescription} / Notes",
              ),
              style: TextStyle(
                color: palette.textPrimary,
              ),
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _dateController,
              decoration: const InputDecoration(
                labelText: "Target Date (YYYY-MM-DD)",
              ),
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
          child: Text(l10n.cleanDataCancel),
          onPressed: () => Navigator.of(context).pop(),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(l10n.createNewList),
        ),
      ],
    );
  }
}
