import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';

import 'local_storage_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final LocalStorageService _localStorageService = locator<LocalStorageService>();

  User? _currentUser;
  User? get currentUser => _currentUser;

  bool get isLoggedIn => _currentUser != null;

  AuthService() {
    _firebaseAuth.authStateChanges().listen(_onAuthStateChanged);
  }

  Future<void> tryAutoLogin() async {
    if (_localStorageService.isUserLoggedIn) {
    }
  }

  Future<void> _onAuthStateChanged(User? user) async {
    _currentUser = user;
    if (user == null) {
      await _localStorageService.setUserLoggedIn(false);
    } else {
      await _localStorageService.setUserLoggedIn(true);
    }
    notifyListeners();
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // Handle errors
      rethrow;
    }
  }

  // Placeholder for sign-out logic
  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }
}