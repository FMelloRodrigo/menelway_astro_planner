import 'package:flutter_test/flutter_test.dart';
import 'package:app/models/observing_list.dart';
import 'package:app/models/target_item.dart';
import 'package:app/services/csv_export_service.dart';

void main() {
  group('CsvExportService', () {
    test('escapeCsvCell correctly adheres to RFC 4180 escaping rules', () {
      expect(CsvExportService.escapeCsvCell(null), '');
      expect(CsvExportService.escapeCsvCell(''), '');
      expect(CsvExportService.escapeCsvCell('SimpleText'), 'SimpleText');
      expect(CsvExportService.escapeCsvCell('Field, with comma'), '"Field, with comma"');
      expect(CsvExportService.escapeCsvCell('Field "with" quotes'), '"Field ""with"" quotes"');
      expect(CsvExportService.escapeCsvCell('Line1\nLine2'), '"Line1\nLine2"');
      expect(CsvExportService.escapeCsvCell('Line1\r\nLine2'), '"Line1\r\nLine2"');
      expect(CsvExportService.escapeCsvCell('Comma, "and" quote\nnewline'), '"Comma, ""and"" quote\nnewline"');
      expect(CsvExportService.escapeCsvCell(42), '42');
      expect(CsvExportService.escapeCsvCell(3.1415), '3.1415');
    });

    test('exportFavoritesCsv generates RFC 4180 compliant CSV', () {
      final items = [
        TargetItem(
          id: 1,
          name: 'M42',
          commonName: 'Great, Orion "Nebula"',
          catalog: 'Messier',
          objectType: 'Emission Nebula',
          constellation: 'Orion',
          raHours: 5.588,
          decDegrees: -5.391,
          magnitude: 4.0,
          majorAxisArcmin: 65.0,
          positionAngleDeg: 0.0,
          peakAltitudeDeg: 45.0,
          transitTime: DateTime(2026, 10, 3, 22, 0),
          visibleDurationHours: 6.5,
          minMoonSepDeg: 45.0,
          meetsCriteria: true,
        ),
        TargetItem(
          id: 2,
          name: 'NGC 7000',
          catalog: 'NGC',
          objectType: 'HII Region',
          constellation: 'Cygnus',
          raHours: 20.98,
          decDegrees: 44.53,
          magnitude: null,
          majorAxisArcmin: 120.0,
          positionAngleDeg: null,
          peakAltitudeDeg: 60.0,
          transitTime: DateTime(2026, 10, 3, 20, 15),
          visibleDurationHours: 4.0,
          minMoonSepDeg: 60.0,
          meetsCriteria: true,
        ),
      ];

      final csv = CsvExportService.exportFavoritesCsv(items);
      final lines = csv.trim().split('\n');

      expect(lines.length, 3);
      expect(lines[0].trim(), 'Name,Catalog,Type,Constellation,RA_Hours,Dec_Deg,Magnitude,Size_Arcmin,PositionAngle_Deg');
      expect(lines[1].trim(), '"M42 (Great, Orion ""Nebula"")",Messier,Emission Nebula,Orion,5.5880,-5.3910,4.00,65.0,0.0');
      expect(lines[2].trim(), 'NGC 7000,NGC,HII Region,Cygnus,20.9800,44.5300,,120.0,');
    });

    test('exportObservingListCsv generates RFC 4180 compliant CSV with notes and statuses', () {
      final list = ObservingListModel(
        id: 10,
        name: 'Autumn Showcase',
        description: 'Selected targets for October',
        sessionDate: '2026-10-03',
        createdAt: 1600000000,
        items: [
          ObservingListItemModel(
            listId: 10,
            dsoId: 1,
            catalog: 'Messier',
            name: 'M31',
            displayName: 'Andromeda Galaxy',
            objectType: 'Spiral Galaxy',
            constellation: 'Andromeda',
            magnitude: 3.44,
            notes: 'Requires dual-band filter, wide FOV',
            status: 'Planned',
            addedAt: 1600000010,
          ),
          ObservingListItemModel(
            listId: 10,
            dsoId: 2,
            catalog: 'NGC',
            name: 'NGC 869',
            displayName: 'Double Cluster',
            objectType: 'Open Cluster',
            constellation: 'Perseus',
            magnitude: 5.3,
            notes: 'Completed 60x120s subs.',
            status: 'Completed',
            addedAt: 1600000020,
          ),
        ],
      );

      final csv = CsvExportService.exportObservingListCsv(list);
      final lines = csv.trim().split('\n');

      expect(lines.length, 3);
      expect(lines[0].trim(), 'Catalog Name,Display Name,Catalog,Type,Constellation,Magnitude,Notes,Status');
      expect(lines[1].trim(), 'M31,Andromeda Galaxy,Messier,Spiral Galaxy,Andromeda,3.44,"Requires dual-band filter, wide FOV",Planned');
      expect(lines[2].trim(), 'NGC 869,Double Cluster,NGC,Open Cluster,Perseus,5.3,Completed 60x120s subs.,Completed');
    });
  });
}
