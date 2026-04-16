class SessionModel {
  final String id;
  final String projectId;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? pausedAt;
  final int pausedDurationMs;
  final List<String> taskIds;
  final bool isPaused;

  SessionModel({
    required this.id,
    required this.projectId,
    required this.startTime,
    this.endTime,
    this.pausedAt,
    this.pausedDurationMs = 0,
    this.taskIds = const [],
    this.isPaused = false,
  });

  bool get isActive => endTime == null;

  Duration get duration {
    final pausedOffset = Duration(milliseconds: pausedDurationMs);

    if (endTime != null) {
      final total = endTime!.difference(startTime);
      final net = total - pausedOffset;
      return net.isNegative ? Duration.zero : net;
    }

    if (isPaused) {
      final ref = pausedAt ?? DateTime.now();
      final total = ref.difference(startTime);
      final net = total - pausedOffset;
      return net.isNegative ? Duration.zero : net;
    }

    final total = DateTime.now().difference(startTime);
    final net = total - pausedOffset;
    return net.isNegative ? Duration.zero : net;
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
    final rawTasks = json['taskIds'] ?? json['tasks'] ?? const [];
    final tasks = (rawTasks as List).map<String>((e) {
      if (e is String) return e;
      if (e is Map) return (e['taskId'] ?? e['_id'] ?? '').toString();
      return e.toString();
    }).where((s) => s.isNotEmpty).toList();

    final pausedDurRaw = json['pausedDurationMs'];
    final pausedDurationMs = pausedDurRaw is int
        ? pausedDurRaw
        : int.tryParse(pausedDurRaw?.toString() ?? '') ?? 0;

    // Support new schema (startTime) and old frontend schema (currentTime)
    final rawStart = json['startTime'] ?? json['currentTime'];

    return SessionModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      startTime: rawStart != null
          ? (DateTime.tryParse(rawStart.toString())?.toLocal()) ?? DateTime.now()
          : DateTime.now(),
      endTime: json['endTime'] != null
          ? DateTime.tryParse(json['endTime'].toString())?.toLocal()
          : null,
      pausedAt: json['pausedAt'] != null
          ? DateTime.tryParse(json['pausedAt'].toString())?.toLocal()
          : null,
      pausedDurationMs: pausedDurationMs,
      taskIds: tasks,
      // Support new schema (isPaused) and old frontend schema (paused)
      isPaused: json['isPaused'] == true || json['paused'] == true,
    );
  }

  SessionModel copyWith({
    String? id,
    String? projectId,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? pausedAt,
    int? pausedDurationMs,
    List<String>? taskIds,
    bool? isPaused,
    bool clearPausedAt = false,
  }) {
    return SessionModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      pausedDurationMs: pausedDurationMs ?? this.pausedDurationMs,
      taskIds: taskIds ?? this.taskIds,
      isPaused: isPaused ?? this.isPaused,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      '_id': id,
      'projectId': projectId,
      'startTime': startTime.toUtc().toIso8601String(),
      if (endTime != null) 'endTime': endTime!.toUtc().toIso8601String(),
      if (pausedAt != null) 'pausedAt': pausedAt!.toUtc().toIso8601String(),
      'pausedDurationMs': pausedDurationMs,
      'taskIds': taskIds,
      'isPaused': isPaused,
    };
  }
}
