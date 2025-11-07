import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/screens/shared/main_screen/main_screen.dart';
import 'package:leisureryde/userspage/home.dart';

import '../../services/auth_service.dart';

enum SignupType { user, driver }

class SignupViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPasswordVisible = false;
  bool get isPasswordVisible => _isPasswordVisible;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  SignupType _signupType = SignupType.user;
  SignupType get signupType => _signupType;

  File? _selectedLicenseFile;
  File? get selectedLicenseFile => _selectedLicenseFile;

  void setSignupType(SignupType type) {
    if (_signupType == type) return;
    _signupType = type;
    notifyListeners();
  }

  Future<void> pickLicense() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'pdf', 'png'],
    );
    if (result != null && result.files.single.path != null) {
      _selectedLicenseFile = File(result.files.single.path!);
      notifyListeners();
    }
  }

// Paste this entire method into your SignupViewModel class, replacing the old one.

  Future<void> signUp(BuildContext context) async {

    // 1. Form Validation (remains the same)
    if (firstNameController.text.trim().length < 2) {
      _showSnackBar(context, "First name is too short."); return;
    }
    if (lastNameController.text.trim().length < 2) {
      _showSnackBar(context, "Last name is too short."); return;
    }
    if (!emailController.text.contains("@")) {
      _showSnackBar(context, "Please enter a valid email address."); return;
    }
    if (phoneController.text.trim().length < 10) {
      _showSnackBar(context, "Please enter a valid phone number."); return;
    }
    if (passwordController.text.trim().length < 6) {
      _showSnackBar(context, "Password must be at least 6 characters."); return;
    }
    if (passwordController.text != confirmPasswordController.text) {
      _showSnackBar(context, "Passwords do not match."); return;
    }

    if (_signupType == SignupType.driver && _selectedLicenseFile == null) {
      _showSnackBar(context, "Please upload your driving credentials.");
      return;
    }

    print('[SIGN UP] Validation passed. Setting loading state to TRUE.');
    _setLoading(true);

    try {
      if (_signupType == SignupType.user) {
        print('[SIGN UP] Awaiting AuthService.signUpWithEmail...');
        await _authService.signUpWithEmail(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
          phone: phoneController.text.trim(),
        );
        print('[SIGN UP] SUCCESS: User account created.');
      } else { // It's a driver
        print('[SIGN UP] Awaiting AuthService.signUpAsDriver...');
        await _authService.signUpAsDriver(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
          phone: phoneController.text.trim(),
          licenseFile: _selectedLicenseFile!,
        );
        print('[SIGN UP] SUCCESS: Driver account created.');
      }

      // =======================================================================
      // THE CRITICAL FIX IS HERE
      // We update the UI state to turn OFF the loader *before* we destroy this
      // screen's context with the navigation call.
      // =======================================================================
      print('[SIGN UP] State Update: Setting loading state to FALSE.');
      _setLoading(false);


      // Now that the loader is off, we can safely navigate.
      if (context.mounted) {
        print('[SIGN UP] Navigation: Navigating to MainScreen and removing all previous routes.');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
        );
      } else {
        // This is unlikely to happen here but is good practice.
        print('[SIGN UP] WARNING: Context was not mounted after sign-up. Cannot navigate.');
      }

    } catch (e) {
      print('[SIGN UP] ERROR: An exception was caught: ${e.toString()}');
      _showSnackBar(context, "Sign-up Failed: ${e.toString()}");
    } finally {
      // The 'finally' block ensures that no matter what happens (success or error),
      // we make one final check to turn off the loader. This is now a safeguard
      // primarily for the 'catch' block scenario.
      print('[SIGN UP] Finally Block: Running final check to ensure loading is false.');
      if (_isLoading) {
        print('[SIGN UP] Finally Block: Loader was still on, turning it off now.');
        _setLoading(false);
      }
    }
  }
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _showSnackBar(BuildContext context, String message) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
  }

  @override
  void dispose() {
    emailController.dispose();
    firstNameController.dispose();
    lastNameController.dispose();
    phoneController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }
}