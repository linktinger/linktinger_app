class Project {
  final String id;
  final String ownerId;
  final String title;
  final String description;
  final String coverImage;
  final List<String> skills;
  final DateTime createdAt;
  final int likes;
  final int views;

  Project({
    required this.id,
    required this.ownerId,
    required this.title,
    required this.description,
    required this.coverImage,
    required this.skills,
    required this.createdAt,
    this.likes = 0,
    this.views = 0,
  });

  /// ✅ copyWith لدعم التعديلات
  Project copyWith({
    String? id,
    String? ownerId,
    String? title,
    String? description,
    String? coverImage,
    List<String>? skills,
    DateTime? createdAt,
    int? likes,
    int? views,
  }) {
    return Project(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      title: title ?? this.title,
      description: description ?? this.description,
      coverImage: coverImage ?? this.coverImage,
      skills: skills ?? this.skills,
      createdAt: createdAt ?? this.createdAt,
      likes: likes ?? this.likes,
      views: views ?? this.views,
    );
  }

  factory Project.fromJson(Map<String, dynamic> json) {
    return Project(
      id: json['id'].toString(),
      ownerId: json['owner_id'].toString(),
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      coverImage: json['cover_image'] ?? '',
      skills: (json['skills'] is String)
          ? (json['skills'] as String).split(',')
          : List<String>.from(json['skills'] ?? []),
      createdAt: DateTime.parse(
        json['created_at'] ?? DateTime.now().toString(),
      ),
      likes: int.tryParse(json['likes'].toString()) ?? 0,
      views: int.tryParse(json['views'].toString()) ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'title': title,
      'description': description,
      'cover_image': coverImage,
      'skills': skills.join(','),
      'created_at': createdAt.toIso8601String(),
      'likes': likes,
      'views': views,
    };
  }
}
