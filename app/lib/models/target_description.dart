class TargetDescription {
  final String title;
  final String description;
  final String extract;
  final String? thumbnailUrl;
  final String? pageUrl;
  final String source;

  const TargetDescription({
    required this.title,
    this.description = '',
    required this.extract,
    this.thumbnailUrl,
    this.pageUrl,
    this.source = 'Wikipedia',
  });

  factory TargetDescription.fromJson(Map<String, dynamic> json) {
    return TargetDescription(
      title: json['title'] as String? ?? '',
      description: json['description'] as String? ?? '',
      extract: json['extract'] as String? ?? '',
      thumbnailUrl: (json['thumbnail_url'] as String?)?.isNotEmpty == true
          ? json['thumbnail_url'] as String
          : (json['thumbnail'] is Map ? json['thumbnail']['source'] as String? : null),
      pageUrl: (json['page_url'] as String?)?.isNotEmpty == true
          ? json['page_url'] as String
          : (json['content_urls'] is Map && json['content_urls']['desktop'] is Map
              ? json['content_urls']['desktop']['page'] as String?
              : null),
      source: json['source'] as String? ?? 'Wikipedia',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'extract': extract,
      'thumbnail_url': thumbnailUrl ?? '',
      'page_url': pageUrl ?? '',
      'source': source,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TargetDescription &&
          runtimeType == other.runtimeType &&
          title == other.title &&
          extract == other.extract;

  @override
  int get hashCode => title.hashCode ^ extract.hashCode;
}
