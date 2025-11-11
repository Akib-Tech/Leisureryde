// In: lib/viewmodel/ride/ride_request_view_model.dart (or your file path)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/models/driver_profile.dart'; // NEW: Import DriverProfile
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart'; // NEW: Import DatabaseService
import 'package:leisureryde/services/ride_service.dart';

class RideRequestsViewModel extends ChangeNotifier {
  // Your existing services
  final RideService _rideService = locator<RideService>();
  final AuthService _authService = locator<AuthService>();

  // NEW: Add DatabaseService to fetch the driver's profile
  final DatabaseService _databaseService = locator<DatabaseService>();

  // NEW: Properties to hold the driver's profile and loading state
  DriverProfile? _driverProfile;
  bool _isInitializing = true;

  // NEW: Public getters for the UI to read the state
  bool get isInitializing => _isInitializing;
  bool get isDriverApproved => _driverProfile?.isApproved ?? false;

  // Your existing stream getter (this remains unchanged)
  Stream<List<RideRequest>> get rideRequestsStream =>
      _rideService.getRideRequestsStream();

  // NEW: Constructor to trigger the profile fetch on creation
  RideRequestsViewModel() {
    _initialize();
  }

  // NEW: Initialization method to fetch the driver profile
  Future<void> _initialize() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _isInitializing = false;
      notifyListeners();
      return;
    }

    try {
      _driverProfile = await _databaseService.getDriverProfile(uid);
    } catch (e) {
      print("Error fetching driver profile in RideRequestsViewModel: $e");
    } finally {
      _isInitializing = false;
      notifyListeners();
    }
  }

  // Your existing methods (these remain unchanged)
  Future<void> acceptRide(String rideId, BuildContext context) async {
    final driverId = _authService.currentUser?.uid;
    if (driverId == null) return;

    try {
      await _rideService.acceptRide(rideId, driverId);
      if (context.mounted) {
        Navigator.pop(context); // Go back to the map
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to accept ride: $e")),
        );
      }
    }
  }

  Future<void> declineRide(String rideId) async {
    try {
      await _rideService.declineRide(rideId);
    } catch (e) {
      print("Failed to decline ride: $e");
    }
  }
}