import 'dart:ffi';
import 'dart:io';
import 'package:path/path.dart' as p;

import 'app_logger.dart';

/// Strategy interface for resolving and loading the native C++ dynamic library
/// (`astro_core`) across different host operating systems and runtimes.
abstract class PlatformLibraryStrategy {
  /// Whether this strategy applies to the current host runtime platform.
  bool appliesToPlatform();

  /// Attempts to resolve and open the native dynamic library.
  /// Returns `null` if resolution fails, allowing subsequent strategies to execute.
  DynamicLibrary? resolve();
}

/// Strategy for resolving `astro_core.dll` on Windows desktop.
class WindowsLibraryStrategy implements PlatformLibraryStrategy {
  static const String _tag = 'WindowsLibraryStrategy';

  @override
  bool appliesToPlatform() => Platform.isWindows;

  @override
  DynamicLibrary? resolve() {
    // 1. Try standard DLL load (same directory as .exe)
    try {
      return DynamicLibrary.open('astro_core.dll');
    } catch (e) {
      AppLogger.debug('Standard DLL load (astro_core.dll) failed: $e', tag: _tag);
    }

    // 2. Try path relative to executable
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final dllPath = p.join(exeDir, 'astro_core.dll');
      if (File(dllPath).existsSync()) {
        return DynamicLibrary.open(dllPath);
      }
    } catch (e) {
      AppLogger.debug('Executable-relative DLL load failed: $e', tag: _tag);
    }

    // 3. Try build output from core/build/Release (development mode)
    try {
      final devDll = p.join(Directory.current.path, '..', 'core', 'build', 'Release', 'astro_core.dll');
      if (File(devDll).existsSync()) {
        return DynamicLibrary.open(p.canonicalize(devDll));
      }

      final devDllAlt = p.join(Directory.current.path, 'core', 'build', 'Release', 'astro_core.dll');
      if (File(devDllAlt).existsSync()) {
        return DynamicLibrary.open(p.canonicalize(devDllAlt));
      }
    } catch (e) {
      AppLogger.debug('Dev build DLL load failed: $e', tag: _tag);
    }

    // 4. Fallback attempt
    try {
      return DynamicLibrary.open('astro_core.dll');
    } catch (e) {
      AppLogger.debug('Final Windows DLL fallback failed: $e', tag: _tag);
      return null;
    }
  }
}

/// Strategy for resolving `libastro_core.so` on Android.
class AndroidLibraryStrategy implements PlatformLibraryStrategy {
  static const String _tag = 'AndroidLibraryStrategy';

  @override
  bool appliesToPlatform() => Platform.isAndroid;

  @override
  DynamicLibrary? resolve() {
    try {
      return DynamicLibrary.open('libastro_core.so');
    } catch (e) {
      AppLogger.debug('Android native library load failed: $e', tag: _tag);
      return null;
    }
  }
}

/// Strategy for resolving `libastro_core.so` on Linux desktop.
class LinuxLibraryStrategy implements PlatformLibraryStrategy {
  static const String _tag = 'LinuxLibraryStrategy';

  @override
  bool appliesToPlatform() => Platform.isLinux;

  @override
  DynamicLibrary? resolve() {
    // 1. Check relative to executable
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final localSo = p.join(exeDir, 'libastro_core.so');
      if (File(localSo).existsSync()) {
        return DynamicLibrary.open(localSo);
      }
    } catch (e) {
      AppLogger.debug('Linux executable-relative library load failed: $e', tag: _tag);
    }

    // 2. Try standard system dynamic loader
    try {
      return DynamicLibrary.open('libastro_core.so');
    } catch (e) {
      AppLogger.debug('Standard Linux library load failed: $e', tag: _tag);
    }

    // 3. Try standard system lib directories
    for (final dir in ['/usr/local/lib', '/usr/lib', '/opt/astro_targets/lib']) {
      final path = p.join(dir, 'libastro_core.so');
      if (File(path).existsSync()) {
        try {
          return DynamicLibrary.open(path);
        } catch (_) {}
      }
    }

    return null;
  }
}

/// Strategy for resolving `libastro_core.dylib` on macOS desktop.
class MacOsLibraryStrategy implements PlatformLibraryStrategy {
  static const String _tag = 'MacOsLibraryStrategy';

  @override
  bool appliesToPlatform() => Platform.isMacOS;

  @override
  DynamicLibrary? resolve() {
    // 1. Try App Bundle Frameworks directory
    try {
      final exeDir = p.dirname(Platform.resolvedExecutable);
      final frameworkDylib = p.join(exeDir, '..', 'Frameworks', 'libastro_core.dylib');
      if (File(frameworkDylib).existsSync()) {
        return DynamicLibrary.open(p.canonicalize(frameworkDylib));
      }
    } catch (e) {
      AppLogger.debug('macOS Frameworks bundle library load failed: $e', tag: _tag);
    }

    // 2. Try standard loader
    try {
      return DynamicLibrary.open('libastro_core.dylib');
    } catch (e) {
      AppLogger.debug('macOS standard dylib load failed: $e', tag: _tag);
      return null;
    }
  }
}

/// Fallback strategy that resolves symbols from the current host process
/// (used for statically linked binaries or iOS).
class ProcessLibraryStrategy implements PlatformLibraryStrategy {
  static const String _tag = 'ProcessLibraryStrategy';

  @override
  bool appliesToPlatform() => Platform.isIOS || !Platform.isWindows;

  @override
  DynamicLibrary? resolve() {
    try {
      return DynamicLibrary.process();
    } catch (e) {
      AppLogger.debug('DynamicLibrary.process() fallback failed: $e', tag: _tag);
      return null;
    }
  }
}

/// Extensible dynamic library resolver implementing the Open-Closed Principle (OCP).
/// Allows registering custom strategies for new platforms or custom embedders without
/// editing existing bridge code.
class NativeLibraryResolver {
  static final List<PlatformLibraryStrategy> _customStrategies = [];

  static final List<PlatformLibraryStrategy> _defaultStrategies = [
    WindowsLibraryStrategy(),
    AndroidLibraryStrategy(),
    LinuxLibraryStrategy(),
    MacOsLibraryStrategy(),
    ProcessLibraryStrategy(),
  ];

  /// Registers a custom library resolution strategy.
  /// If [prepend] is true (default), the strategy runs before built-in strategies.
  static void registerStrategy(PlatformLibraryStrategy strategy, {bool prepend = true}) {
    if (prepend) {
      _customStrategies.insert(0, strategy);
    } else {
      _customStrategies.add(strategy);
    }
  }

  /// Clears all custom strategies and restores default configuration.
  static void resetStrategies() {
    _customStrategies.clear();
  }

  /// Resolves and returns the native dynamic library by querying registered strategies in order.
  static DynamicLibrary resolve({List<PlatformLibraryStrategy>? strategies}) {
    final searchStrategies = strategies ?? [..._customStrategies, ..._defaultStrategies];

    for (final strategy in searchStrategies) {
      if (strategy.appliesToPlatform()) {
        final lib = strategy.resolve();
        if (lib != null) {
          return lib;
        }
      }
    }

    // Final fallback to process
    return DynamicLibrary.process();
  }
}
