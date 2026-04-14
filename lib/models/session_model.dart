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

    return SessionModel(
      id: json['_id']?.toString() ?? json['id']?.toString() ?? '',
      projectId: json['projectId']?.toString() ?? '',
      // Convert backend time payloads to local timezone for correct display.
      startTime: _parseBackendDate(json['startTime']) ?? DateTime.now(),
      endTime: _parseBackendDate(json['endTime']),
      pausedAt: _parseBackendDate(json['pausedAt']),
      pausedDurationMs: pausedDurationMs,
      taskIds: tasks,
      // Backend stores isPaused (camelCase); also accept legacy 'paused'
      isPaused: json['isPaused'] == true || json['paused'] == true,
    );
  }

  static DateTime? _parseBackendDate(dynamic raw) {
    if (raw == null) return null;
    final str = raw.toString().trim();
    if (str.isEmpty) return null;

    final parsed = DateTime.tryParse(str);
    if (parsed == null) return null;

    // If the backend sends UTC without timezone suffix, treat as UTC.
    final hasZone = str.endsWith('Z') || RegExp(r'[+-]\d{2}:\d{2}$').hasMatch(str);
    if (hasZone) return parsed.toLocal();
    return DateTime.utc(
      parsed.year,
      parsed.month,
      parsed.day,
      parsed.hour,
      parsed.minute,
      parsed.second,
      parsed.millisecond,
      parsed.microsecond,
    ).toLocal();
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
