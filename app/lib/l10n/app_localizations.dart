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
  /// **'Type city (e.g. Campinas, London, Atacama, Tokyo)...'**
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
