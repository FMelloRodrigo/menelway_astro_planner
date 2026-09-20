import '../models/equipment_profile.dart';

/// Utility class providing search, tokenization, and multi-field matching
/// for astronomical equipment (telescopes and camera sensors).
class EquipmentSearchUtil {
  /// Splits a search query into lowercase, non-empty tokens for multi-token matching.
  static List<String> tokenize(String query) {
    final clean = query.trim().toLowerCase();
    if (clean.isEmpty) return const [];
    return clean.split(RegExp(r'\s+')).where((t) => t.isNotEmpty).toList();
  }

  /// Tests whether a telescope profile matches all provided search tokens.
  static bool matchesTelescope(TelescopeProfile telescope, Iterable<String> tokens) {
    if (tokens.isEmpty) return true;

    final nameLower = telescope.name.toLowerCase();
    final idLower = telescope.id.toLowerCase();
    final flStr = telescope.focalLengthMm.toString();
    final apStr = telescope.apertureMm.toString();

    return tokens.every((tok) =>
        nameLower.contains(tok) ||
        idLower.contains(tok) ||
        flStr.contains(tok) ||
        apStr.contains(tok));
  }

  /// Filters a list of telescope profiles matching the search query.
  static List<TelescopeProfile> searchTelescopes(
    List<TelescopeProfile> telescopes,
    String query,
  ) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return telescopes;

    return telescopes.where((t) => matchesTelescope(t, tokens)).toList();
  }

  /// Tests whether a camera profile matches all provided search tokens.
  static bool matchesCamera(CameraProfile camera, Iterable<String> tokens) {
    if (tokens.isEmpty) return true;

    final nameLower = camera.name.toLowerCase();
    final idLower = camera.id.toLowerCase();
    final pxStr = camera.pixelSizeMicrons.toString();

    return tokens.every((tok) =>
        nameLower.contains(tok) ||
        idLower.contains(tok) ||
        pxStr.contains(tok));
  }

  /// Filters a list of camera profiles matching the search query.
  static List<CameraProfile> searchCameras(
    List<CameraProfile> cameras,
    String query,
  ) {
    final tokens = tokenize(query);
    if (tokens.isEmpty) return cameras;

    return cameras.where((c) => matchesCamera(c, tokens)).toList();
  }
}
