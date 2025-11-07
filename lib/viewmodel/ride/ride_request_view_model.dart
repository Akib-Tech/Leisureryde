import 'dart:async';
import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';

import '../../models/ride_request_model.dart';
import '../../services/auth_service.dart';
import '../../services/ride_service.dart';


class RideRequestsViewModel extends ChangeNotifier {
  final RideService _rideService = locator<RideService>();
  final AuthService _authService = locator<AuthService>();

  Stream<List<RideRequest>> get rideRequestsStream =>
      _rideService.getRideRequestsStream();

  Future<void> acceptRide(String rideId, BuildContext context) async {
    final driverId = _authService.currentUser?.uid;
    if (driverId == null) return;

    try {
      await _rideService.acceptRide(rideId, driverId);
      // Navigate to the active ride screen
      Navigator.pop(context); // Go back to the map
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed to accept ride: $e")),
      );
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