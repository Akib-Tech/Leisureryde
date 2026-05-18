import 'dart:async';
import 'dart:math' as math;
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
import '../../services/voice_navigation_service.dart';
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
  StreamSubscription<DocumentSnapshot>? _activeRideDocSubscription;
  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;

  bool _rideCancelledByUser = false;
  bool get rideCancelledByUser => _rideCancelledByUser;

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

  // Last position at which we recalculated the route.
  // Prevents hammering the Directions API on every GPS tick.
  LatLng? _lastRouteCalcPosition;

  // Live ETA values from the most-recent Directions API result.
  int _remainingSeconds = 0;
  double _remainingDistanceMiles = 0.0;

  int get remainingSeconds => _remainingSeconds;
  double get remainingDistanceMiles => _remainingDistanceMiles;

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
  final VoiceNavigationService _voiceNav = locator<VoiceNavigationService>();

  // Tracks the last ride+status we called beginNewRoute() for, so that
  // recalculations on the same leg call refreshSteps() instead.
  String? _lastVoiceRideId;
  RideStatus? _lastVoiceStatus;

  bool get voiceEnabled => _voiceNav.isEnabled;

  /// The current maneuver step — used to drive the on-screen navigation banner.
  RouteStep? get currentNavStep => _voiceNav.currentStep;

  /// The first upcoming step with an actual turn maneuver (non-null maneuver).
  /// Used by the navigation banner to show the correct direction icon even
  /// when the active step is a straight/head segment.
  RouteStep? get nextNavManeuverStep => _voiceNav.nextManeuverStep;

  /// Live distance to the next turn in metres.
  int get distanceToNextTurnMeters => _voiceNav.distanceToNextTurnMeters;

  void toggleVoice() {
    _voiceNav.toggle();
    notifyListeners();
  }

  Future<void> testVoice() => _voiceNav.testSpeak();

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
          _notificationService.subscribeToOnlineDriversTopic();
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

  /// Pre-populates the active ride immediately after the driver accepts from
  /// the ride-requests screen. This makes the ActiveTripDriverBottomSheet
  /// appear at once instead of waiting for the Firestore stream to fire.
  /// The doc subscription takes over from here and handles all status changes.
  void preSetActiveRide(RideRequest ride) {
    _activeRide = ride;
    _lastRouteCalcPosition = null;
    // Clear stale voice-nav steps from any previous ride so GPS ticks that
    // fire before the new route is calculated cannot trigger a false
    // "arrived at pickup" announcement.
    _lastVoiceRideId = null;
    _lastVoiceStatus = null;
    _voiceNav.reset();
    // Seed the driver position from the map's device GPS so the initial
    // _drawRouteForActiveRide() call below doesn't bail out early when the
    // location stream hasn't fired its first tick yet.
    if (_driverCurrentPosition == null && mapViewModel.currentPosition != null) {
      _driverCurrentPosition = LatLng(
        mapViewModel.currentPosition!.latitude,
        mapViewModel.currentPosition!.longitude,
      );
    }
    notifyListeners();
    _subscribeToActiveRideDoc(ride.id);
    // Draw the pickup route right away — the location listener won't redraw
    // until the driver moves 30 m, which could be a long wait at a standstill.
    _drawRouteForActiveRide();
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

    // Query stream discovers when a ride is assigned to this driver.
    // A separate document subscription (below) tracks that ride's full lifecycle,
    // including cancellation by the user — which the query misses because the
    // cancelled status drops out of the 'whereIn' filter.
    _activeRideSubscription = FirebaseFirestore.instance
        .collection('rideRequests')
        .where('driverId', isEqualTo: _driverProfile!.uid)
        .where('status', whereIn: ['accepted', 'enroute', 'ongoing', 'pending'])
        .limit(1)
        .snapshots()
        .listen((snapshot) async {
      if (snapshot.docs.isNotEmpty) {
        final rideId = snapshot.docs.first.id;
        // Only attach a new doc listener when we see a genuinely new ride.
        if (_activeRide?.id != rideId) {
          _subscribeToActiveRideDoc(rideId);
        }
      }
      // When the query returns empty the doc subscription handles cleanup.
    }, onError: (error) {
      debugPrint("DriverHomeViewModel: Active ride stream error: $error");
    });

    // Also listen to the driver's own GPS position so we can update
    // the route as the driver moves.
    _listenToOwnLocation();
  }

  /// Document-level subscription for the active ride — catches ALL status
  /// changes, including user cancellation that drops out of the query filter.
  void _subscribeToActiveRideDoc(String rideId) {
    _activeRideDocSubscription?.cancel();

    _activeRideDocSubscription = FirebaseFirestore.instance
        .collection('rideRequests')
        .doc(rideId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        _activeRide = null;
        mapViewModel.clearRoute();
        notifyListeners();
        return;
      }

      final ride = RideRequest.fromFirestore(snapshot);

      if (ride.status == RideStatus.cancelled) {
        _rideCancelledByUser = true;
        _activeRide = null;
        _lastVoiceRideId = null;
        _lastVoiceStatus = null;
        _voiceNav.reset();
        _activeRideDocSubscription?.cancel();
        _activeRideDocSubscription = null;
        mapViewModel.clearRoute();
        notifyListeners();
        return;
      }

      if (ride.status.isTerminal) {
        if (ride.status == RideStatus.completed) {
          await _voiceNav.announceArrival();
        } else {
          _voiceNav.reset();
        }
        _activeRide = null;
        _lastVoiceRideId = null;
        _lastVoiceStatus = null;
        _activeRideDocSubscription?.cancel();
        _activeRideDocSubscription = null;
        mapViewModel.clearRoute();
        notifyListeners();
        return;
      }

      final bool rideChanged =
          _activeRide?.id != ride.id || _activeRide?.status != ride.status;
      _activeRide = ride;

      // Seed driver position from GPS fix if the Firestore watcher hasn't
      // fired yet (common on the first tick right after accepting a ride).
      if (_driverCurrentPosition == null &&
          mapViewModel.currentPosition != null) {
        _driverCurrentPosition = LatLng(
          mapViewModel.currentPosition!.latitude,
          mapViewModel.currentPosition!.longitude,
        );
      }

      notifyListeners();
      if (rideChanged) await _drawRouteForActiveRide();
    }, onError: (error) {
      debugPrint("DriverHomeViewModel: Ride doc stream error: $error");
    });
  }

  void acknowledgePassengerCancellation() {
    _rideCancelledByUser = false;
    notifyListeners();
  }

  /// Haversine distance in metres between two LatLng points.
  double _metersApart(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final aa = sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    return r * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  }

  /// Listens to the driver's own real-time GPS from Firestore
  /// (written there by DriverLocationUpdater) and redraws the route
  /// only when the driver has moved enough to warrant a new Directions call.
  void _listenToOwnLocation() {
    if (_driverProfile == null) return;

    _driverLocationSubscription?.cancel();
    _lastRouteCalcPosition = null;

    _driverLocationSubscription = _databaseService
        .getDriverLocationStream(_driverProfile!.uid)
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      // Use num? cast — Firestore may store these as int or double.
      final lat = (data['latitude'] as num?)?.toDouble();
      final lng = (data['longitude'] as num?)?.toDouble();
      final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;

      if (lat == null || lng == null) return;

      final newPos = LatLng(lat, lng);
      _driverCurrentPosition = newPos;

      // Keep the camera centred on the driver and rotate the map to heading.
      if (_activeRide != null) {
        mapViewModel.followWithBearing(newPos, heading);
      }

      // Voice navigation — checked on every GPS tick regardless of the
      // route-recalculation threshold so announcements are timely.
      if (_activeRide != null) {
        await _voiceNav.onPositionUpdate(newPos);
        // Notify so the navigation banner updates its distance counter.
        notifyListeners();
      }

      // Only recalculate the route when the driver has moved > 30 m to avoid
      // hammering the Directions API on every GPS tick.
      if (_lastRouteCalcPosition == null ||
          _metersApart(_lastRouteCalcPosition!, newPos) > 30) {
        _lastRouteCalcPosition = newPos;
        await _drawRouteForActiveRide();
      }
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

      // Update live ETA — refreshed every time the driver moves 30 m.
      _remainingSeconds = result.durationValue ?? 0;
      _remainingDistanceMiles = ((result.distanceValue ?? 0) * 0.000621371);

      // Feed the freshest polyline to the voice service for off-route detection
      // before updating the steps.
      _voiceNav.setPolyline(result.polylinePoints);

      // Tell the voice service which leg we are on so arrival announcements
      // say "pickup location" vs "destination" as appropriate.
      _voiceNav.setLegContext(_activeRide!.status != RideStatus.ongoing);

      // Feed steps to the voice service.  Only call beginNewRoute() when the
      // ride or its status has genuinely changed; otherwise refreshSteps() so
      // announcement flags are preserved across the 30 m recalculations.
      final isNewLeg = _lastVoiceRideId != _activeRide!.id ||
          _lastVoiceStatus != _activeRide!.status;
      if (isNewLeg) {
        _lastVoiceRideId = _activeRide!.id;
        _lastVoiceStatus = _activeRide!.status;
        await _voiceNav.beginNewRoute(result.steps);
      } else {
        await _voiceNav.refreshSteps(result.steps);
      }
    }
  }

  void _updateDestinationMarker(LatLng destination) {
    mapViewModel.updateMarker(Marker(
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
    ));
  }

  void _stopListeningToActiveRide() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
    _activeRideDocSubscription?.cancel();
    _activeRideDocSubscription = null;
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _activeRide = null;
    _driverCurrentPosition = null;
    _lastRouteCalcPosition = null;
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
    _activeRideDocSubscription?.cancel();
    _driverLocationSubscription?.cancel();
    _voiceNav.dispose();
    super.dispose();
  }
}