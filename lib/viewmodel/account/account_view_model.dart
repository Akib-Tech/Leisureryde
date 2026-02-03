import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/models/saved_places.dart';
import 'package:leisureryde/models/user_profile.dart';
import 'package:leisureryde/screens/shared/account_screen/saved_places_screen.dart';
import 'package:leisureryde/screens/shared/splash_screen/welcome_screen.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart';
import 'package:leisureryde/services/storage_service.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/push_notifications_service.dart';

enum DocumentType {
  licenseUrl,
  vehicleRegistrationUrl,
  proofOfInsuranceUrl,
}

class AccountViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();
  final StorageService _storageService = locator<StorageService>();
  final NotificationService _notificationService = locator<NotificationService>(); // NEW

  List<SavedPlace> _savedPlaces = [];
  List<SavedPlace> get savedPlaces => _savedPlaces;

  final bool isDriver;

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  DriverProfile? get driverProfile =>
      _userProfile is DriverProfile ? _userProfile as DriverProfile : null;

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
      _userProfile = isDriver
          ? await _databaseService.getDriverProfile(uid)
          : await _databaseService.getUserProfile(uid);
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
  }

  Future<void> pickAndUploadProfilePicture() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);
    final uid = _userProfile?.uid;
    if (uid == null) return;
    _isUploading = true;
    notifyListeners();
    try {
      final downloadUrl = await _storageService.uploadFile(file, 'profile_images/$uid/profile.jpg');
      await _databaseService.updateUserProfileData(uid, {'profileImageUrl': downloadUrl});
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

  Future<void> updateVehicleInformation({
    required String carModel,
    required String licensePlate,
  }) async {
    final uid = userProfile?.uid;
    if (uid == null || driverProfile == null) return;
    try {
      final updateData = {'carModel': carModel, 'licensePlate': licensePlate};
      await _databaseService.updateUserProfileData(uid, updateData);
      _userProfile = driverProfile!.copyWith(carModel: carModel, licensePlate: licensePlate);
      notifyListeners();
    } catch (e) {
      print("Failed to update vehicle information: $e");
    }
  }

  Future<void> pickAndUploadDocument(BuildContext context, DocumentType documentType) async {
    final uid = userProfile?.uid;
    if (uid == null || driverProfile == null) return;
    final result = await FilePicker.platform.pickFiles(type: FileType.image);
    if (result == null || result.files.single.path == null) return;
    final file = File(result.files.single.path!);

    _isUploading = true;
    notifyListeners();
    try {
      final documentTypeName = documentType.name;
      final downloadUrl = await _storageService.uploadFile(file, 'driver_documents/$uid/$documentTypeName.jpg');
      await _databaseService.updateUserProfileData(uid, {documentTypeName: downloadUrl});

      switch (documentType) {
        case DocumentType.licenseUrl:
          _userProfile = driverProfile!.copyWith(licenseUrl: downloadUrl);
          break;
        case DocumentType.vehicleRegistrationUrl:
          _userProfile = driverProfile!.copyWith(vehicleRegistrationUrl: downloadUrl);
          break;
        case DocumentType.proofOfInsuranceUrl:
          _userProfile = driverProfile!.copyWith(proofOfInsuranceUrl: downloadUrl);
          break;
      }
      notifyListeners();

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded successfully!')));
      }
    } catch (e) {
      print("Failed to upload document: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      _isUploading = false;
      notifyListeners();
    }
  }

  Future<void> launchUrlHelper(String url, BuildContext context) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.inAppWebView);
    } else {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not open the page.')),
        );
      }
    }
  }

  Future<void> addOrUpdateSavedPlace(BuildContext context, String placeName) async {
    final uid = userProfile?.uid;
    if (uid == null) return;
    final result = await Navigator.of(context).push<SavedPlace>(
        MaterialPageRoute(builder: (_) => AddSavedPlaceScreen(placeType: placeName)));
    if (result != null && context.mounted) {
      try {
        await _databaseService.addOrUpdateSavedPlace(uid, result);
        await _loadSavedPlaces(uid);
        notifyListeners();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("${result.name} location saved!")));
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error saving location: $e")));
      }
    }
  }

  Future<void> deleteSavedPlace(String placeName) async {
    final uid = userProfile?.uid;
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
          MaterialPageRoute(builder: (_) => const WelcomePage()), (route) => false);
    }
  }

  Future<void> deleteAccount(BuildContext context) async {
    final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete Account?'),
          content: const Text(
              'This is a permanent action. All your data will be permanently deleted. Are you sure?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
            TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Delete', style: TextStyle(color: Colors.red))),
          ],
        ));
    if (confirm != true) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _authService.deleteAccount();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Account successfully deleted.')));
        Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomePage()), (route) => false);
      }
    } on Exception catch (e) {
      if (context.mounted) {
        final message = e.toString().contains('requires-recent-login')
            ? 'Please sign in again before deleting your account.'
            : 'Error deleting account: ${e.toString()}';
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
      }
    } finally {
      if (context.mounted) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
  Future<void> updateNotificationPreference(bool isEnabled) async {
    final uid = _userProfile?.uid;
    if (uid == null) return;

    try {
      // 1. Call the service to do the heavy lifting
      await _notificationService.updateUserPushNotificationPreference(uid, isEnabled);

      // 2. Update the local user profile state for instant UI feedback
      if (_userProfile != null) {
        _userProfile = _userProfile!.copyWith(pushNotificationsEnabled: isEnabled);
        notifyListeners();
      }
    } catch (e) {
      print("Failed to update notification preference: $e");
      // Optionally, revert the switch state and show an error
    }
  }
}