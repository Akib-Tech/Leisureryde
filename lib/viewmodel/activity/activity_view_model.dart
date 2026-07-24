
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart';

import '../../models/ride_request_model.dart';

class ActivityViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<RideRequest> _upcomingRides = [];
  List<RideRequest> get upcomingRides => _upcomingRides;

  List<RideRequest> _pastRides = [];
  List<RideRequest> get pastRides => _pastRides;

  StreamSubscription<List<RideRequest>>? _upcomingSub;
  StreamSubscription<List<RideRequest>>? _pastSub;

  ActivityViewModel() {
    notifyListeners();
    _subscribeToRides();
  }

  void _subscribeToRides() {
    final uid = _authService.currentUser?.uid;
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    _upcomingSub = _databaseService.getUpcomingRidesStream(uid).listen(
      (rides) {
        _upcomingRides = rides;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        notifyListeners();
      },
    );

    _pastSub = _databaseService.getPastRidesStream(uid).listen(
      (rides) {
        _pastRides = rides;
        _isLoading = false;
        notifyListeners();
      },
      onError: (_) {
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _upcomingSub?.cancel();
    _pastSub?.cancel();
    super.dispose();
  }
}
