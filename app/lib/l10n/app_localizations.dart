import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_pt.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('pt'),
  ];

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Menelway Astro Planner'**
  String get appTitle;

  /// No description provided for @appSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Astro Target & Session Planner'**
  String get appSubtitle;

  /// No description provided for @tabTargets.
  ///
  /// In en, this message translates to:
  /// **'Targets'**
  String get tabTargets;

  /// No description provided for @tabPlanner.
  ///
  /// In en, this message translates to:
  /// **'Planner'**
  String get tabPlanner;

  /// No description provided for @tabObservingLists.
  ///
  /// In en, this message translates to:
  /// **'Observing Lists'**
  String get tabObservingLists;

  /// No description provided for @tabFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get tabFavorites;

  /// No description provided for @observerLocation.
  ///
  /// In en, this message translates to:
  /// **'Observer Location'**
  String get observerLocation;

  /// No description provided for @darkness.
  ///
  /// In en, this message translates to:
  /// **'Darkness'**
  String get darkness;

  /// No description provided for @moon.
  ///
  /// In en, this message translates to:
  /// **'Moon'**
  String get moon;

  /// No description provided for @databaseSize.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get databaseSize;

  /// No description provided for @nightModeRed.
  ///
  /// In en, this message translates to:
  /// **'Telescope Red Mode'**
  String get nightModeRed;

  /// No description provided for @nightModeStandard.
  ///
  /// In en, this message translates to:
  /// **'Deep Space Obsidian'**
  String get nightModeStandard;

  /// No description provided for @equipmentRigs.
  ///
  /// In en, this message translates to:
  /// **'Equipment Rigs'**
  String get equipmentRigs;

  /// No description provided for @settingsAndData.
  ///
  /// In en, this message translates to:
  /// **'Settings & Data'**
  String get settingsAndData;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @languagePortuguese.
  ///
  /// In en, this message translates to:
  /// **'Português (Brasil)'**
  String get languagePortuguese;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'System Default'**
  String get languageSystem;

  /// No description provided for @resetFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset Target Filters'**
  String get resetFilters;

  /// No description provided for @resetFiltersDesc.
  ///
  /// In en, this message translates to:
  /// **'Clear filter limits & keep observer location'**
  String get resetFiltersDesc;

  /// No description provided for @cleanData.
  ///
  /// In en, this message translates to:
  /// **'Clean All Saved Data...'**
  String get cleanData;

  /// No description provided for @cleanDataDesc.
  ///
  /// In en, this message translates to:
  /// **'Wipe lists, custom location, & local settings'**
  String get cleanDataDesc;

  /// No description provided for @cleanDataConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear All Saved Data?'**
  String get cleanDataConfirmTitle;

  /// No description provided for @cleanDataWarning.
  ///
  /// In en, this message translates to:
  /// **'This will permanently erase your local configuration and reset everything back to factory defaults:'**
  String get cleanDataWarning;

  /// No description provided for @cleanDataPoint1.
  ///
  /// In en, this message translates to:
  /// **'• Custom observer geographic location & coordinates'**
  String get cleanDataPoint1;

  /// No description provided for @cleanDataPoint2.
  ///
  /// In en, this message translates to:
  /// **'• All custom Target Filters & Horizon masks'**
  String get cleanDataPoint2;

  /// No description provided for @cleanDataPoint3.
  ///
  /// In en, this message translates to:
  /// **'• Equipment optics & camera sensor profiles'**
  String get cleanDataPoint3;

  /// No description provided for @cleanDataPoint4.
  ///
  /// In en, this message translates to:
  /// **'• Favorite targets and custom observing lists'**
  String get cleanDataPoint4;

  /// No description provided for @cleanDataCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cleanDataCancel;

  /// No description provided for @cleanDataConfirm.
  ///
  /// In en, this message translates to:
  /// **'Yes, Reset Everything'**
  String get cleanDataConfirm;

  /// No description provided for @cleanDataSuccess.
  ///
  /// In en, this message translates to:
  /// **'All local data reset. App restored to default.'**
  String get cleanDataSuccess;

  /// No description provided for @filtersResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Target filters reset to default (location preserved).'**
  String get filtersResetSuccess;

  /// No description provided for @locationEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Observer Location'**
  String get locationEditTitle;

  /// No description provided for @searchCityOnline.
  ///
  /// In en, this message translates to:
  /// **'Search City & Country (Online)'**
  String get searchCityOnline;

  /// No description provided for @searchCityHint.
  ///
  /// In en, this message translates to:
  /// **'Type city'**
  String get searchCityHint;

  /// No description provided for @searchOnlineTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search online'**
  String get searchOnlineTooltip;

  /// No description provided for @manualCoordinates.
  ///
  /// In en, this message translates to:
  /// **'Manual Coordinates'**
  String get manualCoordinates;

  /// No description provided for @latitude.
  ///
  /// In en, this message translates to:
  /// **'Latitude (°)'**
  String get latitude;

  /// No description provided for @longitude.
  ///
  /// In en, this message translates to:
  /// **'Longitude (°)'**
  String get longitude;

  /// No description provided for @elevation.
  ///
  /// In en, this message translates to:
  /// **'Elevation (m)'**
  String get elevation;

  /// No description provided for @locationNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Location Name'**
  String get locationNameLabel;

  /// No description provided for @saveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save Location'**
  String get saveLocation;

  /// No description provided for @locationNotFound.
  ///
  /// In en, this message translates to:
  /// **'No matching cities found for \'{query}\'.'**
  String locationNotFound(String query);

  /// No description provided for @connectionError.
  ///
  /// In en, this message translates to:
  /// **'Connection error. Check internet connection.'**
  String get connectionError;

  /// No description provided for @searchTargetsHint.
  ///
  /// In en, this message translates to:
  /// **'Search target (e.g. M31, NGC 7000, Orion, Dumbbell)...'**
  String get searchTargetsHint;

  /// No description provided for @filtersButton.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get filtersButton;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort by'**
  String get sortBy;

  /// No description provided for @sortPeakAltitude.
  ///
  /// In en, this message translates to:
  /// **'Peak Altitude'**
  String get sortPeakAltitude;

  /// No description provided for @sortMagnitude.
  ///
  /// In en, this message translates to:
  /// **'Magnitude (Brightest)'**
  String get sortMagnitude;

  /// No description provided for @sortTransitTime.
  ///
  /// In en, this message translates to:
  /// **'Transit Time'**
  String get sortTransitTime;

  /// No description provided for @sortVisibleDuration.
  ///
  /// In en, this message translates to:
  /// **'Visible Duration'**
  String get sortVisibleDuration;

  /// No description provided for @sortSize.
  ///
  /// In en, this message translates to:
  /// **'Size (Largest)'**
  String get sortSize;

  /// No description provided for @noTargetsFound.
  ///
  /// In en, this message translates to:
  /// **'No targets match your filter criteria.'**
  String get noTargetsFound;

  /// No description provided for @noTargetsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Try relaxing altitude limits, magnitude, or clearing search keywords.'**
  String get noTargetsSubtitle;

  /// No description provided for @altitude.
  ///
  /// In en, this message translates to:
  /// **'Altitude'**
  String get altitude;

  /// No description provided for @peakAltitude.
  ///
  /// In en, this message translates to:
  /// **'Peak Alt'**
  String get peakAltitude;

  /// No description provided for @transit.
  ///
  /// In en, this message translates to:
  /// **'Transit'**
  String get transit;

  /// No description provided for @visibleDuration.
  ///
  /// In en, this message translates to:
  /// **'Visible'**
  String get visibleDuration;

  /// No description provided for @moonSeparation.
  ///
  /// In en, this message translates to:
  /// **'Moon Sep'**
  String get moonSeparation;

  /// No description provided for @magnitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Mag'**
  String get magnitudeLabel;

  /// No description provided for @sizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get sizeLabel;

  /// No description provided for @surfaceBrightnessLabel.
  ///
  /// In en, this message translates to:
  /// **'Surf. Brightness'**
  String get surfaceBrightnessLabel;

  /// No description provided for @addToObservingList.
  ///
  /// In en, this message translates to:
  /// **'Add to List'**
  String get addToObservingList;

  /// No description provided for @addedToObservingList.
  ///
  /// In en, this message translates to:
  /// **'Added to list: {listName}'**
  String addedToObservingList(String listName);

  /// No description provided for @targetDetails.
  ///
  /// In en, this message translates to:
  /// **'Target Details'**
  String get targetDetails;

  /// No description provided for @constellationLabel.
  ///
  /// In en, this message translates to:
  /// **'Constellation'**
  String get constellationLabel;

  /// No description provided for @coordinatesLabel.
  ///
  /// In en, this message translates to:
  /// **'Coordinates'**
  String get coordinatesLabel;

  /// No description provided for @visibilityWindow.
  ///
  /// In en, this message translates to:
  /// **'Visibility Window'**
  String get visibilityWindow;

  /// No description provided for @filterDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Filter Targets'**
  String get filterDialogTitle;

  /// No description provided for @tabGeneral.
  ///
  /// In en, this message translates to:
  /// **'General & Altitude'**
  String get tabGeneral;

  /// No description provided for @tabAreaHorizon.
  ///
  /// In en, this message translates to:
  /// **'Area & Horizon'**
  String get tabAreaHorizon;

  /// No description provided for @tabObjectTypes.
  ///
  /// In en, this message translates to:
  /// **'Object Types'**
  String get tabObjectTypes;

  /// No description provided for @tabCatalogs.
  ///
  /// In en, this message translates to:
  /// **'Catalogs'**
  String get tabCatalogs;

  /// No description provided for @tabWindow.
  ///
  /// In en, this message translates to:
  /// **'Time Window'**
  String get tabWindow;

  /// No description provided for @minAltitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Min Altitude: {degrees}°'**
  String minAltitudeLabel(String degrees);

  /// No description provided for @maxAltitudeLabel.
  ///
  /// In en, this message translates to:
  /// **'Max Altitude: {degrees}°'**
  String maxAltitudeLabel(String degrees);

  /// No description provided for @minDurationLabel.
  ///
  /// In en, this message translates to:
  /// **'Min Duration: {hours}h'**
  String minDurationLabel(String hours);

  /// No description provided for @minMoonSeparationLabel.
  ///
  /// In en, this message translates to:
  /// **'Min Moon Separation: {degrees}°'**
  String minMoonSeparationLabel(String degrees);

  /// No description provided for @magnitudeRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Magnitude Range: {minMag} to {maxMag}'**
  String magnitudeRangeLabel(String minMag, String maxMag);

  /// No description provided for @sizeRangeLabel.
  ///
  /// In en, this message translates to:
  /// **'Angular Size: {minSize}\' to {maxSize}\''**
  String sizeRangeLabel(String minSize, String maxSize);

  /// No description provided for @resetAllFilters.
  ///
  /// In en, this message translates to:
  /// **'Reset Filters'**
  String get resetAllFilters;

  /// No description provided for @applyFilters.
  ///
  /// In en, this message translates to:
  /// **'Apply Filters'**
  String get applyFilters;

  /// No description provided for @selectAll.
  ///
  /// In en, this message translates to:
  /// **'Select All'**
  String get selectAll;

  /// No description provided for @deselectAll.
  ///
  /// In en, this message translates to:
  /// **'Deselect All'**
  String get deselectAll;

  /// No description provided for @objGalaxy.
  ///
  /// In en, this message translates to:
  /// **'Galaxy'**
  String get objGalaxy;

  /// No description provided for @objPlanetaryNebula.
  ///
  /// In en, this message translates to:
  /// **'Planetary Nebula'**
  String get objPlanetaryNebula;

  /// No description provided for @objBrightNebula.
  ///
  /// In en, this message translates to:
  /// **'Bright Nebula'**
  String get objBrightNebula;

  /// No description provided for @objDarkNebula.
  ///
  /// In en, this message translates to:
  /// **'Dark Nebula'**
  String get objDarkNebula;

  /// No description provided for @objOpenCluster.
  ///
  /// In en, this message translates to:
  /// **'Open Cluster'**
  String get objOpenCluster;

  /// No description provided for @objGlobularCluster.
  ///
  /// In en, this message translates to:
  /// **'Globular Cluster'**
  String get objGlobularCluster;

  /// No description provided for @objSupernovaRemnant.
  ///
  /// In en, this message translates to:
  /// **'Supernova Remnant'**
  String get objSupernovaRemnant;

  /// No description provided for @objStar.
  ///
  /// In en, this message translates to:
  /// **'Star'**
  String get objStar;

  /// No description provided for @objDoubleStar.
  ///
  /// In en, this message translates to:
  /// **'Double Star'**
  String get objDoubleStar;

  /// No description provided for @objAsterism.
  ///
  /// In en, this message translates to:
  /// **'Asterism'**
  String get objAsterism;

  /// No description provided for @objOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get objOther;

  /// No description provided for @createNewList.
  ///
  /// In en, this message translates to:
  /// **'Create New List'**
  String get createNewList;

  /// No description provided for @listName.
  ///
  /// In en, this message translates to:
  /// **'List Name'**
  String get listName;

  /// No description provided for @listDescription.
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get listDescription;

  /// No description provided for @targetCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 target} other{{count} targets}}'**
  String targetCount(int count);

  /// No description provided for @deleteList.
  ///
  /// In en, this message translates to:
  /// **'Delete List'**
  String get deleteList;

  /// No description provided for @deleteListConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this observing list?'**
  String get deleteListConfirm;

  /// No description provided for @emptyObservingLists.
  ///
  /// In en, this message translates to:
  /// **'No observing lists yet. Create one to organize your session!'**
  String get emptyObservingLists;

  /// No description provided for @noFavoritesYet.
  ///
  /// In en, this message translates to:
  /// **'No favorite targets yet'**
  String get noFavoritesYet;

  /// No description provided for @noFavoritesDesc.
  ///
  /// In en, this message translates to:
  /// **'Click the star icon on any target card or details sheet to pin favorites here.'**
  String get noFavoritesDesc;

  /// No description provided for @exploreTargets.
  ///
  /// In en, this message translates to:
  /// **'Explore Targets'**
  String get exploreTargets;

  /// No description provided for @observingTimeWindow.
  ///
  /// In en, this message translates to:
  /// **'Observing Time Window'**
  String get observingTimeWindow;

  /// No description provided for @astronomicalDarkness.
  ///
  /// In en, this message translates to:
  /// **'Astronomical Darkness'**
  String get astronomicalDarkness;

  /// No description provided for @astroDarknessShort.
  ///
  /// In en, this message translates to:
  /// **'Astro Darkness'**
  String get astroDarknessShort;

  /// No description provided for @customTimeLimit.
  ///
  /// In en, this message translates to:
  /// **'Custom Time Limit'**
  String get customTimeLimit;

  /// No description provided for @customWindowShort.
  ///
  /// In en, this message translates to:
  /// **'Custom Window'**
  String get customWindowShort;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'START TIME'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'END TIME'**
  String get endTime;

  /// No description provided for @window.
  ///
  /// In en, this message translates to:
  /// **'WINDOW'**
  String get window;

  /// No description provided for @hoursShort.
  ///
  /// In en, this message translates to:
  /// **'hrs'**
  String get hoursShort;

  /// No description provided for @duskMidnight.
  ///
  /// In en, this message translates to:
  /// **'Dusk - Midnight'**
  String get duskMidnight;

  /// No description provided for @midnightDawn.
  ///
  /// In en, this message translates to:
  /// **'Midnight - Dawn'**
  String get midnightDawn;

  /// No description provided for @visibilityAltitudeRange.
  ///
  /// In en, this message translates to:
  /// **'Visibility & Altitude Range'**
  String get visibilityAltitudeRange;

  /// No description provided for @zenith.
  ///
  /// In en, this message translates to:
  /// **'(Zenith)'**
  String get zenith;

  /// No description provided for @minimumAltitude.
  ///
  /// In en, this message translates to:
  /// **'Minimum Altitude: {degrees}°'**
  String minimumAltitude(String degrees);

  /// No description provided for @maximumAltitude.
  ///
  /// In en, this message translates to:
  /// **'Maximum Altitude: {degrees}°'**
  String maximumAltitude(String degrees);

  /// No description provided for @minimumDuration.
  ///
  /// In en, this message translates to:
  /// **'Minimum Duration: {hours}h'**
  String minimumDuration(String hours);

  /// No description provided for @durationLabel.
  ///
  /// In en, this message translates to:
  /// **'Duration: {hours}h'**
  String durationLabel(String hours);

  /// No description provided for @directionAzimuthRange.
  ///
  /// In en, this message translates to:
  /// **'Direction & Azimuth Range'**
  String get directionAzimuthRange;

  /// No description provided for @directionPresetMode.
  ///
  /// In en, this message translates to:
  /// **'Direction Preset / Mode'**
  String get directionPresetMode;

  /// No description provided for @quadrantAll.
  ///
  /// In en, this message translates to:
  /// **'All Directions (0° - 360°)'**
  String get quadrantAll;

  /// No description provided for @quadrantN.
  ///
  /// In en, this message translates to:
  /// **'North (315° - 45°)'**
  String get quadrantN;

  /// No description provided for @quadrantE.
  ///
  /// In en, this message translates to:
  /// **'East (45° - 135°)'**
  String get quadrantE;

  /// No description provided for @quadrantS.
  ///
  /// In en, this message translates to:
  /// **'South (135° - 225°)'**
  String get quadrantS;

  /// No description provided for @quadrantW.
  ///
  /// In en, this message translates to:
  /// **'West (225° - 315°)'**
  String get quadrantW;

  /// No description provided for @quadrantNE.
  ///
  /// In en, this message translates to:
  /// **'North-East (0° - 90°)'**
  String get quadrantNE;

  /// No description provided for @quadrantSE.
  ///
  /// In en, this message translates to:
  /// **'South-East (90° - 180°)'**
  String get quadrantSE;

  /// No description provided for @quadrantSW.
  ///
  /// In en, this message translates to:
  /// **'South-West (180° - 270°)'**
  String get quadrantSW;

  /// No description provided for @quadrantNW.
  ///
  /// In en, this message translates to:
  /// **'North-West (270° - 360°)'**
  String get quadrantNW;

  /// No description provided for @quadrantCustom.
  ///
  /// In en, this message translates to:
  /// **'Custom Degree Range'**
  String get quadrantCustom;

  /// No description provided for @minAzimuthLabel.
  ///
  /// In en, this message translates to:
  /// **'Min: {deg}° ({cardinal})'**
  String minAzimuthLabel(String deg, String cardinal);

  /// No description provided for @maxAzimuthLabel.
  ///
  /// In en, this message translates to:
  /// **'Max: {deg}° ({cardinal})'**
  String maxAzimuthLabel(String deg, String cardinal);

  /// No description provided for @compassAll360.
  ///
  /// In en, this message translates to:
  /// **'All 360°'**
  String get compassAll360;

  /// No description provided for @compassClosed.
  ///
  /// In en, this message translates to:
  /// **'0° (Closed)'**
  String get compassClosed;

  /// No description provided for @compassSpan.
  ///
  /// In en, this message translates to:
  /// **'Span: {span}°'**
  String compassSpan(String span);

  /// No description provided for @customHorizonMask.
  ///
  /// In en, this message translates to:
  /// **'Custom Horizon Obstruction Mask'**
  String get customHorizonMask;

  /// No description provided for @customHorizonProfile.
  ///
  /// In en, this message translates to:
  /// **'Custom Horizon Profile'**
  String get customHorizonProfile;

  /// No description provided for @noObstaclePoints.
  ///
  /// In en, this message translates to:
  /// **'No obstacle points defined yet (flat horizon)'**
  String get noObstaclePoints;

  /// No description provided for @obstaclePointsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 obstacle point configured across 360°} other{{count} obstacle points configured across 360°}}'**
  String obstaclePointsCount(int count);

  /// No description provided for @createHorizonProfile.
  ///
  /// In en, this message translates to:
  /// **'Create Horizon Profile...'**
  String get createHorizonProfile;

  /// No description provided for @openHorizonMaker.
  ///
  /// In en, this message translates to:
  /// **'Open Horizon Maker...'**
  String get openHorizonMaker;

  /// No description provided for @moonDistance.
  ///
  /// In en, this message translates to:
  /// **'Moon Distance'**
  String get moonDistance;

  /// No description provided for @minMoonDistanceLabel.
  ///
  /// In en, this message translates to:
  /// **'Min distance from Moon: {degrees}°'**
  String minMoonDistanceLabel(String degrees);

  /// No description provided for @catalogs.
  ///
  /// In en, this message translates to:
  /// **'Catalogs'**
  String get catalogs;

  /// No description provided for @objectTypes.
  ///
  /// In en, this message translates to:
  /// **'Object Types'**
  String get objectTypes;

  /// No description provided for @magnitudeApparentSize.
  ///
  /// In en, this message translates to:
  /// **'Magnitude & Apparent Size'**
  String get magnitudeApparentSize;

  /// No description provided for @faintestLimitLabel.
  ///
  /// In en, this message translates to:
  /// **'Faintest Limit (Max Mag): {mag}'**
  String faintestLimitLabel(String mag);

  /// No description provided for @lowerBrighter.
  ///
  /// In en, this message translates to:
  /// **'(lower = brighter)'**
  String get lowerBrighter;

  /// No description provided for @minSizeLabelAlt.
  ///
  /// In en, this message translates to:
  /// **'Min Size: {size}\''**
  String minSizeLabelAlt(String size);

  /// No description provided for @equipmentRigsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Equipment Rigs & Optics'**
  String get equipmentRigsTooltip;

  /// No description provided for @equipmentRigsButton.
  ///
  /// In en, this message translates to:
  /// **'Equipment Rigs'**
  String get equipmentRigsButton;

  /// No description provided for @settingsAndDataTooltip.
  ///
  /// In en, this message translates to:
  /// **'Settings & Data'**
  String get settingsAndDataTooltip;

  /// No description provided for @settingsDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Settings & Data'**
  String get settingsDialogTitle;

  /// No description provided for @settingsDialogSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage filter presets and application data storage.'**
  String get settingsDialogSubtitle;

  /// No description provided for @settingsSectionFilters.
  ///
  /// In en, this message translates to:
  /// **'Target Filters'**
  String get settingsSectionFilters;

  /// No description provided for @settingsSectionData.
  ///
  /// In en, this message translates to:
  /// **'Storage & Local Data'**
  String get settingsSectionData;

  /// No description provided for @settingsLocation.
  ///
  /// In en, this message translates to:
  /// **'Observer Location...'**
  String get settingsLocation;

  /// No description provided for @actionCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'This action cannot be undone.'**
  String get actionCannotBeUndone;

  /// No description provided for @cleanDataSuccessSnackBar.
  ///
  /// In en, this message translates to:
  /// **'All saved data, settings, and observing lists have been cleared.'**
  String get cleanDataSuccessSnackBar;

  /// No description provided for @selectedCoordsElevation.
  ///
  /// In en, this message translates to:
  /// **'Selected Coordinates & Elevation'**
  String get selectedCoordsElevation;

  /// No description provided for @popularAstroSites.
  ///
  /// In en, this message translates to:
  /// **'Popular Astrophotography Sites:'**
  String get popularAstroSites;

  /// No description provided for @applyLocation.
  ///
  /// In en, this message translates to:
  /// **'Apply Location'**
  String get applyLocation;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @failedLoadCore.
  ///
  /// In en, this message translates to:
  /// **'Failed to load astronomical core'**
  String get failedLoadCore;

  /// No description provided for @initializingEngine.
  ///
  /// In en, this message translates to:
  /// **'Initializing Astro Targets Engine & Database...'**
  String get initializingEngine;

  /// No description provided for @equipmentDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment Rigs & Optics'**
  String get equipmentDialogTitle;

  /// No description provided for @addEquipmentRig.
  ///
  /// In en, this message translates to:
  /// **'Add Equipment Rig'**
  String get addEquipmentRig;

  /// No description provided for @editEquipmentRig.
  ///
  /// In en, this message translates to:
  /// **'Edit Equipment Rig'**
  String get editEquipmentRig;

  /// No description provided for @backToList.
  ///
  /// In en, this message translates to:
  /// **'Back to List'**
  String get backToList;

  /// No description provided for @editRig.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get editRig;

  /// No description provided for @deleteRigTooltip.
  ///
  /// In en, this message translates to:
  /// **'Delete Rig'**
  String get deleteRigTooltip;

  /// No description provided for @createNewRig.
  ///
  /// In en, this message translates to:
  /// **'Create New Rig'**
  String get createNewRig;

  /// No description provided for @rigProfileName.
  ///
  /// In en, this message translates to:
  /// **'Rig Profile Name'**
  String get rigProfileName;

  /// No description provided for @telescopeOptics.
  ///
  /// In en, this message translates to:
  /// **'Telescope / Optics'**
  String get telescopeOptics;

  /// No description provided for @searchScopeHint.
  ///
  /// In en, this message translates to:
  /// **'Search scope: e.g. RedCat, FRA400, 72ED, C8, Seestar...'**
  String get searchScopeHint;

  /// No description provided for @telescopeName.
  ///
  /// In en, this message translates to:
  /// **'Telescope Name'**
  String get telescopeName;

  /// No description provided for @focalLengthMm.
  ///
  /// In en, this message translates to:
  /// **'Focal Length (mm)'**
  String get focalLengthMm;

  /// No description provided for @apertureMm.
  ///
  /// In en, this message translates to:
  /// **'Aperture (mm)'**
  String get apertureMm;

  /// No description provided for @reducerFactor.
  ///
  /// In en, this message translates to:
  /// **'Reducer (e.g. 0.8)'**
  String get reducerFactor;

  /// No description provided for @cameraSensor.
  ///
  /// In en, this message translates to:
  /// **'Camera / Sensor'**
  String get cameraSensor;

  /// No description provided for @searchCameraHint.
  ///
  /// In en, this message translates to:
  /// **'Search camera: e.g. ASI2600, ASI533, IMX571, Sony A7, Canon...'**
  String get searchCameraHint;

  /// No description provided for @cameraName.
  ///
  /// In en, this message translates to:
  /// **'Camera Name'**
  String get cameraName;

  /// No description provided for @sensorWidthMm.
  ///
  /// In en, this message translates to:
  /// **'Sensor Width (mm)'**
  String get sensorWidthMm;

  /// No description provided for @sensorHeightMm.
  ///
  /// In en, this message translates to:
  /// **'Sensor Height (mm)'**
  String get sensorHeightMm;

  /// No description provided for @pixelSizeMicrons.
  ///
  /// In en, this message translates to:
  /// **'Pixel Size (µm)'**
  String get pixelSizeMicrons;

  /// No description provided for @computedOpticalSpecs.
  ///
  /// In en, this message translates to:
  /// **'Computed Optical Specifications'**
  String get computedOpticalSpecs;

  /// No description provided for @effectiveFocal.
  ///
  /// In en, this message translates to:
  /// **'Effective Focal'**
  String get effectiveFocal;

  /// No description provided for @focalRatio.
  ///
  /// In en, this message translates to:
  /// **'Focal Ratio'**
  String get focalRatio;

  /// No description provided for @sensorFov.
  ///
  /// In en, this message translates to:
  /// **'Sensor FOV'**
  String get sensorFov;

  /// No description provided for @imageScale.
  ///
  /// In en, this message translates to:
  /// **'Image Scale'**
  String get imageScale;

  /// No description provided for @sampling.
  ///
  /// In en, this message translates to:
  /// **'Sampling'**
  String get sampling;

  /// No description provided for @saveRig.
  ///
  /// In en, this message translates to:
  /// **'Save Rig'**
  String get saveRig;

  /// No description provided for @gearButton.
  ///
  /// In en, this message translates to:
  /// **'Gear'**
  String get gearButton;

  /// No description provided for @switchRigTooltip.
  ///
  /// In en, this message translates to:
  /// **'Switch Equipment Rig'**
  String get switchRigTooltip;

  /// No description provided for @rigsLabel.
  ///
  /// In en, this message translates to:
  /// **'Rigs'**
  String get rigsLabel;

  /// No description provided for @manageRigsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Manage Rigs / Add Gear'**
  String get manageRigsTooltip;

  /// No description provided for @closeFramingSimulator.
  ///
  /// In en, this message translates to:
  /// **'Close Framing Simulator'**
  String get closeFramingSimulator;

  /// No description provided for @framingSimulatorTitle.
  ///
  /// In en, this message translates to:
  /// **'Equipment Framing Simulator'**
  String get framingSimulatorTitle;

  /// No description provided for @activeRigLabel.
  ///
  /// In en, this message translates to:
  /// **'Active Rig: {rigName}'**
  String activeRigLabel(String rigName);

  /// No description provided for @cameraRotatorAngle.
  ///
  /// In en, this message translates to:
  /// **'Camera Rotator Angle'**
  String get cameraRotatorAngle;

  /// No description provided for @fitToSensor.
  ///
  /// In en, this message translates to:
  /// **'Fit to Sensor'**
  String get fitToSensor;

  /// No description provided for @autoAlignTarget.
  ///
  /// In en, this message translates to:
  /// **'Align'**
  String get autoAlignTarget;

  /// No description provided for @autoAlignTargetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Auto-Align with Target Position Angle'**
  String get autoAlignTargetTooltip;

  /// No description provided for @ruleOfThirdsGrid.
  ///
  /// In en, this message translates to:
  /// **'Rule of Thirds Grid'**
  String get ruleOfThirdsGrid;

  /// No description provided for @ruleOfThirdsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Overlay composition cross-lines inside sensor frame'**
  String get ruleOfThirdsSubtitle;

  /// No description provided for @opticalSystemMetrics.
  ///
  /// In en, this message translates to:
  /// **'Optical System Metrics'**
  String get opticalSystemMetrics;

  /// No description provided for @effectiveFocalLength.
  ///
  /// In en, this message translates to:
  /// **'Effective Focal Length'**
  String get effectiveFocalLength;

  /// No description provided for @sensorFovDegrees.
  ///
  /// In en, this message translates to:
  /// **'Sensor Field of View'**
  String get sensorFovDegrees;

  /// No description provided for @sensorFovArcmin.
  ///
  /// In en, this message translates to:
  /// **'Sensor FOV (Arcmin)'**
  String get sensorFovArcmin;

  /// No description provided for @imageScalePixelSize.
  ///
  /// In en, this message translates to:
  /// **'Image Scale (Pixel Size)'**
  String get imageScalePixelSize;

  /// No description provided for @samplingDiagnosis.
  ///
  /// In en, this message translates to:
  /// **'Sampling Diagnosis'**
  String get samplingDiagnosis;

  /// No description provided for @sensorResolution.
  ///
  /// In en, this message translates to:
  /// **'Sensor Resolution'**
  String get sensorResolution;

  /// No description provided for @copyFramingInfo.
  ///
  /// In en, this message translates to:
  /// **'Copy Info'**
  String get copyFramingInfo;

  /// No description provided for @copyFramingSpecsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Copy Framing Specs (N.I.N.A. / ASIAIR / Stellarium)'**
  String get copyFramingSpecsTooltip;

  /// No description provided for @framingSpecsCopied.
  ///
  /// In en, this message translates to:
  /// **'Framing specs copied to clipboard (ready for N.I.N.A. / ASIAIR / Stellarium)'**
  String get framingSpecsCopied;

  /// No description provided for @framingPanOffset.
  ///
  /// In en, this message translates to:
  /// **'Framing Pan Offset'**
  String get framingPanOffset;

  /// No description provided for @stepSize.
  ///
  /// In en, this message translates to:
  /// **'Step Size'**
  String get stepSize;

  /// No description provided for @centered.
  ///
  /// In en, this message translates to:
  /// **'Centered'**
  String get centered;

  /// No description provided for @offsetLabel.
  ///
  /// In en, this message translates to:
  /// **'{offset}\' offset'**
  String offsetLabel(String offset);

  /// No description provided for @useArrowsToFrame.
  ///
  /// In en, this message translates to:
  /// **'Use arrows to frame off-center composition'**
  String get useArrowsToFrame;

  /// No description provided for @resetToCenter.
  ///
  /// In en, this message translates to:
  /// **'Reset to Target Center'**
  String get resetToCenter;

  /// No description provided for @darkTime.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get darkTime;

  /// No description provided for @moonPhaseNewMoon.
  ///
  /// In en, this message translates to:
  /// **'New Moon'**
  String get moonPhaseNewMoon;

  /// No description provided for @moonPhaseWaxingCrescent.
  ///
  /// In en, this message translates to:
  /// **'Waxing Crescent'**
  String get moonPhaseWaxingCrescent;

  /// No description provided for @moonPhaseFirstQuarter.
  ///
  /// In en, this message translates to:
  /// **'First Quarter'**
  String get moonPhaseFirstQuarter;

  /// No description provided for @moonPhaseWaxingGibbous.
  ///
  /// In en, this message translates to:
  /// **'Waxing Gibbous'**
  String get moonPhaseWaxingGibbous;

  /// No description provided for @moonPhaseFullMoon.
  ///
  /// In en, this message translates to:
  /// **'Full Moon'**
  String get moonPhaseFullMoon;

  /// No description provided for @moonPhaseWaningGibbous.
  ///
  /// In en, this message translates to:
  /// **'Waning Gibbous'**
  String get moonPhaseWaningGibbous;

  /// No description provided for @moonPhaseThirdQuarter.
  ///
  /// In en, this message translates to:
  /// **'Third Quarter'**
  String get moonPhaseThirdQuarter;

  /// No description provided for @moonPhaseWaningCrescent.
  ///
  /// In en, this message translates to:
  /// **'Waning Crescent'**
  String get moonPhaseWaningCrescent;

  /// No description provided for @elevationShort.
  ///
  /// In en, this message translates to:
  /// **'Elevation'**
  String get elevationShort;

  /// No description provided for @searchResultSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Lat: {lat}° | Lon: {lon}° | Elevation: {elev}m'**
  String searchResultSubtitle(String lat, String lon, String elev);

  /// No description provided for @visualSkyPreview.
  ///
  /// In en, this message translates to:
  /// **'Visual Sky Preview'**
  String get visualSkyPreview;

  /// No description provided for @noObservingListsFound.
  ///
  /// In en, this message translates to:
  /// **'No observing lists found. Create a list first!'**
  String get noObservingListsFound;

  /// No description provided for @defaultListNotes.
  ///
  /// In en, this message translates to:
  /// **'Target for imaging'**
  String get defaultListNotes;

  /// No description provided for @addToListDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add {targetName} to List'**
  String addToListDialogTitle(String targetName);

  /// No description provided for @targetObservingListLabel.
  ///
  /// In en, this message translates to:
  /// **'Target Observing List'**
  String get targetObservingListLabel;

  /// No description provided for @sessionNotesLabel.
  ///
  /// In en, this message translates to:
  /// **'Session Notes / Filters'**
  String get sessionNotesLabel;

  /// No description provided for @addBtn.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get addBtn;

  /// No description provided for @addedToObservingListSuccess.
  ///
  /// In en, this message translates to:
  /// **'Added {targetName} to observing list'**
  String addedToObservingListSuccess(String targetName);

  /// No description provided for @simbadQuerying.
  ///
  /// In en, this message translates to:
  /// **'Querying CDS / SIMBAD...'**
  String get simbadQuerying;

  /// No description provided for @simbadVerified.
  ///
  /// In en, this message translates to:
  /// **'Verified on SIMBAD: {objectType}'**
  String simbadVerified(String objectType);

  /// No description provided for @simbadNotFound.
  ///
  /// In en, this message translates to:
  /// **'No additional online records found.'**
  String get simbadNotFound;

  /// No description provided for @removeFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Remove from Favorites'**
  String get removeFromFavorites;

  /// No description provided for @addToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Add to Favorites'**
  String get addToFavorites;

  /// No description provided for @addedToFavorites.
  ///
  /// In en, this message translates to:
  /// **'Added {targetName} to Favorites'**
  String addedToFavorites(String targetName);

  /// No description provided for @removedFromFavorites.
  ///
  /// In en, this message translates to:
  /// **'Removed {targetName} from Favorites'**
  String removedFromFavorites(String targetName);

  /// No description provided for @closeDetailsTooltip.
  ///
  /// In en, this message translates to:
  /// **'Close details (Esc)'**
  String get closeDetailsTooltip;

  /// No description provided for @closeBtn.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get closeBtn;

  /// No description provided for @transitTimeMetric.
  ///
  /// In en, this message translates to:
  /// **'Transit Time'**
  String get transitTimeMetric;

  /// No description provided for @visibleDurationMetric.
  ///
  /// In en, this message translates to:
  /// **'Visible Duration'**
  String get visibleDurationMetric;

  /// No description provided for @moonDistanceMetric.
  ///
  /// In en, this message translates to:
  /// **'Moon Distance'**
  String get moonDistanceMetric;

  /// No description provided for @apparentSizeMetric.
  ///
  /// In en, this message translates to:
  /// **'Apparent Size'**
  String get apparentSizeMetric;

  /// No description provided for @verifyOnlineSimbad.
  ///
  /// In en, this message translates to:
  /// **'Verify Online (SIMBAD)'**
  String get verifyOnlineSimbad;

  /// No description provided for @simulatingYearlyVisibility.
  ///
  /// In en, this message translates to:
  /// **'Simulating 12-month visibility across the year...'**
  String get simulatingYearlyVisibility;

  /// No description provided for @visibleTonight.
  ///
  /// In en, this message translates to:
  /// **'Visible Tonight'**
  String get visibleTonight;

  /// No description provided for @unreachable.
  ///
  /// In en, this message translates to:
  /// **'Unreachable'**
  String get unreachable;

  /// No description provided for @notObservableFiltered.
  ///
  /// In en, this message translates to:
  /// **'Not observable with active filters'**
  String get notObservableFiltered;

  /// No description provided for @notObservableBelowLimits.
  ///
  /// In en, this message translates to:
  /// **'Not observable (below limits)'**
  String get notObservableBelowLimits;

  /// No description provided for @startsTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Starts tomorrow ({date})'**
  String startsTomorrow(String date);

  /// No description provided for @startsInDays.
  ///
  /// In en, this message translates to:
  /// **'Starts in {days} days ({date})'**
  String startsInDays(int days, String date);

  /// No description provided for @startsOnDate.
  ///
  /// In en, this message translates to:
  /// **'Starts {date}'**
  String startsOnDate(String date);

  /// No description provided for @inSeasonBelowLimits.
  ///
  /// In en, this message translates to:
  /// **'In Season · Below limits tonight'**
  String get inSeasonBelowLimits;

  /// No description provided for @offSeasonEnded.
  ///
  /// In en, this message translates to:
  /// **'Off-Season (Ended {date})'**
  String offSeasonEnded(String date);

  /// No description provided for @simulationModeLabel.
  ///
  /// In en, this message translates to:
  /// **'SIMULATION MODE:'**
  String get simulationModeLabel;

  /// No description provided for @activeFiltersMode.
  ///
  /// In en, this message translates to:
  /// **'Active Filters'**
  String get activeFiltersMode;

  /// No description provided for @fullSkyNightMode.
  ///
  /// In en, this message translates to:
  /// **'Full Sky & Night'**
  String get fullSkyNightMode;

  /// No description provided for @yearlyObservingWindow.
  ///
  /// In en, this message translates to:
  /// **'YEARLY OBSERVING WINDOW'**
  String get yearlyObservingWindow;

  /// No description provided for @yearlyDaysObservablePeak.
  ///
  /// In en, this message translates to:
  /// **'{days} days observable this year • Peak: {hours}h on {date}'**
  String yearlyDaysObservablePeak(int days, String hours, String date);

  /// No description provided for @theoreticalMaxAtTransit.
  ///
  /// In en, this message translates to:
  /// **'Theoretical max: {alt}° at transit{extra}'**
  String theoreticalMaxAtTransit(String alt, String extra);

  /// No description provided for @limitsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Limits: ≥{minAlt}° for ≥{minHours}h'**
  String limitsSubtitle(String minAlt, String minHours);

  /// No description provided for @yearRoundCircumpolar.
  ///
  /// In en, this message translates to:
  /// **'Year-Round (Circumpolar)'**
  String get yearRoundCircumpolar;

  /// No description provided for @notObservableWithFilters.
  ///
  /// In en, this message translates to:
  /// **'Not observable with current filters'**
  String get notObservableWithFilters;

  /// No description provided for @neverReachesLatitude.
  ///
  /// In en, this message translates to:
  /// **'Never reaches {minAlt}° at this latitude (Max: {maxAlt}°)'**
  String neverReachesLatitude(String minAlt, String maxAlt);

  /// No description provided for @clearSearchTooltip.
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get clearSearchTooltip;

  /// No description provided for @searchTargetTooltip.
  ///
  /// In en, this message translates to:
  /// **'Search target'**
  String get searchTargetTooltip;

  /// No description provided for @windowFullDarkness.
  ///
  /// In en, this message translates to:
  /// **'Window: Darkness (Full Night)'**
  String get windowFullDarkness;

  /// No description provided for @targetsFoundCount.
  ///
  /// In en, this message translates to:
  /// **'{count} targets found'**
  String targetsFoundCount(int count);

  /// No description provided for @showingMatchingOnly.
  ///
  /// In en, this message translates to:
  /// **'Showing only targets matching active filters tonight.'**
  String get showingMatchingOnly;

  /// No description provided for @searchIncludesOutsideFilters.
  ///
  /// In en, this message translates to:
  /// **'Search includes targets outside active filters tonight. Click any target to view its yearly window.'**
  String get searchIncludesOutsideFilters;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get showAll;

  /// No description provided for @hideNonMatching.
  ///
  /// In en, this message translates to:
  /// **'Hide Non-Matching'**
  String get hideNonMatching;

  /// No description provided for @visibleDurationShort.
  ///
  /// In en, this message translates to:
  /// **'{hours}h visible'**
  String visibleDurationShort(String hours);

  /// No description provided for @visibleDurationAbove.
  ///
  /// In en, this message translates to:
  /// **'{hours}h above {alt}°'**
  String visibleDurationAbove(String hours, String alt);

  /// No description provided for @outsideFilters.
  ///
  /// In en, this message translates to:
  /// **'Outside Filters'**
  String get outsideFilters;

  /// No description provided for @outsideActiveFilters.
  ///
  /// In en, this message translates to:
  /// **'Outside Active Filters'**
  String get outsideActiveFilters;

  /// No description provided for @belowZero.
  ///
  /// In en, this message translates to:
  /// **'Below 0°'**
  String get belowZero;

  /// No description provided for @belowHorizon.
  ///
  /// In en, this message translates to:
  /// **'Below Horizon'**
  String get belowHorizon;

  /// No description provided for @peakAltitudeShort.
  ///
  /// In en, this message translates to:
  /// **'Peak: {alt}°'**
  String peakAltitudeShort(String alt);

  /// No description provided for @moonSeparationShort.
  ///
  /// In en, this message translates to:
  /// **'Moon: {sep}°'**
  String moonSeparationShort(String sep);

  /// No description provided for @selectSkySurveyTooltip.
  ///
  /// In en, this message translates to:
  /// **'Select Sky Survey'**
  String get selectSkySurveyTooltip;

  /// No description provided for @openFramingSimulatorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Open Full Framing Simulator'**
  String get openFramingSimulatorTooltip;

  /// No description provided for @framingSimulatorShort.
  ///
  /// In en, this message translates to:
  /// **'Simulator'**
  String get framingSimulatorShort;

  /// No description provided for @toggleFramingBoxTooltip.
  ///
  /// In en, this message translates to:
  /// **'Toggle Sensor Framing Box'**
  String get toggleFramingBoxTooltip;

  /// No description provided for @framingModeShort.
  ///
  /// In en, this message translates to:
  /// **'Framing'**
  String get framingModeShort;

  /// No description provided for @photoReticleTooltip.
  ///
  /// In en, this message translates to:
  /// **'Photo + Reticle'**
  String get photoReticleTooltip;

  /// No description provided for @photoCleanTooltip.
  ///
  /// In en, this message translates to:
  /// **'Photo Mode (Clean Image)'**
  String get photoCleanTooltip;

  /// No description provided for @vectorSizeTooltip.
  ///
  /// In en, this message translates to:
  /// **'Vector Apparent Size'**
  String get vectorSizeTooltip;

  /// No description provided for @zoomOutTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom Out (Wider FOV)'**
  String get zoomOutTooltip;

  /// No description provided for @zoomInTooltip.
  ///
  /// In en, this message translates to:
  /// **'Zoom In (Closer FOV)'**
  String get zoomInTooltip;

  /// No description provided for @resetFovTooltip.
  ///
  /// In en, this message translates to:
  /// **'Reset Framing FOV'**
  String get resetFovTooltip;

  /// No description provided for @rotateMinus15.
  ///
  /// In en, this message translates to:
  /// **'Rotate -15°'**
  String get rotateMinus15;

  /// No description provided for @rotatePlus15.
  ///
  /// In en, this message translates to:
  /// **'Rotate +15°'**
  String get rotatePlus15;

  /// No description provided for @fitFovToSensorTooltip.
  ///
  /// In en, this message translates to:
  /// **'Fit FOV to Sensor Size'**
  String get fitFovToSensorTooltip;

  /// No description provided for @offlineSkyFallback.
  ///
  /// In en, this message translates to:
  /// **'Offline Sky Fallback'**
  String get offlineSkyFallback;

  /// No description provided for @noAltitudeData.
  ///
  /// In en, this message translates to:
  /// **'No altitude data available for window'**
  String get noAltitudeData;

  /// No description provided for @altitudeVsTimeTarget.
  ///
  /// In en, this message translates to:
  /// **'Altitude vs. Time: {targetName}'**
  String altitudeVsTimeTarget(String targetName);

  /// No description provided for @astronomicalDarknessLabel.
  ///
  /// In en, this message translates to:
  /// **'ASTRONOMICAL DARKNESS'**
  String get astronomicalDarknessLabel;

  /// No description provided for @observingWindowLabel.
  ///
  /// In en, this message translates to:
  /// **'OBSERVING WINDOW'**
  String get observingWindowLabel;

  /// No description provided for @settingsSectionAbout.
  ///
  /// In en, this message translates to:
  /// **'About Menelway'**
  String get settingsSectionAbout;

  /// No description provided for @aboutBtn.
  ///
  /// In en, this message translates to:
  /// **'About Menelway'**
  String get aboutBtn;

  /// No description provided for @aboutDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'About Menelway'**
  String get aboutDialogTitle;

  /// No description provided for @aboutCloseBtn.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get aboutCloseBtn;

  /// No description provided for @aboutCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by Rodrigo F. Mello'**
  String get aboutCreatedBy;

  /// No description provided for @aboutAppName.
  ///
  /// In en, this message translates to:
  /// **'Menelway Astro Planner'**
  String get aboutAppName;

  /// No description provided for @aboutNameOrigin.
  ///
  /// In en, this message translates to:
  /// **'“Menelway” = “Menel” (Elvish/Tolkien for Skies/Heavens) + Arroway (from the Contact book/movie)'**
  String get aboutNameOrigin;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'pt'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'pt':
      return AppLocalizationsPt();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
