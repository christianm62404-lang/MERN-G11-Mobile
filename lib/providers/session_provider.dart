import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class SessionProvider extends ChangeNotifier {
  List<SessionModel> _sessions = [];
  SessionModel? _activeSession;
  String? _activeProjectTitle;
  bool _isLoading = false;
  String? _error;
  Timer? _sessionTimer;
  bool _isPaused = false;
  Duration? _frozenDuration;
  int _timerTick = 0;

  List<SessionModel> get sessions => _sessions;
  SessionModel? get activeSession => _activeSession;
  String? get activeProjectTitle => _activeProjectTitle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveSession => _activeSession != null;
  bool get isPaused => _isPaused;
  Duration? get frozenDuration => _frozenDuration;

  @override
  void dispose() {
    _sessionTimer?.cancel();
    super.dispose();
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

      final list = data is List ? data : (data is Map ? (data['sessions'] ?? []) : []);
      _sessions = (list as List)
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      try {
        _activeSession = _sessions.firstWhere((s) => s.isActive);
        if (_activeSession != null) _startTimer();
      } catch (_) {
        _activeSession = null;
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
        _activeSession = SessionModel.fromJson(data['session'] as Map<String, dynamic>);
        _startTimer();
        notifyListeners();
      } else {
        _activeSession = null;
        notifyListeners();
      }
    } catch (_) {}
  }

  Future<SessionModel?> startSession(String projectId, {String? projectTitle}) async {
    try {
      final info = await AuthService.instance.getUserInfo();
      final userId = info['userId'] ?? '';

      final data = await ApiService.instance.post(
        ApiConstants.createSession,
        body: {'projectId': projectId, 'userId': userId},
      );

      // Safe parse — never use 'as' directly, it can throw TypeError
      SessionModel session;
      try {
        final map = data is Map<String, dynamic>
            ? data
            : (data is Map ? Map<String, dynamic>.from(data as Map) : null);
        if (map != null && map['projectId'] != null) {
          session = SessionModel.fromJson(map);
        } else {
          final rawId = map?['insertedId'];
          final id = rawId is String
              ? rawId
              : (rawId is Map
                  ? rawId[r'$oid']?.toString() ?? rawId.values.first?.toString() ?? ''
                  : rawId?.toString() ?? '');
          session = SessionModel(
            id: id.isNotEmpty ? id : DateTime.now().millisecondsSinceEpoch.toString(),
            projectId: projectId,
            startTime: DateTime.now(),
          );
        }
      } catch (_) {
        session = SessionModel(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          projectId: projectId,
          startTime: DateTime.now(),
        );
      }

      _activeSession = session;
      _activeProjectTitle = projectTitle;
      _isPaused = false;
      _frozenDuration = null;

      // Backend creates sessions as paused — resume immediately to start the timer
      try {
        await ApiService.instance.get(ApiConstants.startSession);
      } catch (_) {} // best-effort; local timer still works if this fails

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
    } catch (e) {
      _error = 'Failed to start session. Check your connection.';
      notifyListeners();
      return null;
    }
  }

  Future<SessionModel?> stopSession() async {
    if (_activeSession == null) return null;
    try {
      // Backend has GET /sessions/stop (uses JWT to identify session, no body needed)
      await ApiService.instance.get(ApiConstants.stopSession);

      final updated = SessionModel(
        id: _activeSession!.id,
        projectId: _activeSession!.projectId,
        startTime: _activeSession!.startTime,
        endTime: DateTime.now(),
        taskIds: _activeSession!.taskIds,
      );

      final idx = _sessions.indexWhere((s) => s.id == updated.id);
      if (idx != -1) {
        _sessions[idx] = updated;
      } else {
        _sessions.insert(0, updated);
      }

      _activeSession = null;
      _activeProjectTitle = null;
      _isPaused = false;
      _frozenDuration = null;
      _sessionTimer?.cancel();
      _sessionTimer = null;
      await NotificationService.instance.cancelAllNotifications();
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> pauseSession() async {
    if (_activeSession == null || _isPaused) return;
    _isPaused = true;
    _frozenDuration = _activeSession!.duration;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    notifyListeners();
    try {
      await ApiService.instance.get(ApiConstants.pauseSession);
    } catch (_) {}
  }

  Future<void> resumeSession() async {
    if (_activeSession == null || !_isPaused) return;
    _isPaused = false;
    _frozenDuration = null;
    _startTimer();
    notifyListeners();
    try {
      await ApiService.instance.get(ApiConstants.startSession);
    } catch (_) {}
  }

  Future<bool> addTaskToSession(String taskId) async {
    if (_activeSession == null) return false;
    try {
      await ApiService.instance.post(
        ApiConstants.addTaskToSession,
        body: {'taskId': taskId},
      );
      final updated = _activeSession!.copyWith(
          taskIds: [..._activeSession!.taskIds, taskId]);
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
          taskIds: _activeSession!.taskIds.where((t) => t != taskId).toList());
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

  Future<bool> addTaskToSession(String taskId) async {
    if (_activeSession == null) return false;
    try {
      await ApiService.instance.post(
        ApiConstants.addTaskToSession,
        body: {'taskId': taskId},
      );
      final updated = _activeSession!.copyWith(
          taskIds: [..._activeSession!.taskIds, taskId]);
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
          taskIds: _activeSession!.taskIds.where((t) => t != taskId).toList());
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
        _sessionTimer?.cancel();
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
    _timerTick = 0;
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_activeSession != null && !_isPaused) {
        _timerTick++;
        if (_timerTick % 30 == 0) {
          NotificationService.instance.showSessionReminder(
            projectTitle: _activeProjectTitle ?? 'Project',
            duration: _activeSession!.formattedDuration,
          );
        }
        notifyListeners();
      }
    });
  }

  List<SessionModel> get completedSessions =>
      _sessions.where((s) => !s.isActive).toList();

  Map<String, Duration> get durationByProject {
    final map = <String, Duration>{};
    for (final s in completedSessions) {
      map[s.projectId] = (map[s.projectId] ?? Duration.zero) + s.duration;
    }
    return map;
  }

  Map<DateTime, Duration> get dailyActivity {
    final map = <DateTime, Duration>{};
    for (final s in completedSessions) {
      final day = DateTime(s.startTime.year, s.startTime.month, s.startTime.day);
      map[day] = (map[day] ?? Duration.zero) + s.duration;
    }
    return map;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
