import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

class AuthService {
  static UserModel? _currentUser;

  static UserModel? get currentUser => _currentUser;

  static Future<void> saveUser(UserModel user) async {
    _currentUser = user;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.userKey, user.toJsonString());
  }

  static Future<UserModel?> loadUser() async {
    if (_currentUser != null) return _currentUser;
    final prefs = await SharedPreferences.getInstance();
    final str = prefs.getString(AppConstants.userKey);
    if (str != null) {
      _currentUser = UserModel.fromJsonString(str);
      return _currentUser;
    }
    return null;
  }

  static Future<void> logout() async {
    _currentUser = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userKey);
  }

  static Future<bool> isLoggedIn() async {
    final user = await loadUser();
    return user != null;
  }
}
