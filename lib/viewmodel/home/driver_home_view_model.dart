import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart';
import 'package:leisureryde/services/ride_service.dart';
import '../../services/driver_locator.dart';   // your DriverLocationUpdater helper
import '../maps/maps_viewmodel.dart';

class DriverHomeViewModel extends ChangeNotifier {
  // --- Services ---
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();
  final RideService _rideService = locator<RideService>();

  // --- Map + State ---
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  late final MapViewModel mapViewModel;

  // --- Driver Info ---
  DriverProfile? _driverProfile;
  DriverProfile? get driverProfile => _driverProfile;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  // --- Live location updater ---
  DriverLocationUpdater? _locUpdater;

  // --- Live data ---
  int _todayTrips = 0;
  double _todayEarnings = 0.0;
  double _hoursOnline = 0.0;
  int _pendingRequestsCount = 0;

  int get todayTrips => _todayTrips;
  double get todayEarnings => _todayEarnings;
  double get hoursOnline => _hoursOnline;
  int get pendingRequestsCount => _pendingRequestsCount;

  StreamSubscription? _dailyStatsSub;
  StreamSubscription? _pendingReqSub;

  // --- Constructor ---
  DriverHomeViewModel() {
    mapViewModel = MapViewModel();
    initializeDriverHome();
  }

  // ===================================
  // INITIALIZATION
  // ===================================
  Future<void> initializeDriverHome() async {
    _isLoading = true;
    notifyListeners();

    // ✅ Step 1: initialize map first
    await mapViewModel.initialize();

    // ✅ Step 2: load driver profile
    final user = _authService.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _driverProfile = await _databaseService.getDriverProfile(user.uid);

      // If approved, check online status
      if (_driverProfile?.isApproved == true) {
        _isOnline = _driverProfile!.isOnline;
        if (_isOnline) {
          _startLocationUpdates();
          _startListeningToStats();
        }
      } else {
        _isOnline = false;
      }
    } catch (e) {
      debugPrint("Driver profile load error: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ===================================
  // ONLINE / OFFLINE TOGGLE
  // ===================================
  Future<void> toggleOnlineStatus() async {
    if (_driverProfile == null) return;

    _isOnline = !_isOnline;
    notifyListeners();

    try {
      await _databaseService.updateDriverOnlineStatus(_driverProfile!.uid, _isOnline);

      if (_isOnline) {
        _startLocationUpdates();
        _startListeningToStats();
      } else {
        await _stopLocationUpdates();
        _stopListeningToStats();
      }
    } catch (e) {
      debugPrint("Error toggling online: $e");
      _isOnline = !_isOnline;
      notifyListeners();
    }
  }

  // ===================================
  // LOCATION UPDATER
  // ===================================
  Future<void> _startLocationUpdates() async {
    if (_driverProfile == null) return;
    _locUpdater ??= DriverLocationUpdater(_driverProfile!.uid);
    await _locUpdater!.start(); // starts continuous GPS->Firestore update
  }

  Future<void> _stopLocationUpdates() async {
    await _locUpdater?.stop();
  }

  // ===================================
  // FIRESTORE LIVE STATS
  // ===================================
  void _startListeningToStats() {
    if (_driverProfile == null) return;

    // Cancel any old listeners first
    _dailyStatsSub?.cancel();
    _pendingReqSub?.cancel();

    // Daily trips + earnings
    _dailyStatsSub = _databaseService
        .getTodaysTripsStream(_driverProfile!.uid)
        .listen((docs) {
      _todayTrips = docs.length;
      _todayEarnings =
          docs.fold(0.0, (sum, doc) => sum + (doc['fare'] ?? 0.0));
      notifyListeners();
    });

    // Pending ride requests count
    _pendingReqSub = _rideService.getRideRequestsStream().listen((rides) {
      // Ideally filter by status == 'pending'
      _pendingRequestsCount = rides
          .where((r) => r.status == RideStatus.pending.toString())
          .length;
      notifyListeners();
    });

    final lastOnlineTimestamp = _driverProfile!.lastWentOnlineAt;
    if (lastOnlineTimestamp != null) {
      final duration =
      DateTime.now().difference(lastOnlineTimestamp.toDate());
      _hoursOnline = duration.inMinutes / 60.0;
    }
  }

  void _stopListeningToStats() {
    _dailyStatsSub?.cancel();
    _pendingReqSub?.cancel();

    _todayTrips = 0;
    _todayEarnings = 0;
    _hoursOnline = 0;
    _pendingRequestsCount = 0;
    notifyListeners();
  }

  // ===================================
  // RIDE REQUESTS ACTIONS
  // ===================================
  Future<void> acceptRide(String rideId) async {
    if (_driverProfile == null) return;
    await _rideService.acceptRide(rideId, _driverProfile!.uid);
  }

  Future<void> declineRide(String rideId) async {
    await _rideService.declineRide(rideId);
  }

  // ===================================
  // CLEANUP
  // ===================================
  @override
  void dispose() {
    mapViewModel.dispose();
    _dailyStatsSub?.cancel();
    _pendingReqSub?.cancel();
    super.dispose();
  }
}