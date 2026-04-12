class ProjectModel {
  final String id;
  final String title;
  final String description;
  final String userId;
  final DateTime createdAt;

  ProjectModel({
    required this.id,
    required this.title,
    required this.description,
    required this.userId,
    required this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) {
    return ProjectModel(
      id: json['_id'] ?? json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      userId: json['userId'] ?? json['id'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'id': userId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  ProjectModel copyWith({
    String? id,
    String? title,
    String? description,
    String? userId,
    DateTime? createdAt,
  }) {
    return ProjectModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      userId: userId ?? this.userId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
