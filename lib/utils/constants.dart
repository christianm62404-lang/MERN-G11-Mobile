class ApiConstants {
  // Replace with your actual backend URL
  // Android emulator → local machine: http://10.0.2.2:5000/api
  // iOS simulator → local machine:    http://127.0.0.1:5000/api
  // Physical device → your LAN IP:    http://192.168.x.x:5000/api
  static const String baseUrl = 'http://10.0.2.2:5050/api';

  // ── Users ──────────────────────────────────────────────────────
  static const String createUser             = '/users/create';
  static const String loginUser              = '/users/login';
  static const String verifyEmail            = '/users/verify';       // GET ?token=
  static const String regenVerification      = '/users/verify/regen'; // POST {email}
  static const String resetPasswordRequest   = '/users/password/reset/request'; // POST {email}
  static const String resetPassword          = '/users/password/reset';         // POST {token, newPassword}

  // ── Projects ───────────────────────────────────────────────────
  static const String createProject    = '/projects/create';     // POST {title, description, id(userId)}
  static const String fetchOneProject  = '/projects/fetch/one';  // GET  body:{…}
  static const String fetchManyProjects= '/projects/fetch/many'; // GET  body:{id}
  static const String updateProject    = '/projects/update';     // PUT  body:{id, update:{…}}
  static const String deleteProject    = '/projects/delete';     // DELETE body:{id}

  // ── Tasks ──────────────────────────────────────────────────────
  static const String createTask     = '/tasks/create';      // POST
  static const String fetchOneTask   = '/tasks/fetch/one';   // GET
  static const String fetchManyTasks = '/tasks/fetch/many';  // GET
  static const String updateTask     = '/tasks/update';      // PUT
  static const String deleteTask     = '/tasks/delete';      // DELETE

  // ── Sessions ───────────────────────────────────────────────────
  static const String createSession      = '/sessions/create';     // POST {projectId}  — auth required
  static const String startSession       = '/sessions/start';      // GET               — resume paused
  static const String pauseSession       = '/sessions/pause';      // GET               — pause active
  static const String stopSession        = '/sessions/stop';       // GET               — stop & commit
  static const String sessionStatus      = '/sessions/status';     // GET               — current state
  static const String addTaskToSession   = '/sessions/task/add';   // POST {taskId}
  static const String removeTaskFromSession = '/sessions/task/remove'; // POST {taskId}
  static const String fetchOneSession    = '/sessions/fetch/one';  // GET  body:{}
  static const String fetchManySessions  = '/sessions/fetch/many'; // GET  body:{}
  static const String deleteSession      = '/sessions/delete';     // DELETE body:{id}

  // ── Notes ──────────────────────────────────────────────────────
  static const String createNote     = '/notes/create';     // POST {content, parentId, parentType}
  static const String fetchOneNote   = '/notes/fetch/one';  // GET
  static const String fetchManyNotes = '/notes/fetch/many'; // GET  body:{parentId, parentType}
  static const String deleteNote     = '/notes/delete';     // DELETE body:{id}
}

class StorageKeys {
  static const String authToken    = 'auth_token';
  static const String userId       = 'user_id';
  static const String userEmail    = 'user_email';
  static const String userFirstName= 'user_first_name';
  static const String fcmToken     = 'fcm_token';
}
