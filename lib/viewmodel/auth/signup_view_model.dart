import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/screens/shared/main_screen/main_screen.dart';

import '../../services/auth_service.dart';
import '../../services/push_notifications_service.dart';

enum SignupType { user, driver }

class SignupViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();
  final NotificationService _notificationService = locator<NotificationService>();

  final TextEditingController emailController = TextEditingController();
  final TextEditingController firstNameController = TextEditingController();
  final TextEditingController lastNameController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // Bank details (driver only)
  final TextEditingController bankAccountNameController = TextEditingController();
  final TextEditingController bankNameController = TextEditingController();
  final TextEditingController accountNumberController = TextEditingController();
  final TextEditingController bankCodeController = TextEditingController();

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isPasswordVisible = false;
  bool get isPasswordVisible => _isPasswordVisible;

  void togglePasswordVisibility() {
    _isPasswordVisible = !_isPasswordVisible;
    notifyListeners();
  }

  DateTime? _dateOfBirth;
  DateTime? get dateOfBirth => _dateOfBirth;

  String _gender = '';
  String get gender => _gender;

  static const List<String> genderOptions = [
    'Male',
    'Female',
    'Prefer not to say',
  ];

  void setDateOfBirth(DateTime date) {
    _dateOfBirth = date;
    notifyListeners();
  }

  void setGender(String value) {
    _gender = value;
    notifyListeners();
  }

  String get formattedDateOfBirth {
    if (_dateOfBirth == null) return '';
    return '${_dateOfBirth!.year}-'
        '${_dateOfBirth!.month.toString().padLeft(2, '0')}-'
        '${_dateOfBirth!.day.toString().padLeft(2, '0')}';
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

    _setLoading(true);

    try {
      if (_signupType == SignupType.user) {
        await _authService.signUpWithEmail(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
          phone: phoneController.text.trim(),
          dateOfBirth: formattedDateOfBirth,
          gender: _gender,
        );
      } else {
        await _authService.signUpAsDriver(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
          firstName: firstNameController.text.trim(),
          lastName: lastNameController.text.trim(),
          phone: phoneController.text.trim(),
          licenseFile: _selectedLicenseFile!,
          dateOfBirth: formattedDateOfBirth,
          gender: _gender,
          bankAccountName: bankAccountNameController.text.trim(),
          bankName: bankNameController.text.trim(),
          accountNumber: accountNumberController.text.trim(),
          bankCode: bankCodeController.text.trim(),
        );
      }

      final uid = _authService.currentUser!.uid;
      _notificationService.initialize(uid);

      _setLoading(false);


      // Now that the loader is off, we can safely navigate.
      if (context.mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const MainScreen()),
              (route) => false,
        );
      } else {
        // This is unlikely to happen here but is good practice.
      }

    } on FirebaseAuthException catch (e) {
      _showSnackBar(context, _friendlyAuthError(e.code));
    } catch (_) {
      _showSnackBar(context, "Something went wrong. Please try again.");
    } finally {
      // The 'finally' block ensures that no matter what happens (success or error),
      // we make one final check to turn off the loader. This is now a safeguard
      // primarily for the 'catch' block scenario.
      if (_isLoading) {
        _setLoading(false);
      }
    }
  }
  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  String _friendlyAuthError(String code) {
    switch (code) {
      case 'email-already-in-use':
        return 'An account already exists with this email address.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'weak-password':
        return 'Password is too weak. Please use at least 6 characters.';
      case 'operation-not-allowed':
        return 'Sign-up is currently unavailable. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection and try again.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      default:
        return 'Sign-up failed. Please check your details and try again.';
    }
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
    bankAccountNameController.dispose();
    bankNameController.dispose();
    accountNumberController.dispose();
    bankCodeController.dispose();
    super.dispose();
  }
}