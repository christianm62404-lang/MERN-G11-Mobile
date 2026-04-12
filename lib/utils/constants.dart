import 'package:flutter/foundation.dart' show kIsWeb;

class ApiConstants {
  // Web (flutter run -d chrome) → localhost
  // Android emulator           → 10.0.2.2:5050
  // iPhone / physical device   → Mac's LAN IP:5050
  static String get baseUrl => kIsWeb
      ? 'http://localhost:5050/api'
      : 'http://10.37.32.207:5050/api';

  static const String createUser             = '/users/create';
  static const String loginUser              = '/users/login';
  static const String verifyEmail            = '/users/verify';
  static const String regenVerification      = '/users/verify/regen';
  static const String resetPasswordRequest   = '/users/password/reset/request';
  static const String resetPassword          = '/users/password/reset';

  static const String createProject    = '/projects/create';
  static const String fetchOneProject  = '/projects/fetch/one';
  static const String fetchManyProjects= '/projects/fetch/many';
  static const String updateProject    = '/projects/update';
  static const String deleteProject    = '/projects/delete';

  static const String createTask     = '/tasks/create';
  static const String fetchOneTask   = '/tasks/fetch/one';
  static const String fetchManyTasks = '/tasks/fetch/many';
  static const String updateTask     = '/tasks/update';
  static const String deleteTask     = '/tasks/delete';

  static const String createSession      = '/sessions/create';
  static const String startSession       = '/sessions/start';
  static const String pauseSession       = '/sessions/pause';
  static const String stopSession        = '/sessions/stop';
  static const String sessionStatus      = '/sessions/status';
  static const String addTaskToSession   = '/sessions/task/add';
  static const String removeTaskFromSession = '/sessions/task/remove';
  static const String fetchOneSession    = '/sessions/fetch/one';
  static const String fetchManySessions  = '/sessions/fetch/many';
  static const String deleteSession      = '/sessions/delete';

  static const String createNote     = '/notes/create';
  static const String fetchOneNote   = '/notes/fetch/one';
  static const String fetchManyNotes = '/notes/fetch/many';
  static const String deleteNote     = '/notes/delete';
}

class StorageKeys {
  static const String authToken    = 'auth_token';
  static const String userId       = 'user_id';
  static const String userEmail    = 'user_email';
  static const String userFirstName= 'user_first_name';
  static const String fcmToken     = 'fcm_token';
}
