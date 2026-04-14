import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/session_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../services/notification_service.dart';
import '../utils/constants.dart';

class SessionProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _sessionsCachePrefix = 'cache_sessions_';
  static const _activeSessionCachePrefix = 'cache_active_session_';
  static const _activeProjectTitleCachePrefix = 'cache_active_project_title_';

  List<SessionModel> _sessions = [];
  SessionModel? _activeSession;
  String? _activeProjectTitle;
  Duration? _frozenDuration;
  bool _isLoading = false;
  String? _error;
  Timer? _sessionTimer;

  // Guards against concurrent startSession calls
  bool _isStarting = false;
  String? _currentAccountKey;

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

  /// On mobile only: sync with backend when returning to foreground.
  /// On web, tab-switch fires this event — skipping it prevents the
  /// active session from being cleared by a stale backend response.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!kIsWeb && state == AppLifecycleState.resumed) {
      fetchStatus();
    }
    // NEVER call stopSession() here. Sessions only end when the user
    // explicitly stops them or signs out.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionTimer?.cancel();
    super.dispose();
  }

  // ── Lifecycle helpers ───────────────────────────────────────────────────────

  void stopAndClear() {
    if (_activeSession != null) {
      stopSession().whenComplete(clearData);
      return;
    }
    clearData();
  }

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

  Future<void> fetchSessions({String? projectId}) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final info = await AuthService.instance.getUserInfo();
      final userId = info['userId'] ?? '';
      _currentAccountKey = await _resolveAccountKey();
      if (_currentAccountKey != null) {
        await _restoreFromCache(_currentAccountKey!);
      }
      final requestBody = <String, dynamic>{
        if (userId.isNotEmpty) 'id': userId,
        if (userId.isNotEmpty) 'userId': userId,
        if (projectId != null && projectId.isNotEmpty) 'projectId': projectId,
      };

      final data = requestBody.isNotEmpty
          ? await ApiService.instance.getWithBody(
              ApiConstants.fetchManySessions,
              body: requestBody,
            )
          : await ApiService.instance.get(ApiConstants.fetchManySessions);

      final list = data is List
          ? data
          : (data is Map ? (data['sessions'] ?? []) : []);

      final allSessions = (list as List)
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .where((s) => projectId == null || s.projectId == projectId)
          .toList();

      if (allSessions.isNotEmpty || _sessions.isEmpty) {
        allSessions.sort((a, b) => b.startTime.compareTo(a.startTime));
        _sessions = allSessions;
      }

      if (_activeSession == null) {
        final running =
            _sessions.where((s) => s.isActive && !s.isPaused).toList();
        final paused =
            _sessions.where((s) => s.isActive && s.isPaused).toList();

        if (running.isNotEmpty) {
          _activeSession = running.first;
          _startTimer();
        } else if (paused.isNotEmpty) {
          _activeSession = paused.first;
          _frozenDuration = paused.first.duration;
        }
      }
      await _persistToCache();
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
      final data = await ApiService.instance.getWithBody(
        ApiConstants.sessionStatus,
        body: {
          if (_activeSession != null) 'sessionId': _activeSession!.id,
        },
      );
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
        await _persistToCache();
        notifyListeners();
      } else {
        if (_activeSession != null) {
          _activeSession = null;
          _frozenDuration = null;
          _sessionTimer?.cancel();
          _sessionTimer = null;
          await _persistToCache();
          notifyListeners();
        }
      }
    } catch (_) {}
  }

  // ── Session control ─────────────────────────────────────────────────────────

  /// Guards:
  /// 1. If an active session already exists locally, return it — no API call.
  /// 2. If a start call is already in flight, do nothing (prevents duplicate sessions).
  Future<SessionModel?> startSession(String projectId,
      {String? projectTitle}) async {
    if (_activeSession != null) return _activeSession;
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
      await _persistToCache();
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
    await _persistToCache();
    notifyListeners();

    await NotificationService.instance.cancelAllNotifications();

    try {
      await ApiService.instance.post(
        ApiConstants.stopSession,
        body: {'sessionId': stoppingSession.id},
      );
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
    } catch (_) {}

    return completed;
  }

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
      final data = await ApiService.instance.post(
        ApiConstants.pauseSession,
        body: {'sessionId': _activeSession!.id},
      );
      if (data != null && data is Map) {
        final updated = SessionModel.fromJson(data as Map<String, dynamic>);
        _activeSession = updated;
        _frozenDuration = updated.duration;
        await _persistToCache();
        notifyListeners();
      }
    } on ApiException catch (_) {
      // Keep local paused state to ensure timer actually pauses even if backend
      // endpoint shape differs.
      await _persistToCache();
      notifyListeners();
    } catch (_) {}
  }

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
    await _persistToCache();
    notifyListeners();

    try {
      final data = await ApiService.instance.post(
        ApiConstants.startSession,
        body: {'sessionId': _activeSession!.id},
      );
      if (data != null && data is Map) {
        final updated = SessionModel.fromJson(data as Map<String, dynamic>);
        _activeSession = updated;
        await _persistToCache();
        notifyListeners();
      }
    } on ApiException catch (_) {
      // Keep local resumed state to preserve UX even if backend response fails.
      await _persistToCache();
      notifyListeners();
    } catch (_) {}
  }

  // ── Task linking ────────────────────────────────────────────────────────────

  Future<bool> addTaskToSession(String taskId, {String? sessionId}) async {
    final sid = sessionId ?? _activeSession?.id;
    if (sid == null || sid.isEmpty) return false;
    try {
      final idx = _sessions.indexWhere((s) => s.id == sid);
      if (idx == -1) return false;
      final target = _sessions[idx];
      if (!target.taskIds.contains(taskId)) {
        final updated = target.copyWith(taskIds: [...target.taskIds, taskId]);
        _sessions[idx] = updated;
        if (_activeSession?.id == sid) _activeSession = updated;
      }

      try {
        await ApiService.instance.post(
          ApiConstants.addTaskToSession,
          body: {'taskId': taskId, 'sessionId': sid},
        );
      } on ApiException {
        // Legacy backends may only accept taskId.
        await ApiService.instance.post(
          ApiConstants.addTaskToSession,
          body: {'taskId': taskId},
        );
      }
      await _persistToCache();
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

  Future<bool> removeTaskFromSession(String taskId, {String? sessionId}) async {
    final sid = sessionId ?? _activeSession?.id;
    if (sid == null || sid.isEmpty) return false;
    try {
      final idx = _sessions.indexWhere((s) => s.id == sid);
      if (idx == -1) return false;
      final target = _sessions[idx];
      final updated =
          target.copyWith(taskIds: target.taskIds.where((t) => t != taskId).toList());
      _sessions[idx] = updated;
      if (_activeSession?.id == sid) _activeSession = updated;

      try {
        await ApiService.instance.post(
          ApiConstants.removeTaskFromSession,
          body: {'taskId': taskId, 'sessionId': sid},
        );
      } on ApiException {
        await ApiService.instance.post(
          ApiConstants.removeTaskFromSession,
          body: {'taskId': taskId},
        );
      }
      await _persistToCache();
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

  Future<bool> setTaskChecked({
    required String sessionId,
    required String taskId,
    required bool isChecked,
  }) async {
    if (isChecked) {
      return addTaskToSession(taskId, sessionId: sessionId);
    }
    return removeTaskFromSession(taskId, sessionId: sessionId);
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
      await _persistToCache();
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

  List<SessionModel> get completedSessions {
    final list = _sessions.where((s) => !s.isActive).toList();
    list.sort((a, b) => b.startTime.compareTo(a.startTime));
    return list;
  }

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

  Future<void> reconcileWithProjectIds(Set<String> projectIds) async {
    if (projectIds.isEmpty) {
      _sessions = [];
      _activeSession = null;
      _activeProjectTitle = null;
      _frozenDuration = null;
      _sessionTimer?.cancel();
      _sessionTimer = null;
      await _persistToCache();
      notifyListeners();
      return;
    }

    _sessions = _sessions.where((s) => projectIds.contains(s.projectId)).toList();
    if (_activeSession != null &&
        !projectIds.contains(_activeSession!.projectId)) {
      _activeSession = null;
      _activeProjectTitle = null;
      _frozenDuration = null;
      _sessionTimer?.cancel();
      _sessionTimer = null;
    }
    await _persistToCache();
    notifyListeners();
  }

  Future<void> _persistToCache() async {
    var accountKey = _currentAccountKey;
    if (accountKey == null || accountKey.isEmpty) {
      final resolved = await _resolveAccountKey();
      if (resolved == null || resolved.isEmpty) return;
      _currentAccountKey = resolved;
      accountKey = resolved;
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      '$_sessionsCachePrefix$accountKey',
      jsonEncode(_sessions.map((s) => s.toJson()).toList()),
    );
    if (_activeSession != null) {
      await prefs.setString(
        '$_activeSessionCachePrefix$accountKey',
        jsonEncode(_activeSession!.toJson()),
      );
    } else {
      await prefs.remove('$_activeSessionCachePrefix$accountKey');
    }
    if (_activeProjectTitle != null && _activeProjectTitle!.isNotEmpty) {
      await prefs.setString(
        '$_activeProjectTitleCachePrefix$accountKey',
        _activeProjectTitle!,
      );
    } else {
      await prefs.remove('$_activeProjectTitleCachePrefix$accountKey');
    }
  }

  Future<void> _restoreFromCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final sessionsRaw = prefs.getString('$_sessionsCachePrefix$userId');
    if (sessionsRaw != null && sessionsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(sessionsRaw) as List;
        _sessions = decoded
            .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    final activeRaw = prefs.getString('$_activeSessionCachePrefix$userId');
    if (activeRaw != null && activeRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(activeRaw) as Map<String, dynamic>;
        _activeSession = SessionModel.fromJson(decoded);
        if (_activeSession != null && !_activeSession!.isPaused) {
          _startTimer();
        } else {
          _frozenDuration = _activeSession?.duration;
        }
      } catch (_) {}
    }
    _activeProjectTitle =
        prefs.getString('$_activeProjectTitleCachePrefix$userId');
  }

  Future<String?> _resolveAccountKey() async {
    final info = await AuthService.instance.getUserInfo();
    final userId = (info['userId'] ?? '').trim();
    final email = (info['email'] ?? '').trim().toLowerCase();
    if (userId.isNotEmpty) return 'uid_$userId';
    if (email.isNotEmpty) return 'email_$email';
    return null;
  }
}
