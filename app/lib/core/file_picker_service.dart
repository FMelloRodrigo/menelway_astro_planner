import 'dart:io';

/// Platform-agnostic image file picker that works on Windows desktop without
/// requiring third-party native plugin symlinks or Developer Mode privileges.
class FilePickerService {
  static Future<String?> pickPanoramaImage() async {
    if (Platform.isWindows) {
      try {
        final psCommand = [
          '-NoProfile',
          '-Command',
          '''
Add-Type -AssemblyName System.Windows.Forms
\$dlg = New-Object System.Windows.Forms.OpenFileDialog
\$dlg.Filter = "Panoramic / Image Files (*.jpg;*.jpeg;*.png)|*.jpg;*.jpeg;*.png|All Files (*.*)|*.*"
\$dlg.Title = "Select Panorama Background Image"
\$dlg.RestoreDirectory = \$true
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    Write-Output \$dlg.FileName
}
''',
        ];

        final result = await Process.run('powershell', psCommand);
        if (result.exitCode == 0) {
          final path = result.stdout.toString().trim();
          if (path.isNotEmpty && File(path).existsSync()) {
            return path;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
