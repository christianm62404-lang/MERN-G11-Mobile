class SessionModel {
  final String id;
  final String projectId;
  final DateTime startTime;
  final DateTime? endTime;
  final int? durationSeconds;
  final List<String> taskIds;

  SessionModel({
    required this.id,
    required this.projectId,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.taskIds = const [],
  });

  bool get isActive => endTime == null;

  Duration get duration {
    if (durationSeconds != null) {
      return Duration(seconds: durationSeconds!);
    }
    final end = endTime ?? DateTime.now();
    return end.difference(startTime);
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds}s';
    }
    return '${seconds}s';
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final rawTasks = json['taskIds'];
    final tasks = rawTasks is List
        ? rawTasks.map((e) => e.toString()).toList()
        : <String>[];
    return SessionModel(
      id: json['_id'] ?? json['id'] ?? '',
      projectId: json['projectId'] ?? '',
      startTime: json['startTime'] != null
          ? DateTime.tryParse(json['startTime']) ?? DateTime.now()
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'])
          : null,
      durationSeconds: json['duration'],
      taskIds: tasks,
    );
  }

  SessionModel copyWith({List<String>? taskIds}) {
    return SessionModel(
      id: id,
      projectId: projectId,
      startTime: startTime,
      endTime: endTime,
      durationSeconds: durationSeconds,
      taskIds: taskIds ?? this.taskIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'projectId': projectId,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      if (durationSeconds != null) 'duration': durationSeconds,
      'taskIds': taskIds,
    };
  }
}
