import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class SessionProvider extends ChangeNotifier {
  List<SessionModel> _sessions = [];
  SessionModel? _activeSession;
  String? _activeProjectTitle;
  bool _isLoading = false;
  String? _error;
  Timer? _sessionTimer;

  List<SessionModel> get sessions => _sessions;
  SessionModel? get activeSession => _activeSession;
  String? get activeProjectTitle => _activeProjectTitle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveSession => _activeSession != null;

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
      final body = <String, dynamic>{};
      if (projectId != null) body['projectId'] = projectId;

      // GET /sessions/fetch/many with req.body
      final data = await ApiService.instance.getWithBody(
        ApiConstants.fetchManySessions,
        body: body,
      );

      final list = data is List ? data : (data is Map ? (data['sessions'] ?? []) : []);
      _sessions = (list as List)
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Identify active session
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

  /// Also fetches current status from the server (active session state).
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

  /// POST /sessions/create {projectId}
  Future<SessionModel?> startSession(String projectId, {String? projectTitle}) async {
    try {
      final data = await ApiService.instance.post(
        ApiConstants.createSession,
        body: {'projectId': projectId},
      );

      final session = SessionModel.fromJson(data as Map<String, dynamic>);
      _activeSession = session;
      _activeProjectTitle = projectTitle;

      // Insert or update in list
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

  /// GET /sessions/stop
  Future<SessionModel?> stopSession() async {
    try {
      final data = await ApiService.instance.get(ApiConstants.stopSession);
      final updated = SessionModel.fromJson(data as Map<String, dynamic>);

      final idx = _sessions.indexWhere((s) => s.id == updated.id);
      if (idx != -1) {
        _sessions[idx] = updated;
      } else {
        _sessions.insert(0, updated);
      }

      _activeSession = null;
      _activeProjectTitle = null;
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

  /// GET /sessions/pause
  Future<void> pauseSession() async {
    try {
      final data = await ApiService.instance.get(ApiConstants.pauseSession);
      if (data != null) {
        final updated = SessionModel.fromJson(data as Map<String, dynamic>);
        _activeSession = updated;
        notifyListeners();
      }
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    }
  }

  /// GET /sessions/start (resume a paused session)
  Future<void> resumeSession() async {
    try {
      final data = await ApiService.instance.get(ApiConstants.startSession);
      if (data != null) {
        final updated = SessionModel.fromJson(data as Map<String, dynamic>);
        _activeSession = updated;
        _startTimer();
        notifyListeners();
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
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_activeSession != null) {
        NotificationService.instance.showSessionReminder(
          projectTitle: _activeProjectTitle ?? 'Project',
          duration: _activeSession!.formattedDuration,
        );
        notifyListeners(); // Refresh elapsed display
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
