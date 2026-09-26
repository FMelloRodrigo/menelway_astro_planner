import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/app_localizations.dart';
import '../models/filter_state.dart';
import '../models/night_summary.dart';
import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../theme/astro_theme.dart';
import 'target_details_sheet.dart';

enum PlanetSortMode {
  orderFromSun,
  brightness,
  peakAltitude,
  visibleDuration,
  transitTime,
}

class PlanetsView extends StatefulWidget {
  final List<TargetItem> planets;
  final NightSummary night;
  final FilterState filters;
  final bool isLoading;
  final bool isRedNightMode;
  final List<ObservingListModel> availableLists;
  final void Function(FilterState updated) onFilterChanged;
  final void Function(int listId, int dsoId, String notes) onAddToList;

  const PlanetsView({
    super.key,
    required this.planets,
    required this.night,
    required this.filters,
    required this.isLoading,
    this.isRedNightMode = false,
    required this.availableLists,
    required this.onFilterChanged,
    required this.onAddToList,
  });

  @override
  State<PlanetsView> createState() => _PlanetsViewState();
}

class _PlanetsViewState extends State<PlanetsView> {
  PlanetSortMode _sortMode = PlanetSortMode.orderFromSun;
  final TextEditingController _searchController = TextEditingController();
  TargetItem? _selectedPlanet;
  String _searchFilter = '';

  static const Map<String, int> _sunOrder = {
    'Sun': 0,
    'Mercury': 1,
    'Venus': 2,
    'Moon': 3,
    'Mars': 4,
    'Jupiter': 5,
    'Saturn': 6,
    'Uranus': 7,
    'Neptune': 8,
    'Pluto': 9,
  };

  @override
  void initState() {
    super.initState();
    if (widget.planets.isNotEmpty) {
      _selectedPlanet = widget.planets.first;
    }
  }

  @override
  void didUpdateWidget(PlanetsView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedPlanet != null) {
      final matching = widget.planets.where((p) => p.id == _selectedPlanet!.id).firstOrNull;
      if (matching != null) {
        _selectedPlanet = matching;
      } else if (widget.planets.isNotEmpty) {
        _selectedPlanet = widget.planets.first;
      }
    } else if (widget.planets.isNotEmpty) {
      _selectedPlanet = widget.planets.first;
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<TargetItem> get _sortedPlanets {
    var list = List<TargetItem>.from(widget.planets);

    if (_searchFilter.isNotEmpty) {
      final q = _searchFilter.toLowerCase();
      list = list.where((p) {
        return p.name.toLowerCase().contains(q) ||
            (p.commonName != null && p.commonName!.toLowerCase().contains(q)) ||
            p.constellation.toLowerCase().contains(q);
      }).toList();
    }

    switch (_sortMode) {
      case PlanetSortMode.orderFromSun:
        list.sort((a, b) {
          final oA = _sunOrder[a.name] ?? 99;
          final oB = _sunOrder[b.name] ?? 99;
          return oA.compareTo(oB);
        });
        break;
      case PlanetSortMode.brightness:
        list.sort((a, b) {
          final magA = a.magnitude ?? 99.0;
          final magB = b.magnitude ?? 99.0;
          return magA.compareTo(magB);
        });
        break;
      case PlanetSortMode.peakAltitude:
        list.sort((a, b) => b.peakAltitudeDeg.compareTo(a.peakAltitudeDeg));
        break;
      case PlanetSortMode.visibleDuration:
        list.sort((a, b) => b.visibleDurationHours.compareTo(a.visibleDurationHours));
        break;
      case PlanetSortMode.transitTime:
        list.sort((a, b) => a.transitTime.compareTo(b.transitTime));
        break;
    }

    return list;
  }

  IconData _getPlanetIcon(String name) {
    switch (name) {
      case 'Sun':
        return Icons.wb_sunny_rounded;
      case 'Moon':
        return Icons.nightlight_round;
      case 'Saturn':
        return Icons.album_rounded;
      case 'Jupiter':
        return Icons.circle_rounded;
      case 'Mars':
        return Icons.lens_rounded;
      default:
        return Icons.public_rounded;
    }
  }

  Color _getPlanetColor(String name) {
    if (widget.isRedNightMode) return AstroColors.nightVisionRed;
    switch (name) {
      case 'Sun':
        return Colors.amber;
      case 'Moon':
        return Colors.white70;
      case 'Mercury':
        return const Color(0xFFB0BEC5);
      case 'Venus':
        return const Color(0xFFFFF9C4);
      case 'Mars':
        return const Color(0xFFFF7043);
      case 'Jupiter':
        return const Color(0xFFFFD54F);
      case 'Saturn':
        return const Color(0xFFFFE082);
      case 'Uranus':
        return const Color(0xFF80DEEA);
      case 'Neptune':
        return const Color(0xFF64B5F6);
      case 'Pluto':
        return const Color(0xFFBCAAA4);
      default:
        return AstroColors.starlightCyan;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final isWideScreen = MediaQuery.of(context).size.width >= 900;
    final displayPlanets = _sortedPlanets;

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
                        hintText: "Search planet or moon (e.g. Jupiter, Saturn, Mars)...",
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
                      child: DropdownButton<PlanetSortMode>(
                        value: _sortMode,
                        dropdownColor: widget.isRedNightMode
                            ? AstroColors.nightVisionSurface
                            : AstroColors.spaceDarkSurface,
                        icon: Icon(Icons.sort_rounded, size: 18, color: accentColor),
                        style: TextStyle(color: textColor, fontSize: 13, fontWeight: FontWeight.w600),
                        items: [
                          DropdownMenuItem(value: PlanetSortMode.orderFromSun, child: Text(l10n?.sortOrderFromSun ?? "Order from Sun")),
                          DropdownMenuItem(value: PlanetSortMode.brightness, child: Text(l10n?.sortBrightness ?? "Brightness")),
                          DropdownMenuItem(value: PlanetSortMode.peakAltitude, child: Text(l10n?.sortPeakAltitude ?? "Peak Altitude")),
                          DropdownMenuItem(value: PlanetSortMode.visibleDuration, child: Text(l10n?.sortVisibleDuration ?? "Observable Duration")),
                          DropdownMenuItem(value: PlanetSortMode.transitTime, child: Text(l10n?.sortTransitTime ?? "Transit Time")),
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
                    _buildChip("Solar System", Icons.public_rounded, accentColor),
                    const SizedBox(width: 6),
                    _buildChip("${displayPlanets.length} bodies evaluated", Icons.filter_tilt_shift_rounded, textColor),
                    const SizedBox(width: 6),
                    _buildChip("Real-time Ephemeris", Icons.auto_awesome_rounded, AstroColors.starGold),
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
              : displayPlanets.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.public_off_rounded, size: 48, color: textColor.withValues(alpha: 0.3)),
                          const SizedBox(height: 12),
                          Text(
                            "No planets match your search.",
                            style: TextStyle(fontSize: 16, color: textColor.withValues(alpha: 0.6)),
                          ),
                        ],
                      ),
                    )
                  : isWideScreen && _selectedPlanet != null
                      ? CallbackShortcuts(
                          bindings: {
                            const SingleActivator(LogicalKeyboardKey.escape): () {
                              setState(() => _selectedPlanet = null);
                            },
                          },
                          child: Focus(
                            autofocus: true,
                            child: Row(
                              children: [
                                Expanded(
                                  flex: 5,
                                  child: _buildPlanetList(displayPlanets),
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
                                    target: _selectedPlanet!,
                                    night: widget.night,
                                    latitude: widget.filters.observerLat,
                                    longitude: widget.filters.observerLon,
                                    elevation: widget.filters.observerElevation,
                                    isRedNightMode: widget.isRedNightMode,
                                    availableLists: widget.availableLists,
                                    onAddToList: widget.onAddToList,
                                    filters: widget.filters,
                                    onClose: () => setState(() => _selectedPlanet = null),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : _buildPlanetList(displayPlanets),
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

  Widget _buildPlanetList(List<TargetItem> planets) {
    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: planets.length,
      itemBuilder: (context, index) {
        final planet = planets[index];
        final isSelected = _selectedPlanet?.id == planet.id;
        return _buildPlanetCard(planet, isSelected);
      },
    );
  }

  Widget _buildPlanetCard(TargetItem planet, bool isSelected) {
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final planetColor = _getPlanetColor(planet.name);

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
            setState(() => _selectedPlanet = planet);
          } else {
            showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (ctx) => FractionallySizedBox(
                heightFactor: 0.9,
                child: TargetDetailsSheet(
                  target: planet,
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
              // Header: Planet Icon, Name, Constellation, Magnitude, Diameter
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: planetColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: planetColor.withValues(alpha: 0.6), width: 1.5),
                    ),
                    child: Icon(_getPlanetIcon(planet.name), color: planetColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              planet.name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            if (planet.commonName != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                "(${planet.commonName})",
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textColor.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          "Solar System Body • Constellation: ${planet.constellation.isNotEmpty ? planet.constellation : 'Ecliptic'}",
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.6),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Badges: Mag & Size
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (planet.magnitude != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AstroColors.starGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AstroColors.starGold.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            "Mag ${planet.magnitude! >= 0 ? '+' : ''}${planet.magnitude!.toStringAsFixed(1)}",
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AstroColors.starGold,
                            ),
                          ),
                        ),
                      if (planet.majorAxisArcmin != null && planet.majorAxisArcmin! > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          planet.majorAxisArcmin! >= 1.0
                              ? "${planet.majorAxisArcmin!.toStringAsFixed(1)}'"
                              : "${(planet.majorAxisArcmin! * 60).toStringAsFixed(1)}\"",
                          style: TextStyle(
                            fontSize: 11,
                            color: textColor.withValues(alpha: 0.6),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Visibility Metrics Row
              Row(
                children: [
                  _buildMetricPill(
                    Icons.trending_up_rounded,
                    "${planet.peakAltitudeDeg.round()}° peak",
                    planet.peakAltitudeDeg >= 30.0 ? accentColor : textColor.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    Icons.timer_outlined,
                    "${planet.visibleDurationHours.toStringAsFixed(1)}h visible",
                    planet.visibleDurationHours > 0 ? AstroColors.deepSkyTeal : textColor.withValues(alpha: 0.5),
                  ),
                  const SizedBox(width: 8),
                  _buildMetricPill(
                    Icons.explore_outlined,
                    "${planet.transitTime.toLocal().hour.toString().padLeft(2, '0')}:${planet.transitTime.toLocal().minute.toString().padLeft(2, '0')} transit",
                    textColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Observable Night Window Progress Bar
              if (planet.visibleDurationHours > 0)
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (planet.visibleDurationHours / 10.0).clamp(0.05, 1.0),
                    backgroundColor: widget.isRedNightMode
                        ? AstroColors.nightVisionSurfaceVariant
                        : AstroColors.spaceDarkSurfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      planet.meetsCriteria ? accentColor : Colors.amber,
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
