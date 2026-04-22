import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart';
import 'package:leisureryde/services/directions_service.dart';
import 'package:leisureryde/services/ride_service.dart';
import '../../services/driver_locator.dart';
import '../../services/push_notifications_service.dart';
import '../maps/maps_viewmodel.dart';

class DriverHomeViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();
  final RideService _rideService = locator<RideService>();
  final DirectionsService _directionsService = locator<DirectionsService>();

  RideRequest? _activeRide;
  RideRequest? get activeRide => _activeRide;

  bool get hasActiveTrip => _activeRide != null;

  StreamSubscription<QuerySnapshot>? _activeRideSubscription;
  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  late final MapViewModel mapViewModel;

  DriverProfile? _driverProfile;
  DriverProfile? get driverProfile => _driverProfile;

  bool _isOnline = false;
  bool get isOnline => _isOnline;

  DriverLocationUpdater? _locUpdater;

  // The driver's own current position — updated from their GPS.
  LatLng? _driverCurrentPosition;

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

  DriverHomeViewModel() {
    mapViewModel = MapViewModel();
    initializeDriverHome();
  }

  Future<void> initializeDriverHome() async {
    _isLoading = true;
    notifyListeners();

    await mapViewModel.initialize();

    final user = _authService.currentUser;
    if (user == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      _driverProfile = await _databaseService.getDriverProfile(user.uid);

      if (_driverProfile?.isApproved == true) {
        _isOnline = _driverProfile!.isOnline;
        if (_isOnline) {
          _startLocationUpdates();
          _startListeningToStats();
          await _startListeningToActiveRide();
        }
      } else {
        _isOnline = false;
      }
    } catch (error) {
      debugPrint("DriverHomeViewModel: Profile load error: $error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> toggleOnlineStatus() async {
    if (_driverProfile == null) return;

    _isOnline = !_isOnline;
    notifyListeners();

    try {
      await _databaseService.updateDriverOnlineStatus(_driverProfile!.uid, _isOnline);

      if (_isOnline) {
        _notificationService.subscribeToOnlineDriversTopic();
        _startLocationUpdates();
        _startListeningToStats();
        await _startListeningToActiveRide();
      } else {
        _notificationService.unsubscribeFromOnlineDriversTopic();
        await _stopLocationUpdates();
        _stopListeningToStats();
        _stopListeningToActiveRide();
        mapViewModel.clearRoute();
      }
    } catch (error) {
      debugPrint("DriverHomeViewModel: Toggle online error: $error");
      _isOnline = !_isOnline;
      notifyListeners();
    }
  }

  Future<void> _startLocationUpdates() async {
    if (_driverProfile == null) return;
    _locUpdater ??= DriverLocationUpdater(_driverProfile!.uid);
    await _locUpdater!.start();
  }

  Future<void> _stopLocationUpdates() async {
    await _locUpdater?.stop();
  }

  void _startListeningToStats() {
    if (_driverProfile == null) return;

    _dailyStatsSub?.cancel();
    _pendingReqSub?.cancel();

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

    _pendingReqSub = _rideService.getRideRequestsStream().listen((rides) {
      _pendingRequestsCount = rides
          .where((rideRequest) => rideRequest.status == RideStatus.pending)
          .length;
      notifyListeners();
    });

    final lastOnlineTimestamp = _driverProfile!.lastWentOnlineAt;
    if (lastOnlineTimestamp != null) {
      final duration = DateTime.now().difference(lastOnlineTimestamp.toDate());
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

  Future<void> acceptRide(String rideId) async {
    if (_driverProfile == null) return;
    await _rideService.acceptRide(rideId, _driverProfile!.uid);
  }

  Future<void> declineRide(String rideId) async {
    await _rideService.declineRide(rideId);
  }

  Future<void> _startListeningToActiveRide() async {
    if (_driverProfile?.uid == null) return;

    _activeRideSubscription?.cancel();

    debugPrint("DriverHomeViewModel: Listening to active ride for driver: ${_driverProfile!.uid}");

    _activeRideSubscription = FirebaseFirestore.instance
        .collection('rideRequests')
        .where('driverId', isEqualTo: _driverProfile!.uid)
        .where('status', whereIn: ['accepted', 'enroute', 'ongoing', 'pending'])
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final updatedRide = RideRequest.fromFirestore(snapshot.docs.first);
        final bool rideChanged = _activeRide?.id != updatedRide.id ||
            _activeRide?.status != updatedRide.status;

        _activeRide = updatedRide;
        notifyListeners();

        // Redraw the route whenever the ride or its status changes.
        if (rideChanged) {
          await _drawRouteForActiveRide();
        }
      } else {
        _activeRide = null;
        // No active ride — clear the map route.
        mapViewModel.clearRoute();
        notifyListeners();
      }
    }, onError: (error) {
      debugPrint("DriverHomeViewModel: Active ride stream error: $error");
    });

    // Also listen to the driver's own GPS position so we can update
    // the route as the driver moves.
    _listenToOwnLocation();
  }

  /// Listens to the driver's own real-time GPS from Firestore
  /// (written there by DriverLocationUpdater) and redraws the route
  /// each time they move.
  void _listenToOwnLocation() {
    if (_driverProfile == null) return;

    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = _databaseService
        .getDriverLocationStream(_driverProfile!.uid)
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final latitude = data['latitude'] as double?;
      final longitude = data['longitude'] as double?;

      if (latitude == null || longitude == null) return;

      _driverCurrentPosition = LatLng(latitude, longitude);

      // Redraw the live route from the updated driver position.
      await _drawRouteForActiveRide();
    });
  }

  /// Draws the correct polyline into mapViewModel based on ride status:
  ///
  /// - accepted / enroute  → driver current position → passenger pickup
  /// - ongoing             → driver current position → passenger destination
  /// - anything else       → clear the route
  ///
  /// Because this writes into mapViewModel (which the GoogleMap widget reads),
  /// the polyline persists even when the driver navigates away and returns —
  /// the data lives in mapViewModel, not in a widget that can be disposed.
  Future<void> _drawRouteForActiveRide() async {
    if (_activeRide == null || _driverCurrentPosition == null) return;

    LatLng routeDestination;

    switch (_activeRide!.status) {
      case RideStatus.accepted:
      case RideStatus.enroute:
        routeDestination = _activeRide!.pickupLocation;
        break;

      case RideStatus.ongoing:
        routeDestination = _activeRide!.destinationLocation;
        break;

      default:
        mapViewModel.clearLiveRoute();
        return;
    }

    final result = await _directionsService.getDirections(
      origin: _driverCurrentPosition!,
      destination: routeDestination,
    );

    if (result != null) {
      // Write the polyline directly into mapViewModel.
      // The GoogleMap widget in DriverHomeScreen reads mapViewModel.polylines,
      // so this is what actually makes the line appear on screen.
      mapViewModel.setLiveRoutePolyline(result.polylinePoints);

      // Also update the destination marker so the driver knows where to go.
      _updateDestinationMarker(routeDestination);
    }
  }

  void _updateDestinationMarker(LatLng destination) {
    mapViewModel.markers.removeWhere(
          (marker) => marker.markerId == const MarkerId('destination'),
    );
    mapViewModel.markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: InfoWindow(
          title: _activeRide!.status == RideStatus.ongoing ? 'Destination' : 'Pickup',
        ),
        icon: BitmapDescriptor.defaultMarkerWithHue(
          _activeRide!.status == RideStatus.ongoing
              ? BitmapDescriptor.hueRed
              : BitmapDescriptor.hueGreen,
        ),
      ),
    );
    mapViewModel.notifyListeners();
  }

  void _stopListeningToActiveRide() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _activeRide = null;
    _driverCurrentPosition = null;
  }

  Future<void> refreshStats() async {
    if (_driverProfile == null) return;

    try {
      final docs = await _databaseService.getTodaysTripsStream(_driverProfile!.uid).first;
      _todayTrips = docs.length;
      _todayEarnings = docs.fold(0.0, (sum, doc) => sum + (doc['fare'] ?? 0.0));

      final lastOnlineTimestamp = _driverProfile!.lastWentOnlineAt;
      if (lastOnlineTimestamp != null) {
        _hoursOnline = DateTime.now().difference(lastOnlineTimestamp.toDate()).inMinutes / 60.0;
      }

      notifyListeners();
    } catch (error) {
      debugPrint("DriverHomeViewModel: Error refreshing stats: $error");
    }
  }

  Future<void> requestLocationPermission() async {
    _isLoading = true;
    notifyListeners();

    try {
      await mapViewModel.initialize();

      if (mapViewModel.currentPosition != null) {
        final user = _authService.currentUser;
        if (user != null) {
          _driverProfile = await _databaseService.getDriverProfile(user.uid);

          if (_driverProfile?.isApproved == true && _isOnline) {
            _startLocationUpdates();
            _startListeningToStats();
            await _startListeningToActiveRide();
          }
        }
      }
    } catch (error) {
      debugPrint("DriverHomeViewModel: Location permission error: $error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    mapViewModel.dispose();
    _dailyStatsSub?.cancel();
    _pendingReqSub?.cancel();
    _activeRideSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    super.dispose();
  }
}