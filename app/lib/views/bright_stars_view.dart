import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
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

  Color _getStarColor(String name) {
    if (widget.isRedNightMode) return AstroColors.nightVisionRed;
    // Basic spectral tint approximation
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
        return const Color(0xFFFFE082); // Orange
      case 'Betelgeuse':
      case 'Antares':
      case 'Gacrux':
        return const Color(0xFFFF8A65); // Red giant
      default:
        return AstroColors.starGold;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final isWideScreen = MediaQuery.of(context).size.width >= 900;
    final displayStars = _sortedStars;

    return Column(
      children: [
        // Top Toolbar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface,
            border: Border(
              bottom: BorderSide(
                color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
              ),
            ),
          ),
          child: Column(
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final isNarrow = constraints.maxWidth < 650;
                  const double topBarHeight = 44.0;

                  final searchField = SizedBox(
                    height: topBarHeight,
                    child: TextField(
                      controller: _searchController,
                      textAlignVertical: TextAlignVertical.center,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: "Search bright star (e.g. Sirius, Vega, Polaris, Betelgeuse)...",
                        prefixIcon: Icon(Icons.search_rounded, size: 20, color: accentColor),
                        prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                padding: EdgeInsets.zero,
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() => _searchFilter = '');
                                },
                              )
                            : null,
                      ),
                      onChanged: (text) {
                        setState(() => _searchFilter = text.trim());
                      },
                    ),
                  );

                  final sortDropdown = Container(
                    height: topBarHeight,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: widget.isRedNightMode
                          ? AstroColors.nightVisionSurfaceVariant
                          : AstroColors.spaceDarkSurfaceVariant,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
                      ),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<StarSortMode>(
                        value: _sortMode,
                        dropdownColor: widget.isRedNightMode
                            ? AstroColors.nightVisionSurface
                            : AstroColors.spaceDarkSurface,
                        icon: Icon(Icons.sort_rounded, size: 18, color: accentColor),
                        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                        items: [
                          DropdownMenuItem(value: StarSortMode.brightness, child: Text(l10n?.sortBrightness ?? "Brightness")),
                          DropdownMenuItem(value: StarSortMode.peakAltitude, child: Text(l10n?.sortPeakAltitude ?? "Peak Altitude")),
                          DropdownMenuItem(value: StarSortMode.visibleDuration, child: Text(l10n?.sortVisibleDuration ?? "Observable Duration")),
                          DropdownMenuItem(value: StarSortMode.transitTime, child: Text(l10n?.sortTransitTime ?? "Transit Time")),
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
              // Summary Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildChip("Navigational Stars", Icons.star_rounded, AstroColors.starGold),
                    const SizedBox(width: 6),
                    _buildChip("${displayStars.length} stars cataloged", Icons.auto_awesome_rounded, textColor),
                    const SizedBox(width: 6),
                    _buildChip("Telescope Alignment & Focus", Icons.center_focus_strong_rounded, accentColor),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Main Content Area
        Expanded(
          child: widget.isLoading
              ? const Center(child: CircularProgressIndicator())
              : displayStars.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.star_border_rounded, size: 48, color: textColor.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            "No stars match your search.",
                            style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    )
                  : isWideScreen && _selectedStar != null
                      ? CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape): () {
                              setState(() => _selectedStar = null);
                            },
                          },
                          child: Focus(
                            autofocus: true,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _buildStarList(displayStars),
                                ),
                                Container(
                                  width: 1,
                                  color: widget.isRedNightMode
                                      ? AstroColors.nightVisionBorder
                                      : AstroColors.spaceDarkBorder,
                                ),
                                Expanded(
                                  flex: 6,
                                  child: TargetDetailsSheet(
                                    target: _selectedStar!,
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
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildStarList(displayStars),
        ),
      ],
    );
  }

  Widget _buildChip(String label, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: widget.isRedNightMode
            ? AstroColors.nightVisionSurfaceVariant
            : AstroColors.spaceDarkSurfaceVariant,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: widget.isRedNightMode
              ? AstroColors.nightVisionBorder
              : AstroColors.spaceDarkBorder,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildStarList(List<TargetItem> stars) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: stars.length,
      itemBuilder: (context, index) {
        final star = stars[index];
        final isSelected = _selectedStar?.id == star.id;
        return _buildStarCard(star, isSelected);
      },
    );
  }

  Widget _buildStarCard(TargetItem star, bool isSelected) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final starColor = _getStarColor(star.name);

    final card = Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: isSelected
          ? (widget.isRedNightMode
              ? AstroColors.nightVisionSurfaceVariant
              : AstroColors.spaceDarkSurfaceVariant)
          : (widget.isRedNightMode
              ? AstroColors.nightVisionSurface
              : AstroColors.spaceDarkSurface),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isSelected
              ? accentColor
              : (widget.isRedNightMode
                  ? AstroColors.nightVisionBorder
                  : AstroColors.spaceDarkBorder),
          width: isSelected ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          final isWide = MediaQuery.of(context).size.width >= 900;
          if (isWide) {
            setState(() => _selectedStar = star);
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => FractionallySizedBox(
                heightFactor: 0.9,
                child: TargetDetailsSheet(
                  target: star,
                  night: widget.night,
                  latitude: widget.filters.observerLat,
                  longitude: widget.filters.observerLon,
                  elevation: widget.filters.observerElevation,
                  isRedNightMode: widget.isRedNightMode,
                  availableLists: widget.availableLists,
                  onAddToList: widget.onAddToList,
                  filters: widget.filters,
                ),
              ),
            );
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Star Icon, Name, Common Names, Magnitude
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
                  // Magnitude Badge
                  if (star.magnitude != null)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AstroColors.starGold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: AstroColors.starGold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        "Mag ${star.magnitude! >= 0 ? '+' : ''}${star.magnitude!.toStringAsFixed(2)}",
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: AstroColors.starGold,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),

              // Visibility Metrics Row
              Row(
                children: [
                  _buildMetricPill(
                    Icons.trending_up_rounded,
                    "${star.peakAltitudeDeg.round()}° peak",
                    star.peakAltitudeDeg >= 30.0 ? accentColor : textColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    Icons.timer_outlined,
                    "${star.visibleDurationHours.toStringAsFixed(1)}h visible",
                    star.visibleDurationHours > 0 ? AstroColors.deepSkyTeal : textColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    Icons.explore_outlined,
                    "${star.transitTime.toLocal().hour.toString().padLeft(2, '0')}:${star.transitTime.toLocal().minute.toString().padLeft(2, '0')} transit",
                    textColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Observable Night Window Progress Bar
              if (star.visibleDurationHours > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (star.visibleDurationHours / 10.0).clamp(0.05, 1.0),
                    backgroundColor: widget.isRedNightMode
                        ? AstroColors.nightVisionSurfaceVariant
                        : AstroColors.spaceDarkSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      star.meetsCriteria ? accentColor : Colors.amber,
                    ),
                    minHeight: 4,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    return card;
  }

  Widget _buildMetricPill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
