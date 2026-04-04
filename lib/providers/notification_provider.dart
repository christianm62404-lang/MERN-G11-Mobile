import 'package:flutter/foundation.dart';
import '../services/notification_service.dart';

class NotificationProvider extends ChangeNotifier {
  String? _fcmToken;
  bool _notificationsEnabled = true;

  String? get fcmToken => _fcmToken;
  bool get notificationsEnabled => _notificationsEnabled;

  NotificationProvider() {
    _initialize();
  }

  Future<void> _initialize() async {
    _fcmToken = await NotificationService.instance.getToken();
    notifyListeners();
  }

  void setNotificationsEnabled(bool value) {
    _notificationsEnabled = value;
    notifyListeners();
  }
}
