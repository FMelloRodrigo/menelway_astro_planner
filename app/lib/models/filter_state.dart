class FilterState {
  double minAltitude;
  double minDurationHours;
  DateTime date;
  double minMoonSeparation;
  double minAzimuth;
  double maxAzimuth;
  int quadrant; // 0=All, 1=N, 2=E, 3=S, 4=W, 5=NE, 6=SE, 7=SW, 8=NW
  double maxMagnitude;
  double minMagnitude;
  double minSizeArcmin;
  double maxSizeArcmin;
  Set<String> selectedCatalogs;
  Set<String> selectedObjectTypes;
  String searchQuery;

  // Observer
  double observerLat;
  double observerLon;
  double observerElevation;

  FilterState({
    this.minAltitude = 30.0,
    this.minDurationHours = 2.0,
    DateTime? date,
    this.minMoonSeparation = 15.0,
    this.minAzimuth = 0.0,
    this.maxAzimuth = 360.0,
    this.quadrant = 0,
    this.maxMagnitude = 14.0,
    this.minMagnitude = -5.0,
    this.minSizeArcmin = 0.0,
    this.maxSizeArcmin = 600.0,
    Set<String> ? selectedCatalogs,
    Set<String> ? selectedObjectTypes,
    this.searchQuery = '',
    this.observerLat = 40.7128,
    this.observerLon = -74.0060,
    this.observerElevation = 10.0,
  })  : date = date ?? DateTime.now(),
        selectedCatalogs = selectedCatalogs ?? {'Messier', 'Caldwell'},
        selectedObjectTypes = selectedObjectTypes ?? {
          'Galaxy',
          'Planetary Nebula',
          'Bright Nebula',
          'Dark Nebula',
          'Open Cluster',
          'Globular Cluster',
          'Supernova Remnant',
        };

  FilterState copyWith({
    double? minAltitude,
    double? minDurationHours,
    DateTime? date,
    double? minMoonSeparation,
    double? minAzimuth,
    double? maxAzimuth,
    int? quadrant,
    double? maxMagnitude,
    double? minMagnitude,
    double? minSizeArcmin,
    double? maxSizeArcmin,
    Set<String>? selectedCatalogs,
    Set<String>? selectedObjectTypes,
    String? searchQuery,
    double? observerLat,
    double? observerLon,
    double? observerElevation,
  }) {
    return FilterState(
      minAltitude: minAltitude ?? this.minAltitude,
      minDurationHours: minDurationHours ?? this.minDurationHours,
      date: date ?? this.date,
      minMoonSeparation: minMoonSeparation ?? this.minMoonSeparation,
      minAzimuth: minAzimuth ?? this.minAzimuth,
      maxAzimuth: maxAzimuth ?? this.maxAzimuth,
      quadrant: quadrant ?? this.quadrant,
      maxMagnitude: maxMagnitude ?? this.maxMagnitude,
      minMagnitude: minMagnitude ?? this.minMagnitude,
      minSizeArcmin: minSizeArcmin ?? this.minSizeArcmin,
      maxSizeArcmin: maxSizeArcmin ?? this.maxSizeArcmin,
      selectedCatalogs: selectedCatalogs ?? Set.from(this.selectedCatalogs),
      selectedObjectTypes: selectedObjectTypes ?? Set.from(this.selectedObjectTypes),
      searchQuery: searchQuery ?? this.searchQuery,
      observerLat: observerLat ?? this.observerLat,
      observerLon: observerLon ?? this.observerLon,
      observerElevation: observerElevation ?? this.observerElevation,
    );
  }
}
