class SessionModel {
  final String id;
  final String projectId;
  final DateTime startTime;
  final DateTime? endTime;
  final DateTime? pausedAt;
  final int pausedDurationMs; // total ms spent paused (from backend)
  final int? durationSeconds; // optional override used locally after pause
  final List<String> taskIds;
  final bool isPaused;

  SessionModel({
    required this.id,
    required this.projectId,
    required this.startTime,
    this.endTime,
    this.pausedAt,
    this.pausedDurationMs = 0,
    this.durationSeconds,
    this.taskIds = const [],
    this.isPaused = false,
  });

  bool get isActive => endTime == null;

  Duration get duration {
    if (endTime != null) {
      // Completed: total wall time minus accumulated paused time
      if (durationSeconds != null) return Duration(seconds: durationSeconds!);
      final total = endTime!.difference(startTime);
      final paused = Duration(milliseconds: pausedDurationMs);
      final net = total - paused;
      return net.isNegative ? Duration.zero : net;
    }

    // If we have a local frozen value (set at pause time), use it
    if (durationSeconds != null) {
      if (isPaused) return Duration(seconds: durationSeconds!);
      // Running after a resume: frozen base + live elapsed since startTime
      return Duration(seconds: durationSeconds!) +
          DateTime.now().difference(startTime);
    }

    if (isPaused) {
      // Paused with no local override: use wall time up to pause start minus
      // previously accumulated paused time
      final ref = pausedAt ?? DateTime.now();
      final total = ref.difference(startTime);
      final paused = Duration(milliseconds: pausedDurationMs);
      final net = total - paused;
      return net.isNegative ? Duration.zero : net;
    }

    // Running: live wall time minus accumulated paused time
    final total = DateTime.now().difference(startTime);
    final paused = Duration(milliseconds: pausedDurationMs);
    final net = total - paused;
    return net.isNegative ? Duration.zero : net;
  }

  String get formattedDuration {
    final d = duration;
    final hours = d.inHours;
    final minutes = d.inMinutes.remainder(60);
    final seconds = d.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes.toString().padLeft(2, '0')}m';
    if (minutes > 0) return '${minutes}m ${seconds.toString().padLeft(2, '0')}s';
    return '${seconds}s';
  }

  factory SessionModel.fromJson(Map<String, dynamic> json) {
    final startRaw = json['startTime'] ?? json['currentTime'];
    final durRaw = json['totalTime'] ?? json['duration'];
    final pausedMsRaw = json['pausedDurationMs'] ?? 0;
    final pausedAtRaw = json['pausedAt'];

    // Tasks can be plain strings or objects {taskId, totalTime}
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
      pausedAt: pausedAtRaw != null
          ? DateTime.tryParse(pausedAtRaw.toString())
          : null,
      pausedDurationMs: pausedMsRaw is int
          ? pausedMsRaw
          : int.tryParse(pausedMsRaw.toString()) ?? 0,
      durationSeconds: durRaw != null
          ? (durRaw is int ? durRaw : int.tryParse(durRaw.toString()))
          : null,
      taskIds: tasks,
      // Backend stores 'isPaused'; also accept legacy 'paused'
      isPaused:
          json['isPaused'] == true || json['paused'] == true,
    );
  }

  SessionModel copyWith({
    String? id,
    String? projectId,
    DateTime? startTime,
    DateTime? endTime,
    DateTime? pausedAt,
    int? pausedDurationMs,
    int? durationSeconds,
    List<String>? taskIds,
    bool? isPaused,
  }) {
    return SessionModel(
      id: id ?? this.id,
      projectId: projectId ?? this.projectId,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      pausedAt: pausedAt ?? this.pausedAt,
      pausedDurationMs: pausedDurationMs ?? this.pausedDurationMs,
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
      if (pausedAt != null) 'pausedAt': pausedAt!.toIso8601String(),
      'pausedDurationMs': pausedDurationMs,
      if (durationSeconds != null) 'totalTime': durationSeconds,
      'taskIds': taskIds,
      'isPaused': isPaused,
    };
  }
}
