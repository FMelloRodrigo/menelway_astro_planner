import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../core/geocoding_service.dart';
import '../core/observing_site_manager.dart';
import '../l10n/app_localizations.dart';
import '../models/observing_site.dart';
import '../theme/astro_theme.dart';

/// Modal dialog allowing the observer to view, switch, add, edit, and delete
/// observing sites, complete with an interactive Visual Bortle Darkness Selector.
class ObservingSitesDialog extends StatefulWidget {
  final bool isRedNightMode;
  final String? initialEditSiteId;
  final bool startInAddMode;
  final void Function(ObservingSite activeSite)? onActiveSiteChanged;

  const ObservingSitesDialog({
    super.key,
    required this.isRedNightMode,
    this.initialEditSiteId,
    this.startInAddMode = false,
    this.onActiveSiteChanged,
  });

  @override
  State<ObservingSitesDialog> createState() => _ObservingSitesDialogState();
}

enum _DialogMode { list, edit }

class _ObservingSitesDialogState extends State<ObservingSitesDialog> {
  late _DialogMode _mode;
  String? _editingSiteId;

  // Controllers for Editor
  final _nameController = TextEditingController();
  final _latController = TextEditingController();
  final _lonController = TextEditingController();
  final _eleController = TextEditingController();
  final _notesController = TextEditingController();

  // Bortle Scale State
  int _bortleClass = 4;

  // Search Controllers & State
  final _searchController = TextEditingController();
  final _addressController = TextEditingController();
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
    if (widget.startInAddMode) {
      _mode = _DialogMode.edit;
      _editingSiteId = null;
      _initEditorWithDefaults();
    } else if (widget.initialEditSiteId != null) {
      final site = ObservingSiteManager.instance.sites.firstWhere(
        (s) => s.id == widget.initialEditSiteId,
        orElse: () => ObservingSiteManager.instance.activeSite,
      );
      _mode = _DialogMode.edit;
      _editingSiteId = site.id;
      _initEditorWithSite(site);
    } else {
      _mode = _DialogMode.list;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _latController.dispose();
    _lonController.dispose();
    _eleController.dispose();
    _notesController.dispose();
    _searchController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  void _initEditorWithDefaults() {
    final active = ObservingSiteManager.instance.activeSite;
    _nameController.text = '';
    _latController.text = active.latitude.toStringAsFixed(4);
    _lonController.text = active.longitude.toStringAsFixed(4);
    _eleController.text = active.elevation.round().toString();
    _notesController.text = '';
    _bortleClass = active.bortleClass;
    _clearSearch();
  }

  void _initEditorWithSite(ObservingSite site) {
    _nameController.text = site.name;
    _latController.text = site.latitude.toStringAsFixed(4);
    _lonController.text = site.longitude.toStringAsFixed(4);
    _eleController.text = site.elevation.round().toString();
    _notesController.text = site.notes;
    _bortleClass = site.bortleClass;
    _clearSearch();
  }

  void _clearSearch() {
    _searchController.clear();
    _addressController.clear();
    _searchResults = [];
    _addressResults = [];
    _isSearching = false;
    _isSearchingAddress = false;
    _searchError = null;
    _addressError = null;
  }

  Future<void> _doCitySearch(AppLocalizations? l10n) async {
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
          _addressError = "No matching addresses found for '$q'.";
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

  void _saveSite() {
    final l10n = AppLocalizations.of(context);
    final rawName = _nameController.text.trim();
    final name = rawName.isNotEmpty ? rawName : (l10n?.siteName ?? 'Observing Site');

    final lat = (double.tryParse(_latController.text.replaceAll(',', '.')) ?? -22.2819)
        .clamp(ObservingSite.minLatitude, ObservingSite.maxLatitude);
    final lon = (double.tryParse(_lonController.text.replaceAll(',', '.')) ?? -42.5311)
        .clamp(ObservingSite.minLongitude, ObservingSite.maxLongitude);
    final ele = (double.tryParse(_eleController.text.replaceAll(',', '.')) ?? 858.0)
        .clamp(ObservingSite.minElevation, ObservingSite.maxElevation);

    final siteId = _editingSiteId ?? 'site_${DateTime.now().millisecondsSinceEpoch}';
    final isNew = _editingSiteId == null;

    final site = ObservingSite(
      id: siteId,
      name: name,
      latitude: lat,
      longitude: lon,
      elevation: ele,
      bortleClass: _bortleClass,
      notes: _notesController.text.trim(),
    );

    if (isNew) {
      ObservingSiteManager.instance.addSite(site, setAsActive: true);
    } else {
      ObservingSiteManager.instance.updateSite(site);
    }

    widget.onActiveSiteChanged?.call(ObservingSiteManager.instance.activeSite);

    setState(() {
      _mode = _DialogMode.list;
      _editingSiteId = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(l10n?.siteSaved ?? "Observing site saved."),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDeleteSite(ObservingSite site) {
    final l10n = AppLocalizations.of(context);
    if (ObservingSiteManager.instance.sites.length <= 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n?.cannotDeleteLastSite ?? "You must keep at least one observing site."),
          backgroundColor: Colors.orangeAccent,
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l10n?.deleteSite ?? "Delete Site"),
        content: Text("${l10n?.deleteSiteConfirm ?? "Are you sure you want to delete this observing site?"}\n\n\"${site.name}\""),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(l10n?.cancel ?? "Cancel"),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () {
              Navigator.of(ctx).pop();
              final wasActive = ObservingSiteManager.instance.activeSiteId == site.id;
              ObservingSiteManager.instance.deleteSite(site.id);
              if (wasActive) {
                widget.onActiveSiteChanged?.call(ObservingSiteManager.instance.activeSite);
              }
              setState(() {});
            },
            child: Text(l10n?.deleteSite ?? "Delete"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final textColor = widget.isRedNightMode ? AstroColors.nightVisionRed : Colors.white;
    final accentColor = widget.isRedNightMode ? AstroColors.nightVisionRed : AstroColors.starlightCyan;
    final surfaceColor = widget.isRedNightMode ? AstroColors.nightVisionSurface : AstroColors.spaceDarkSurface;
    final borderColor = widget.isRedNightMode ? AstroColors.nightVisionBorder : AstroColors.spaceDarkBorder;

    return Dialog(
      backgroundColor: surfaceColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580, maxHeight: 720),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              _buildHeader(l10n, textColor, accentColor),
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 14),

              // Content Body
              Expanded(
                child: _mode == _DialogMode.list
                    ? _buildListView(l10n, textColor, accentColor, borderColor)
                    : _buildEditorView(l10n, textColor, accentColor, borderColor),
              ),

              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),

              // Footer Actions
              _buildFooterActions(l10n, accentColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations? l10n, Color textColor, Color accentColor) {
    return Row(
      children: [
        Icon(
          _mode == _DialogMode.list ? Icons.location_city_rounded : Icons.edit_location_alt_rounded,
          color: accentColor,
          size: 24,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            _mode == _DialogMode.list
                ? (l10n?.observingSites ?? "Observing Sites")
                : (_editingSiteId == null
                    ? (l10n?.addNewSite ?? "Add New Site")
                    : (l10n?.editSite ?? "Edit Site")),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        ),
        if (_mode == _DialogMode.list)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              backgroundColor: widget.isRedNightMode
                  ? AstroColors.nightVisionRed.withValues(alpha: 0.2)
                  : AstroColors.starlightCyan.withValues(alpha: 0.15),
              foregroundColor: accentColor,
              side: BorderSide(color: accentColor.withValues(alpha: 0.6)),
            ),
            icon: const Icon(Icons.add_location_alt_rounded, size: 16),
            label: Text(l10n?.addNewSite ?? "Add Site", style: const TextStyle(fontSize: 12)),
            onPressed: () {
              setState(() {
                _mode = _DialogMode.edit;
                _editingSiteId = null;
                _initEditorWithDefaults();
              });
            },
          )
        else
          IconButton(
            tooltip: l10n?.cancel ?? "Back to List",
            icon: const Icon(Icons.arrow_back_rounded),
            color: textColor.withValues(alpha: 0.7),
            onPressed: () {
              setState(() {
                _mode = _DialogMode.list;
                _editingSiteId = null;
              });
            },
          ),
      ],
    );
  }

  // -------------------------------------------------------------
  // LIST VIEW: ALL OBSERVING SITES
  // -------------------------------------------------------------
  Widget _buildListView(AppLocalizations? l10n, Color textColor, Color accentColor, Color borderColor) {
    final sites = ObservingSiteManager.instance.sites;
    final activeId = ObservingSiteManager.instance.activeSiteId;

    return ListView.separated(
      itemCount: sites.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (ctx, index) {
        final site = sites[index];
        final isActive = site.id == activeId;
        final bortle = site.bortleInfo;

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isActive
                ? (widget.isRedNightMode
                    ? AstroColors.nightVisionRed.withValues(alpha: 0.12)
                    : AstroColors.starlightCyan.withValues(alpha: 0.08))
                : (widget.isRedNightMode
                    ? AstroColors.nightVisionSurfaceVariant
                    : AstroColors.spaceDarkSurfaceVariant),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isActive ? accentColor : borderColor,
              width: isActive ? 1.6 : 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Active Radio / Icon
                  InkWell(
                    onTap: () {
                      ObservingSiteManager.instance.setActiveSite(site.id);
                      widget.onActiveSiteChanged?.call(site);
                      setState(() {});
                    },
                    borderRadius: BorderRadius.circular(20),
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(
                        isActive ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                        color: isActive ? accentColor : textColor.withValues(alpha: 0.4),
                        size: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Site Details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                site.name,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: textColor,
                                ),
                              ),
                            ),
                            if (isActive)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                margin: const EdgeInsets.only(left: 6),
                                decoration: BoxDecoration(
                                  color: accentColor.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: accentColor.withValues(alpha: 0.5)),
                                ),
                                child: Text(
                                  l10n?.activeSite ?? "Active",
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: accentColor,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),

                        // Coordinates and Elevation
                        Text(
                          site.coordinatesFormatted,
                          style: TextStyle(
                            fontSize: 12,
                            color: textColor.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Bortle Darkness Pill
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: bortle.color.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: bortle.color, width: 1.2),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: bortle.color,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Flexible(
                                child: Text(
                                  "Bortle ${site.bortleClass} • ${bortle.title}",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: textColor.withValues(alpha: 0.95),
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),

                        if (site.notes.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text(
                            site.notes,
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: textColor.withValues(alpha: 0.55),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  // Actions: Edit and Delete
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: l10n?.editSite ?? "Edit Site",
                        color: textColor.withValues(alpha: 0.7),
                        onPressed: () {
                          setState(() {
                            _mode = _DialogMode.edit;
                            _editingSiteId = site.id;
                            _initEditorWithSite(site);
                          });
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        tooltip: l10n?.deleteSite ?? "Delete Site",
                        color: sites.length > 1 ? Colors.redAccent.withValues(alpha: 0.8) : textColor.withValues(alpha: 0.2),
                        onPressed: sites.length > 1 ? () => _confirmDeleteSite(site) : null,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // -------------------------------------------------------------
  // EDITOR VIEW: ADD OR EDIT OBSERVING SITE
  // -------------------------------------------------------------
  Widget _buildEditorView(AppLocalizations? l10n, Color textColor, Color accentColor, Color borderColor) {
    final bortleInfo = BortleInfo.get(_bortleClass);
    // Dynamic derivation of slider divisions according to Engineering Standards
    final bortleDivisions = math.max(1, ((ObservingSite.maxBortle - ObservingSite.minBortle) / 1).round());

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Site Name
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n?.siteName ?? "Site Name",
              hintText: "e.g. Home Backyard, Dark Sky Mountain Camp",
              prefixIcon: const Icon(Icons.label_outline_rounded, size: 18),
            ),
          ),
          const SizedBox(height: 14),

          // Online City Search
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: l10n?.searchCityOnline ?? "Search City & Country (Online)",
                    hintText: l10n?.searchCityHint ?? "Type city",
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _isSearching
                        ? const Padding(
                            padding: EdgeInsets.all(10),
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        : IconButton(
                            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                            tooltip: l10n?.searchOnlineTooltip ?? "Search online",
                            onPressed: () => _doCitySearch(l10n),
                          ),
                  ),
                  onSubmitted: (_) => _doCitySearch(l10n),
                ),
              ),
            ],
          ),

          if (_searchError != null) ...[
            const SizedBox(height: 6),
            Text(
              _searchError!,
              style: TextStyle(fontSize: 12, color: textColor.withValues(alpha: 0.6)),
            ),
          ],

          if (_searchResults.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              constraints: const BoxConstraints(maxHeight: 160),
              decoration: BoxDecoration(
                color: widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: borderColor),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: _searchResults.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (ctx, idx) {
                  final item = _searchResults[idx];
                  return ListTile(
                    dense: true,
                    title: Text(
                      item.displayName,
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: textColor),
                    ),
                    subtitle: Text(
                      "Lat: ${item.latitude.toStringAsFixed(2)}° | Lon: ${item.longitude.toStringAsFixed(2)}° | Ele: ${item.elevation.round()}m",
                      style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
                    ),
                    trailing: Icon(Icons.check_circle_outline_rounded, size: 16, color: accentColor),
                    onTap: () {
                      setState(() {
                        _nameController.text = item.displayName.split(',').first.trim();
                        _latController.text = item.latitude.toStringAsFixed(4);
                        _lonController.text = item.longitude.toStringAsFixed(4);
                        _eleController.text = item.elevation.round().toString();
                        _searchResults = [];
                      });
                    },
                  );
                },
              ),
            ),
          ],

          const SizedBox(height: 10),

          // Expandable Address Search
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
                hintText: l10n?.searchAddressHint ?? "Type street name, neighborhood, city",
                prefixIcon: const Icon(Icons.pin_drop_outlined, size: 18),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                  onPressed: _doAddressSearch,
                ),
              ),
              onSubmitted: (_) => _doAddressSearch(),
            ),
            if (_isSearchingAddress) ...[
              const SizedBox(height: 4),
              const LinearProgressIndicator(),
            ],
            if (_addressError != null) ...[
              const SizedBox(height: 4),
              Text(_addressError!, style: TextStyle(fontSize: 11, color: textColor.withValues(alpha: 0.6))),
            ],
            if (_addressResults.isNotEmpty) ...[
              const SizedBox(height: 6),
              Container(
                constraints: const BoxConstraints(maxHeight: 140),
                decoration: BoxDecoration(
                  color: widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: borderColor),
                ),
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _addressResults.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, idx) {
                    final item = _addressResults[idx];
                    return ListTile(
                      dense: true,
                      leading: Icon(Icons.pin_drop_rounded, size: 16, color: accentColor),
                      title: Text(item.displayName, style: TextStyle(fontSize: 11, color: textColor)),
                      subtitle: Text("Lat: ${item.latitude.toStringAsFixed(4)}° | Lon: ${item.longitude.toStringAsFixed(4)}°",
                          style: TextStyle(fontSize: 10, color: textColor.withValues(alpha: 0.6))),
                      trailing: Icon(Icons.check_circle_outline_rounded, size: 16, color: accentColor),
                      onTap: () async {
                        setState(() {
                          _nameController.text = item.displayName.split(',').first.trim();
                          _latController.text = item.latitude.toStringAsFixed(4);
                          _lonController.text = item.longitude.toStringAsFixed(4);
                          _addressResults = [];
                        });
                        final elev = await GeocodingService.fetchElevation(item.latitude, item.longitude);
                        if (elev != null && mounted) {
                          setState(() {
                            _eleController.text = elev.round().toString();
                          });
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ],

          const SizedBox(height: 14),

          // Coordinates & Elevation Row
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _latController,
                  decoration: InputDecoration(
                    labelText: l10n?.latitude ?? "Latitude (°)",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _lonController,
                  decoration: InputDecoration(
                    labelText: l10n?.longitude ?? "Longitude (°)",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _eleController,
                  decoration: InputDecoration(
                    labelText: l10n?.elevation ?? "Elevation (m)",
                  ),
                  keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // -------------------------------------------------------------
          // VISUAL BORTLE SELECTOR (1 to 9)
          // -------------------------------------------------------------
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: widget.isRedNightMode ? AstroColors.nightVisionSurfaceVariant : AstroColors.spaceDarkSurfaceVariant,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.brightness_medium_rounded, size: 16, color: accentColor),
                        const SizedBox(width: 6),
                        Text(
                          l10n?.bortleDarkness ?? "Bortle Sky Darkness",
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                    Text(
                      "SQM: ${bortleInfo.sqmRange} mag/arcsec²",
                      style: TextStyle(
                        fontSize: 11,
                        color: textColor.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Large Preview Pill
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: bortleInfo.color.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: bortleInfo.color, width: 1.8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 14,
                            height: 14,
                            decoration: BoxDecoration(
                              color: bortleInfo.color,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              "Class $_bortleClass: ${bortleInfo.title}",
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        bortleInfo.description,
                        style: TextStyle(
                          fontSize: 11,
                          color: textColor.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Interactive Slider
                SliderTheme(
                  data: SliderTheme.of(context).copyWith(
                    activeTrackColor: bortleInfo.color,
                    inactiveTrackColor: textColor.withValues(alpha: 0.2),
                    thumbColor: bortleInfo.color,
                    overlayColor: bortleInfo.color.withValues(alpha: 0.2),
                    tickMarkShape: const RoundSliderTickMarkShape(tickMarkRadius: 2.5),
                    activeTickMarkColor: Colors.white.withValues(alpha: 0.7),
                    inactiveTickMarkColor: textColor.withValues(alpha: 0.3),
                  ),
                  child: Slider(
                    value: _bortleClass.toDouble(),
                    min: ObservingSite.minBortle.toDouble(),
                    max: ObservingSite.maxBortle.toDouble(),
                    divisions: bortleDivisions,
                    label: "Bortle $_bortleClass",
                    onChanged: (val) {
                      setState(() {
                        _bortleClass = val.round().clamp(ObservingSite.minBortle, ObservingSite.maxBortle);
                      });
                    },
                  ),
                ),

                // Mini Color Palette Chips (Tappable 1..9)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (int b = 1; b <= 9; b++) ...[
                      InkWell(
                        onTap: () => setState(() => _bortleClass = b),
                        borderRadius: BorderRadius.circular(14),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Column(
                            children: [
                              Container(
                                width: 18,
                                height: 18,
                                decoration: BoxDecoration(
                                  color: BortleInfo.get(b).color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _bortleClass == b ? accentColor : Colors.white.withValues(alpha: 0.2),
                                    width: _bortleClass == b ? 2.2 : 1.0,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                "$b",
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: _bortleClass == b ? FontWeight.bold : FontWeight.normal,
                                  color: _bortleClass == b ? accentColor : textColor.withValues(alpha: 0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 14),

          // Optional Notes
          TextField(
            controller: _notesController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: l10n?.siteNotes ?? "Notes (Optional)",
              hintText: "e.g. Backyard with roof obstruction to the South, power outlet available",
              prefixIcon: const Icon(Icons.notes_rounded, size: 18),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterActions(AppLocalizations? l10n, Color accentColor) {
    if (_mode == _DialogMode.list) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
            ),
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n?.closeBtn ?? "Close"),
          ),
        ],
      );
    } else {
      return Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(
            onPressed: () {
              setState(() {
                _mode = _DialogMode.list;
                _editingSiteId = null;
              });
            },
            child: Text(l10n?.cancel ?? "Cancel"),
          ),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: Colors.black,
            ),
            icon: const Icon(Icons.check_rounded, size: 16),
            label: Text(l10n?.saveSite ?? "Save Site"),
            onPressed: _saveSite,
          ),
        ],
      );
    }
  }
}
