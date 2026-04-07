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
import '../../services/push_notifications_service.dart';
import '../maps/maps_viewmodel.dart';

class DriverHomeViewModel extends ChangeNotifier {
  // --- Services ---
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();
  final RideService _rideService = locator<RideService>();

  RideRequest? _activeRide;
  RideRequest? get activeRide => _activeRide;

  bool get hasActiveTrip => _activeRide != null;

  StreamSubscription<QuerySnapshot>? _activeRideSubscription;

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

  final NotificationService _notificationService = locator<NotificationService>();


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
          _startListeningToActiveRide();
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

    // Optimistically update UI
    _isOnline = !_isOnline;
    notifyListeners();

    try {
      // 1. Update driver status in the database
      await _databaseService.updateDriverOnlineStatus(_driverProfile!.uid, _isOnline);

      // 2. Subscribe or unsubscribe from the 'online_drivers' topic
      if (_isOnline) {
        _notificationService.subscribeToOnlineDriversTopic();
        _startLocationUpdates();
        _startListeningToStats();
        _startListeningToActiveRide();
      } else {
        _notificationService.unsubscribeFromOnlineDriversTopic();
        await _stopLocationUpdates();
        _stopListeningToStats();
        _stopListeningToActiveRide();
      }
    } catch (e) {
      debugPrint("Error toggling online: $e");
      // Revert UI on failure
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
      _todayEarnings = docs.fold(0.0, (sum, doc) {
        final fare = doc['fare'];

        if (fare is int) return sum + fare.toDouble();
        if (fare is double) return sum + fare;
        if (fare is String) return sum + (double.tryParse(fare) ?? 0.0);

        return sum;
      });
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
    _activeRideSubscription?.cancel();
    super.dispose();
  }

  // ===================================
  // Refresh
  // ===================================
  Future<void> refreshStats() async {
    if (_driverProfile == null) return;

    try {
      // Take the first value from the same stream you already use for live updates.
      final docs = await _databaseService.getTodaysTripsStream(_driverProfile!.uid).first;

      print('TODAYS TRIPS: ${docs.first.data().toString()}');
      // Update the same private fields you already expose via getters
      _todayTrips = docs.length;
      _todayEarnings = docs.fold(0.0, (sum, doc) => sum + (doc['fare'] ?? 0.0));
      print('TODAYS EARNING: $_todayEarnings');
      // Recompute hoursOnline too if you want
      final lastOnlineTimestamp = _driverProfile!.lastWentOnlineAt;
      if (lastOnlineTimestamp != null) {
        _hoursOnline = DateTime.now().difference(lastOnlineTimestamp.toDate()).inMinutes / 60.0;
      }

      notifyListeners();
    } catch (e) {
      debugPrint('Error refreshing stats: $e');
    }
  }

  Future<void> _startListeningToActiveRide() async {
    if (_driverProfile?.uid == null) return;

    _activeRideSubscription?.cancel();

    print("driver profile: ${_driverProfile!.uid}");
    _activeRideSubscription = FirebaseFirestore.instance
        .collection('rideRequests')
        .where('driverId', isEqualTo: _driverProfile!.uid)
        .where('status', whereIn: ['accepted', 'enroute', 'ongoing','pending'])
        .limit(1) // a driver should have max 1 active trip
        .snapshots()
        .listen((snapshot) {
          print(snapshot.docs.isEmpty);
      if (snapshot.docs.isNotEmpty) {
        _activeRide = RideRequest.fromFirestore(snapshot.docs.first);
        print(_activeRide);
      } else {
        _activeRide = null;
        print(_activeRide);
      }
      notifyListeners(); // ← very important
    }, onError: (e) {
      debugPrint("Active ride stream error: $e");
    });
  }

  // ── Add this cleanup method ──
  void _stopListeningToActiveRide() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
    _activeRide = null;
  }

  /// Re-requests location permission and refreshes the map
  Future<void> requestLocationPermission() async {
    _isLoading = true;
    notifyListeners();

    try {
      // Re-initialize the map (this should trigger permission request again)
      await mapViewModel.initialize();

      // If permission is now granted, refresh driver profile and start listeners
      if (mapViewModel.currentPosition != null) {
        final user = _authService.currentUser;
        if (user != null) {
          _driverProfile = await _databaseService.getDriverProfile(user.uid);

          if (_driverProfile?.isApproved == true && _isOnline) {
            _startLocationUpdates();
            _startListeningToStats();
            _startListeningToActiveRide();
          }
        }
      }
    } catch (e) {
      debugPrint("Error requesting location permission: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

}