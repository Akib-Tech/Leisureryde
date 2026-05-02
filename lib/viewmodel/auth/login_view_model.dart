import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/screens/shared/main_screen/main_screen.dart';

import '../../app/enums.dart';
import '../../screens/admin/admin_home_page.dart';
import '../../services/auth_service.dart';
import '../../services/push_notifications_service.dart';


enum LoginType { user, driver }


class LoginViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();
  final NotificationService _notificationService = locator<NotificationService>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  LoginType _loginType = LoginType.user;
  LoginType get loginType => _loginType;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPasswordVisible = false;
  bool get isPasswordVisible => _isPasswordVisible;

  void setLoginType(LoginType type) {
    if (_loginType == type) return;
    _loginType = type;
    notifyListeners();
  }

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  Future<void> signIn(BuildContext context) async {
    if (!emailController.text.contains("@")) {
      _showSnackBar(context, "Please enter a valid email address.");
      return;
    }

    if (passwordController.text.trim().length < 6) {
      _showSnackBar(context, "Password must be at least 6 characters.");
      return;
    }

    _setLoading(true);
    try {
      await _authService.signInWithEmail(
        emailController.text.trim(),
        passwordController.text.trim(),
      );

      final uid = _authService.currentUser!.uid;
      _notificationService.initialize(uid);

      final role = await _authService.getCurrentUserRole();

      if (!context.mounted) return;

      Widget next;
      switch (role) {
        case UserRole.admin:
          next = const AdminHomePage();
          break;
        default:
          next = const MainScreen();
      }

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => next),
            (route) => false,
      );
    } on FirebaseAuthException catch (e) {
      _showSnackBar(context, _friendlyAuthError(e.code));
    } catch (_) {
      _showSnackBar(context, "Something went wrong. Please try again.");
    } finally {
      _setLoading(false);
    }
  }
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'user-not-found':
        return 'No account found with this email address.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'invalid-credential':
        return 'Incorrect email or password. Please try again.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled. Please contact support.';
      case 'too-many-requests':
        return 'Too many failed attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      default:
        return 'Login failed. Please check your details and try again.';
    }
  }

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }
}