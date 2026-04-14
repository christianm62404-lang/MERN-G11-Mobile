import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class ProjectProvider extends ChangeNotifier {
  static const _projectsCachePrefix = 'cache_projects_';
  static const _tasksCachePrefix = 'cache_tasks_';
  static const _notesCachePrefix = 'cache_notes_';

  List<ProjectModel> _projects = [];
  final Map<String, List<TaskModel>> _tasksByProject = {};
  final Map<String, List<NoteModel>> _notesByParent = {};
  bool _isLoading = false;
  String? _error;
  String? _currentAccountKey;

  List<ProjectModel> get projects => _projects;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<TaskModel> tasksForProject(String projectId) =>
      _tasksByProject[projectId] ?? [];

  List<NoteModel> notesForParent(String parentId) =>
      _notesByParent[parentId] ?? [];

  void clearData() {
    _projects = [];
    _tasksByProject.clear();
    _notesByParent.clear();
    _error = null;
    notifyListeners();
  }

  // ── Projects ──────────────────────────────────────────────────

  Future<void> fetchProjects() async {
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

      // Some backend deployments expect userId in body even on fetch routes.
      final data = userId.isNotEmpty
          ? await ApiService.instance.getWithBody(
              ApiConstants.fetchManyProjects,
              body: {'id': userId, 'userId': userId},
            )
          : await ApiService.instance.get(ApiConstants.fetchManyProjects);

      final list = _asList(data);
      final fetched = list
          .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
          .toList();
      if (fetched.isNotEmpty || _projects.isEmpty) {
        _projects = fetched;
        await _persistToCache();
      }
    } on ApiException catch (e) {
      _error = e.message;
    } catch (e) {
      _error = 'Failed to load projects';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<ProjectModel?> createProject({
    required String title,
    String description = '',
  }) async {
    final info = await AuthService.instance.getUserInfo();
    final userId = info['userId'] ?? '';
    final fallbackProject = ProjectModel(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      title: title,
      description: description,
      userId: userId,
      createdAt: DateTime.now(),
    );

    try {
      final data = await ApiService.instance.post(
        ApiConstants.createProject,
        body: {
          'title': title,
          'description': description,
          'id': userId,
          'userId': userId,
        },
      );

      final map = data as Map<String, dynamic>?;
      final project = (map != null && map['title'] != null)
          ? ProjectModel.fromJson(map)
          : ProjectModel(
              id: map?['insertedId']?.toString() ?? map?['_id']?.toString() ?? '',
              title: title,
              description: description,
              userId: userId,
              createdAt: DateTime.now(),
            );
      _projects.insert(0, project);
      await _persistToCache();
      notifyListeners();
      return project;
    } on ApiException catch (e) {
      _error = e.message;
      // Allow optional-description and offline flows by saving locally.
      _projects.insert(0, fallbackProject);
      await _persistToCache();
      notifyListeners();
      return fallbackProject;
    } catch (_) {
      // Allow optional-description and offline flows by saving locally.
      _projects.insert(0, fallbackProject);
      await _persistToCache();
      notifyListeners();
      return fallbackProject;
    }
  }

  Future<bool> updateProject(String id,
      {String? title, String? description}) async {
    try {
      final update = <String, dynamic>{};
      if (title != null) update['title'] = title;
      if (description != null) update['description'] = description;

      await ApiService.instance
          .put(ApiConstants.updateProject, body: {'id': id, 'update': update});

      final index = _projects.indexWhere((p) => p.id == id);
      if (index != -1) {
        _projects[index] =
            _projects[index].copyWith(title: title, description: description);
        await _persistToCache();
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteProject(String id) async {
    try {
      await ApiService.instance
          .delete(ApiConstants.deleteProject, body: {'id': id});
      _projects.removeWhere((p) => p.id == id);
      _tasksByProject.remove(id);
      await _persistToCache();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── Tasks ─────────────────────────────────────────────────────

  Future<void> fetchTasks(String projectId) async {
    try {
      final data = await ApiService.instance.getWithBody(
        ApiConstants.fetchManyTasks,
        body: {'projectId': projectId},
      );
      final list = _asList(data);
      _tasksByProject[projectId] = list
          .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _persistToCache();
      notifyListeners();
    } catch (_) {
      // Keep existing tasks on failure
    }
  }

  Future<TaskModel?> createTask({
    required String projectId,
    required String name,
    required String description,
  }) async {
    try {
      final data = await ApiService.instance.post(
        ApiConstants.createTask,
        body: {'projectId': projectId, 'name': name, 'description': description},
      );
      final task = TaskModel.fromJson(data as Map<String, dynamic>);
      _tasksByProject[projectId] = [
        task,
        ...(_tasksByProject[projectId] ?? [])
      ];
      await _persistToCache();
      notifyListeners();
      return task;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTask(String taskId, String projectId,
      {String? name, String? description}) async {
    try {
      final update = <String, dynamic>{};
      if (name != null) update['name'] = name;
      if (description != null) update['description'] = description;

      await ApiService.instance
          .put(ApiConstants.updateTask, body: {'id': taskId, 'update': update});

      final tasks = _tasksByProject[projectId] ?? [];
      final i = tasks.indexWhere((t) => t.id == taskId);
      if (i != -1) {
        tasks[i] = tasks[i].copyWith(name: name, description: description);
        _tasksByProject[projectId] = tasks;
        await _persistToCache();
        notifyListeners();
      }
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteTask(String taskId, String projectId) async {
    try {
      await ApiService.instance
          .delete(ApiConstants.deleteTask, body: {'id': taskId});
      _tasksByProject[projectId]?.removeWhere((t) => t.id == taskId);
      await _persistToCache();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  // ── Notes ─────────────────────────────────────────────────────

  Future<void> fetchNotes(String parentId, String parentType) async {
    try {
      final data = await ApiService.instance.getWithBody(
        ApiConstants.fetchManyNotes,
        body: {'parentId': parentId, 'parentType': parentType},
      );
      final list = _asList(data);
      _notesByParent[parentId] = list
          .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
          .toList();
      await _persistToCache();
      notifyListeners();
    } catch (_) {}
  }

  Future<NoteModel?> createNote({
    required String content,
    required String parentId,
    required String parentType,
  }) async {
    NoteParentType pt;
    switch (parentType) {
      case 'task':
        pt = NoteParentType.task;
        break;
      case 'session':
        pt = NoteParentType.session;
        break;
      default:
        pt = NoteParentType.project;
    }
    final tempId = 'temp_${DateTime.now().millisecondsSinceEpoch}';
    final tempNote = NoteModel(
      id: tempId,
      content: content,
      parentType: pt,
      parentId: parentId,
      createdAt: DateTime.now(),
    );
    _notesByParent[parentId] = [tempNote, ...(_notesByParent[parentId] ?? [])];
    await _persistToCache();
    notifyListeners();

    try {
      final data = await ApiService.instance.post(
        ApiConstants.createNote,
        body: {'content': content, 'parentId': parentId, 'parentType': parentType},
      );

      NoteModel? realNote;
      if (data is Map<String, dynamic>) {
        realNote = NoteModel.fromJson(data);
      }

      final list = List<NoteModel>.from(_notesByParent[parentId] ?? []);
      final idx = list.indexWhere((n) => n.id == tempId);
      if (realNote != null && realNote.content.isNotEmpty && idx != -1) {
        list[idx] = realNote;
      } else if (realNote != null && realNote.content.isNotEmpty) {
        list.insert(0, realNote);
      }
      _notesByParent[parentId] = list;
      await _persistToCache();
      notifyListeners();
      return realNote ?? tempNote;
    } on ApiException catch (e) {
      _notesByParent[parentId]?.removeWhere((n) => n.id == tempId);
      await _persistToCache();
      _error = e.message;
      notifyListeners();
      return null;
    } catch (e) {
      _notesByParent[parentId]?.removeWhere((n) => n.id == tempId);
      await _persistToCache();
      _error = 'Failed to save note';
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteNote(String noteId, String parentId) async {
    try {
      await ApiService.instance
          .delete(ApiConstants.deleteNote, body: {'id': noteId});
      _notesByParent[parentId]?.removeWhere((n) => n.id == noteId);
      await _persistToCache();
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  List _asList(dynamic data) {
    if (data is List) return data;
    if (data is Map) {
      for (final key in ['projects', 'tasks', 'notes', 'sessions']) {
        if (data[key] is List) return data[key] as List;
      }
    }
    return [];
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
    await Future.wait([
      prefs.setString(
        '$_projectsCachePrefix$accountKey',
        jsonEncode(_projects.map((p) => p.toJson()).toList()),
      ),
      prefs.setString(
        '$_tasksCachePrefix$accountKey',
        jsonEncode(
          _tasksByProject.map(
            (key, value) => MapEntry(key, value.map((t) => t.toJson()).toList()),
          ),
        ),
      ),
      prefs.setString(
        '$_notesCachePrefix$accountKey',
        jsonEncode(
          _notesByParent.map(
            (key, value) => MapEntry(key, value.map((n) => n.toJson()).toList()),
          ),
        ),
      ),
    ]);
  }

  Future<void> _restoreFromCache(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final projectsRaw = prefs.getString('$_projectsCachePrefix$userId');
    final tasksRaw = prefs.getString('$_tasksCachePrefix$userId');
    final notesRaw = prefs.getString('$_notesCachePrefix$userId');

    if (projectsRaw != null && projectsRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(projectsRaw) as List;
        _projects = decoded
            .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {}
    }

    if (tasksRaw != null && tasksRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(tasksRaw) as Map<String, dynamic>;
        _tasksByProject
          ..clear()
          ..addAll(
            decoded.map(
              (key, value) => MapEntry(
                key,
                (value as List)
                    .map((e) => TaskModel.fromJson(e as Map<String, dynamic>))
                    .toList(),
              ),
            ),
          );
      } catch (_) {}
    }

    if (notesRaw != null && notesRaw.isNotEmpty) {
      try {
        final decoded = jsonDecode(notesRaw) as Map<String, dynamic>;
        _notesByParent
          ..clear()
          ..addAll(
            decoded.map(
              (key, value) => MapEntry(
                key,
                (value as List)
                    .map((e) => NoteModel.fromJson(e as Map<String, dynamic>))
                    .toList(),
              ),
            ),
          );
      } catch (_) {}
    }
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
