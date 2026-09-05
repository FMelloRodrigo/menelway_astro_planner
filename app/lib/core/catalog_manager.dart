import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

class CatalogManager {
  static const String dbFileName = 'catalogs.db';

  /// Ensures that the local database file exists on disk and returns its absolute path.
  static Future<String> getDatabasePath() async {
    // 1. Check next to executable (Windows desktop portable release)
    final exeDir = p.dirname(Platform.resolvedExecutable);
    final portablePath = p.join(exeDir, dbFileName);
    if (await File(portablePath).exists()) {
      return portablePath;
    }

    // 2. Check in data/flutter_assets/assets/catalogs.db (Flutter Windows bundle)
    final bundledAssetPath = p.join(exeDir, 'data', 'flutter_assets', 'assets', dbFileName);
    if (await File(bundledAssetPath).exists()) {
      return bundledAssetPath;
    }

    // 3. Check in current working directory / core / assets
    final localAsset = p.join(Directory.current.path, 'assets', dbFileName);
    if (await File(localAsset).exists()) {
      return localAsset;
    }

    final coreDataPath = p.join(Directory.current.path, '..', 'core', 'data', dbFileName);
    if (await File(coreDataPath).exists()) {
      return p.canonicalize(coreDataPath);
    }

    // 4. Fallback for mobile / app data directory
    final appDir = Platform.isAndroid
        ? Directory('/data/data/com.astrotargets.app/files')
        : Directory(p.join(Platform.environment['LOCALAPPDATA'] ?? '.', 'AstroTargetsTool'));

    if (!await appDir.exists()) {
      await appDir.create(recursive: true);
    }

    final targetFile = File(p.join(appDir.path, dbFileName));
    if (!await targetFile.exists()) {
      // Unpack from Flutter asset
      final byteData = await rootBundle.load('assets/$dbFileName');
      final buffer = byteData.buffer;
      await targetFile.writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
      );
    }

    return targetFile.path;
  }

  /// Returns size of the local database in megabytes.
  static Future<double> getDatabaseSizeMb() async {
    try {
      final path = await getDatabasePath();
      final f = File(path);
      if (await f.exists()) {
        final bytes = await f.length();
        return bytes / (1024.0 * 1024.0);
      }
    } catch (_) {}
    return 0.0;
  }

  /// Queries the public CDS Sesame resolver for astronomical objects online.
  static Future<Map<String, dynamic>?> queryOnlineObject(String targetName) async {
    try {
      final encoded = Uri.encodeComponent(targetName.trim());
      final url = Uri.parse('https://cds.unistra.fr/cgi-bin/nph-sesame/-oxp/SNVA?$encoded');
      final response = await http.get(url).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = response.body;
        // Simple XML/text parsing for jradeg (RA) and jdedeg (Dec)
        final raMatch = RegExp(r'<jradeg>([\d\.\+\-]+)</jradeg>').firstMatch(body);
        final decMatch = RegExp(r'<jdedeg>([\d\.\+\-]+)</jdedeg>').firstMatch(body);
        final otypeMatch = RegExp(r'<otype>([^<]+)</otype>').firstMatch(body);

        if (raMatch != null && decMatch != null) {
          final raDeg = double.parse(raMatch.group(1)!);
          final decDeg = double.parse(decMatch.group(1)!);
          final otype = otypeMatch?.group(1) ?? 'Astronomical Object';

          return {
            'name': targetName,
            'ra_deg': raDeg,
            'dec_deg': decDeg,
            'object_type': otype,
            'source': 'CDS / SIMBAD (Online)',
          };
        }
      }
    } catch (_) {
      // Network or parsing error
    }
    return null;
  }
}
