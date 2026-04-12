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
    // Tasks: backend stores as [{taskId: ObjectId, totalTime: num}] or plain strings
    final rawTasks = json['taskIds'] ?? json['tasks'];
    final tasks = <String>[];
    if (rawTasks is List) {
        for (final t in rawTasks) {
            if (t is String) {
                tasks.add(t);
            } else if (t is Map) {
                final tid = t['taskId']?.toString() ?? t['_id']?.toString();
                if (tid != null && tid.isNotEmpty) tasks.add(tid);
            }
        }
    }

    // Start time: backend uses 'currentTime' (set on creation, updated on resume)
    DateTime startTime = DateTime.now();
    for (final key in ['startTime', 'startedAt', 'currentTime']) {
        if (json[key] != null) {
            startTime = DateTime.tryParse(json[key].toString()) ?? startTime;
            break;
        }
    }

    // Duration: backend uses 'totalTime' in seconds
    int? durationSecs;
    final rawTotal = json['totalTime'] ?? json['duration'] ?? json['durationSeconds'];
    if (rawTotal is num) durationSecs = rawTotal.toInt();

    // End time + active state
    DateTime? endTime;
    if (json['endTime'] != null) {
        endTime = DateTime.tryParse(json['endTime'].toString());
    }
    // Backend marks sessions inactive with active: false
    if (json['active'] == false && endTime == null) {
        endTime = DateTime.now();
    }

    return SessionModel(
        id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
        projectId: json['projectId']?.toString() ?? '',
        startTime: startTime,
        endTime: endTime,
        durationSeconds: durationSecs,
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
