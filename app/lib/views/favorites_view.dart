import 'package:flutter/material.dart';

import '../core/favorites_manager.dart';
import '../l10n/app_localizations.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../services/csv_export_service.dart';
import '../theme/astro_theme.dart';
import 'equipment_framing_dialog.dart';
import 'target_details_sheet.dart';

class FavoritesView extends StatefulWidget {
  final NightSummary? night;
  final FilterState filters;
  final bool isRedNightMode;
  final List<ObservingListModel> availableLists;
  final void Function(int listId, int dsoId, String notes) onAddToList;
  final VoidCallback onExploreTargets;

  const FavoritesView({
    super.key,
    this.night,
    required this.filters,
    this.isRedNightMode = false,
    required this.availableLists,
    required this.onAddToList,
    required this.onExploreTargets,
  });

  @override
  State<FavoritesView> createState() => _FavoritesViewState();
}

class _FavoritesViewState extends State<FavoritesView> {
  final TextEditingController _searchController = TextEditingController();
  TargetItem? _selectedTarget;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    FavoritesManager.instance.addListener(_onFavoritesChanged);
    final favs = FavoritesManager.instance.favorites;
    if (favs.isNotEmpty) {
      _selectedTarget = favs.first;
    }
  }

  @override
  void dispose() {
    FavoritesManager.instance.removeListener(_onFavoritesChanged);
    _searchController.dispose();
    super.dispose();
  }

  void _onFavoritesChanged() {
    if (!mounted) return;
    final favs = FavoritesManager.instance.favorites;
    if (_selectedTarget != null && !favs.any((t) => t.id == _selectedTarget!.id)) {
      _selectedTarget = favs.isNotEmpty ? favs.first : null;
    } else if (_selectedTarget == null && favs.isNotEmpty) {
      _selectedTarget = favs.first;
    }
    setState(() {});
  }

  List<TargetItem> _getFilteredFavorites() {
    final favs = FavoritesManager.instance.favorites;
    if (_searchQuery.trim().isEmpty) return favs;

    final q = _searchQuery.trim().toLowerCase();
    return favs.where((t) {
      final name = t.name.toLowerCase();
      final messier = t.messier?.toLowerCase() ?? '';
      final caldwell = t.caldwell?.toLowerCase() ?? '';
      final arp = t.arp?.toLowerCase() ?? '';
      final herschel = t.herschel?.toLowerCase() ?? '';
      final common = t.commonName?.toLowerCase() ?? '';
      final constel = t.constellation.toLowerCase();
      final type = t.objectType.toLowerCase();

      return name.contains(q) ||
          messier.contains(q) ||
          caldwell.contains(q) ||
          arp.contains(q) ||
          herschel.contains(q) ||
          common.contains(q) ||
          constel.contains(q) ||
          type.contains(q);
    }).toList();
  }

  void _exportFavoritesCsv(List<TargetItem> items) {
    if (items.isEmpty) return;
    final csv = CsvExportService.exportFavoritesCsv(items);
    CsvExportService.showCsvDialog(
      context,
      title: "Exported Favorites (${items.length} targets)",
      csvContent: csv,
      copiedMessage: "Favorites CSV copied to clipboard",
    );
  }

  void _showAddAllToListDialog(List<TargetItem> items) {
    if (widget.availableLists.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("No observing lists found. Create a list in the Observing Lists tab first!"),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    int selectedListId = widget.availableLists.first.id;

    showDialog(
      context: context,
      builder: (ctx) {
        final palette = AstroPalette.of(ctx);
        return StatefulBuilder(
          builder: (context, setDlgState) => AlertDialog(
            backgroundColor: palette.surface,
            title: Text(
              "Add All Favorites to Observing List",
              style: TextStyle(
                color: palette.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Add ${items.length} favorite targets to:",
                  style: TextStyle(
                    color: palette.textSecondary,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedListId,
                  decoration: const InputDecoration(labelText: "Target Observing List"),
                  dropdownColor: palette.surface,
                  items: widget.availableLists.map((l) {
                    return DropdownMenuItem<int>(
                      value: l.id,
                      child: Text(l.name),
                    );
                  }).toList(),
                  onChanged: (val) {
                    if (val != null) setDlgState(() => selectedListId = val);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                child: const Text("Cancel"),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
              FilledButton(
                child: const Text("Add All"),
                onPressed: () {
                  for (final t in items) {
                    widget.onAddToList(selectedListId, t.id, "Added from Favorites");
                  }
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text("Added ${items.length} favorite targets to observing list"),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmClearFavorites() {
    showDialog(
      context: context,
      builder: (ctx) {
        final palette = AstroPalette.of(ctx);
        return AlertDialog(
          backgroundColor: palette.surface,
          title: Text(
            "Clear All Favorites?",
            style: TextStyle(
              color: palette.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            "Are you sure you want to remove all saved targets from your favorites list?",
            style: TextStyle(color: palette.textSecondary),
          ),
          actions: [
            TextButton(
              child: const Text("Cancel"),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            FilledButton(
              style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
              child: const Text("Clear All"),
              onPressed: () {
                FavoritesManager.instance.clear();
                Navigator.of(ctx).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text("All favorites cleared"),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  void _openDetailsModal(TargetItem target) {
    if (widget.night == null) return;
    TargetDetailsSheet.show(
      context,
      target: target,
      night: widget.night!,
      latitude: widget.filters.observerLat,
      longitude: widget.filters.observerLon,
      elevation: widget.filters.observerElevation,
      isRedNightMode: widget.isRedNightMode,
      filters: widget.filters,
      availableLists: widget.availableLists,
      onAddToList: widget.onAddToList,
    );
  }

  void _openFramingDialog(TargetItem target) {
    showDialog(
      context: context,
      builder: (_) => EquipmentFramingDialog(
        target: target,
      ),
    );
  }

  Widget _buildEmptyState(AstroPalette palette) {
    final l10n = AppLocalizations.of(context);
    final heartColor = palette.isRedNightMode ? palette.accent : Colors.pinkAccent;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: heartColor.withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: heartColor.withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 40,
                color: heartColor,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n.noFavoritesYet,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: palette.textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                l10n.noFavoritesDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: palette.textSecondary,
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.radar_rounded, size: 18),
              label: Text(l10n.exploreTargets),
              style: FilledButton.styleFrom(
                backgroundColor: palette.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              ),
              onPressed: widget.onExploreTargets,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(TargetItem target, bool isSelected, bool isWide, AstroPalette palette) {
    final borderColor = isSelected ? palette.accent : palette.border;
    final cardBg = isSelected ? palette.surfaceVariant : palette.surface;
    final heartColor = palette.isRedNightMode ? palette.accent : Colors.pinkAccent;

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      color: cardBg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: isSelected ? 1.5 : 1.0),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          setState(() => _selectedTarget = target);
          if (!isWide) {
            _openDetailsModal(target);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top row: Display name & Heart action
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          target.displayName,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: palette.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildBadge(target.catalog, palette.deepSkyTeal, palette),
                            _buildBadge(target.objectType, palette.starlightCyan, palette),
                            _buildBadge(target.constellation, palette.starGold, palette),
                          ],
                        ),
                      ],
                    ),
                  ),
                  // Heart Toggle Button
                  Tooltip(
                    message: "Remove from Favorites",
                    child: IconButton(
                      icon: Icon(
                        Icons.favorite_rounded,
                        color: heartColor,
                        size: 20,
                      ),
                      onPressed: () {
                        FavoritesManager.instance.removeFavorite(target.id);
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("Removed ${target.displayName} from Favorites"),
                            behavior: SnackBarBehavior.floating,
                            duration: const Duration(seconds: 2),
                            action: SnackBarAction(
                              label: "Undo",
                              onPressed: () => FavoritesManager.instance.addFavorite(target),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Metadata row
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  // Magnitude
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 13, color: palette.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        target.magnitude != null ? "Mag ${target.magnitude!.toStringAsFixed(1)}" : "Mag N/A",
                        style: TextStyle(fontSize: 11, color: palette.textSecondary),
                      ),
                    ],
                  ),
                  // Size
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.aspect_ratio_rounded, size: 13, color: palette.textTertiary),
                      const SizedBox(width: 3),
                      Text(
                        target.majorAxisArcmin != null
                            ? "${target.majorAxisArcmin!.toStringAsFixed(1)}'"
                            : "Point Source",
                        style: TextStyle(fontSize: 11, color: palette.textSecondary),
                      ),
                    ],
                  ),
                  // Position Angle
                  if (target.positionAngleDeg != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rotate_right_rounded, size: 13, color: palette.starGold),
                        const SizedBox(width: 3),
                        Text(
                          "PA ${target.positionAngleDeg!.toStringAsFixed(1)}°",
                          style: TextStyle(fontSize: 11, color: palette.textSecondary),
                        ),
                      ],
                    ),
                  // RA & Dec
                  Text(
                    "RA: ${target.formattedRa}  Dec: ${target.formattedDec}",
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: palette.textSecondary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Action buttons bar
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Framing Simulator Button
                  OutlinedButton.icon(
                    icon: const Icon(Icons.crop_rotate_rounded, size: 15),
                    label: const Text("Framing", style: TextStyle(fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      side: BorderSide(
                        color: palette.border,
                      ),
                    ),
                    onPressed: () => _openFramingDialog(target),
                  ),
                  const SizedBox(width: 8),
                  // View Details Button
                  FilledButton.tonalIcon(
                    icon: const Icon(Icons.visibility_rounded, size: 15),
                    label: const Text("Details", style: TextStyle(fontSize: 11)),
                    style: FilledButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    ),
                    onPressed: () => _openDetailsModal(target),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(String text, Color color, AstroPalette palette) {
    final badgeColor = palette.isRedNightMode ? palette.accent : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: badgeColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: badgeColor.withValues(alpha: 0.4)),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: badgeColor,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = AstroPalette.of(context);
    final heartColor = palette.isRedNightMode ? palette.accent : Colors.pinkAccent;

    final isWide = MediaQuery.of(context).size.width >= 900;
    final allFavorites = FavoritesManager.instance.favorites;
    final filteredFavorites = _getFilteredFavorites();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: allFavorites.isEmpty
          ? _buildEmptyState(palette)
          : Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 480;
                      final titleRow = Row(
                        children: [
                          Icon(
                            Icons.favorite_rounded,
                            color: heartColor,
                            size: 24,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Flexible(
                                      child: Text(
                                        "Favorite Targets",
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w700,
                                          color: palette.textPrimary,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: heartColor.withValues(alpha: 0.18),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        "${allFavorites.length}",
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                          color: heartColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  "Quick access for observing and camera framing",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: palette.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      );

                      final actionButtons = Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.file_download_outlined, size: 20),
                            tooltip: "Export Favorites CSV",
                            onPressed: () => _exportFavoritesCsv(allFavorites),
                          ),
                          IconButton(
                            icon: const Icon(Icons.playlist_add_rounded, size: 20),
                            tooltip: "Add All to Observing List",
                            onPressed: () => _showAddAllToListDialog(allFavorites),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_sweep_outlined, size: 20),
                            tooltip: "Clear All Favorites",
                            onPressed: _confirmClearFavorites,
                          ),
                        ],
                      );

                      if (isNarrow) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            titleRow,
                            const SizedBox(height: 4),
                            Align(
                              alignment: Alignment.centerRight,
                              child: actionButtons,
                            ),
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: titleRow),
                          actionButtons,
                        ],
                      );
                    },
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: palette.textPrimary, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Search favorites by name, catalog, constellation...",
                      hintStyle: TextStyle(color: palette.textTertiary, fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: palette.textTertiary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded, size: 16),
                              onPressed: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                            )
                          : null,
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      filled: true,
                      fillColor: palette.surfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: palette.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: palette.border),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // Content (Split view on wide screens, Single list on narrow)
                Expanded(
                  child: filteredFavorites.isEmpty
                      ? Center(
                          child: Text(
                            "No favorites matching '$_searchQuery'",
                            style: TextStyle(color: palette.textSecondary),
                          ),
                        )
                      : isWide
                          ? Row(
                              children: [
                                // Left column: Target Cards List
                                SizedBox(
                                  width: 420,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                    itemCount: filteredFavorites.length,
                                    itemBuilder: (context, index) {
                                      final target = filteredFavorites[index];
                                      final isSelected = _selectedTarget?.id == target.id;
                                      return _buildFavoriteCard(target, isSelected, isWide, palette);
                                    },
                                  ),
                                ),

                                const VerticalDivider(width: 1),

                                // Right column: Selected Target Details Sheet
                                Expanded(
                                  child: _selectedTarget != null && widget.night != null
                                      ? TargetDetailsSheet(
                                          key: ValueKey(_selectedTarget!.id),
                                          target: _selectedTarget!,
                                          night: widget.night!,
                                          latitude: widget.filters.observerLat,
                                          longitude: widget.filters.observerLon,
                                          elevation: widget.filters.observerElevation,
                                          isRedNightMode: widget.isRedNightMode,
                                          filters: widget.filters,
                                          availableLists: widget.availableLists,
                                          onAddToList: widget.onAddToList,
                                        )
                                      : Center(
                                          child: Text(
                                            "Select a target to view details",
                                            style: TextStyle(color: palette.textSecondary),
                                          ),
                                        ),
                                ),
                              ],
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: filteredFavorites.length,
                              itemBuilder: (context, index) {
                                final target = filteredFavorites[index];
                                return _buildFavoriteCard(target, false, isWide, palette);
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
