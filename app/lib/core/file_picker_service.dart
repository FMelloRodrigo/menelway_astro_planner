import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Platform-agnostic image file picker that works on Windows desktop without
/// requiring third-party native plugin symlinks or Developer Mode privileges,
/// and works natively on Android via platform storage channels.
class FilePickerService {
  static const MethodChannel _storageChannel = MethodChannel('com.astrotargets.app/storage');

  static Future<String?> pickPanoramaImage() async {
    if (Platform.isWindows) {
      try {
        final psCommand = [
          '-NoProfile',
          '-STA',
          '-Command',
          '''
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Add-Type -AssemblyName System.Windows.Forms
\$dlg = New-Object System.Windows.Forms.OpenFileDialog
\$dlg.Filter = "Panoramic / Image Files (*.jpg;*.jpeg;*.png;*.webp)|*.jpg;*.jpeg;*.png;*.webp|All Files (*.*)|*.*"
\$dlg.Title = "Select Panorama Background Image"
\$dlg.RestoreDirectory = \$true
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$dlg.FileName
}
''',
        ];

        final result = await Process.run(
          'powershell',
          psCommand,
          stdoutEncoding: utf8,
          stderrEncoding: utf8,
        );
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty && File(path).existsSync()) {
            return path;
          }
        }
      } catch (e) {
        debugPrint('Windows file picker error: $e');
      }
    } else if (Platform.isAndroid) {
      try {
        final String? path = await _storageChannel.invokeMethod<String>('pickImage');
        if (path != null && path.isNotEmpty && File(path).existsSync()) {
          return path;
        }
      } catch (e) {
        debugPrint('Android file picker error: $e');
      }
    }
    return null;
  }
}

