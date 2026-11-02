class AppConstants {
  // Change this to your backend IP when running on a physical device.
  // For Android emulator use: http://10.0.2.2:8000
  // For iOS simulator use: http://127.0.0.1:8000
  // For physical device use your machine's local IP: http://192.168.x.x:8000
 static const String baseUrl = 'http://172.20.10.4:8000';
  // Route names
  static const String splashRoute = '/';
  static const String loginRoute = '/login';
  static const String registerRoute = '/register';
  static const String dashboardRoute = '/dashboard';
  static const String uploadRoute = '/upload';
  static const String recorderRoute = '/recorder';
  static const String historyRoute = '/history';
  static const String evidenceDetailRoute = '/evidence-detail';
  static const String verifyRoute = '/verify';

  // Storage keys
  static const String userKey = 'user_data';
}
