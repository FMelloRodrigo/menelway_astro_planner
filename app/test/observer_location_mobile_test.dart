import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/core/geocoding_service.dart';
import 'package:app/l10n/app_localizations.dart';

void main() {
  testWidgets('Observer location dialog on mobile 360x640 displays results without intrinsic layout crash', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('pt', 'BR'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                key: const Key('open_dialog_btn'),
                onPressed: () {
                  final searchController = TextEditingController();
                  final latController = TextEditingController(text: '-22.2811');
                  final lonController = TextEditingController(text: '-42.5311');
                  final eleController = TextEditingController(text: '846');
                  List<GeoLocationResult> searchResults = [];

                  final addressController = TextEditingController();
                  bool isAddressSearchExpanded = true;
                  List<GeoLocationResult> addressResults = [];

                  showDialog(
                    context: context,
                    builder: (ctx) => StatefulBuilder(
                      builder: (context, setDialogState) {
                        final l10n = AppLocalizations.of(context);
                        const textColor = Colors.white;
                        const accentColor = Colors.cyan;
                        final isNarrow = MediaQuery.of(context).size.width < 600;

                        return AlertDialog(
                          insetPadding: EdgeInsets.symmetric(
                            horizontal: isNarrow ? 12 : 40,
                            vertical: isNarrow ? 16 : 24,
                          ),
                          title: Row(
                            children: [
                              const Icon(Icons.location_city_rounded, color: accentColor, size: 22),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  l10n.locationEditTitle,
                                  style: const TextStyle(color: textColor, fontSize: 17, fontWeight: FontWeight.w700),
                                ),
                              ),
                            ],
                          ),
                          content: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 520),
                            child: SingleChildScrollView(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  TextField(controller: searchController),
                                  if (searchResults.isNotEmpty) ...[
                                    Container(
                                      constraints: const BoxConstraints(maxHeight: 180),
                                      child: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            for (int idx = 0; idx < searchResults.length; idx++) ...[
                                              if (idx > 0) const Divider(height: 1),
                                              ListTile(
                                                dense: true,
                                                title: Text(searchResults[idx].displayName),
                                                subtitle: Text(
                                                  l10n.searchResultSubtitle(
                                                    searchResults[idx].latitude.toStringAsFixed(2),
                                                    searchResults[idx].longitude.toStringAsFixed(2),
                                                    searchResults[idx].elevation.round().toString(),
                                                  ),
                                                ),
                                                onTap: () {
                                                  setDialogState(() {
                                                    latController.text = searchResults[idx].latitude.toStringAsFixed(4);
                                                    lonController.text = searchResults[idx].longitude.toStringAsFixed(4);
                                                    eleController.text = searchResults[idx].elevation.round().toString();
                                                    searchResults = [];
                                                  });
                                                },
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                  if (isAddressSearchExpanded) ...[
                                    TextField(controller: addressController),
                                    if (addressResults.isNotEmpty) ...[
                                      Container(
                                        constraints: const BoxConstraints(maxHeight: 180),
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              for (int idx = 0; idx < addressResults.length; idx++) ...[
                                                if (idx > 0) const Divider(height: 1),
                                                ListTile(
                                                  dense: true,
                                                  title: Text(addressResults[idx].displayName),
                                                  subtitle: Text(
                                                    "Lat: ${addressResults[idx].latitude.toStringAsFixed(4)}° | Lon: ${addressResults[idx].longitude.toStringAsFixed(4)}°",
                                                  ),
                                                  onTap: () {
                                                    setDialogState(() {
                                                      latController.text = addressResults[idx].latitude.toStringAsFixed(4);
                                                      lonController.text = addressResults[idx].longitude.toStringAsFixed(4);
                                                      addressResults = [];
                                                    });
                                                  },
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                  ElevatedButton(
                                    key: const Key('populate_results_btn'),
                                    onPressed: () {
                                      setDialogState(() {
                                        addressResults = [
                                          const GeoLocationResult(
                                            id: 1,
                                            name: 'Rua Alberto Braune',
                                            latitude: -22.2815,
                                            longitude: -42.5312,
                                            elevation: 846,
                                            country: 'Brasil',
                                            admin1: 'Rio de Janeiro',
                                            formattedAddress: 'Rua Alberto Braune, Centro, Nova Friburgo, Brasil',
                                          ),
                                          const GeoLocationResult(
                                            id: 2,
                                            name: 'Cônego',
                                            latitude: -22.3120,
                                            longitude: -42.5410,
                                            elevation: 900,
                                            country: 'Brasil',
                                            admin1: 'Rio de Janeiro',
                                            formattedAddress: 'Cônego, Nova Friburgo, Brasil',
                                          ),
                                        ];
                                      });
                                    },
                                    child: const Text('Search'),
                                  ),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: TextField(
                                          controller: latController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: lonController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: eleController,
                                          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(ctx).pop(),
                              child: const Text('Apply Location'),
                            ),
                          ],
                        );
                      },
                    ),
                  );
                },
                child: const Text('Open'),
              );
            },
          ),
        ),
      ),
    );

    // Open dialog
    await tester.tap(find.byKey(const Key('open_dialog_btn')));
    await tester.pumpAndSettle();

    expect(find.text('Local do Observador'), findsOneWidget);

    // Populate search results (simulate searching for a specific location on mobile)
    await tester.tap(find.byKey(const Key('populate_results_btn')));
    await tester.pumpAndSettle();

    // Verify results render without any solid color error box or intrinsic dimensions crash
    expect(find.text('Rua Alberto Braune, Centro, Nova Friburgo, Brasil'), findsOneWidget);
    expect(find.text('Cônego, Nova Friburgo, Brasil'), findsOneWidget);

    // Tap a result
    await tester.tap(find.text('Rua Alberto Braune, Centro, Nova Friburgo, Brasil'));
    await tester.pumpAndSettle();

    // Results collapse and coordinates are updated
    expect(find.text('Rua Alberto Braune, Centro, Nova Friburgo, Brasil'), findsNothing);
    expect(find.text('-22.2815'), findsOneWidget);
    expect(find.text('-42.5312'), findsOneWidget);
  });
}
