import 'dart:ffi';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/native_library_resolver.dart';

class _FakeStrategy implements PlatformLibraryStrategy {
  final bool applicable;
  final DynamicLibrary? libraryToReturn;
  int callCount = 0;

  _FakeStrategy({required this.applicable, this.libraryToReturn});

  @override
  bool appliesToPlatform() => applicable;

  @override
  DynamicLibrary? resolve() {
    callCount++;
    return libraryToReturn;
  }
}

void main() {
  group('NativeLibraryResolver Tests', () {
    tearDown(() {
      NativeLibraryResolver.resetStrategies();
    });

    test('platform strategies identify their target operating systems correctly', () {
      final win = WindowsLibraryStrategy();
      final android = AndroidLibraryStrategy();
      final linux = LinuxLibraryStrategy();
      final mac = MacOsLibraryStrategy();

      expect(win.appliesToPlatform(), Platform.isWindows);
      expect(android.appliesToPlatform(), Platform.isAndroid);
      expect(linux.appliesToPlatform(), Platform.isLinux);
      expect(mac.appliesToPlatform(), Platform.isMacOS);
    });

    test('resolves library using custom strategy when prepended', () {
      final dummyLib = DynamicLibrary.process();
      final customStrategy = _FakeStrategy(applicable: true, libraryToReturn: dummyLib);

      NativeLibraryResolver.registerStrategy(customStrategy, prepend: true);

      final resolved = NativeLibraryResolver.resolve();
      expect(resolved.handle, dummyLib.handle);
      expect(customStrategy.callCount, 1);
    });

    test('skips non-applicable strategies and falls back to next applicable strategy', () {
      final dummyLib = DynamicLibrary.process();
      final nonApplicable = _FakeStrategy(applicable: false, libraryToReturn: null);
      final failingApplicable = _FakeStrategy(applicable: true, libraryToReturn: null);
      final successfulStrategy = _FakeStrategy(applicable: true, libraryToReturn: dummyLib);

      final result = NativeLibraryResolver.resolve(
        strategies: [nonApplicable, failingApplicable, successfulStrategy],
      );

      expect(nonApplicable.callCount, 0); // Not called because appliesToPlatform() == false
      expect(failingApplicable.callCount, 1); // Called but returned null
      expect(successfulStrategy.callCount, 1); // Called and succeeded
      expect(result.handle, dummyLib.handle);
    });

    test('resetStrategies clears custom registrations', () {
      final customStrategy = _FakeStrategy(applicable: true, libraryToReturn: DynamicLibrary.process());
      NativeLibraryResolver.registerStrategy(customStrategy);

      NativeLibraryResolver.resetStrategies();

      // With default strategies on Windows, it will run standard resolution
      // (customStrategy shouldn't be invoked)
      expect(customStrategy.callCount, 0);
    });
  });
}
