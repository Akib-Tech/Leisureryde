import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';

import '../../services/auth_service.dart';

class ForgotPasswordViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();

  final TextEditingController emailController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> sendResetLink(BuildContext context) async {
    final email = emailController.text.trim();

    // Simple validation
    if (!email.contains('@') || email.isEmpty) {
      _showSnackBar(context, "Please enter a valid email address.");
      return;
    }

    _setLoading(true);

    try {
      await _authService.sendPasswordResetEmail(email: email);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '✅ Password reset link sent! Check your email.',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop(); // go back to LoginScreen
      }
    } catch (e) {
      if (context.mounted) {
        _showSnackBar(context, "Failed to send reset link: ${e.toString()}");
      }
    } finally {
      _setLoading(false);
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
    super.dispose();
  }
}