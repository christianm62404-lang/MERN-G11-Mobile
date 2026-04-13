import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class SessionProvider extends ChangeNotifier with WidgetsBindingObserver {
  List<SessionModel> _sessions = [];
  SessionModel? _activeSession;
  String? _activeProjectTitle;
  Duration? _frozenDuration;
  bool _isLoading = false;
  String? _error;
  Timer? _sessionTimer;

  List<SessionModel> get sessions => _sessions;
  SessionModel? get activeSession => _activeSession;
  String? get activeProjectTitle => _activeProjectTitle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveSession => _activeSession != null;

  bool get isPaused => _activeSession?.isPaused ?? false;
  Duration? get frozenDuration => _frozenDuration;

  SessionProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync session from backend when user returns to the app.
      // Do NOT stop the session on background — the backend keeps tracking.
      fetchStatus();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    super.dispose();
  }

  void clearData() {
    _sessions = [];
    _activeSession = null;
    _activeProjectTitle = null;
    _frozenDuration = null;
    _error = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    notifyListeners();
  }

  Future<void> fetchSessions({String? projectId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final info = await AuthService.instance.getUserInfo();
      final body = <String, dynamic>{'userId': info['userId'] ?? ''};
      if (projectId != null) body['projectId'] = projectId;

      final data = await ApiService.instance.getWithBody(
        ApiConstants.fetchManySessions,
        body: body,
      );

      final list = data is List
          ? data
          : (data is Map ? (data['sessions'] ?? []) : []);
      _sessions = (list as List)
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Restore active session if one is still running
      final active = _sessions.where((s) => s.isActive).toList();
      if (active.isNotEmpty && _activeSession == null) {
        _activeSession = active.first;
        if (!_activeSession!.isPaused) _startTimer();
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load sessions';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> fetchStatus() async {
    try {
      final data = await ApiService.instance.get(ApiConstants.sessionStatus);
      if (data is Map && data['session'] != null) {
        final synced =
            SessionModel.fromJson(data['session'] as Map<String, dynamic>);
        _activeSession = synced;
        if (!synced.isPaused) {
          _startTimer();
        } else {
          _sessionTimer?.cancel();
          _sessionTimer = null;
        }
        notifyListeners();
      } else {
        _activeSession = null;
        _sessionTimer?.cancel();
        _sessionTimer = null;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<SessionModel?> startSession(String projectId,
      {String? projectTitle}) async {
    try {
      final info = await AuthService.instance.getUserInfo();
      final userId = info['userId'] ?? '';

      final data = await ApiService.instance.post(
        ApiConstants.createSession,
        body: {'projectId': projectId, 'userId': userId},
      );

      final map = data as Map<String, dynamic>?;
      SessionModel session;
      if (map != null && map['projectId'] != null) {
        session = SessionModel.fromJson(map);
      } else {
        session = SessionModel(
          id: map?['insertedId']?.toString() ??
              map?['_id']?.toString() ??
              '',
          projectId: projectId,
          startTime: DateTime.now(),
        );
      }

      // Backend creates sessions as active (not paused), so no need to call
      // /sessions/start here — that endpoint is only for resuming paused sessions.

      _activeSession = session;
      _activeProjectTitle = projectTitle;
      _frozenDuration = null;

      final idx = _sessions.indexWhere((s) => s.id == session.id);
      if (idx == -1) {
        _sessions.insert(0, session);
      } else {
        _sessions[idx] = session;
      }

      _startTimer();
      notifyListeners();
      return session;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  /// Immediately marks the session as completed in the list (so it never
  /// disappears), then tells the backend to stop it.
  Future<SessionModel?> stopSession() async {
    if (_activeSession == null) return null;

    final stoppingSession = _activeSession!;
    final elapsed = stoppingSession.duration;
    final endTime = DateTime.now();

    // Build the completed record immediately
    final completed = SessionModel(
      id: stoppingSession.id,
      projectId: stoppingSession.projectId,
      startTime: stoppingSession.startTime,
      endTime: endTime,
      pausedDurationMs: stoppingSession.pausedDurationMs,
      durationSeconds: elapsed.inSeconds,
      taskIds: stoppingSession.taskIds,
      isPaused: false,
    );

    // Update UI immediately — session moves to completedSessions right now
    _activeSession = null;
    _activeProjectTitle = null;
    _frozenDuration = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;

    final idx = _sessions.indexWhere((s) => s.id == completed.id);
    if (idx != -1) {
      _sessions[idx] = completed;
    } else {
      _sessions.insert(0, completed);
    }
    notifyListeners();

    await NotificationService.instance.cancelAllNotifications();

    // Fire-and-forget backend call — session is already saved locally
    try {
      await ApiService.instance.get(ApiConstants.stopSession);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }

    return completed;
  }

  /// Optimistically pauses locally first, then syncs with backend.
  Future<void> pauseSession() async {
    if (_activeSession == null) return;

    _frozenDuration = _activeSession!.duration;
    _activeSession = _activeSession!.copyWith(
      isPaused: true,
      durationSeconds: _frozenDuration!.inSeconds,
    );
    _sessionTimer?.cancel();
    _sessionTimer = null;
    notifyListeners();

    try {
      final data = await ApiService.instance.get(ApiConstants.pauseSession);
      if (data != null && data is Map) {
        final updated =
            SessionModel.fromJson(data as Map<String, dynamic>);
        if (updated.id.isNotEmpty) {
          _activeSession =
              updated.isPaused ? updated : updated.copyWith(isPaused: true);
          notifyListeners();
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// Optimistically resumes locally first, then syncs with backend.
  Future<void> resumeSession() async {
    if (_activeSession == null) return;

    _activeSession = SessionModel(
      id: _activeSession!.id,
      projectId: _activeSession!.projectId,
      startTime: DateTime.now(),
      pausedDurationMs: _activeSession!.pausedDurationMs,
      durationSeconds: _activeSession!.durationSeconds,
      taskIds: _activeSession!.taskIds,
      isPaused: false,
    );
    _frozenDuration = null;
    _startTimer();
    notifyListeners();

    try {
      final data = await ApiService.instance.get(ApiConstants.startSession);
      if (data != null && data is Map) {
        final updated =
            SessionModel.fromJson(data as Map<String, dynamic>);
        if (updated.id.isNotEmpty && !updated.isPaused) {
          _activeSession = updated;
          notifyListeners();
        }
      }
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  Future<bool> addTaskToSession(String taskId) async {
    if (_activeSession == null) return false;
    try {
      await ApiService.instance.post(
        ApiConstants.addTaskToSession,
        body: {'taskId': taskId},
      );
      final updated = _activeSession!
          .copyWith(taskIds: [..._activeSession!.taskIds, taskId]);
      _activeSession = updated;
      final idx = _sessions.indexWhere((s) => s.id == updated.id);
      if (idx != -1) _sessions[idx] = updated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> removeTaskFromSession(String taskId) async {
    if (_activeSession == null) return false;
    try {
      await ApiService.instance.post(
        ApiConstants.removeTaskFromSession,
        body: {'taskId': taskId},
      );
      final updated = _activeSession!.copyWith(
          taskIds:
              _activeSession!.taskIds.where((t) => t != taskId).toList());
      _activeSession = updated;
      final idx = _sessions.indexWhere((s) => s.id == updated.id);
      if (idx != -1) _sessions[idx] = updated;
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteSession(String sessionId) async {
    try {
      await ApiService.instance
          .delete(ApiConstants.deleteSession, body: {'id': sessionId});
      _sessions.removeWhere((s) => s.id == sessionId);
      if (_activeSession?.id == sessionId) {
        _activeSession = null;
        _frozenDuration = null;
        _sessionTimer?.cancel();
        _sessionTimer = null;
      }
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  void _startTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeSession != null && !_activeSession!.isPaused) {
        notifyListeners();
        if (timer.tick % 300 == 0) {
          NotificationService.instance.showSessionReminder(
            projectTitle: _activeProjectTitle ?? 'Project',
            duration: _activeSession!.formattedDuration,
          );
        }
      }
    });
  }

  // Sorted newest-first
  List<SessionModel> get completedSessions {
    final list = _sessions.where((s) => !s.isActive).toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  Map<String, Duration> get durationByProject {
    final map = <String, Duration>{};
    for (final s in completedSessions) {
      map[s.projectId] =
          (map[s.projectId] ?? Duration.zero) + s.duration;
    }
    return map;
  }

  Map<DateTime, Duration> get dailyActivity {
    final map = <DateTime, Duration>{};
    for (final s in completedSessions) {
      final day =
          DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      map[day] = (map[day] ?? Duration.zero) + s.duration;
    }
    return map;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
