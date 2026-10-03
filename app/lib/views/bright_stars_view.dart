import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import '../widgets/astro_chips.dart';
import '../widgets/target_list_scaffold.dart';
import 'target_details_sheet.dart';

enum StarSortMode {
  brightness,
  peakAltitude,
  visibleDuration,
  transitTime,
}

class BrightStarsView extends StatefulWidget {
  final List<TargetItem> stars;
  final NightSummary night;
  final FilterState filters;
  final bool isLoading;
  final bool isRedNightMode;
  final List<ObservingListModel> availableLists;
  final void Function(FilterState updated) onFilterChanged;
  final void Function(int listId, int dsoId, String notes) onAddToList;

  const BrightStarsView({
    super.key,
    required this.stars,
    required this.night,
    required this.filters,
    required this.isLoading,
    this.isRedNightMode = false,
    required this.availableLists,
    required this.onFilterChanged,
    required this.onAddToList,
  });

  @override
  State<BrightStarsView> createState() => _BrightStarsViewState();
}

class _BrightStarsViewState extends State<BrightStarsView> {
  StarSortMode _sortMode = StarSortMode.brightness;
  final TextEditingController _searchController = TextEditingController();
  TargetItem? _selectedStar;
  String _searchFilter = '';

  @override
  void initState() {
    super.initState();
    if (widget.stars.isNotEmpty) {
      _selectedStar = widget.stars.first;
    }
  }

  @override
  void didUpdateWidget(BrightStarsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedStar != null) {
      final matching = widget.stars.where((s) => s.id == _selectedStar!.id).firstOrNull;
      if (matching != null) {
        _selectedStar = matching;
      } else if (widget.stars.isNotEmpty) {
        _selectedStar = widget.stars.first;
      }
    } else if (widget.stars.isNotEmpty) {
      _selectedStar = widget.stars.first;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TargetItem> get _sortedStars {
    var list = List<TargetItem>.from(widget.stars);

    if (_searchFilter.isNotEmpty) {
      final q = _searchFilter.toLowerCase();
      list = list.where((s) {
        return s.name.toLowerCase().contains(q) ||
            (s.commonName != null && s.commonName!.toLowerCase().contains(q)) ||
            s.constellation.toLowerCase().contains(q);
      }).toList();
    }

    switch (_sortMode) {
      case StarSortMode.brightness:
        list.sort((a, b) {
          final magA = a.magnitude ?? 99.0;
          final magB = b.magnitude ?? 99.0;
          return magA.compareTo(magB);
        });
        break;
      case StarSortMode.peakAltitude:
        list.sort((a, b) => b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg));
        break;
      case StarSortMode.visibleDuration:
        list.sort((a, b) => b.visibleDurationHours.compareTo(a.visibleDurationHours));
        break;
      case StarSortMode.transitTime:
        list.sort((a, b) => a.transitTime.compareTo(b.transitTime));
        break;
    }

    return list;
  }

  Color _getStarColor(String name, AstroPalette palette) {
    if (palette.isRedNightMode) return palette.accent;
    switch (name) {
      case 'Rigel':
      case 'Achernar':
      case 'Spica':
      case 'Bellatrix':
      case 'Alnilam':
      case 'Alnitak':
      case 'Shaula':
        return const Color(0xFFBBDEFB); // Blue-white
      case 'Sirius':
      case 'Vega':
      case 'Altair':
      case 'Deneb':
      case 'Fomalhaut':
      case 'Castor':
        return Colors.white; // Pure white
      case 'Procyon':
      case 'Canopus':
      case 'Polaris':
        return const Color(0xFFFFF9C4); // Yellow-white
      case 'Capella':
      case 'Arcturus':
      case 'Pollux':
      case 'Aldebaran':
        return const Color(0xFFFFE082); // Orange-yellow
      case 'Betelgeuse':
      case 'Antares':
        return const Color(0xFFFF8A65); // Red-orange supergiant
      default:
        return Colors.white;
    }
  }

  void _onStarSelected(TargetItem star, bool isWide) {
    if (isWide) {
      setState(() => _selectedStar = star);
    } else {
      TargetDetailsSheet.show(
        context,
        target: star,
        night: widget.night,
        latitude: widget.filters.observerLat,
        longitude: widget.filters.observerLon,
        elevation: widget.filters.observerElevation,
        isRedNightMode: widget.isRedNightMode,
        availableLists: widget.availableLists,
        onAddToList: widget.onAddToList,
        filters: widget.filters,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final palette = AstroPalette.of(context);
    final isWide = MediaQuery.of(context).size.width >= 900;
    final displayStars = _sortedStars;

    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 500;
            final searchField = TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchFilter = val.trim()),
              style: TextStyle(color: palette.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: "Search bright star (e.g. Sirius, Vega, Polaris, Betelgeuse)...",
                hintStyle: TextStyle(color: palette.text.withValues(alpha: 0.4)),
                prefixIcon: Icon(Icons.search_rounded, size: 18, color: palette.accent),
                suffixIcon: _searchFilter.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, size: 16),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchFilter = '');
                        },
                      )
                    : null,
                filled: true,
                fillColor: palette.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: palette.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: palette.border),
                ),
              ),
            );

            final sortDropdown = Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: palette.surfaceVariant,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: palette.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<StarSortMode>(
                  value: _sortMode,
                  dropdownColor: palette.surfaceVariant,
                  icon: Icon(Icons.sort_rounded, size: 18, color: palette.accent),
                  style: TextStyle(color: palette.text, fontSize: 13, fontWeight: FontWeight.w600),
                  items: [
                    DropdownMenuItem(value: StarSortMode.brightness, child: Text(l10n.sortBrightness)),
                    DropdownMenuItem(value: StarSortMode.peakAltitude, child: Text(l10n.sortPeakAltitude)),
                    DropdownMenuItem(value: StarSortMode.visibleDuration, child: Text(l10n.sortVisibleDuration)),
                    DropdownMenuItem(value: StarSortMode.transitTime, child: Text(l10n.sortTransitTime)),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _sortMode = val);
                  },
                ),
              ),
            );

            if (isNarrow) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  searchField,
                  const SizedBox(height: 8),
                  sortDropdown,
                ],
              );
            }

            return Row(
              children: [
                Expanded(child: searchField),
                const SizedBox(width: 12),
                sortDropdown,
              ],
            );
          },
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              InfoChip(label: "Navigational Stars", icon: Icons.star_rounded, color: palette.starGold),
              const SizedBox(width: 6),
              InfoChip(
                label: "${displayStars.length} stars cataloged",
                icon: Icons.auto_awesome_rounded,
                color: palette.text,
              ),
              const SizedBox(width: 6),
              InfoChip(label: "Telescope Alignment & Focus", icon: Icons.center_focus_strong_rounded, color: palette.accent),
            ],
          ),
        ),
      ],
    );

    return TargetListScaffold<TargetItem>(
      items: displayStars,
      selectedItem: _selectedStar,
      isLoading: widget.isLoading,
      header: header,
      onItemSelected: (star) => _onStarSelected(star, isWide),
      emptyState: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.star_outline_rounded, size: 48, color: palette.text.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              "No stars match your search.",
              style: TextStyle(fontSize: 16, color: palette.text.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
      itemBuilder: (context, star, isSelected) => _buildStarCard(star, isSelected, isWide),
      detailBuilder: (context, star) => TargetDetailsSheet(
        target: star,
        night: widget.night,
        latitude: widget.filters.observerLat,
        longitude: widget.filters.observerLon,
        elevation: widget.filters.observerElevation,
        isRedNightMode: widget.isRedNightMode,
        availableLists: widget.availableLists,
        onAddToList: widget.onAddToList,
        filters: widget.filters,
        onClose: () => setState(() => _selectedStar = null),
      ),
    );
  }

  Widget _buildStarCard(TargetItem star, bool isSelected, bool isWide) {
    final palette = AstroPalette.of(context);
    final textColor = palette.text;
    final accentColor = palette.accent;
    final starColor = _getStarColor(star.name, palette);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected ? palette.surfaceVariant : palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected ? accentColor : palette.border,
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _onStarSelected(star, isWide),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: starColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: starColor.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Icon(
                      star.objectType == 'Double Star' ? Icons.join_inner_rounded : Icons.star_rounded,
                      color: starColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              star.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            if (star.commonName != null) ...[
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  "(${star.commonName})",
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: textColor.withValues(alpha: 0.6),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "${star.objectType} • Constellation: ${star.constellation}",
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (star.magnitude != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: palette.starGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: palette.starGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        "Mag ${star.magnitude! >= 0 ? '+' : ''}${star.magnitude!.toStringAsFixed(2)}",
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: palette.starGold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  MetricPill(
                    icon: Icons.trending_up_rounded,
                    label: "${star.peakAltitudeDeg.toStringAsFixed(1)}° peak",
                    color: star.peakAltitudeDeg >= widget.filters.minAltitude
                        ? palette.visibleGreen
                        : textColor.withValues(alpha: 0.5),
                  ),
                  MetricPill(
                    icon: Icons.timer_outlined,
                    label: "${star.visibleDurationHours.toStringAsFixed(1)} hrs",
                    color: star.visibleDurationHours > 0 ? palette.deepSkyTeal : textColor.withValues(alpha: 0.5),
                  ),
                  MetricPill(
                    icon: Icons.explore_outlined,
                    label:
                        "${star.transitTime.toLocal().hour.toString().padLeft(2, '0')}:${star.transitTime.toLocal().minute.toString().padLeft(2, '0')} transit",
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
              if (star.visibleDurationHours > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (star.visibleDurationHours / 10.0).clamp(0.05, 1.0),
                    backgroundColor: palette.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      star.meetsCriteria ? accentColor : palette.starGold,
                    ),
                    minHeight: 4,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
