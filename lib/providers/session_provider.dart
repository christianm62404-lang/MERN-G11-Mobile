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

  /// POST /sessions/create {projectId, userId}
  Future<SessionModel?> startSession(String projectId, {String? projectTitle}) async {
    try {
      final info = await AuthService.instance.getUserInfo();
      final userId = info['userId'] ?? '';

      final data = await ApiService.instance.post(
        ApiConstants.createSession,
        body: {'projectId': projectId, 'userId': userId},
      );

      // Backend returns full session doc; fall back to building locally if needed
      final map = data as Map<String, dynamic>?;
      final session = (map != null && map['projectId'] != null)
          ? SessionModel.fromJson(map)
          : SessionModel(
              id: map?['insertedId']?.toString() ?? map?['_id']?.toString() ?? '',
              projectId: projectId,
              startTime: DateTime.now(),
            );

      _activeSession = session;
      _activeProjectTitle = projectTitle;

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

  /// POST /sessions/stop {id}
  Future<SessionModel?> stopSession() async {
    if (_activeSession == null) return null;
    try {
      await ApiService.instance.post(
        ApiConstants.stopSession,
        body: {'id': _activeSession!.id},
      );

      // Backend returns updateOne result, not the doc — build locally
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
