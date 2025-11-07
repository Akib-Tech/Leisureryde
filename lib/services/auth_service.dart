import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/services/storage_service.dart';

import '../app/enums.dart';
import 'database_service.dart';
import 'local_storage_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final LocalStorageService _localStorageService = locator<LocalStorageService>();
  final DatabaseService _databaseService = locator<DatabaseService>(); // Add this
  final StorageService _storageService = locator<StorageService>(); // Add this

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
  Future<UserRole> getCurrentUserRole() async {
    if (_firebaseAuth.currentUser == null) return UserRole.user;
    final doc = await _db.collection('users').doc(_firebaseAuth.currentUser!.uid).get();
    final roleString = doc.data()?['role'] ?? 'user';
    switch (roleString) {
      case 'admin':
        return UserRole.admin;
      case 'driver':
        return UserRole.driver;
      default:
        return UserRole.user;
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

  Future<void> signUpAsDriver({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
    required File licenseFile, // Driver-specific file
  }) async {
    try {
      // 1. Create the user in Firebase Auth
      final UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? newUser = userCredential.user;

      if (newUser != null) {
        // 2. Upload the license file to Firebase Storage
        final String licenseUrl = await _storageService.uploadFile(
          licenseFile,
          'driver_licenses/${newUser.uid}/${licenseFile.path.split('/').last}',
        );

        // 3. Create the driver profile in Firestore with the license URL
        await _databaseService.createDriverProfile(
          uid: newUser.uid,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
          licenseUrl: licenseUrl,
        );
      }
    } on FirebaseAuthException catch (e) {
      // ... (same error handling as before)
      rethrow;
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _firebaseAuth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      // Handle errors
      rethrow;
    }
  }




  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    try {
      // 1. Create the user in Firebase Authentication
      final UserCredential userCredential = await _firebaseAuth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final User? newUser = userCredential.user;

      if (newUser != null) {
        await _databaseService.createUserProfile(
          uid: newUser.uid,
          firstName: firstName,
          lastName: lastName,
          email: email,
          phone: phone,
        );
      }
    } on FirebaseAuthException catch (e) {
      if (e.code == 'weak-password') {
        throw Exception('The password provided is too weak.');
      } else if (e.code == 'email-already-in-use') {
        throw Exception('An account already exists for that email.');
      }
      rethrow; // Rethrow for generic errors
    } catch (e) {
      rethrow;
    }
  }

  Future<void> signOut() async {
    await _firebaseAuth.signOut();
  }

  Future<void> deleteAccount() async {
    final user = _firebaseAuth.currentUser;
    if (user == null) {
      throw Exception("No user is currently signed in.");
    }

    try {
      await _databaseService.deleteUserProfile(user.uid);

      await user.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        // This is a Firebase security protection.
        // The user must reauthenticate before account deletion.
        throw Exception('This action requires you to sign in again for security.');
      } else {
        throw Exception("FirebaseAuth error: ${e.message}");
      }
    } catch (e) {
      throw Exception("Error deleting account: $e");
    }
  }
}