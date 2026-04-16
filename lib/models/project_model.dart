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
    // Support new schema (createdAt) and old frontend schema (startDate)
    final rawDate = json['createdAt'] ?? json['startDate'];

    return ProjectModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      // Support both 'title' (direct endpoints) and 'name' (queries endpoint)
      title: json['title']?.toString() ?? json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      userId: json['userId']?.toString() ?? '',
      createdAt: rawDate != null
          ? DateTime.tryParse(rawDate.toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'title': title,
      'description': description,
      'userId': userId,
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
