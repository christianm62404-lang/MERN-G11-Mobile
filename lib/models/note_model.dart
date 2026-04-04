enum NoteParentType { project, task, session }

class NoteModel {
  final String id;
  final String content;
  final NoteParentType parentType;
  final String parentId;
  final DateTime createdAt;

  NoteModel({
    required this.id,
    required this.content,
    required this.parentType,
    required this.parentId,
    required this.createdAt,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    NoteParentType type;
    switch (json['parentType']) {
      case 'task':
        type = NoteParentType.task;
        break;
      case 'session':
        type = NoteParentType.session;
        break;
      default:
        type = NoteParentType.project;
    }

    return NoteModel(
      id: json['_id'] ?? json['id'] ?? '',
      content: json['content'] ?? '',
      parentType: type,
      parentId: json['parentId'] ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get parentTypeString {
    switch (parentType) {
      case NoteParentType.task:
        return 'task';
      case NoteParentType.session:
        return 'session';
      case NoteParentType.project:
        return 'project';
    }
  }
}
