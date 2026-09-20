import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Lightweight platform-agnostic URL launcher that works on Windows desktop
/// without requiring third-party native plugin symlinks or Developer Mode privileges,
/// and works natively on Android via platform intent channels.
class UrlService {
  static const MethodChannel _channel = MethodChannel('com.astrotargets.app/storage');

  static Future<bool> openUrl(String url) async {
    try {
      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', url]);
        return true;
      } else if (Platform.isAndroid) {
        final res = await _channel.invokeMethod<bool>('openUrl', {'url': url});
        return res ?? false;
      } else if (Platform.isMacOS) {
        await Process.run('open', [url]);
        return true;
      } else if (Platform.isLinux) {
        await Process.run('xdg-open', [url]);
        return true;
      }
    } catch (e) {
      debugPrint('UrlService error opening URL ($url): $e');
    }
    return false;
  }
}
