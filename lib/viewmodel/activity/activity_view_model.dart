
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart';

import '../../models/driver_profile.dart';
import '../../models/ride_request_model.dart';
import '../../services/directions_service.dart';
import '../../services/ride_service.dart';



class ActivityViewModel extends ChangeNotifier {
  // Services
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();

  // State Properties
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<RideRequest> _upcomingRides = [];
  List<RideRequest> get upcomingRides => _upcomingRides;

  List<RideRequest> _pastRides = [];
  List<RideRequest> get pastRides => _pastRides;

  // ✨ FIX 1: The constructor is now simple and correct for this ViewModel.
  // It takes no parameters.
  ActivityViewModel() {
    _fetchRides();
  }

  // ✨ FIX 2: This is the ONLY logic that should be in this file.
  Future<void> _fetchRides() async {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      // Fetch both lists in parallel for better performance
      final results = await Future.wait([
        _databaseService.getUpcomingRides(uid),
        _databaseService.getPastRides(uid),
      ]);
      _upcomingRides = results[0];
      _pastRides = results[1];
    } catch (e) {
      print("Error fetching activity: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}