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
      final queryParams = <String, String>{};
      if (projectId != null) queryParams['projectId'] = projectId;

      final response = await ApiService.instance.get(
        ApiConstants.fetchManySession,
        queryParams: queryParams.isNotEmpty ? queryParams : null,
      );
      final list = response['sessions'] as List? ?? response as List? ?? [];
      _sessions = list
          .map((e) => SessionModel.fromJson(e as Map<String, dynamic>))
          .toList();

      // Check for active session
      _activeSession = _sessions.firstWhere(
        (s) => s.isActive,
        orElse: () => SessionModel(
          id: '',
          projectId: '',
          startTime: DateTime.now(),
        ),
      );
      if (_activeSession!.id.isEmpty) _activeSession = null;

      if (_activeSession != null) {
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

  Future<SessionModel?> startSession(String projectId, {String? projectTitle}) async {
    try {
      final response = await ApiService.instance.post(
        ApiConstants.createSession,
        body: {'projectId': projectId},
      );
      final session = SessionModel.fromJson(response['session'] ?? response);
      _activeSession = session;
      _activeProjectTitle = projectTitle;
      _sessions.insert(0, session);
      _startTimer();
      notifyListeners();
      return session;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<SessionModel?> stopSession(String sessionId) async {
    try {
      final response = await ApiService.instance.post(
        ApiConstants.stopSession,
        body: {'id': sessionId},
      );
      final updated = SessionModel.fromJson(response['session'] ?? response);

      final index = _sessions.indexWhere((s) => s.id == sessionId);
      if (index != -1) _sessions[index] = updated;

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

  Future<bool> deleteSession(String sessionId) async {
    try {
      await ApiService.instance.delete(ApiConstants.deleteSession, body: {'id': sessionId});
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
        final title = _activeProjectTitle ?? 'Project';
        final duration = _activeSession!.formattedDuration;
        NotificationService.instance.showSessionReminder(
          projectTitle: title,
          duration: duration,
        );
        notifyListeners(); // Refresh duration display
      }
    });
  }

  List<SessionModel> get completedSessions =>
      _sessions.where((s) => !s.isActive).toList();

  Map<String, Duration> get durationByProject {
    final map = <String, Duration>{};
    for (final session in completedSessions) {
      map[session.projectId] =
          (map[session.projectId] ?? Duration.zero) + session.duration;
    }
    return map;
  }

  /// Returns a map of date -> total duration for heatmap
  Map<DateTime, Duration> get dailyActivity {
    final map = <DateTime, Duration>{};
    for (final session in completedSessions) {
      final day = DateTime(
        session.startTime.year,
        session.startTime.month,
        session.startTime.day,
      );
      map[day] = (map[day] ?? Duration.zero) + session.duration;
    }
    return map;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }
}
