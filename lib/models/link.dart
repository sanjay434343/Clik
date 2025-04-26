class Link {
  final int? id;
  final String url;
  final String title;
  final String description;
  final String tags;
  final DateTime createdAt;
  final bool isArchived;
  final bool isDeleted;
  final bool isPinned;
  final bool isFavorite;
  String? cachedContent;
  String? cachedSummary;

  Link({
    this.id,
    required this.url,
    required this.title,
    required this.description,
    required this.tags,
    DateTime? createdAt,
    this.isArchived = false,
    this.isDeleted = false,
    this.isPinned = false,
    this.isFavorite = false,
    this.cachedContent,
    this.cachedSummary,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'url': url,
      'title': title,
      'description': description,
      'tags': tags,
      'createdAt': createdAt.toIso8601String(),
      'isArchived': isArchived ? 1 : 0,
      'isDeleted': isDeleted ? 1 : 0,
      'isPinned': isPinned ? 1 : 0,
      'isFavorite': isFavorite ? 1 : 0,
      'cached_content': cachedContent,
      'cached_summary': cachedSummary,
    };
  }

  factory Link.fromMap(Map<String, dynamic> map) {
    return Link(
      id: map['id'],
      url: map['url'],
      title: map['title'],
      description: map['description'],
      tags: map['tags'],
      createdAt: DateTime.parse(map['createdAt']),
      isArchived: map['isArchived'] == 1,
      isDeleted: map['isDeleted'] == 1,
      isPinned: map['isPinned'] == 1,
      isFavorite: map['isFavorite'] == 1,
      cachedContent: map['cached_content'],
      cachedSummary: map['cached_summary'],
    );
  }
}
