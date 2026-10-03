import 'package:flutter/foundation.dart';
import '../models/filter_state.dart';
import '../models/observing_site.dart';

/// Central state manager for observer locations and observing sites.
/// Provides reactive updates when active observing location changes.
class ObservingSiteManager extends ChangeNotifier {
  static ObservingSiteManager instance = ObservingSiteManager();

  List<ObservingSite> _sites;
  String _activeSiteId;

  ObservingSiteManager({
    List<ObservingSite>? sites,
    String? activeSiteId,
  })  : _sites = sites != null && sites.isNotEmpty
            ? List.from(sites)
            : [ObservingSite.defaultSite],
        _activeSiteId = activeSiteId ??
            (sites != null && sites.isNotEmpty
                ? sites.first.id
                : ObservingSite.defaultSite.id);

  List<ObservingSite> get sites => List.unmodifiable(_sites);
  String get activeSiteId => _activeSiteId;

  /// Returns the currently active site, falling back to the first available site or defaultSite.
  /// Pure query getter with zero state mutation side-effects.
  ObservingSite get activeSite {
    if (_sites.isEmpty) {
      return ObservingSite.defaultSite;
    }
    return _sites.firstWhere(
      (s) => s.id == _activeSiteId,
      orElse: () => _sites.first,
    );
  }

  /// Builds the default observing sites list, optionally migrating from FilterState.
  static List<ObservingSite> createDefaultSites(FilterState? fallbackFilters) {
    if (fallbackFilters != null) {
      return [
        ObservingSite(
          id: 'site_primary',
          name: fallbackFilters.observerLocationName.isNotEmpty
              ? fallbackFilters.observerLocationName
              : 'Default Site',
          latitude: fallbackFilters.observerLat,
          longitude: fallbackFilters.observerLon,
          elevation: fallbackFilters.observerElevation,
          bortleClass: 4,
        ),
      ];
    }
    return [ObservingSite.defaultSite];
  }

  /// Initializes the manager from saved settings or builds a default site from FilterState.
  void init({
    List<ObservingSite>? savedSites,
    String? savedActiveId,
    FilterState? fallbackFilters,
  }) {
    if (savedSites != null && savedSites.isNotEmpty) {
      _sites = List.from(savedSites);
    } else {
      _sites = createDefaultSites(fallbackFilters);
    }

    if (savedActiveId != null && _sites.any((s) => s.id == savedActiveId)) {
      _activeSiteId = savedActiveId;
    } else {
      _activeSiteId = _sites.first.id;
    }

    notifyListeners();
  }

  /// Sets the currently active observing site by its unique ID.
  void setActiveSite(String id) {
    if (_sites.any((s) => s.id == id)) {
      _activeSiteId = id;
      notifyListeners();
    }
  }

  /// Adds a new observing site and optionally activates it.
  void addSite(ObservingSite site, {bool setAsActive = true}) {
    _sites.add(site);
    if (setAsActive) {
      _activeSiteId = site.id;
    }
    notifyListeners();
  }

  /// Updates an existing observing site.
  void updateSite(ObservingSite site) {
    final index = _sites.indexWhere((s) => s.id == site.id);
    if (index != -1) {
      _sites[index] = site;
      notifyListeners();
    }
  }

  /// Deletes an observing site by its unique ID.
  /// Prevents deletion if only one site exists.
  bool deleteSite(String id) {
    if (_sites.length <= 1) return false;
    _sites.removeWhere((s) => s.id == id);
    if (_activeSiteId == id) {
      _activeSiteId = _sites.first.id;
    }
    notifyListeners();
    return true;
  }

  /// Resets sites to the default list or fallback filters.
  void resetToDefault({FilterState? fallbackFilters}) {
    _sites = createDefaultSites(fallbackFilters);
    _activeSiteId = _sites.first.id;
    notifyListeners();
  }
}
