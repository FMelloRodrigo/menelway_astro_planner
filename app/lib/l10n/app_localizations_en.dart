// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Menelway Astro Planner';

  @override
  String get appSubtitle => 'Astro Target & Session Planner';

  @override
  String get tabTargets => 'Targets';

  @override
  String get tabPlanner => 'Planner';

  @override
  String get tabObservingLists => 'Observing Lists';

  @override
  String get tabFavorites => 'Favorites';

  @override
  String get observerLocation => 'Observer Location';

  @override
  String get darkness => 'Darkness';

  @override
  String get moon => 'Moon';

  @override
  String get databaseSize => 'Database';

  @override
  String get nightModeRed => 'Telescope Red Mode';

  @override
  String get nightModeStandard => 'Deep Space Obsidian';

  @override
  String get equipmentRigs => 'Equipment Rigs';

  @override
  String get settingsAndData => 'Settings & Data';

  @override
  String get language => 'Language';

  @override
  String get languageEnglish => 'English';

  @override
  String get languagePortuguese => 'Português (Brasil)';

  @override
  String get languageSystem => 'System Default';

  @override
  String get resetFilters => 'Reset Target Filters';

  @override
  String get resetFiltersDesc => 'Clear filter limits & keep observer location';

  @override
  String get cleanData => 'Clean All Saved Data...';

  @override
  String get cleanDataDesc => 'Wipe lists, custom location, & local settings';

  @override
  String get cleanDataConfirmTitle => 'Clear All Saved Data?';

  @override
  String get cleanDataWarning =>
      'This will permanently erase your local configuration and reset everything back to factory defaults:';

  @override
  String get cleanDataPoint1 =>
      '• Custom observer geographic location & coordinates';

  @override
  String get cleanDataPoint2 => '• All custom Target Filters & Horizon masks';

  @override
  String get cleanDataPoint3 => '• Equipment optics & camera sensor profiles';

  @override
  String get cleanDataPoint4 => '• Favorite targets and custom observing lists';

  @override
  String get cleanDataCancel => 'Cancel';

  @override
  String get cleanDataConfirm => 'Yes, Reset Everything';

  @override
  String get cleanDataSuccess =>
      'All local data reset. App restored to default.';

  @override
  String get filtersResetSuccess =>
      'Target filters reset to default (location preserved).';

  @override
  String get locationEditTitle => 'Observer Location';

  @override
  String get searchCityOnline => 'Search City & Country (Online)';

  @override
  String get searchCityHint =>
      'Type city (e.g. Campinas, London, Atacama, Tokyo)...';

  @override
  String get searchOnlineTooltip => 'Search online';

  @override
  String get manualCoordinates => 'Manual Coordinates';

  @override
  String get latitude => 'Latitude (°)';

  @override
  String get longitude => 'Longitude (°)';

  @override
  String get elevation => 'Elevation (m)';

  @override
  String get locationNameLabel => 'Location Name';

  @override
  String get saveLocation => 'Save Location';

  @override
  String locationNotFound(String query) {
    return 'No matching cities found for \'$query\'.';
  }

  @override
  String get connectionError => 'Connection error. Check internet connection.';

  @override
  String get searchTargetsHint =>
      'Search target (e.g. M31, NGC 7000, Orion, Dumbbell)...';

  @override
  String get filtersButton => 'Filters';

  @override
  String get sortBy => 'Sort by';

  @override
  String get sortPeakAltitude => 'Peak Altitude';

  @override
  String get sortMagnitude => 'Magnitude (Brightest)';

  @override
  String get sortTransitTime => 'Transit Time';

  @override
  String get sortVisibleDuration => 'Visible Duration';

  @override
  String get sortSize => 'Size (Largest)';

  @override
  String get noTargetsFound => 'No targets match your filter criteria.';

  @override
  String get noTargetsSubtitle =>
      'Try relaxing altitude limits, magnitude, or clearing search keywords.';

  @override
  String get altitude => 'Altitude';

  @override
  String get peakAltitude => 'Peak Alt';

  @override
  String get transit => 'Transit';

  @override
  String get visibleDuration => 'Visible';

  @override
  String get moonSeparation => 'Moon Sep';

  @override
  String get magnitudeLabel => 'Mag';

  @override
  String get sizeLabel => 'Size';

  @override
  String get surfaceBrightnessLabel => 'Surf. Brightness';

  @override
  String get addToObservingList => 'Add to List';

  @override
  String addedToObservingList(String listName) {
    return 'Added to list: $listName';
  }

  @override
  String get targetDetails => 'Target Details';

  @override
  String get constellationLabel => 'Constellation';

  @override
  String get coordinatesLabel => 'Coordinates';

  @override
  String get visibilityWindow => 'Visibility Window';

  @override
  String get filterDialogTitle => 'Filter Targets';

  @override
  String get tabGeneral => 'General & Altitude';

  @override
  String get tabAreaHorizon => 'Area & Horizon';

  @override
  String get tabObjectTypes => 'Object Types';

  @override
  String get tabCatalogs => 'Catalogs';

  @override
  String get tabWindow => 'Time Window';

  @override
  String minAltitudeLabel(String degrees) {
    return 'Min Altitude: $degrees°';
  }

  @override
  String maxAltitudeLabel(String degrees) {
    return 'Max Altitude: $degrees°';
  }

  @override
  String minDurationLabel(String hours) {
    return 'Min Duration: ${hours}h';
  }

  @override
  String minMoonSeparationLabel(String degrees) {
    return 'Min Moon Separation: $degrees°';
  }

  @override
  String magnitudeRangeLabel(String minMag, String maxMag) {
    return 'Magnitude Range: $minMag to $maxMag';
  }

  @override
  String sizeRangeLabel(String minSize, String maxSize) {
    return 'Angular Size: $minSize\' to $maxSize\'';
  }

  @override
  String get resetAllFilters => 'Reset Filters';

  @override
  String get applyFilters => 'Apply Filters';

  @override
  String get selectAll => 'Select All';

  @override
  String get deselectAll => 'Deselect All';

  @override
  String get objGalaxy => 'Galaxy';

  @override
  String get objPlanetaryNebula => 'Planetary Nebula';

  @override
  String get objBrightNebula => 'Bright Nebula';

  @override
  String get objDarkNebula => 'Dark Nebula';

  @override
  String get objOpenCluster => 'Open Cluster';

  @override
  String get objGlobularCluster => 'Globular Cluster';

  @override
  String get objSupernovaRemnant => 'Supernova Remnant';

  @override
  String get objStar => 'Star';

  @override
  String get objDoubleStar => 'Double Star';

  @override
  String get objAsterism => 'Asterism';

  @override
  String get objOther => 'Other';

  @override
  String get createNewList => 'Create New List';

  @override
  String get listName => 'List Name';

  @override
  String get listDescription => 'Description (optional)';

  @override
  String targetCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count targets',
      one: '1 target',
    );
    return '$_temp0';
  }

  @override
  String get deleteList => 'Delete List';

  @override
  String get deleteListConfirm =>
      'Are you sure you want to delete this observing list?';

  @override
  String get emptyObservingLists =>
      'No observing lists yet. Create one to organize your session!';

  @override
  String get noFavoritesYet => 'No favorite targets yet';

  @override
  String get noFavoritesDesc =>
      'Click the star icon on any target card or details sheet to pin favorites here.';

  @override
  String get exploreTargets => 'Explore Targets';
}
