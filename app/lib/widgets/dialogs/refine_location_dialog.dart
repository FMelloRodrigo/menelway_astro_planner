import 'package:flutter/material.dart';

import '../../core/geocoding_service.dart';
import '../../theme/astro_theme.dart';

class RefineLocationDialog extends StatefulWidget {
  final bool isRedNightMode;
  final String initialLocationName;
  final double initialLat;
  final double initialLon;
  final double initialElevation;
  final void Function(String locName, double lat, double lon, double ele, bool rescan) onApply;

  const RefineLocationDialog({super.key, 
    required this.isRedNightMode,
    required this.initialLocationName,
    required this.initialLat,
    required this.initialLon,
    required this.initialElevation,
    required this.onApply,
  });

  @override
  State<RefineLocationDialog> createState() => _RefineLocationDialogState();
}

class _RefineLocationDialogState extends State<RefineLocationDialog> {
  late final TextEditingController _searchCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lonCtrl;
  late final TextEditingController _eleCtrl;
  late String _locName;
  List<GeoLocationResult> _results = [];
  bool _isSearching = false;
  String? _searchError;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    _latCtrl = TextEditingController(text: widget.initialLat.toStringAsFixed(4));
    _lonCtrl = TextEditingController(text: widget.initialLon.toStringAsFixed(4));
    _eleCtrl = TextEditingController(text: widget.initialElevation.round().toString());
    _locName = widget.initialLocationName;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    _eleCtrl.dispose();
    super.dispose();
  }

  Future<void> _doSearch() async {
    final q = _searchCtrl.text.trim();
    if (q.length < 2) return;
    setState(() {
      _isSearching = true;
      _searchError = null;
    });
    try {
      final res = await GeocodingService.searchPreciseAddress(q);
      if (!mounted) return;
      setState(() {
        _results = res;
        _isSearching = false;
        if (res.isEmpty) {
          _searchError = "No matching street or neighborhood found for '$q'.";
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = "Connection error. Check internet connection.";
      });
    }
  }

  void _apply({required bool rescan}) {
    final lat = double.tryParse(_latCtrl.text) ?? widget.initialLat;
    final lon = double.tryParse(_lonCtrl.text) ?? widget.initialLon;
    final ele = double.tryParse(_eleCtrl.text) ?? widget.initialElevation;
    Navigator.of(context).pop();
    widget.onApply(_locName, lat, lon, ele, rescan);
  }

  @override
  Widget build(BuildContext context) {
    final palette = AstroPalette.of(context);
    final textColor = palette.textPrimary;
    final accentColor = palette.accent;
    final isNarrow = MediaQuery.of(context).size.width < 600;

    return AlertDialog(
      backgroundColor: palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: palette.border,
        ),
      ),
      insetPadding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 12 : 40,
        vertical: isNarrow ? 16 : 24,
      ),
      title: Row(
        children: [
          Icon(Icons.pin_drop_rounded, color: accentColor, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              "Refine Observer Location",
              style: TextStyle(color: textColor, fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
          IconButton(
            icon: Icon(Icons.close_rounded, color: textColor.withValues(alpha: 0.6)),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Pinpointing your exact observing site (street, neighborhood, or rural site) ensures mountain viewshed raymarching matches your visual horizon.",
                style: TextStyle(fontSize: 12, height: 1.3, color: textColor.withValues(alpha: 0.7)),
              ),
              const SizedBox(height: 12),
              Text(
                "Search Street / Neighborhood / Landmark:",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor),
              ),
              const SizedBox(height: 6),
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: "Detailed address, usually street name is enough to get a precise location",
                  prefixIcon: const Icon(Icons.search_rounded, size: 18),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                    tooltip: "Search address worldwide",
                    onPressed: _doSearch,
                  ),
                ),
                onSubmitted: (_) => _doSearch(),
              ),
              if (_isSearching) ...[
                const SizedBox(height: 6),
                const LinearProgressIndicator(),
              ],
              if (_searchError != null) ...[
                const SizedBox(height: 6),
                Text(_searchError!, style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6))),
              ],
              if (_results.isNotEmpty) ...[
                const SizedBox(height: 6),
                Container(
                  constraints: const BoxConstraints(maxHeight: 160),
                  decoration: BoxDecoration(
                    color: palette.surfaceVariant,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: palette.border,
                    ),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (int idx = 0; idx < _results.length; idx++) ...[
                          if (idx > 0) const Divider(height: 1),
                          ListTile(
                            dense: true,
                            leading: Icon(Icons.location_on_outlined, size: 16, color: accentColor),
                            title: Text(_results[idx].displayName, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor)),
                            subtitle: Text(
                              "Lat: ${_results[idx].latitude.toStringAsFixed(4)}° | Lon: ${_results[idx].longitude.toStringAsFixed(4)}°",
                              style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6)),
                            ),
                            onTap: () async {
                              final r = _results[idx];
                              setState(() {
                                _latCtrl.text = r.latitude.toStringAsFixed(4);
                                _lonCtrl.text = r.longitude.toStringAsFixed(4);
                                _locName = r.displayName;
                                _results = [];
                              });
                              final elev = await GeocodingService.fetchElevation(r.latitude, r.longitude);
                              if (elev != null && mounted) {
                                setState(() {
                                  _eleCtrl.text = elev.round().toString();
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
              const SizedBox(height: 12),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                "Exact Coordinates & Elevation (Meters):",
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor.withValues(alpha: 0.8)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: "Latitude (°)"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _lonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: "Longitude (°)"),
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 90,
                    child: TextField(
                      controller: _eleCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: "Elev (m)"),
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
          child: const Text("Cancel"),
        ),
        OutlinedButton(
          onPressed: () => _apply(rescan: false),
          child: const Text("Apply Location"),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: widget.isRedNightMode ? Colors.white : Colors.black,
          ),
          icon: const Icon(Icons.radar_rounded, size: 16),
          label: const Text("Apply & Re-scan Mountains", style: TextStyle(fontWeight: FontWeight.bold)),
          onPressed: () => _apply(rescan: true),
        ),
      ],
    );
  }
}
