import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
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

  // Guards against concurrent startSession calls
  bool _isStarting = false;

  List<SessionModel> get sessions => _sessions;
  SessionModel? get activeSession => _activeSession;
  String? get activeProjectTitle => _activeProjectTitle;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasActiveSession => _activeSession != null;

  /// Whether the active session is currently paused.
  bool get isPaused => _activeSession?.isPaused ?? false;

  /// Duration captured at the moment of pausing — shown as a frozen value.
  Duration? get frozenDuration => _frozenDuration;

  SessionProvider() {
    WidgetsBinding.instance.addObserver(this);
  }

  /// On mobile: sync with backend when returning to foreground.
  /// On web (Chrome): skip — Dart timers keep running in background tabs,
  /// and the duration getter uses DateTime.now() so it stays accurate.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb && state == AppLifecycleState.resumed) {
      fetchStatus();
    }
    // NEVER call stopSession() on any lifecycle event.
    // Sessions only end when the user explicitly stops them or signs out.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ── Lifecycle helpers ───────────────────────────────────────────────────────

  /// Stops any active session via the API (fire-and-forget) then clears all
  /// local data. Called from the logout handler while the JWT is still valid.
  void stopAndClear() {
    if (_activeSession != null) {
      ApiService.instance.get(ApiConstants.stopSession).catchError((_) {});
    }
    clearData();
  }

  /// Clear all in-memory data (called on logout to prevent data leaking between accounts).
  void clearData() {
    _sessions = [];
    _activeSession = null;
    _activeProjectTitle = null;
    _frozenDuration = null;
    _error = null;
    _isStarting = false;
    _sessionTimer?.cancel();
    _sessionTimer = null;
    notifyListeners();
  }

  // ── Fetch ───────────────────────────────────────────────────────────────────

  /// Load all sessions for the authenticated user.
  /// The backend reads userId from the JWT — no body needed.
  Future<void> fetchSessions({String? projectId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data =
          await ApiService.instance.get(ApiConstants.fetchManySessions);

      final list = data is List
          ? data
          : (data is Map ? (data['sessions'] ?? []) : []);

      final allSessions = (list as List).expand<SessionModel>((e) {
        try {
          return [SessionModel.fromJson(e as Map<String, dynamic>)];
        } catch (_) {
          return [];
        }
      }).toList();

      // Sort newest first
      allSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
      _sessions = allSessions;

      // Do NOT restore the active session from the local list heuristically.
      // Any session with endTime==null in the DB list could be orphaned (created
      // by the old duplicate-start bug). Instead, fetchStatus() asks the backend
      // for the definitive active session — it runs below after this try block.
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load sessions';
    } finally {
      _isLoading = false;
      notifyListeners();
    }

    // Ask the backend which session (if any) is truly active.
    // This overwrites any stale local _activeSession and prevents orphaned
    // endTime==null sessions from triggering the timer on login.
    if (_activeSession == null) {
      await fetchStatus();
    }
  }

  /// Sync active session state with the backend (mobile resume only).
  Future<void> fetchStatus() async {
    try {
      final data = await ApiService.instance.get(ApiConstants.sessionStatus);
      if (data is Map && data['session'] != null) {
        final session =
            SessionModel.fromJson(data['session'] as Map<String, dynamic>);
        _activeSession = session;
        if (!session.isPaused) {
          _startTimer();
        } else {
          _sessionTimer?.cancel();
          _sessionTimer = null;
          _frozenDuration = session.duration;
        }
        notifyListeners();
      } else {
        if (_activeSession != null) {
          _activeSession = null;
          _frozenDuration = null;
          _sessionTimer?.cancel();
          _sessionTimer = null;
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // ── Session control ─────────────────────────────────────────────────────────

  /// POST /sessions/create — starts a new session.
  ///
  /// Guards:
  /// 1. If an active session already exists locally, return it without
  ///    hitting the backend (prevents duplicate sessions).
  /// 2. If a start is already in progress (_isStarting), do nothing.
  Future<SessionModel?> startSession(String projectId,
      {String? projectTitle}) async {
    // Guard 1: already have an active session — don't create a duplicate
    if (_activeSession != null) return _activeSession;

    // Guard 2: a start API call is already in flight
    if (_isStarting) return null;
    _isStarting = true;

    try {
      final data = await ApiService.instance.post(
        ApiConstants.createSession,
        body: {'projectId': projectId},
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
    } catch (e) {
      _error = 'Failed to start session';
      notifyListeners();
      return null;
    } finally {
      _isStarting = false;
    }
  }

  /// Optimistically marks the session as complete, then calls the backend.
  /// The completed session is saved to [completedSessions] immediately so it
  /// is never "lost" even if the network call fails.
  Future<SessionModel?> stopSession() async {
    if (_activeSession == null) return null;

    final stoppingSession = _activeSession!;
    final endTime = DateTime.now();

    final completed = SessionModel(
      id: stoppingSession.id,
      projectId: stoppingSession.projectId,
      startTime: stoppingSession.startTime,
      endTime: endTime,
      pausedDurationMs: stoppingSession.pausedDurationMs,
      taskIds: stoppingSession.taskIds,
      isPaused: false,
    );

    // Update UI immediately (optimistic) — before the network call
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

    try {
      await ApiService.instance.get(ApiConstants.stopSession);
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (_) {}

    return completed;
  }

  /// Optimistically pauses the active session.
  Future<void> pauseSession() async {
    if (_activeSession == null) return;

    _frozenDuration = _activeSession!.duration;
    final pausedAt = DateTime.now();

    _activeSession = _activeSession!.copyWith(
      isPaused: true,
      pausedAt: pausedAt,
    );
    _sessionTimer?.cancel();
    _sessionTimer = null;
    notifyListeners();

    try {
      final data = await ApiService.instance.get(ApiConstants.pauseSession);
      if (data != null && data is Map) {
        final updated = SessionModel.fromJson(data as Map<String, dynamic>);
        _activeSession = updated;
        _frozenDuration = updated.duration;
        notifyListeners();
      }
    } on ApiException catch (e) {
      // Revert
      _activeSession =
          _activeSession?.copyWith(isPaused: false, clearPausedAt: true);
      _frozenDuration = null;
      _startTimer();
      _error = e.message;
      notifyListeners();
    } catch (_) {}
  }

  /// Optimistically resumes a paused session.
  Future<void> resumeSession() async {
    if (_activeSession == null) return;

    final additionalPausedMs = _activeSession!.pausedAt != null
        ? DateTime.now().difference(_activeSession!.pausedAt!).inMilliseconds
        : 0;
    final newPausedDurationMs =
        _activeSession!.pausedDurationMs + additionalPausedMs;

    _activeSession = SessionModel(
      id: _activeSession!.id,
      projectId: _activeSession!.projectId,
      startTime: _activeSession!.startTime,
      pausedDurationMs: newPausedDurationMs,
      taskIds: _activeSession!.taskIds,
      isPaused: false,
    );
    _frozenDuration = null;
    _startTimer();
    notifyListeners();

    try {
      final data = await ApiService.instance.get(ApiConstants.startSession);
      if (data != null && data is Map) {
        final updated = SessionModel.fromJson(data as Map<String, dynamic>);
        _activeSession = updated;
        notifyListeners();
      }
    } on ApiException catch (e) {
      // Revert
      _activeSession = _activeSession?.copyWith(
        isPaused: true,
        pausedAt: DateTime.now(),
        pausedDurationMs:
            _activeSession!.pausedDurationMs - additionalPausedMs,
      );
      _sessionTimer?.cancel();
      _sessionTimer = null;
      _frozenDuration = _activeSession?.duration;
      _error = e.message;
      notifyListeners();
    } catch (_) {}
  }

  // ── Task linking ────────────────────────────────────────────────────────────

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
    } catch (e) {
      _error = 'Failed to link task';
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
    } catch (e) {
      _error = 'Failed to unlink task';
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
    } catch (e) {
      _error = 'Failed to delete session';
      notifyListeners();
      return false;
    }
  }

  // ── Timer ───────────────────────────────────────────────────────────────────

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

  // ── Computed views ──────────────────────────────────────────────────────────

  /// Shows all historical sessions except the currently active one.
  /// Orphaned sessions (endTime==null but not the active session) are included
  /// so that sessions started before a crash or app restart still appear.
  List<SessionModel> get completedSessions {
    final activeId = _activeSession?.id;
    final list = _sessions.where((s) => s.id != activeId).toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

  Map<String, Duration> get durationByProject {
    final map = <String, Duration>{};
    // Only count sessions that were properly stopped (endTime set).
    for (final s in completedSessions.where((s) => s.endTime != null)) {
      map[s.projectId] = (map[s.projectId] ?? Duration.zero) + s.duration;
    }
    return map;
  }

  Map<DateTime, Duration> get dailyActivity {
    final map = <DateTime, Duration>{};
    // Only count sessions that were properly stopped (endTime set).
    for (final s in completedSessions.where((s) => s.endTime != null)) {
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
