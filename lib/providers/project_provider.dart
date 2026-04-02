import 'package:flutter/foundation.dart';
import '../models/project_model.dart';
import '../models/task_model.dart';
import '../models/note_model.dart';
import '../services/api_service.dart';
import '../utils/constants.dart';

class ProjectProvider extends ChangeNotifier {
  List<ProjectModel> _projects = [];
  Map<String, List<TaskModel>> _tasksByProject = {};
  Map<String, List<NoteModel>> _notesByParent = {};
  bool _isLoading = false;
  String? _error;

  List<ProjectModel> get projects => _projects;
  bool get isLoading => _isLoading;
  String? get error => _error;

  List<TaskModel> tasksForProject(String projectId) =>
      _tasksByProject[projectId] ?? [];

  List<NoteModel> notesForParent(String parentId) =>
      _notesByParent[parentId] ?? [];

  Future<void> fetchProjects() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.instance.get(ApiConstants.fetchManyProjects);
      final list = response['projects'] as List? ?? response as List? ?? [];
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
      final response = await ApiService.instance.post(
        ApiConstants.createProject,
        body: {'title': title, 'description': description},
      );
      final project = ProjectModel.fromJson(response['project'] ?? response);
      _projects.insert(0, project);
      notifyListeners();
      return project;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateProject(String id, {String? title, String? description}) async {
    try {
      final body = <String, dynamic>{'id': id};
      if (title != null) body['title'] = title;
      if (description != null) body['description'] = description;

      await ApiService.instance.put(ApiConstants.updateProject, body: body);

      final index = _projects.indexWhere((p) => p.id == id);
      if (index != -1) {
        _projects[index] = _projects[index].copyWith(
          title: title,
          description: description,
        );
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
      await ApiService.instance.delete(ApiConstants.deleteProject, body: {'id': id});
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

  Future<void> fetchTasks(String projectId) async {
    try {
      final response = await ApiService.instance.get(
        ApiConstants.fetchManyTasks,
        queryParams: {'projectId': projectId},
      );
      final list = response['tasks'] as List? ?? response as List? ?? [];
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
      final response = await ApiService.instance.post(
        ApiConstants.createTask,
        body: {'projectId': projectId, 'name': name, 'description': description},
      );
      final task = TaskModel.fromJson(response['task'] ?? response);
      _tasksByProject[projectId] = [task, ...(_tasksByProject[projectId] ?? [])];
      notifyListeners();
      return task;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return null;
    }
  }

  Future<bool> updateTask(String taskId, String projectId, {String? name, String? description}) async {
    try {
      final body = <String, dynamic>{'id': taskId};
      if (name != null) body['name'] = name;
      if (description != null) body['description'] = description;

      await ApiService.instance.put(ApiConstants.updateTask, body: body);

      final tasks = _tasksByProject[projectId] ?? [];
      final index = tasks.indexWhere((t) => t.id == taskId);
      if (index != -1) {
        tasks[index] = tasks[index].copyWith(name: name, description: description);
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
      await ApiService.instance.delete(ApiConstants.deleteTask, body: {'id': taskId});
      _tasksByProject[projectId]?.removeWhere((t) => t.id == taskId);
      notifyListeners();
      return true;
    } on ApiException catch (e) {
      _error = e.message;
      notifyListeners();
      return false;
    }
  }

  Future<void> fetchNotes(String parentId, String parentType) async {
    try {
      final response = await ApiService.instance.get(
        ApiConstants.fetchManyNotes,
        queryParams: {'parentId': parentId, 'parentType': parentType},
      );
      final list = response['notes'] as List? ?? response as List? ?? [];
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
      final response = await ApiService.instance.post(
        ApiConstants.createNote,
        body: {'content': content, 'parentId': parentId, 'parentType': parentType},
      );
      final note = NoteModel.fromJson(response['note'] ?? response);
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
      await ApiService.instance.delete(ApiConstants.deleteNote, body: {'id': noteId});
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
}
