class ApiConstants {
  // Replace with your actual backend URL
  static const String baseUrl = 'http://10.0.2.2:5000/api';

  // Auth
  static const String createUser = '/users/create';
  static const String loginUser = '/users/login';
  static const String verifyEmail = '/users/verify';
  static const String regenVerification = '/users/verify/regen';
  static const String resetPasswordRequest = '/users/password/reset/request';
  static const String resetPassword = '/users/password/reset';

  // Projects
  static const String createProject = '/projects/create';
  static const String fetchOneProject = '/projects/fetch/one';
  static const String fetchManyProjects = '/projects/fetch/many';
  static const String updateProject = '/projects/update';
  static const String deleteProject = '/projects/delete';

  // Tasks
  static const String createTask = '/tasks/create';
  static const String fetchOneTask = '/tasks/fetch/one';
  static const String fetchManyTasks = '/tasks/fetch/many';
  static const String updateTask = '/tasks/update';
  static const String deleteTask = '/tasks/delete';

  // Sessions
  static const String createSession = '/sessions/create';
  static const String stopSession = '/sessions/stop';
  static const String fetchOneSession = '/sessions/fetch/one';
  static const String fetchManySession = '/sessions/fetch/many';
  static const String deleteSession = '/sessions/delete';

  // Notes
  static const String createNote = '/notes/create';
  static const String fetchOneNote = '/notes/fetch/one';
  static const String fetchManyNotes = '/notes/fetch/many';
  static const String deleteNote = '/notes/delete';
}

class StorageKeys {
  static const String authToken = 'auth_token';
  static const String userId = 'user_id';
  static const String userEmail = 'user_email';
  static const String userFirstName = 'user_first_name';
  static const String fcmToken = 'fcm_token';
}
