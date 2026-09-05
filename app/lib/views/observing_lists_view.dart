import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/observing_list.dart';
import '../theme/astro_theme.dart';

class ObservingListsView extends StatefulWidget {
  final List<ObservingListModel> lists;
  final bool isRedNightMode;
  final void Function(String name, String description, String date) onCreateList;
  final void Function(int listId) onDeleteList;
  final void Function(int listId, int dsoId) onRemoveItem;

  const ObservingListsView({
    super.key,
    required this.lists,
    this.isRedNightMode = false,
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
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final dateController = TextEditingController(
      text: DateFormat('yyyy-MM-dd').format(DateTime.now()),
    );

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: widget.isRedNightMode
              ? AstroColors.nightVisionSurface
              : AstroColors.spaceDarkSurface,
          title: Text(
            "Create New Observing List",
            style: TextStyle(
              color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
              fontSize: 16,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(labelText: "List Name (e.g. Bortle 4 Trip)"),
                style: TextStyle(
                  color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: descController,
                decoration: const InputDecoration(labelText: "Description / Gear Notes"),
                style: TextStyle(
                  color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: dateController,
                decoration: const InputDecoration(labelText: "Target Date (YYYY-MM-DD)"),
                style: TextStyle(
                  color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            FilledButton(
              child: const Text("Create"),
              onPressed: () {
                if (nameController.text.trim().isNotEmpty) {
                  widget.onCreateList(
                    nameController.text.trim(),
                    descController.text.trim(),
                    dateController.text.trim(),
                  );
                  Navigator.of(ctx).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  void _exportListCsv(ObservingListModel list) {
    final buffer = StringBuffer();
    buffer.writeln("Catalog Name,Display Name,Catalog,Type,Constellation,Magnitude,Notes,Status");
    for (final item in list.items) {
      buffer.writeln(
        '"${item.name}","${item.displayName}","${item.catalog}","${item.objectType}","${item.constellation}",${item.magnitude ?? ''},"${item.notes}","${item.status}"',
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isRedNightMode
            ? AstroColors.nightVisionSurface
            : AstroColors.spaceDarkSurface,
        title: Text(
          "Exported CSV: ${list.name}",
          style: TextStyle(color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white),
        ),
        content: SizedBox(
          width: 500,
          child: SelectableText(
            buffer.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ),
        actions: [
          TextButton(
            child: const Text("Close"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: accentColor,
        foregroundColor: Colors.black,
        icon: const Icon(Icons.add_rounded),
        label: const Text("New Observing List"),
        onPressed: _showCreateDialog,
      ),
      body: widget.lists.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.playlist_play_rounded, size: 56, color: textColor.withValues(alpha: 0.3)),
                  const SizedBox(height: 12),
                  Text(
                    "No custom observing lists yet",
                    style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.7)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Create a list to organize targets for specific observation dates",
                    style: TextStyle(fontSize: 13, color: textColor.withValues(alpha: 0.5)),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    icon: const Icon(Icons.add_rounded),
                    label: const Text("Create List"),
                    style: FilledButton.styleFrom(backgroundColor: accentColor),
                    onPressed: _showCreateDialog,
                  ),
                ],
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
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionBorder
                          : AstroColors.spaceDarkBorder,
                    ),
                  ),
                  child: Column(
                    children: [
                      ListTile(
                        leading: CircleAvatar(
                          backgroundColor: accentColor.withValues(alpha: 0.15),
                          child: Icon(Icons.event_note_rounded, color: accentColor, size: 20),
                        ),
                        title: Text(
                          list.name,
                          style: TextStyle(fontWeight: FontWeight.w700, color: textColor),
                        ),
                        subtitle: Text(
                          "${list.sessionDate.isNotEmpty ? '${list.sessionDate} • ' : ''}${list.items.length} targets planned",
                          style: TextStyle(color: textColor.withValues(alpha: 0.6), fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.file_download_outlined, size: 20),
                              tooltip: "Export CSV / Framing",
                              onPressed: () => _exportListCsv(list),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 20),
                              tooltip: "Delete list",
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
                              "No targets in this list. Add targets from the search view!",
                              style: TextStyle(color: textColor.withValues(alpha: 0.5), fontSize: 12),
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
                                    color: textColor,
                                  ),
                                ),
                                subtitle: Text(
                                  "${item.objectType} in ${item.constellation}${item.notes.isNotEmpty ? ' • Notes: ${item.notes}' : ''}",
                                  style: TextStyle(
                                    color: textColor.withValues(alpha: 0.6),
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
