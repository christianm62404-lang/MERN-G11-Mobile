class SessionModel {
  final String id;
  final String projectId;
  final DateTime startTime; // maps to backend 'currentTime' (last resume time)
  final DateTime? endTime;
  final int? durationSeconds; // maps to backend 'totalTime' (accumulated seconds)
  final List<String> taskIds;
  final bool isPaused;

  SessionModel({
    required this.id,
    required this.projectId,
    required this.startTime,
    this.endTime,
    this.durationSeconds,
    this.taskIds = const [],
    this.isPaused = false,
  });

  bool get isActive => endTime == null;

  Duration get duration {
    if (endTime != null) {
      if (durationSeconds != null) return Duration(seconds: durationSeconds!);
      return endTime!.difference(startTime);
    }
    if (isPaused) {
      return Duration(seconds: durationSeconds ?? 0);
    }
    final accumulated = Duration(seconds: durationSeconds ?? 0);
    return accumulated + DateTime.now().difference(startTime);
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) {
      return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    } else if (minutes > 0) {
      return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    }
    return '${seconds}s';
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final startRaw = json['currentTime'] ?? json['startTime'];
    final durRaw = json['totalTime'] ?? json['duration'];

    final rawTasks = json['taskIds'] ?? json['tasks'] ?? const [];
    final tasks = (rawTasks as List).map<String>((e) {
      if (e is String) return e;
      if (e is Map) return (e['taskId'] ?? e['_id'] ?? '').toString();
      return e.toString();
    }).where((s) => s.isNotEmpty).toList();

    return SessionModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      startTime: startRaw != null
          ? DateTime.tryParse(startRaw.toString()) ?? DateTime.now()
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'].toString())
          : null,
      durationSeconds: durRaw != null
          ? (durRaw is int ? durRaw : int.tryParse(durRaw.toString()))
          : null,
      taskIds: tasks,
      isPaused: json['paused'] == true,
    );
  }

  SessionModel copyWith({
    String? id,
    String? projectId,
    DateTime? startTime,
    DateTime? endTime,
    int? durationSeconds,
    List<String>? taskIds,
    bool? isPaused,
  }) {
    return SessionModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      taskIds: taskIds ?? this.taskIds,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'projectId': projectId,
      'startTime': startTime.toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toIso8601String(),
      if (durationSeconds != null) 'totalTime': durationSeconds,
      'taskIds': taskIds,
      'paused': isPaused,
    };
  }
}
