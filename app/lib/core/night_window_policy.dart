import '../models/filter_state.dart';
import '../models/night_summary.dart';

/// Represents an observing time window range in UTC Unix seconds.
class ObservingWindowRange {
  final int startUtcSeconds;
  final int endUtcSeconds;

  const ObservingWindowRange({
    required this.startUtcSeconds,
    required this.endUtcSeconds,
  });
}

/// Pure domain policy determining effective observing windows based on
/// astronomical twilight, custom time windows, and polar night fallbacks.
class NightWindowPolicy {
  /// Computes the effective observing window in Unix UTC seconds
  /// based on whether a custom window is enabled or twilight bounds.
  static ObservingWindowRange calculateWindow({
    required FilterState filters,
    required NightSummary night,
  }) {
    int windowStartUtc;
    int windowEndUtc;

    if (filters.useCustomTimeWindow) {
      final startDt = filters.getWindowStart(filters.date);
      final endDt = filters.getWindowEnd(filters.date);
      windowStartUtc = startDt.toUtc().millisecondsSinceEpoch ~/ 1000;
      windowEndUtc = endDt.toUtc().millisecondsSinceEpoch ~/ 1000;
    } else {
      if (!night.hasAstronomicalNight || night.astronomicalDawn.isBefore(night.astronomicalDusk)) {
        final start = (night.nauticalDusk.isBefore(night.nauticalDawn) && night.nauticalDusk.isAfter(night.sunset))
            ? night.nauticalDusk
            : night.sunset;
        final end = (night.nauticalDawn.isAfter(start))
            ? night.nauticalDawn
            : (night.sunrise.isAfter(start) ? night.sunrise : start.add(const Duration(hours: 8)));
        windowStartUtc = start.toUtc().millisecondsSinceEpoch ~/ 1000;
        windowEndUtc = end.toUtc().millisecondsSinceEpoch ~/ 1000;
      } else {
        windowStartUtc = night.astronomicalDusk.toUtc().millisecondsSinceEpoch ~/ 1000;
        windowEndUtc = night.astronomicalDawn.toUtc().millisecondsSinceEpoch ~/ 1000;
      }
    }

    if (windowEndUtc <= windowStartUtc) {
      windowEndUtc = windowStartUtc + 8 * 3600;
    }

    return ObservingWindowRange(
      startUtcSeconds: windowStartUtc,
      endUtcSeconds: windowEndUtc,
    );
  }
}
