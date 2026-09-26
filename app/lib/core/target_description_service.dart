import 'dart:convert';
import 'package:http/http.dart' as http;

import '../models/target_description.dart';
import '../models/target_item.dart';
import 'app_logger.dart';
import 'astro_engine.dart';

/// Service responsible for retrieving readable target descriptions via the
/// "Pre-Baked + Cache" architecture:
/// 1. Instant offline retrieval from local SQLite database / pre-baked catalog.
/// 2. Seamless online fetch from Wikipedia Summary API for unbaked targets,
///    automatically caching them into local storage for permanent offline use.
class TargetDescriptionService {
  static const String _tag = 'TargetDescriptionService';
  static final TargetDescriptionService _instance = TargetDescriptionService._();
  static TargetDescriptionService get instance => _instance;

  TargetDescriptionService._();

  // In-memory fast cache to avoid redundant engine queries during a session
  final Map<int, TargetDescription> _sessionCache = {};

  /// Retrieves the target description for [target].
  ///
  /// Checks the local engine first. If missing and [allowOnline] is true,
  /// fetches from the Wikipedia REST API and writes to local cache.
  Future<TargetDescription?> getDescription(
    TargetItem target, {
    AstroEngine? engine,
    bool allowOnline = true,
  }) async {
    // 1. Session Memory Cache
    if (_sessionCache.containsKey(target.id)) {
      return _sessionCache[target.id];
    }

    final eng = engine ?? AstroEngine.instance;

    // 2. Query Local Pre-baked / Cached Database
    final localCandidates = _buildLookupKeys(target);
    for (final key in localCandidates) {
      final desc = eng.getTargetDescription(key);
      if (desc != null && desc.extract.trim().isNotEmpty) {
        _sessionCache[target.id] = desc;
        return desc;
      }
    }

    // 3. Online On-Demand Fetch via Wikipedia REST API
    if (!allowOnline) return null;

    final onlineCandidates = _buildOnlineCandidates(target);
    for (final cand in onlineCandidates) {
      try {
        final desc = await _fetchWikipediaSummary(cand);
        if (desc != null && desc.extract.trim().isNotEmpty) {
          // Cache in local SQLite database for future offline usage
          try {
            eng.saveTargetDescription(desc, aliases: localCandidates);
          } catch (e) {
            AppLogger.debug('Could not cache description to engine: $e', tag: _tag);
          }

          _sessionCache[target.id] = desc;
          return desc;
        }
      } catch (e) {
        AppLogger.debug('Failed to fetch Wikipedia summary for "$cand": $e', tag: _tag);
      }
    }

    return null;
  }

  /// Clears the in-memory session cache.
  void clearSessionCache() {
    _sessionCache.clear();
  }

  List<String> _buildLookupKeys(TargetItem target) {
    final keys = <String>{};
    if (target.name.isNotEmpty) keys.add(target.name);
    if (target.messier != null && target.messier!.isNotEmpty) {
      keys.add(target.messier!);
      keys.add(target.messier!.replaceAll(' ', ''));
      final numMatch = RegExp(r'\d+').firstMatch(target.messier!);
      if (numMatch != null) {
        keys.add('Messier ${numMatch.group(0)}');
      }
    }
    if (target.caldwell != null && target.caldwell!.isNotEmpty) {
      keys.add(target.caldwell!);
      keys.add(target.caldwell!.replaceAll(' ', ''));
      final numMatch = RegExp(r'\d+').firstMatch(target.caldwell!);
      if (numMatch != null) {
        keys.add('Caldwell ${numMatch.group(0)}');
      }
    }
    if (target.arp != null && target.arp!.isNotEmpty) {
      keys.add(target.arp!);
      keys.add(target.arp!.replaceAll(' ', ''));
    }
    if (target.commonName != null && target.commonName!.isNotEmpty) {
      for (final part in target.commonName!.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) keys.add(trimmed);
      }
    }
    return keys.toList();
  }

  List<String> _buildOnlineCandidates(TargetItem target) {
    final candidates = <String>[];

    // Priority 1: Messier designation (e.g. Messier 31)
    if (target.messier != null && target.messier!.isNotEmpty) {
      final numMatch = RegExp(r'\d+').firstMatch(target.messier!);
      if (numMatch != null) {
        candidates.add('Messier ${numMatch.group(0)}');
      }
    }

    // Priority 2: Common names (e.g. Andromeda Galaxy, Ring Nebula)
    if (target.commonName != null && target.commonName!.isNotEmpty) {
      for (final part in target.commonName!.split(',')) {
        final trimmed = part.trim();
        if (trimmed.isNotEmpty) candidates.add(trimmed);
      }
    }

    // Priority 3: Catalog identifier (e.g. NGC 7000, IC 434)
    if (target.name.isNotEmpty) {
      candidates.add(target.name);
    }

    // Priority 4: Caldwell designation (e.g. Caldwell 14)
    if (target.caldwell != null && target.caldwell!.isNotEmpty) {
      final numMatch = RegExp(r'\d+').firstMatch(target.caldwell!);
      if (numMatch != null) {
        candidates.add('Caldwell ${numMatch.group(0)}');
      }
    }

    // Priority 5: Arp designation (e.g. Arp 220)
    if (target.arp != null && target.arp!.isNotEmpty) {
      candidates.add(target.arp!);
    }

    return candidates;
  }

  Future<TargetDescription?> _fetchWikipediaSummary(String title) async {
    final clean = title.trim().replaceAll(' ', '_');
    final encoded = Uri.encodeComponent(clean);
    final url = Uri.parse('https://en.wikipedia.org/api/rest_v1/page/summary/$encoded');

    final response = await http.get(
      url,
      headers: {
        'User-Agent': 'AstroTargetsTool/1.0 (Astrophotography Planner; info@astrotargets.app)',
      },
    ).timeout(const Duration(seconds: 5));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      if (data['type'] == 'disambiguation') return null;
      final extract = data['extract'] as String? ?? '';
      if (extract.trim().isNotEmpty) {
        return TargetDescription.fromJson(data);
      }
    }
    return null;
  }
}
