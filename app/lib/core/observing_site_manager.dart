import 'package:flutter/foundation.dart';
import '../models/filter_state.dart';
import '../models/observing_site.dart';

/// Central state manager for observer locations and observing sites.
/// Provides reactive updates when active observing location changes.
class ObservingSiteManager extends ChangeNotifier {
  ObservingSiteManager._();
  static final ObservingSiteManager instance = ObservingSiteManager._();

  List<ObservingSite> _sites = [];
  String _activeSiteId = '';

  List<ObservingSite> get sites => List.unmodifiable(_sites);
  String get activeSiteId => _activeSiteId;

  /// Returns the currently active site, falling back to the first available site or defaultSite.
  ObservingSite get activeSite {
    if (_sites.isEmpty) {
      _sites = [ObservingSite.defaultSite];
      _activeSiteId = _sites.first.id;
    }
    return _sites.firstWhere(
      (s) => s.id == _activeSiteId,
      orElse: () => _sites.first,
    );
  }

  /// Initializes the manager from saved settings or builds a default site from FilterState.
  void init({
    List<ObservingSite>? savedSites,
    String? savedActiveId,
    FilterState? fallbackFilters,
  }) {
    if (savedSites != null && savedSites.isNotEmpty) {
      _sites = List.from(savedSites);
    } else if (fallbackFilters != null) {
      // Migrate from single location in legacy settings
      _sites = [
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
    } else {
      _sites = [ObservingSite.defaultSite];
    }

    if (savedActiveId != null && _sites.any((s) => s.id == savedActiveId)) {
      _activeSiteId = savedActiveId;
    } else {
      _activeSiteId = _sites.first.id;
    }

    notifyListeners();
  }

  /// Sets the active observing site by its unique ID.
  void setActiveSite(String id) {
    if (_sites.any((s) => s.id == id) && _activeSiteId != id) {
      _activeSiteId = id;
      notifyListeners();
    }
  }

  /// Adds a new site and optionally sets it as active immediately.
  void addSite(ObservingSite site, {bool setAsActive = true}) {
    _sites.add(site);
    if (setAsActive) {
      _activeSiteId = site.id;
    }
    notifyListeners();
  }

  /// Updates an existing site. If it was active, listeners will be notified of changes.
  void updateSite(ObservingSite site) {
    final index = _sites.indexWhere((s) => s.id == site.id);
    if (index != -1) {
      _sites[index] = site;
      notifyListeners();
    }
  }

  /// Deletes a site. Prevents deleting if only one site exists.
  /// If the deleted site was active, selects the first remaining site.
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
    if (fallbackFilters != null) {
      _sites = [
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
    } else {
      _sites = [ObservingSite.defaultSite];
    }
    _activeSiteId = _sites.first.id;
    notifyListeners();
  }
}
