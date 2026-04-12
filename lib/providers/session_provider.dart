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

  /// Whether the active session is currently paused.
  bool get isPaused => _activeSession?.isPaused ?? false;

  /// The duration captured at the moment the session was paused.
  /// Used by the UI timer widgets to show a frozen value while paused.
  Duration? get frozenDuration => _frozenDuration;

  SessionProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Stop and save the session when the app is closed or goes to background.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_activeSession != null &&
        (state == AppLifecycleState.detached ||
            state == AppLifecycleState.paused)) {
      stopSession();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    super.dispose();
  }

  /// Clear all data on logout so another user's session is not visible.
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

      final list = data is List ? data : (data is Map ? (data['sessions'] ?? []) : []);
      _sessions = (list as List)
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Restore active session and timer if one is found in the list
      final active = _sessions.where((s) => s.isActive).toList();
      if (active.isNotEmpty && _activeSession == null) {
        _activeSession = active.first;
        _startTimer();
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

  /// POST /sessions/create, then GET /sessions/start to begin tracking.
  Future<SessionModel?> startSession(String projectId, {String? projectTitle}) async {
    try {
      final info = await AuthService.instance.getUserInfo();
      final userId = info['userId'] ?? '';

      final data = await ApiService.instance.post(
        ApiConstants.createSession,
        body: {'projectId': projectId, 'userId': userId},
      );

      // Build session from backend response or locally
      final map = data as Map<String, dynamic>?;
      SessionModel session;
      if (map != null && map['projectId'] != null) {
        session = SessionModel.fromJson(map);
      } else {
        session = SessionModel(
          id: map?['insertedId']?.toString() ?? map?['_id']?.toString() ?? '',
          projectId: projectId,
          startTime: DateTime.now(),
        );
      }

      // Call GET /sessions/start so the backend marks it as running (not paused)
      try {
        final startData = await ApiService.instance.get(ApiConstants.startSession);
        if (startData is Map) {
          final started = SessionModel.fromJson(startData as Map<String, dynamic>);
          if (started.id.isNotEmpty) session = started;
        }
      } catch (_) {
        // Non-fatal — continue with the created session
      }

      // Anchor the live timer from now so elapsed starts at 0 for brand new sessions
      if (!session.isPaused && (session.durationSeconds ?? 0) == 0) {
        session = SessionModel(
          id: session.id,
          projectId: session.projectId,
          startTime: DateTime.now(),
          taskIds: session.taskIds,
          isPaused: false,
        );
      }

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

  /// Optimistically clears the active session immediately, then calls the backend.
  Future<SessionModel?> stopSession() async {
    if (_activeSession == null) return null;

    final stoppingSession = _activeSession!;
    final elapsed = stoppingSession.duration;

    // Clear immediately so the UI updates without waiting for the network
    _activeSession = null;
    _activeProjectTitle = null;
    _frozenDuration = null;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    notifyListeners();

    await NotificationService.instance.cancelAllNotifications();

    try {
      // Backend uses GET /sessions/stop — JWT identifies whose session to stop
      await ApiService.instance.get(ApiConstants.stopSession);

      final updated = SessionModel(
        id: stoppingSession.id,
        projectId: stoppingSession.projectId,
        startTime: stoppingSession.startTime,
        endTime: DateTime.now(),
        durationSeconds: elapsed.inSeconds,
        taskIds: stoppingSession.taskIds,
      );

      final idx = _sessions.indexWhere((s) => s.id == updated.id);
      if (idx != -1) {
        _sessions[idx] = updated;
      } else {
        _sessions.insert(0, updated);
      }
      notifyListeners();
      return updated;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<void> pauseSession() async {
    if (_activeSession == null) return;
    // Capture the live duration before pausing so the UI can show the frozen value
    _frozenDuration = _activeSession!.duration;
    try {
      final data = await ApiService.instance.get(ApiConstants.pauseSession);
      if (data != null && data is Map) {
        _activeSession = SessionModel.fromJson(data as Map<String, dynamic>);
      } else {
        _activeSession = _activeSession!.copyWith(
          isPaused: true,
          durationSeconds: _frozenDuration!.inSeconds,
        );
      }
      _sessionTimer?.cancel();
      _sessionTimer = null;
      notifyListeners();
    } on ApiException catch (e) {
      _frozenDuration = null; // revert on error
      _error = e.message;
      notifyListeners();
    }
  }

  Future<void> resumeSession() async {
    try {
      final data = await ApiService.instance.get(ApiConstants.startSession);
      if (data != null && data is Map) {
        _activeSession = SessionModel.fromJson(data as Map<String, dynamic>);
      } else if (_activeSession != null) {
        // Anchor a fresh startTime so live elapsed resumes from accumulated total
        _activeSession = SessionModel(
          id: _activeSession!.id,
          projectId: _activeSession!.projectId,
          startTime: DateTime.now(),
          durationSeconds: _activeSession!.durationSeconds,
          taskIds: _activeSession!.taskIds,
          isPaused: false,
        );
      }
      _frozenDuration = null;
      _startTimer();
      notifyListeners();
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

  /// Ticks every second so the live timer updates in the UI.
  void _startTimer() {
    _sessionTimer?.cancel();
    _sessionTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_activeSession != null && !_activeSession!.isPaused) {
        notifyListeners();
        // Show a reminder notification every 5 minutes
        if (timer.tick % 300 == 0) {
          NotificationService.instance.showSessionReminder(
            projectTitle: _activeProjectTitle ?? 'Project',
            duration: _activeSession!.formattedDuration,
          );
        }
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
