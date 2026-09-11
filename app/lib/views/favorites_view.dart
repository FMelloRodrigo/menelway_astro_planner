import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/favorites_manager.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
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

    final buffer = StringBuffer();
    buffer.writeln("Name,Catalog,Type,Constellation,RA_Hours,Dec_Deg,Magnitude,Size_Arcmin,PositionAngle_Deg");
    for (final t in items) {
      buffer.writeln(
        '"${t.displayName}","${t.catalog}","${t.objectType}","${t.constellation}",'
        '${t.raHours.toStringAsFixed(4)},${t.decDegrees.toStringAsFixed(4)},'
        '${t.magnitude?.toStringAsFixed(2) ?? ""},'
        '${t.majorAxisArcmin?.toStringAsFixed(1) ?? ""},'
        '${t.positionAngleDeg?.toStringAsFixed(1) ?? ""}',
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        title: Text(
          "Exported Favorites (${items.length} targets)",
          style: TextStyle(color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white),
        ),
        content: SizedBox(
          width: 500,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SelectableText(
                buffer.toString(),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
              ),
            ],
          ),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 16),
            label: const Text("Copy CSV"),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: buffer.toString()));
              Navigator.of(ctx).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text("Favorites CSV copied to clipboard"),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            },
          ),
          FilledButton(
            child: const Text("Done"),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      ),
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
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDlgState) => AlertDialog(
          backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
          title: Text(
            "Add All Favorites to Observing List",
            style: TextStyle(
              color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
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
                  color: (widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white).withValues(alpha: 0.8),
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                value: selectedListId,
                decoration: const InputDecoration(labelText: "Target Observing List"),
                dropdownColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
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
      ),
    );
  }

  void _confirmClearFavorites() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
        title: Text(
          "Clear All Favorites?",
          style: TextStyle(
            color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        content: const Text(
          "Are you sure you want to remove all saved targets from your favorites list?",
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
      ),
    );
  }

  void _openDetailsModal(TargetItem target) {
    if (widget.night == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FractionallySizedBox(
        heightFactor: 0.88,
        child: TargetDetailsSheet(
          target: target,
          night: widget.night!,
          latitude: widget.filters.observerLat,
          longitude: widget.filters.observerLon,
          elevation: widget.filters.observerElevation,
          isRedNightMode: widget.isRedNightMode,
          filters: widget.filters,
          availableLists: widget.availableLists,
          onAddToList: widget.onAddToList,
        ),
      ),
    );
  }

  void _openFramingDialog(TargetItem target) {
    showDialog(
      context: context,
      builder: (_) => EquipmentFramingDialog(
        target: target,
        isRedNightMode: widget.isRedNightMode,
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color accentColor) {
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
                color: (widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent).withValues(alpha: 0.12),
                shape: BoxShape.circle,
                border: Border.all(
                  color: (widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent).withValues(alpha: 0.35),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 40,
                color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              "No Favorite Targets Yet",
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: textColor,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Text(
                "Save your favorite deep-sky targets by clicking the heart button next to 'Add to List' on any target's details card for fast planning and framing.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: textColor.withValues(alpha: 0.7),
                  height: 1.4,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              icon: const Icon(Icons.radar_rounded, size: 18),
              label: const Text("Explore Night Targets"),
              style: FilledButton.styleFrom(
                backgroundColor: accentColor,
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

  Widget _buildFavoriteCard(TargetItem target, bool isSelected, bool isWide, Color textColor, Color accentColor) {
    final borderColor = isSelected
        ? accentColor
        : (widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder);

    final cardBg = isSelected
        ? (widget.isRedNightMode
            ? AstroColors.nightVisionSurfaceVariant
            : AstroColors.spaceDarkSurfaceVariant)
        : (widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface);

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
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _buildBadge(target.catalog, Colors.teal, widget.isRedNightMode),
                            _buildBadge(target.objectType, AstroColors.starlightCyan, widget.isRedNightMode),
                            _buildBadge(target.constellation, AstroColors.starGold, widget.isRedNightMode),
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
                        color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent,
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
                      Icon(Icons.auto_awesome_rounded, size: 13, color: textColor.withValues(alpha: 0.5)),
                      const SizedBox(width: 3),
                      Text(
                        target.magnitude != null ? "Mag ${target.magnitude!.toStringAsFixed(1)}" : "Mag N/A",
                        style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                  // Size
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.aspect_ratio_rounded, size: 13, color: textColor.withValues(alpha: 0.5)),
                      const SizedBox(width: 3),
                      Text(
                        target.majorAxisArcmin != null
                            ? "${target.majorAxisArcmin!.toStringAsFixed(1)}'"
                            : "Point Source",
                        style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                      ),
                    ],
                  ),
                  // Position Angle
                  if (target.positionAngleDeg != null)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rotate_right_rounded, size: 13, color: AstroColors.starGold),
                        const SizedBox(width: 3),
                        Text(
                          "PA ${target.positionAngleDeg!.toStringAsFixed(1)}°",
                          style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  // RA & Dec
                  Text(
                    "RA: ${target.formattedRa}  Dec: ${target.formattedDec}",
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 10,
                      color: textColor.withValues(alpha: 0.6),
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
                        color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
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

  Widget _buildBadge(String text, Color color, bool isRed) {
    final badgeColor = isRed ? AstroColors.nightVisionRed : color;
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
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final borderColor = widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder;

    final isWide = MediaQuery.of(context).size.width >= 900;
    final allFavorites = FavoritesManager.instance.favorites;
    final filteredFavorites = _getFilteredFavorites();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: allFavorites.isEmpty
          ? _buildEmptyState(textColor, accentColor)
          : Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.favorite_rounded,
                        color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  "Favorite Targets",
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: (widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent)
                                        .withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    "${allFavorites.length}",
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.pinkAccent,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              "Quick access for observing and camera framing",
                              style: TextStyle(
                                fontSize: 11,
                                color: textColor.withValues(alpha: 0.6),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Top Actions
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
                  ),
                ),

                // Search Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: textColor, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: "Search favorites by name, catalog, constellation...",
                      hintStyle: TextStyle(color: textColor.withValues(alpha: 0.4), fontSize: 13),
                      prefixIcon: Icon(Icons.search_rounded, size: 18, color: textColor.withValues(alpha: 0.5)),
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
                      fillColor: widget.isRedNightMode
                          ? AstroColors.nightVisionSurfaceVariant
                          : AstroColors.spaceDarkSurfaceVariant,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: BorderSide(color: borderColor),
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
                            style: TextStyle(color: textColor.withValues(alpha: 0.5)),
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
                                      return _buildFavoriteCard(target, isSelected, isWide, textColor, accentColor);
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
                                            style: TextStyle(color: textColor.withValues(alpha: 0.5)),
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
                                return _buildFavoriteCard(target, false, isWide, textColor, accentColor);
                              },
                            ),
                ),
              ],
            ),
    );
  }
}
