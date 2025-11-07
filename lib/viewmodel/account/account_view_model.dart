import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';

import '../../models/saved_places.dart';
import '../../models/user_profile.dart';
import '../../screens/shared/account_screen/saved_places_screen.dart';
import '../../screens/shared/splash_screen/welcome_screen.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';
import '../../services/storage_service.dart';

class AccountViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();
  final StorageService _storageService = locator<StorageService>();

  List<SavedPlace> _savedPlaces = [];
  List<SavedPlace> get savedPlaces => _savedPlaces;

  bool _isLoadingPlaces = false;
  bool get isLoadingPlaces => _isLoadingPlaces;

  final bool isDriver;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isUploading = false;
  bool get isUploading => _isUploading;

  AccountViewModel({required this.isDriver}) {
    loadInitialData();
  }

  Future<void> loadInitialData() async {
    _isLoading = true;
    notifyListeners();

    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    await Future.wait([
      _loadProfile(uid),
      _loadSavedPlaces(uid),
    ]);

    _isLoading = false;
    notifyListeners();
  }

  Future<void> _loadProfile(String uid) async {
    try {
      if (isDriver) {
        _userProfile = await _databaseService.getDriverProfile(uid);
      } else {
        _userProfile = await _databaseService.getUserProfile(uid);
      }
    } catch (e) {
      print("Failed to load profile: $e");
    }
  }

  Future<void> _loadSavedPlaces(String uid) async {
    try {
      _savedPlaces = await _databaseService.getSavedPlaces(uid);
    } catch (e) {
      print("Error loading saved places: $e");
    }
    // No need to notify listeners here as loadInitialData handles it
  }
  Future<void> pickAndUploadProfilePicture() async {
    // 1. Pick Image
    final result = await FilePicker.platform.pickFiles(
      type: FileType.image,
      allowMultiple: false,
    );

    if (result == null || result.files.single.path == null) return;

    final file = File(result.files.single.path!);
    final uid = _userProfile?.uid;
    if (uid == null) return;

    _isUploading = true;
    notifyListeners();

    try {
      final downloadUrl = await _storageService.uploadFile(
        file,
        'profile_images/$uid/profile.jpg',
      );

      await _databaseService.updateUserProfileData(uid, {
        'profileImageUrl': downloadUrl,
      });

      if (_userProfile != null) {
        _userProfile = _userProfile!.copyWith(profileImageUrl: downloadUrl);
      }

    } catch (e) {
      print("Failed to upload profile picture: $e");
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> addOrUpdateSavedPlace(BuildContext context, String placeName) async {
    final uid = _userProfile?.uid;
    if (uid == null) return;

    final result = await Navigator.of(context).push<SavedPlace>(
      MaterialPageRoute(
        builder: (_) => AddSavedPlaceScreen(placeType: placeName),
      ),
    );

    if (result != null && context.mounted) {
      try {
        await _databaseService.addOrUpdateSavedPlace(uid, result);
        await _loadSavedPlaces(uid);
        notifyListeners(); // Refresh the UI with the new list
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("${result.name} location saved!")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error saving location: $e")),
        );
      }
    }
  }
  Future<void> deleteSavedPlace(String placeName) async {
    final uid = _userProfile?.uid;
    if (uid == null) return;

    try {
      await _databaseService.deleteSavedPlace(uid, placeName);
      _savedPlaces.removeWhere((place) => place.name == placeName);
      notifyListeners();
    } catch (e) {
      print("Error deleting saved place: $e");
    }
  }
  Future<void> signOut(BuildContext context) async {
    await _authService.signOut();
    if (context.mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
      );
    }
  }

  Future<void> deleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('Delete Account?'),
            content: const Text(
              'This is a permanent action. All your data, ride history, and settings will be permanently deleted. Are you sure you want to proceed?',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                    'Delete', style: TextStyle(color: Colors.red)),
              ),
            ],
          ),
    );

    if (confirm != true) return;

    _isLoading = true;
    notifyListeners();

    try {
      await _authService.deleteAccount();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Account successfully deleted.')),
        );

        // Navigate to your Welcome or Login screen
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (route) => false,
        );
      }
    } on Exception catch (e) {
      if (context.mounted) {
        final message = e.toString().contains('requires you to sign in again')
            ? 'You must log in again before deleting your account.'
            : 'Error deleting account: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)));
      }
    } finally {
      if (context.mounted) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
}