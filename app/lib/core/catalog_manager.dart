import 'dart:io';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'app_logger.dart';

class CatalogManager {
  static const String dbFileName = 'catalogs.db';
  static const String _tag = 'CatalogManager';
  static const MethodChannel _storageChannel = MethodChannel('com.astrotargets.app/storage');

  static Future<String>? _dbPathFuture;

  /// Returns the persistent app storage directory for the current platform.
  static Future<Directory> getStorageDirectory() async {
    if (Platform.isAndroid) {
      // 1. Ask native Android host for the verified application files directory
      try {
        final String? nativeFilesDir = await _storageChannel.invokeMethod<String>('getFilesDir');
        if (nativeFilesDir != null && nativeFilesDir.isNotEmpty) {
          final dir = Directory(nativeFilesDir);
          if (!await dir.exists()) {
            await dir.create(recursive: true);
          }
          return dir;
        }
      } catch (e) {
        AppLogger.debug('Native storage channel invoke failed on Android: $e', tag: _tag);
      }

      // 2. Fallback heuristics if native channel is unavailable (e.g. headless tests)
      try {
        final parent = Directory.systemTemp.parent;
        if (parent.existsSync()) {
          final candidate = Directory(p.join(parent.path, 'files'));
          if (!candidate.existsSync()) {
            candidate.createSync(recursive: true);
          }
          if (candidate.existsSync()) {
            return candidate;
          }
        }
      } catch (e) {
        AppLogger.debug('System temp parent check fallback failed: $e', tag: _tag);
      }

      final candidates = [
        '/data/user/0/com.astrotargets.app.app/files',
        '/data/data/com.astrotargets.app.app/files',
        '/data/user/0/com.astrotargets.app/files',
        '/data/data/com.astrotargets.app/files',
      ];
      for (final pth in candidates) {
        final d = Directory(pth);
        if (d.existsSync()) {
          return d;
        }
      }
      final fallbackDir = Directory(candidates.first);
      if (!fallbackDir.existsSync()) {
        try {
          fallbackDir.createSync(recursive: true);
        } catch (e) {
          AppLogger.warning('Failed to create fallback directory on Android: $fallbackDir', tag: _tag, error: e);
        }
      }
      return fallbackDir;
    } else {
      final localAppData = Platform.environment['LOCALAPPDATA'];
      final baseDir = localAppData != null && localAppData.isNotEmpty
          ? p.join(localAppData, 'AstroTargetsTool')
          : p.join(Directory.current.path, '.astro_data');
      final dir = Directory(baseDir);
      if (!dir.existsSync()) {
        try {
          dir.createSync(recursive: true);
        } catch (e) {
          AppLogger.warning('Failed to create storage directory: $baseDir', tag: _tag, error: e);
        }
      }
      return dir;
    }
  }

  /// Ensures that the local database file exists on disk and returns its absolute path.
  static Future<String> getDatabasePath() {
    _dbPathFuture ??= _resolveDatabasePath();
    return _dbPathFuture!;
  }

  static Future<String> _resolveDatabasePath() async {
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
    final appDir = await getStorageDirectory();
    final targetFile = File(p.join(appDir.path, dbFileName));

    try {
      final byteData = await rootBundle.load('assets/$dbFileName');
      final assetSize = byteData.lengthInBytes;

      bool needsUnpack = true;
      if (await targetFile.exists()) {
        final existingSize = await targetFile.length();
        // Database is only considered valid if it matches the bundled asset size
        // and is at least 1MB
        if (existingSize == assetSize && existingSize > 1024 * 1024) {
          needsUnpack = false;
        }
      }

      if (needsUnpack) {
        final tmpFile = File(p.join(appDir.path, '$dbFileName.tmp'));
        final buffer = byteData.buffer;
        await tmpFile.writeAsBytes(
          buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes),
          flush: true,
        );

        if (await targetFile.exists()) {
          try {
            await targetFile.delete();
          } catch (e) {
            AppLogger.debug('Could not delete old target database file before replacing: $e', tag: _tag);
          }
        }
        await tmpFile.rename(targetFile.path);
      }
    } catch (e, st) {
      AppLogger.warning('Exception unpacking bundled catalog database', tag: _tag, error: e, stackTrace: st);
      if (await targetFile.exists()) {
        final len = await targetFile.length();
        if (len > 1024 * 1024) {
          return targetFile.path;
        }
      }
      rethrow;
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
    } catch (e) {
      AppLogger.warning('Error determining database file size', tag: _tag, error: e);
    }
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
      } else {
        AppLogger.warning('CDS Sesame returned status ${response.statusCode} for "$targetName"', tag: _tag);
      }
    } catch (e) {
      AppLogger.warning('Failed to query CDS Sesame online object "$targetName"', tag: _tag, error: e);
    }
    return null;
  }
}
