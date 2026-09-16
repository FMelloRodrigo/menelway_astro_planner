import 'app_localizations.dart';

/// Helper to translate astronomical object types from canonical DB strings into the user's active language.
String localizeObjectType(String rawType, AppLocalizations? l10n) {
  if (l10n == null) return rawType;
  switch (rawType) {
    case 'Galaxy':
      return l10n.objGalaxy;
    case 'Planetary Nebula':
      return l10n.objPlanetaryNebula;
    case 'Bright Nebula':
      return l10n.objBrightNebula;
    case 'Dark Nebula':
      return l10n.objDarkNebula;
    case 'Open Cluster':
      return l10n.objOpenCluster;
    case 'Globular Cluster':
      return l10n.objGlobularCluster;
    case 'Supernova Remnant':
      return l10n.objSupernovaRemnant;
    case 'Star':
      return l10n.objStar;
    case 'Double Star':
      return l10n.objDoubleStar;
    case 'Asterism':
      return l10n.objAsterism;
    default:
      return rawType;
  }
}
