import 'package:flutter/material.dart';
import '../core/geocoding_service.dart';
import '../l10n/app_localizations.dart';
import '../theme/astro_theme.dart';

/// Modal dialog allowing the observer to set their geographical coordinates,
/// elevation, and location name via city search, street address search, or manual input.
class ObserverLocationDialog extends StatefulWidget {
  final double initialLat;
  final double initialLon;
  final double initialElevation;
  final String initialLocationName;
  final bool isRedNightMode;
  final void Function(double lat, double lon, double elevation, String locationName) onLocationApplied;

  const ObserverLocationDialog({
    super.key,
    required this.initialLat,
    required this.initialLon,
    required this.initialElevation,
    required this.initialLocationName,
    required this.isRedNightMode,
    required this.onLocationApplied,
  });

  @override
  State<ObserverLocationDialog> createState() => _ObserverLocationDialogState();
}

class _ObserverLocationDialogState extends State<ObserverLocationDialog> {
  late final TextEditingController _searchController;
  late final TextEditingController _latController;
  late final TextEditingController _lonController;
  late final TextEditingController _eleController;
  late final TextEditingController _addressController;

  late String _currentLocationName;
  List<GeoLocationResult> _searchResults = [];
  bool _isSearching = false;
  String? _searchError;

  bool _isAddressSearchExpanded = false;
  List<GeoLocationResult> _addressResults = [];
  bool _isSearchingAddress = false;
  String? _addressError;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    _latController = TextEditingController(text: widget.initialLat.toStringAsFixed(4));
    _lonController = TextEditingController(text: widget.initialLon.toStringAsFixed(4));
    _eleController = TextEditingController(text: widget.initialElevation.round().toString());
    _addressController = TextEditingController();
    _currentLocationName = widget.initialLocationName;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _eleController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _doSearch(AppLocalizations? l10n) async {
    final q = _searchController.text.trim();
    if (q.length < 2) return;

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final results = await GeocodingService.searchCities(q);
      if (!mounted) return;
      setState(() {
        _searchResults = results;
        _isSearching = false;
        if (results.isEmpty) {
          _searchError = l10n?.locationNotFound(q) ?? "No matching cities found for '$q'.";
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = l10n?.connectionError ?? "Connection error. Check internet connection.";
      });
    }
  }

  Future<void> _doAddressSearch() async {
    final q = _addressController.text.trim();
    if (q.length < 2) return;

    setState(() {
      _isSearchingAddress = true;
      _addressError = null;
    });

    try {
      final results = await GeocodingService.searchPreciseAddress(q);
      if (!mounted) return;
      setState(() {
        _addressResults = results;
        _isSearchingAddress = false;
        if (results.isEmpty) {
          _addressError = "No matching street or neighborhood found for '$q'.";
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSearchingAddress = false;
        _addressError = "Connection error. Check internet connection.";
      });
    }
  }

  void _applyAndClose() {
    final newLat = double.tryParse(_latController.text) ?? widget.initialLat;
    final newLon = double.tryParse(_lonController.text) ?? widget.initialLon;
    final newEle = double.tryParse(_eleController.text) ?? widget.initialElevation;

    widget.onLocationApplied(newLat, newLon, newEle, _currentLocationName);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      backgroundColor: widget.isRedNightMode
          ? AstroColors.nightVisionSurface
          : AstroColors.spaceDarkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder,
        ),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 40,
        vertical: isNarrow ? 16 : 24,
      ),
      title: Row(
        children: [
          Icon(Icons.location_city_rounded, color: accentColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n?.locationEditTitle ?? "Observer Location",
              style: TextStyle(
                color: textColor,
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Tooltip(
            message: l10n?.closeBtn ?? "Close",
            child: InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionSurfaceVariant
                      : const Color(0xFF222F42),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: widget.isRedNightMode
                        ? AstroColors.nightVisionBorder
                        : Colors.white.withValues(alpha: 0.3),
                    width: 1.4,
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  size: 18,
                  color: widget.isRedNightMode
                      ? AstroColors.nightVisionRed
                      : Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Search Field (City / Worldwide)
              TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: l10n?.searchCityHint ?? "Search city worldwide...",
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded),
                    tooltip: l10n?.searchOnlineTooltip ?? "Search online",
                    onPressed: () => _doSearch(l10n),
                  ),
                ),
                onSubmitted: (_) => _doSearch(l10n),
              ),
              if (_isSearching) ...[
                const SizedBox(height: 6),
                const LinearProgressIndicator(),
              ],
              if (_searchError != null) ...[
                const SizedBox(height: 6),
                Text(
                  _searchError!,
                  style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                ),
              ],
              if (_searchResults.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 180),
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
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int idx = 0; idx < _searchResults.length; idx++) ...[
                          if (idx > 0) const Divider(height: 1),
                          ListTile(
                            dense: true,
                            title: Text(
                              _searchResults[idx].displayName,
                              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: textColor),
                            ),
                            subtitle: Text(
                              l10n?.searchResultSubtitle(
                                    _searchResults[idx].latitude.toStringAsFixed(2),
                                    _searchResults[idx].longitude.toStringAsFixed(2),
                                    _searchResults[idx].elevation.round().toString(),
                                  ) ??
                                  "Lat: ${_searchResults[idx].latitude.toStringAsFixed(2)}° | Lon: ${_searchResults[idx].longitude.toStringAsFixed(2)}° | Ele: ${_searchResults[idx].elevation.round()}m",
                              style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.7)),
                            ),
                            trailing: Icon(Icons.check_circle_outline_rounded, size: 18, color: accentColor),
                            onTap: () {
                              setState(() {
                                _latController.text = _searchResults[idx].latitude.toStringAsFixed(4);
                                _lonController.text = _searchResults[idx].longitude.toStringAsFixed(4);
                                _eleController.text = _searchResults[idx].elevation.round().toString();
                                _currentLocationName = _searchResults[idx].displayName;
                                _searchResults = [];
                              });
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 10),

              // Expandable Precise Address / Street search
              InkWell(
                onTap: () => setState(() => _isAddressSearchExpanded = !_isAddressSearchExpanded),
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      Icon(
                        _isAddressSearchExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                        size: 16,
                        color: accentColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        l10n?.searchAddressTooltip ?? "Search specific street / neighborhood (optional)",
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: accentColor),
                      ),
                    ],
                  ),
                ),
              ),
              if (_isAddressSearchExpanded) ...[
                const SizedBox(height: 6),
                TextField(
                  controller: _addressController,
                  decoration: InputDecoration(
                    hintText: l10n?.searchAddressHint ?? "Type the detailed location, like street name, and city",
                    prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                      tooltip: l10n?.searchAddressTooltip ?? "Search precise street/neighborhood (worldwide)",
                      onPressed: _doAddressSearch,
                    ),
                  ),
                  onSubmitted: (_) => _doAddressSearch(),
                ),
                if (_isSearchingAddress) ...[
                  const SizedBox(height: 6),
                  const LinearProgressIndicator(),
                ],
                if (_addressError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _addressError!,
                    style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6)),
                  ),
                ],
                if (_addressResults.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Container(
                    constraints: const BoxConstraints(maxHeight: 180),
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
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (int idx = 0; idx < _addressResults.length; idx++) ...[
                            if (idx > 0) const Divider(height: 1),
                            ListTile(
                              dense: true,
                              leading: Icon(Icons.pin_drop_rounded, size: 18, color: accentColor),
                              title: Text(
                                _addressResults[idx].displayName,
                                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: textColor),
                              ),
                              subtitle: Text(
                                "Lat: ${_addressResults[idx].latitude.toStringAsFixed(4)}° | Lon: ${_addressResults[idx].longitude.toStringAsFixed(4)}°",
                                style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
                              ),
                              trailing: Icon(Icons.check_circle_outline_rounded, size: 16, color: accentColor),
                              onTap: () async {
                                final r = _addressResults[idx];
                                setState(() {
                                  _latController.text = r.latitude.toStringAsFixed(4);
                                  _lonController.text = r.longitude.toStringAsFixed(4);
                                  _currentLocationName = r.displayName;
                                  _addressResults = [];
                                });
                                // Auto-fetch precise elevation
                                final elev = await GeocodingService.fetchElevation(r.latitude, r.longitude);
                                if (elev != null && mounted) {
                                  setState(() {
                                    _eleController.text = elev.round().toString();
                                  });
                                }
                              },
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),

              // Manual Coordinates Section
              Row(
                children: [
                  Icon(Icons.tune_rounded, size: 14, color: textColor.withValues(alpha: 0.6)),
                  const SizedBox(width: 4),
                  Text(
                    l10n?.selectedCoordsElevation ?? "Selected Coordinates & Elevation",
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: textColor.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latController,
                      decoration: InputDecoration(labelText: l10n?.latitude ?? "Latitude (°)"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lonController,
                      decoration: InputDecoration(labelText: l10n?.longitude ?? "Longitude (°)"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _eleController,
                      decoration: InputDecoration(labelText: l10n?.elevation ?? "Elevation (m)"),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n?.cancel ?? "Cancel"),
        ),
        FilledButton(
          onPressed: _applyAndClose,
          child: Text(l10n?.applyLocation ?? "Apply Location"),
        ),
      ],
    );
  }
}
