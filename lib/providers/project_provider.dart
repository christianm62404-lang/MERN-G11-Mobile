import 'package:flutter/foundation.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';
import '../utils/constants.dart';

class ProjectProvider extends ChangeNotifier {
  List<ProjectModel> _projects = [];
  final Map<String, List<TaskModel>> _tasksByProject = {};
  final Map<String, List<NoteModel>> _notesByParent = {};
  bool _isLoading = false;
  String? _error;

  List<ProjectModel> get projects => _projects;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<TaskModel> tasksForProject(String projectId) =>
      _tasksByProject[projectId] ?? [];

  List<NoteModel> notesForParent(String parentId) =>
      _notesByParent[parentId] ?? [];

  // ── Projects ──────────────────────────────────────────────────

  Future<void> fetchProjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final info = await AuthService.instance.getUserInfo();
      final userId = info['userId'] ?? '';

      // GET /projects/fetch/many with body {id: userId}
      final data = await ApiService.instance.getWithBody(
        ApiConstants.fetchManyProjects,
        body: {'id': userId},
      );

      final list = _asList(data);
      _projects = list
          .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
          .toList();
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
    required String description,
  }) async {
    try {
      final info = await AuthService.instance.getUserInfo();
      final userId = info['userId'] ?? '';

      // POST /projects/create {title, description, id: userId}
      final data = await ApiService.instance.post(
        ApiConstants.createProject,
        body: {'title': title, 'description': description, 'id': userId},
      );

      final project = ProjectModel.fromJson(data as Map<String, dynamic>);
      _projects.insert(0, project);
      notifyListeners();
      return project;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateProject(String id,
      {String? title, String? description}) async {
    try {
      final update = <String, dynamic>{};
      if (title != null) update['title'] = title;
      if (description != null) update['description'] = description;

      // PUT /projects/update {id, update:{…}}
      await ApiService.instance
          .put(ApiConstants.updateProject, body: {'id': id, 'update': update});

      final index = _projects.indexWhere((p) => p.id == id);
      if (index != -1) {
        _projects[index] =
            _projects[index].copyWith(title: title, description: description);
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
      notifyListeners();
    } on ApiException catch (_) {}
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
      notifyListeners();
    } on ApiException catch (_) {}
  }

  Future<NoteModel?> createNote({
    required String content,
    required String parentId,
    required String parentType,
  }) async {
    try {
      final data = await ApiService.instance.post(
        ApiConstants.createNote,
        body: {
          'content': content,
          'parentId': parentId,
          'parentType': parentType
        },
      );
      final note = NoteModel.fromJson(data as Map<String, dynamic>);
      _notesByParent[parentId] = [note, ...(_notesByParent[parentId] ?? [])];
      notifyListeners();
      return note;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> deleteNote(String noteId, String parentId) async {
    try {
      await ApiService.instance
          .delete(ApiConstants.deleteNote, body: {'id': noteId});
      _notesByParent[parentId]?.removeWhere((n) => n.id == noteId);
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
      // Sometimes wrapped in another key
      for (final key in ['projects', 'tasks', 'notes', 'sessions']) {
        if (data[key] is List) return data[key] as List;
      }
    }
    return [];
  }
}
