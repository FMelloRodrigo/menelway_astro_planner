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

  @override
  String get observingTimeWindow => 'Observing Time Window';

  @override
  String get astronomicalDarkness => 'Astronomical Darkness';

  @override
  String get astroDarknessShort => 'Astro Darkness';

  @override
  String get customTimeLimit => 'Custom Time Limit';

  @override
  String get customWindowShort => 'Custom Window';

  @override
  String get startTime => 'START TIME';

  @override
  String get endTime => 'END TIME';

  @override
  String get window => 'WINDOW';

  @override
  String get hoursShort => 'hrs';

  @override
  String get duskMidnight => 'Dusk - Midnight';

  @override
  String get midnightDawn => 'Midnight - Dawn';

  @override
  String get visibilityAltitudeRange => 'Visibility & Altitude Range';

  @override
  String get zenith => '(Zenith)';

  @override
  String minimumAltitude(String degrees) {
    return 'Minimum Altitude: $degrees°';
  }

  @override
  String maximumAltitude(String degrees) {
    return 'Maximum Altitude: $degrees°';
  }

  @override
  String minimumDuration(String hours) {
    return 'Minimum Duration: ${hours}h';
  }

  @override
  String durationLabel(String hours) {
    return 'Duration: ${hours}h';
  }

  @override
  String get directionAzimuthRange => 'Direction & Azimuth Range';

  @override
  String get directionPresetMode => 'Direction Preset / Mode';

  @override
  String get quadrantAll => 'All Directions (0° - 360°)';

  @override
  String get quadrantN => 'North (315° - 45°)';

  @override
  String get quadrantE => 'East (45° - 135°)';

  @override
  String get quadrantS => 'South (135° - 225°)';

  @override
  String get quadrantW => 'West (225° - 315°)';

  @override
  String get quadrantNE => 'North-East (0° - 90°)';

  @override
  String get quadrantSE => 'South-East (90° - 180°)';

  @override
  String get quadrantSW => 'South-West (180° - 270°)';

  @override
  String get quadrantNW => 'North-West (270° - 360°)';

  @override
  String get quadrantCustom => 'Custom Degree Range';

  @override
  String minAzimuthLabel(String deg, String cardinal) {
    return 'Min: $deg° ($cardinal)';
  }

  @override
  String maxAzimuthLabel(String deg, String cardinal) {
    return 'Max: $deg° ($cardinal)';
  }

  @override
  String get compassAll360 => 'All 360°';

  @override
  String get compassClosed => '0° (Closed)';

  @override
  String compassSpan(String span) {
    return 'Span: $span°';
  }

  @override
  String get customHorizonMask => 'Custom Horizon Obstruction Mask';

  @override
  String get customHorizonProfile => 'Custom Horizon Profile';

  @override
  String get noObstaclePoints =>
      'No obstacle points defined yet (flat horizon)';

  @override
  String obstaclePointsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count obstacle points configured across 360°',
      one: '1 obstacle point configured across 360°',
    );
    return '$_temp0';
  }

  @override
  String get createHorizonProfile => 'Create Horizon Profile...';

  @override
  String get openHorizonMaker => 'Open Horizon Maker...';

  @override
  String get moonDistance => 'Moon Distance';

  @override
  String minMoonDistanceLabel(String degrees) {
    return 'Min distance from Moon: $degrees°';
  }

  @override
  String get catalogs => 'Catalogs';

  @override
  String get objectTypes => 'Object Types';

  @override
  String get magnitudeApparentSize => 'Magnitude & Apparent Size';

  @override
  String faintestLimitLabel(String mag) {
    return 'Faintest Limit (Max Mag): $mag';
  }

  @override
  String get lowerBrighter => '(lower = brighter)';

  @override
  String minSizeLabelAlt(String size) {
    return 'Min Size: $size\'';
  }

  @override
  String get equipmentRigsTooltip => 'Equipment Rigs & Optics';

  @override
  String get equipmentRigsButton => 'Equipment Rigs';

  @override
  String get settingsAndDataTooltip => 'Settings & Data';

  @override
  String get settingsDialogTitle => 'Settings & Data';

  @override
  String get settingsDialogSubtitle =>
      'Manage filter presets and application data storage.';

  @override
  String get settingsSectionFilters => 'Target Filters';

  @override
  String get settingsSectionData => 'Storage & Local Data';

  @override
  String get settingsLocation => 'Observer Location...';

  @override
  String get actionCannotBeUndone => 'This action cannot be undone.';

  @override
  String get cleanDataSuccessSnackBar =>
      'All saved data, settings, and observing lists have been cleared.';

  @override
  String get selectedCoordsElevation => 'Selected Coordinates & Elevation';

  @override
  String get popularAstroSites => 'Popular Astrophotography Sites:';

  @override
  String get applyLocation => 'Apply Location';

  @override
  String get cancel => 'Cancel';

  @override
  String get retry => 'Retry';

  @override
  String get failedLoadCore => 'Failed to load astronomical core';

  @override
  String get initializingEngine =>
      'Initializing Astro Targets Engine & Database...';

  @override
  String get equipmentDialogTitle => 'Equipment Rigs & Optics';

  @override
  String get addEquipmentRig => 'Add Equipment Rig';

  @override
  String get editEquipmentRig => 'Edit Equipment Rig';

  @override
  String get backToList => 'Back to List';

  @override
  String get editRig => 'Edit';

  @override
  String get deleteRigTooltip => 'Delete Rig';

  @override
  String get createNewRig => 'Create New Rig';

  @override
  String get rigProfileName => 'Rig Profile Name';

  @override
  String get telescopeOptics => 'Telescope / Optics';

  @override
  String get searchScopeHint =>
      'Search scope: e.g. RedCat, FRA400, 72ED, C8, Seestar...';

  @override
  String get telescopeName => 'Telescope Name';

  @override
  String get focalLengthMm => 'Focal Length (mm)';

  @override
  String get apertureMm => 'Aperture (mm)';

  @override
  String get reducerFactor => 'Reducer (e.g. 0.8)';

  @override
  String get cameraSensor => 'Camera / Sensor';

  @override
  String get searchCameraHint =>
      'Search camera: e.g. ASI2600, ASI533, IMX571, Sony A7, Canon...';

  @override
  String get cameraName => 'Camera Name';

  @override
  String get sensorWidthMm => 'Sensor Width (mm)';

  @override
  String get sensorHeightMm => 'Sensor Height (mm)';

  @override
  String get pixelSizeMicrons => 'Pixel Size (µm)';

  @override
  String get computedOpticalSpecs => 'Computed Optical Specifications';

  @override
  String get effectiveFocal => 'Effective Focal';

  @override
  String get focalRatio => 'Focal Ratio';

  @override
  String get sensorFov => 'Sensor FOV';

  @override
  String get imageScale => 'Image Scale';

  @override
  String get sampling => 'Sampling';

  @override
  String get saveRig => 'Save Rig';

  @override
  String get gearButton => 'Gear';

  @override
  String get switchRigTooltip => 'Switch Equipment Rig';

  @override
  String get rigsLabel => 'Rigs';

  @override
  String get manageRigsTooltip => 'Manage Rigs / Add Gear';

  @override
  String get closeFramingSimulator => 'Close Framing Simulator';

  @override
  String get framingSimulatorTitle => 'Equipment Framing Simulator';

  @override
  String activeRigLabel(String rigName) {
    return 'Active Rig: $rigName';
  }

  @override
  String get cameraRotatorAngle => 'Camera Rotator Angle';

  @override
  String get fitToSensor => 'Fit to Sensor';

  @override
  String get autoAlignTarget => 'Align';

  @override
  String get autoAlignTargetTooltip => 'Auto-Align with Target Position Angle';

  @override
  String get ruleOfThirdsGrid => 'Rule of Thirds Grid';

  @override
  String get ruleOfThirdsSubtitle =>
      'Overlay composition cross-lines inside sensor frame';

  @override
  String get opticalSystemMetrics => 'Optical System Metrics';

  @override
  String get effectiveFocalLength => 'Effective Focal Length';

  @override
  String get sensorFovDegrees => 'Sensor Field of View';

  @override
  String get sensorFovArcmin => 'Sensor FOV (Arcmin)';

  @override
  String get imageScalePixelSize => 'Image Scale (Pixel Size)';

  @override
  String get samplingDiagnosis => 'Sampling Diagnosis';

  @override
  String get sensorResolution => 'Sensor Resolution';

  @override
  String get copyFramingInfo => 'Copy Info';

  @override
  String get copyFramingSpecsTooltip =>
      'Copy Framing Specs (N.I.N.A. / ASIAIR / Stellarium)';

  @override
  String get framingSpecsCopied =>
      'Framing specs copied to clipboard (ready for N.I.N.A. / ASIAIR / Stellarium)';

  @override
  String get framingPanOffset => 'Framing Pan Offset';

  @override
  String get stepSize => 'Step Size';

  @override
  String get centered => 'Centered';

  @override
  String offsetLabel(String offset) {
    return '$offset\' offset';
  }

  @override
  String get useArrowsToFrame => 'Use arrows to frame off-center composition';

  @override
  String get resetToCenter => 'Reset to Target Center';

  @override
  String get darkTime => 'Dark';

  @override
  String get moonPhaseNewMoon => 'New Moon';

  @override
  String get moonPhaseWaxingCrescent => 'Waxing Crescent';

  @override
  String get moonPhaseFirstQuarter => 'First Quarter';

  @override
  String get moonPhaseWaxingGibbous => 'Waxing Gibbous';

  @override
  String get moonPhaseFullMoon => 'Full Moon';

  @override
  String get moonPhaseWaningGibbous => 'Waning Gibbous';

  @override
  String get moonPhaseThirdQuarter => 'Third Quarter';

  @override
  String get moonPhaseWaningCrescent => 'Waning Crescent';

  @override
  String get elevationShort => 'Elevation';

  @override
  String searchResultSubtitle(String lat, String lon, String elev) {
    return 'Lat: $lat° | Lon: $lon° | Elevation: ${elev}m';
  }

  @override
  String get visualSkyPreview => 'Visual Sky Preview';

  @override
  String get noObservingListsFound =>
      'No observing lists found. Create a list first!';

  @override
  String get defaultListNotes => 'Target for imaging';

  @override
  String addToListDialogTitle(String targetName) {
    return 'Add $targetName to List';
  }

  @override
  String get targetObservingListLabel => 'Target Observing List';

  @override
  String get sessionNotesLabel => 'Session Notes / Filters';

  @override
  String get addBtn => 'Add';

  @override
  String addedToObservingListSuccess(String targetName) {
    return 'Added $targetName to observing list';
  }

  @override
  String get simbadQuerying => 'Querying CDS / SIMBAD...';

  @override
  String simbadVerified(String objectType) {
    return 'Verified on SIMBAD: $objectType';
  }

  @override
  String get simbadNotFound => 'No additional online records found.';

  @override
  String get removeFromFavorites => 'Remove from Favorites';

  @override
  String get addToFavorites => 'Add to Favorites';

  @override
  String addedToFavorites(String targetName) {
    return 'Added $targetName to Favorites';
  }

  @override
  String removedFromFavorites(String targetName) {
    return 'Removed $targetName from Favorites';
  }

  @override
  String get closeDetailsTooltip => 'Close details (Esc)';

  @override
  String get closeBtn => 'Close';

  @override
  String get transitTimeMetric => 'Transit Time';

  @override
  String get visibleDurationMetric => 'Visible Duration';

  @override
  String get moonDistanceMetric => 'Moon Distance';

  @override
  String get apparentSizeMetric => 'Apparent Size';

  @override
  String get verifyOnlineSimbad => 'Verify Online (SIMBAD)';

  @override
  String get simulatingYearlyVisibility =>
      'Simulating 12-month visibility across the year...';

  @override
  String get visibleTonight => 'Visible Tonight';

  @override
  String get unreachable => 'Unreachable';

  @override
  String get notObservableFiltered => 'Not observable with active filters';

  @override
  String get notObservableBelowLimits => 'Not observable (below limits)';

  @override
  String startsTomorrow(String date) {
    return 'Starts tomorrow ($date)';
  }

  @override
  String startsInDays(int days, String date) {
    return 'Starts in $days days ($date)';
  }

  @override
  String startsOnDate(String date) {
    return 'Starts $date';
  }

  @override
  String get inSeasonBelowLimits => 'In Season · Below limits tonight';

  @override
  String offSeasonEnded(String date) {
    return 'Off-Season (Ended $date)';
  }

  @override
  String get simulationModeLabel => 'SIMULATION MODE:';

  @override
  String get activeFiltersMode => 'Active Filters';

  @override
  String get fullSkyNightMode => 'Full Sky & Night';

  @override
  String get yearlyObservingWindow => 'YEARLY OBSERVING WINDOW';

  @override
  String yearlyDaysObservablePeak(int days, String hours, String date) {
    return '$days days observable this year • Peak: ${hours}h on $date';
  }

  @override
  String theoreticalMaxAtTransit(String alt, String extra) {
    return 'Theoretical max: $alt° at transit$extra';
  }

  @override
  String limitsSubtitle(String minAlt, String minHours) {
    return 'Limits: ≥$minAlt° for ≥${minHours}h';
  }

  @override
  String get yearRoundCircumpolar => 'Year-Round (Circumpolar)';

  @override
  String get notObservableWithFilters => 'Not observable with current filters';

  @override
  String neverReachesLatitude(String minAlt, String maxAlt) {
    return 'Never reaches $minAlt° at this latitude (Max: $maxAlt°)';
  }

  @override
  String get clearSearchTooltip => 'Clear search';

  @override
  String get searchTargetTooltip => 'Search target';

  @override
  String get windowFullDarkness => 'Window: Darkness (Full Night)';

  @override
  String targetsFoundCount(int count) {
    return '$count targets found';
  }

  @override
  String get showingMatchingOnly =>
      'Showing only targets matching active filters tonight.';

  @override
  String get searchIncludesOutsideFilters =>
      'Search includes targets outside active filters tonight. Click any target to view its yearly window.';

  @override
  String get showAll => 'Show All';

  @override
  String get hideNonMatching => 'Hide Non-Matching';

  @override
  String visibleDurationShort(String hours) {
    return '${hours}h visible';
  }

  @override
  String visibleDurationAbove(String hours, String alt) {
    return '${hours}h above $alt°';
  }

  @override
  String get outsideFilters => 'Outside Filters';

  @override
  String get outsideActiveFilters => 'Outside Active Filters';

  @override
  String get belowZero => 'Below 0°';

  @override
  String get belowHorizon => 'Below Horizon';

  @override
  String peakAltitudeShort(String alt) {
    return 'Peak: $alt°';
  }

  @override
  String moonSeparationShort(String sep) {
    return 'Moon: $sep°';
  }

  @override
  String get selectSkySurveyTooltip => 'Select Sky Survey';

  @override
  String get openFramingSimulatorTooltip => 'Open Full Framing Simulator';

  @override
  String get framingSimulatorShort => 'Simulator';

  @override
  String get toggleFramingBoxTooltip => 'Toggle Sensor Framing Box';

  @override
  String get framingModeShort => 'Framing';

  @override
  String get photoReticleTooltip => 'Photo + Reticle';

  @override
  String get photoCleanTooltip => 'Photo Mode (Clean Image)';

  @override
  String get vectorSizeTooltip => 'Vector Apparent Size';

  @override
  String get zoomOutTooltip => 'Zoom Out (Wider FOV)';

  @override
  String get zoomInTooltip => 'Zoom In (Closer FOV)';

  @override
  String get resetFovTooltip => 'Reset Framing FOV';

  @override
  String get rotateMinus15 => 'Rotate -15°';

  @override
  String get rotatePlus15 => 'Rotate +15°';

  @override
  String get fitFovToSensorTooltip => 'Fit FOV to Sensor Size';

  @override
  String get offlineSkyFallback => 'Offline Sky Fallback';

  @override
  String get noAltitudeData => 'No altitude data available for window';

  @override
  String altitudeVsTimeTarget(String targetName) {
    return 'Altitude vs. Time: $targetName';
  }

  @override
  String get astronomicalDarknessLabel => 'ASTRONOMICAL DARKNESS';

  @override
  String get observingWindowLabel => 'OBSERVING WINDOW';

  @override
  String get settingsSectionAbout => 'About Menelway';

  @override
  String get aboutBtn => 'About Menelway';

  @override
  String get aboutDialogTitle => 'About Menelway';

  @override
  String get aboutCloseBtn => 'Close';

  @override
  String get aboutCreatedBy => 'Created by Rodrigo F. Mello';

  @override
  String get aboutAppName => 'Menelway Astro Planner';

  @override
  String get aboutNameOrigin =>
      '“Menelway” = “Menel” (Elvish/Tolkien for Skies/Heavens) + Arroway (from the Contact book/movie)';
}
