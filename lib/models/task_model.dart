class TaskModel {
  final String id;
  final String projectId;
  final String name;
  final String description;
  final DateTime createdAt;

  TaskModel({
    required this.id,
    required this.projectId,
    required this.name,
    required this.description,
    required this.createdAt,
  });

  factory TaskModel.fromJson(Map<String, dynamic> json) {
    return TaskModel(
      id: json['_id'] ?? json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'projectId': projectId,
      'name': name,
      'description': description,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  TaskModel copyWith({
    String? id,
    String? projectId,
    String? name,
    String? description,
    DateTime? createdAt,
  }) {
    return TaskModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      name: name ?? this.name,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
