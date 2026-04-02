# MERN-G11-Mobile — Flutter App

A Flutter mobile frontend for the G11 Project & Time Tracking application. This app connects to the MERN-G11-Backend API and provides a native mobile experience for Android and iOS.

## Features

- **Authentication** — Login, register, email verification (JWT-based)
- **Dashboard** — At-a-glance overview: active session, stats, recent projects/sessions
- **Projects** — Create, view, edit, and delete projects
- **Tasks** — Manage tasks within each project
- **Sessions** — Start/stop time tracking sessions per project; view history
- **Insights** — Bar charts, activity heatmap, weekly trend line chart
- **Notes** — Add notes to projects
- **Push Notifications** — Firebase Cloud Messaging (FCM) for session reminders and updates
- **Dark Mode** — Full system dark/light theme support

## Tech Stack

| Layer | Technology |
|---|---|
| Framework | Flutter 3.x / Dart |
| State Management | Provider |
| Navigation | go_router |
| HTTP | http |
| Push Notifications | firebase_messaging + flutter_local_notifications |
| Secure Storage | flutter_secure_storage |
| Charts | fl_chart |

## Project Structure

```
lib/
├── main.dart                  # Entry point + Firebase init
├── router/app_router.dart     # go_router route definitions
├── utils/
│   ├── app_theme.dart         # Light + dark Material 3 themes
│   └── constants.dart         # API base URL + endpoint constants
├── models/                    # Data models (User, Project, Task, Session, Note)
├── services/
│   ├── api_service.dart       # HTTP client with auth headers
│   ├── auth_service.dart      # JWT storage via flutter_secure_storage
│   └── notification_service.dart  # FCM + local notifications
├── providers/                 # ChangeNotifier state providers
│   ├── auth_provider.dart
│   ├── project_provider.dart
│   ├── session_provider.dart
│   └── notification_provider.dart
├── screens/
│   ├── auth/                  # Login, Register, VerifyEmail
│   ├── dashboard/             # Dashboard with stats + active session
│   ├── projects/              # Projects list + detail (tasks, notes, sessions)
│   ├── sessions/              # All sessions + start/stop
│   ├── insights/              # Charts and analytics
│   └── account/               # Profile, notification settings, logout
└── widgets/                   # Shared UI components
```

## Setup & Configuration

### 1. Backend URL

Edit `lib/utils/constants.dart` and update `baseUrl`:

```dart
static const String baseUrl = 'http://YOUR_BACKEND_IP:5000/api';
```

For Android emulator pointing to local backend, use `http://10.0.2.2:5000/api`.

### 2. Firebase Setup (Push Notifications)

1. Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
2. Add an Android app with package name `com.mern.g11mobile`
3. Download `google-services.json` and place it at `android/app/google-services.json`
4. (iOS) Add an iOS app, download `GoogleService-Info.plist`, place in `ios/Runner/`
5. Run `flutterfire configure` to generate `lib/firebase_options.dart`
6. Update `lib/main.dart` to pass the options:
   ```dart
   await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
   ```

A template is provided at:
- `android/app/google-services.json.template`
- `lib/firebase_options.dart.template`

### 3. Install Dependencies

```bash
flutter pub get
```

### 4. Run the App

```bash
# Android
flutter run

# iOS (requires macOS + Xcode)
flutter run -d ios
```

## Push Notification Details

- **Foreground**: FCM messages are intercepted and shown as local notifications
- **Background/Terminated**: Handled natively by FCM SDK
- **Session Reminders**: A persistent notification is shown every 30s while a session is active
- **Tap Actions**: Notification taps route to the relevant screen via deep links (`g11tracker://`)

## Notes

- The app targets **Android API 21+** (Android 5.0) and **iOS 12+**
- Push notifications require a real device for full testing on iOS
- `android:usesCleartextTraffic="true"` is set to allow HTTP connections during development; use HTTPS in production