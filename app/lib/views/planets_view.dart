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

  Color _getPlanetColor(String name, AstroPalette palette) {
    if (palette.isRedNightMode) return palette.accent;
    switch (name) {
      case 'Sun':
        return palette.starGold;
      case 'Moon':
        return const Color(0xFFE2E8F0);
      case 'Mars':
        return const Color(0xFFEF4444);
      case 'Jupiter':
        return const Color(0xFFF59E0B);
      case 'Saturn':
        return const Color(0xFFD97706);
      case 'Venus':
        return const Color(0xFFFDE68A);
      case 'Mercury':
        return const Color(0xFF94A3B8);
      case 'Uranus':
        return palette.starlightCyan;
      case 'Neptune':
        return palette.nebulaIndigo;
      default:
        return palette.accent;
    }
  }

  void _onPlanetSelected(TargetItem planet, bool isWide) {
    if (isWide) {
      setState(() => _selectedPlanet = planet);
    } else {
      TargetDetailsSheet.show(
        context,
        target: planet,
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
    final displayPlanets = _sortedPlanets;

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
                hintText: "Search planet or moon (e.g. Jupiter, Saturn, Mars)...",
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
                child: DropdownButton<PlanetSortMode>(
                  value: _sortMode,
                  dropdownColor: palette.surfaceVariant,
                  icon: Icon(Icons.sort_rounded, size: 18, color: palette.accent),
                  style: TextStyle(color: palette.text, fontSize: 13, fontWeight: FontWeight.w600),
                  items: [
                    DropdownMenuItem(value: PlanetSortMode.orderFromSun, child: Text(l10n.sortOrderFromSun)),
                    DropdownMenuItem(value: PlanetSortMode.brightness, child: Text(l10n.sortBrightness)),
                    DropdownMenuItem(value: PlanetSortMode.peakAltitude, child: Text(l10n.sortPeakAltitude)),
                    DropdownMenuItem(value: PlanetSortMode.visibleDuration, child: Text(l10n.sortVisibleDuration)),
                    DropdownMenuItem(value: PlanetSortMode.transitTime, child: Text(l10n.sortTransitTime)),
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
              InfoChip(label: "Solar System", icon: Icons.public_rounded, color: palette.accent),
              const SizedBox(width: 6),
              InfoChip(
                label: "${displayPlanets.length} bodies evaluated",
                icon: Icons.filter_tilt_shift_rounded,
                color: palette.text,
              ),
              const SizedBox(width: 6),
              InfoChip(label: "Real-time Ephemeris", icon: Icons.auto_awesome_rounded, color: palette.starGold),
            ],
          ),
        ),
      ],
    );

    return TargetListScaffold<TargetItem>(
      items: displayPlanets,
      selectedItem: _selectedPlanet,
      isLoading: widget.isLoading,
      header: header,
      onItemSelected: (planet) => _onPlanetSelected(planet, isWide),
      emptyState: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.public_off_rounded, size: 48, color: palette.text.withValues(alpha: 0.3)),
            const SizedBox(height: 12),
            Text(
              "No planets match your search.",
              style: TextStyle(fontSize: 16, color: palette.text.withValues(alpha: 0.6)),
            ),
          ],
        ),
      ),
      itemBuilder: (context, planet, isSelected) => _buildPlanetCard(planet, isSelected, isWide),
      detailBuilder: (context, planet) => TargetDetailsSheet(
        target: planet,
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
    );
  }

  Widget _buildPlanetCard(TargetItem planet, bool isSelected, bool isWide) {
    final palette = AstroPalette.of(context);
    final textColor = palette.text;
    final accentColor = palette.accent;
    final planetColor = _getPlanetColor(planet.name, palette);

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
        onTap: () => _onPlanetSelected(planet, isWide),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (planet.magnitude != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: palette.starGold.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: palette.starGold.withValues(alpha: 0.4)),
                          ),
                          child: Text(
                            "Mag ${planet.magnitude! > 0 ? '+' : ''}${planet.magnitude!.toStringAsFixed(1)}",
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: palette.starGold,
                            ),
                          ),
                        ),
                      if (planet.majorAxisArcmin != null && planet.majorAxisArcmin! > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          planet.majorAxisArcmin! < 1.0
                              ? "${(planet.majorAxisArcmin! * 60).toStringAsFixed(1)}\""
                              : "${planet.majorAxisArcmin!.toStringAsFixed(1)}'",
                          style: TextStyle(
                            fontSize: 10,
                            color: textColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ],
                    ],
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
                    label: "${planet.peakAltitudeDeg.toStringAsFixed(1)}° peak",
                    color: planet.peakAltitudeDeg >= widget.filters.minAltitude
                        ? palette.visibleGreen
                        : textColor.withValues(alpha: 0.5),
                  ),
                  MetricPill(
                    icon: Icons.timer_outlined,
                    label: "${planet.visibleDurationHours.toStringAsFixed(1)} hrs",
                    color: planet.visibleDurationHours > 0 ? palette.deepSkyTeal : textColor.withValues(alpha: 0.5),
                  ),
                  MetricPill(
                    icon: Icons.explore_outlined,
                    label:
                        "${planet.transitTime.toLocal().hour.toString().padLeft(2, '0')}:${planet.transitTime.toLocal().minute.toString().padLeft(2, '0')} transit",
                    color: textColor.withValues(alpha: 0.7),
                  ),
                ],
              ),
              if (planet.visibleDurationHours > 0) ...[
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (planet.visibleDurationHours / 10.0).clamp(0.05, 1.0),
                    backgroundColor: palette.surfaceVariant,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      planet.meetsCriteria ? accentColor : Colors.amber,
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
