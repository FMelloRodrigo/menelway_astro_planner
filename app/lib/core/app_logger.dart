import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

/// Lightweight, centralized logging utility for Astro Targets Tool.
class AppLogger {
  AppLogger._();

  static LogLevel minLogLevel = kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Custom log listener hook, useful for in-app diagnostics or telemetry.
  static void Function(LogLevel level, String tag, String message, Object? error, StackTrace? stackTrace)? onLog;

  static void debug(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.debug, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void info(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.info, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void warning(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.warning, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void error(String message, {String tag = 'App', Object? error, StackTrace? stackTrace}) {
    _log(LogLevel.error, message, tag: tag, error: error, stackTrace: stackTrace);
  }

  static void _log(
    LogLevel level,
    String message, {
    required String tag,
    Object? error,
    StackTrace? stackTrace,
  }) {
    if (level.index < minLogLevel.index) {
      return;
    }

    final levelName = level.name.toUpperCase();
    final formatted = '[$levelName][$tag] $message';

    if (kDebugMode) {
      developer.log(
        formatted,
        name: 'AstroTargets',
        level: _toDeveloperLogLevel(level),
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      if (level == LogLevel.error || level == LogLevel.warning) {
        debugPrint(formatted);
        if (error != null) debugPrint('Error: $error');
        if (stackTrace != null) debugPrint('$stackTrace');
      }
    }

    onLog?.call(level, tag, message, error, stackTrace);
  }

  static int _toDeveloperLogLevel(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return 500;
      case LogLevel.info:
        return 800;
      case LogLevel.warning:
        return 900;
      case LogLevel.error:
        return 1000;
    }
  }
}
