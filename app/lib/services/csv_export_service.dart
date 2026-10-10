import 'package:flutter/material.dart';

import '../models/observing_list.dart';
import '../models/target_item.dart';
import '../widgets/csv_export_dialog.dart';

/// Provides RFC 4180 compliant CSV serialization and export dialog presentation for astronomical targets.
class CsvExportService {
  const CsvExportService._();

  /// Escapes a single cell value adhering to RFC 4180 standards:
  /// wraps in double quotes if it contains commas, quotes, or newlines, and escapes embedded quotes as `""`.
  static String escapeCsvCell(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Generates a standardized, comma-separated CSV document from a list of [TargetItem]s.
  static String exportFavoritesCsv(List<TargetItem> items) {
    final buffer = StringBuffer();
    buffer.writeln("Name,Catalog,Type,Constellation,RA_Hours,Dec_Deg,Magnitude,Size_Arcmin,PositionAngle_Deg");
    for (final t in items) {
      final cells = [
        escapeCsvCell(t.displayName),
        escapeCsvCell(t.catalog),
        escapeCsvCell(t.objectType),
        escapeCsvCell(t.constellation),
        t.raHours.toStringAsFixed(4),
        t.decDegrees.toStringAsFixed(4),
        t.magnitude?.toStringAsFixed(2) ?? '',
        t.majorAxisArcmin?.toStringAsFixed(1) ?? '',
        t.positionAngleDeg?.toStringAsFixed(1) ?? '',
      ];
      buffer.writeln(cells.join(','));
    }
    return buffer.toString();
  }

  /// Generates a standardized, comma-separated CSV document from an [ObservingListModel].
  static String exportObservingListCsv(ObservingListModel list) {
    final buffer = StringBuffer();
    buffer.writeln("Catalog Name,Display Name,Catalog,Type,Constellation,Magnitude,Notes,Status");
    for (final item in list.items) {
      final cells = [
        escapeCsvCell(item.name),
        escapeCsvCell(item.displayName),
        escapeCsvCell(item.catalog),
        escapeCsvCell(item.objectType),
        escapeCsvCell(item.constellation),
        item.magnitude != null ? item.magnitude.toString() : '',
        escapeCsvCell(item.notes),
        escapeCsvCell(item.status),
      ];
      buffer.writeln(cells.join(','));
    }
    return buffer.toString();
  }

  /// Presents a styled modal dialog displaying exported CSV text with a one-click clipboard copy action.
  static Future<void> showCsvDialog(
    BuildContext context, {
    required String title,
    required String csvContent,
    required String copiedMessage,
  }) {
    return CsvExportDialog.show(
      context,
      title: title,
      csvContent: csvContent,
      copiedMessage: copiedMessage,
    );
  }
}
