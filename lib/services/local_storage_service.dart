import 'package:shared_preferences/shared_preferences.dart';

class LocalStorageService {
  static const String _userLoggedInKey = 'isLoggedIn';
  late SharedPreferences _preferences; // Change to late

  Future<void> init() async {
    _preferences = await SharedPreferences.getInstance();
  }

  // Add this getter
  SharedPreferences getPreferences() {
    return _preferences;
  }

  bool get isUserLoggedIn {
    return _preferences.getBool(_userLoggedInKey) ?? false;
  }

  Future<void> setUserLoggedIn(bool value) async {
    await _preferences.setBool(_userLoggedInKey, value);
  }

  Future<void> clear() async {
    await _preferences.clear();
  }
}