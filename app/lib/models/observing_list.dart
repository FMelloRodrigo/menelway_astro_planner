class ObservingListItemModel {
  final int listId;
  final int dsoId;
  final String name;
  final String displayName;
  final String catalog;
  final String objectType;
  final String constellation;
  final double? magnitude;
  final String notes;
  final String status;
  final int addedAt;

  ObservingListItemModel({
    required this.listId,
    required this.dsoId,
    required this.name,
    required this.displayName,
    required this.catalog,
    required this.objectType,
    required this.constellation,
    this.magnitude,
    required this.notes,
    required this.status,
    required this.addedAt,
  });

  factory ObservingListItemModel.fromJson(Map<String, dynamic> json) {
    return ObservingListItemModel(
      listId: json['list_id'] as int,
      dsoId: json['dso_id'] as int,
      name: json['name'] as String? ?? '',
      displayName: json['display_name'] as String? ?? '',
      catalog: json['catalog'] as String? ?? '',
      objectType: json['object_type'] as String? ?? '',
      constellation: json['constellation'] as String? ?? '',
      magnitude: (json['magnitude'] as num?)?.toDouble(),
      notes: json['notes'] as String? ?? '',
      status: json['status'] as String? ?? 'planned',
      addedAt: json['added_at'] as int? ?? 0,
    );
  }
}

class ObservingListModel {
  final int id;
  final String name;
  final String description;
  final String sessionDate;
  final int createdAt;
  final List<ObservingListItemModel> items;

  ObservingListModel({
    required this.id,
    required this.name,
    required this.description,
    required this.sessionDate,
    required this.createdAt,
    required this.items,
  });

  factory ObservingListModel.fromJson(Map<String, dynamic> json) {
    final itemsList = (json['items'] as List<dynamic>?)
            ?.map((e) => ObservingListItemModel.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return ObservingListModel(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      sessionDate: json['session_date'] as String? ?? '',
      createdAt: json['created_at'] as int? ?? 0,
      items: itemsList,
    );
  }
}
