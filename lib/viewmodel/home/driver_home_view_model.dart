// ignore_for_file: unused_field, unused_element, prefer_final_fields, avoid_types_as_parameter_names

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
import 'package:leisureryde/services/fare_calculation_service.dart';
import 'package:leisureryde/services/ride_service.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/driver_locator.dart';
import '../../services/push_notifications_service.dart';
import '../../services/voice_navigation_service.dart';
import '../maps/maps_viewmodel.dart';

class DriverHomeViewModel extends ChangeNotifier {
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();
  final RideService _rideService = locator<RideService>();
  final DirectionsService _directionsService = locator<DirectionsService>();

  // Multiple rides can be active at once if the driver accepts a new one
  // while another is already in progress. _activeRides holds all of them,
  // keyed by ride id; _selectedRideId is whichever one is currently shown
  // in the bottom sheet and being navigated to.
  final Map<String, RideRequest> _activeRides = {};
  String? _selectedRideId;

  List<RideRequest> get activeRides => _activeRides.values.toList(growable: false);
  RideRequest? get activeRide =>
      _selectedRideId != null ? _activeRides[_selectedRideId] : null;
  bool get hasActiveTrip => _activeRides.isNotEmpty;

  StreamSubscription<QuerySnapshot>? _activeRideSubscription;
  final Map<String, StreamSubscription<DocumentSnapshot>> _activeRideDocSubscriptions = {};
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
  LatLng? get driverCurrentPosition => _driverCurrentPosition;

  // Last position and time at which we recalculated the route.
  // Both must satisfy their thresholds before a new Directions API call fires.
  LatLng? _lastRouteCalcPosition;
  DateTime? _lastRouteCalcTime;

  // Live ETA values from the most-recent Directions API result.
  final int _remainingSeconds = 0;
  final double _remainingDistanceMiles = 0.0;

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

  // Tracks the last ride+status+waypoint for which Waze was launched, so we
  // re-launch whenever the leg changes (new ride, new status, or next waypoint).
  String? _lastWazeRideId;
  RideStatus? _lastWazeStatus;
  int _lastWazeWaypointIndex = -1;

  bool get voiceEnabled => _voiceNav.isEnabled;

  // True while a Directions API reroute call is in-flight (off-route detected).
  // Drives the "Recalculating..." state in the navigation banner.
  bool _isRecalculating = false;
  bool get isRecalculating => _isRecalculating;

  // Signals that the upcoming _drawRouteForActiveRide() call was triggered by
  // an off-route deviation — voice should announce the new first turn.
  bool _pendingReroute = false;

  // True while the driver has Waze (or another external nav app) open.
  bool _mutedByWaze = false;
  bool get mutedByWaze => _mutedByWaze;

  /// Mutes in-app voice while an external navigation app is open.
  void muteVoiceForExternalApp() {
    _mutedByWaze = true;
    _voiceNav.mute();
    notifyListeners();
  }

  /// Restores in-app voice when the driver returns from the external app.
  Future<void> restoreVoiceAfterExternalApp() async {
    if (!_mutedByWaze) return;
    _mutedByWaze = false;
    _voiceNav.unmute();
    await _voiceNav.reinitialize();
    notifyListeners();
  }

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

  /// Called by the screen's lifecycle observer when the app returns from
  /// background. Re-initialises the TTS engine which Android may have killed.
  Future<void> reinitializeVoice() => _voiceNav.reinitialize();

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
       
        final fare = _parseFare(doc['fare']);
        return sum + FareCalculationService.driverEarnings(fare);
      });
      notifyListeners();
    });

    _pendingReqSub = _rideService.getRideRequestsStream().listen((rides) {
      _pendingRequestsCount = rides
          .where((rideRequest) => rideRequest.status == RideStatus.pending ||
      rideRequest.status == RideStatus.scheduled)
          .length;


      notifyListeners();
    });

    final lastOnlineTimestamp = _driverProfile!.lastWentOnlineAt;
    if (lastOnlineTimestamp != null) {
      final duration = DateTime.now().difference(lastOnlineTimestamp.toDate());
      _hoursOnline = duration.inMinutes / 60.0;
    }
  }
 double _parseFare(dynamic fare) {
    if (fare is num) return fare.toDouble();
    if (fare is String) return double.tryParse(fare) ?? 0.0;
    return 0.0;
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

  /// Pre-populates an active ride immediately after the driver accepts from
  /// the ride-requests screen. This makes the ActiveTripDriverBottomSheet
  /// appear at once instead of waiting for the Firestore stream to fire.
  /// The doc subscription takes over from here and handles all status changes.
  ///
  /// If another ride is already active, this one joins _activeRides without
  /// stealing focus — the currently selected/viewed ride does not change.
  void preSetActiveRide(RideRequest ride) {
    _activeRides[ride.id] = ride;
    _selectedRideId ??= ride.id;
    // Reset both throttles so _drawRouteForActiveRide fires on the
    // very next GPS tick (or immediately below) rather than waiting 150 m.
    _lastRouteCalcPosition = null;
    _lastRouteCalcTime = null;
    // Seed the driver position from the map's device GPS so the initial
    // _drawRouteForActiveRide() call below doesn't bail out early when the
    // Realtime Database stream hasn't fired its first tick yet.
    if (_driverCurrentPosition == null && mapViewModel.currentPosition != null) {
      _driverCurrentPosition = LatLng(
        mapViewModel.currentPosition!.latitude,
        mapViewModel.currentPosition!.longitude,
      );
    }
    notifyListeners();
    _subscribeToActiveRideDoc(ride.id);
    // Draw the pickup route right away — the location listener won't redraw
    // until the driver moves 150 m, which could be a long wait at a standstill.
    // Only do this for the ride actually being viewed.
    if (_selectedRideId == ride.id) {
      _drawRouteForActiveRide();
    }
  }

  /// Switches which active ride is currently shown in the bottom sheet and
  /// being navigated to. Does not affect the other active rides' Firestore
  /// subscriptions — they keep updating in the background.
  void selectActiveRide(String rideId) {
    if (!_activeRides.containsKey(rideId) || _selectedRideId == rideId) return;
    _selectedRideId = rideId;
    _lastRouteCalcPosition = null;
    _lastRouteCalcTime = null;
    notifyListeners();
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
    // Separate document subscriptions (below), one per ride, track each
    // ride's full lifecycle, including cancellation by the user — which the
    // query misses because the cancelled status drops out of the 'whereIn'
    // filter.
    _activeRideSubscription = FirebaseFirestore.instance
        .collection('rideRequests')
        .where('driverId', isEqualTo: _driverProfile!.uid)
        .where('status', whereIn: ['accepted', 'enroute', 'ongoing'])
        .snapshots()
        .listen((snapshot) async {
      for (final doc in snapshot.docs) {
        // Only attach a new doc listener when we see a genuinely new ride.
        if (!_activeRideDocSubscriptions.containsKey(doc.id)) {
          _subscribeToActiveRideDoc(doc.id);
        }
      }
      // When a ride drops out of the query the doc subscription handles cleanup.
    }, onError: (error) {
      debugPrint("DriverHomeViewModel: Active ride stream error: $error");
    });

    // Also listen to the driver's own GPS position so we can update
    // the route as the driver moves.
    _listenToOwnLocation();
  }

  /// Document-level subscription for one active ride — catches ALL status
  /// changes for that ride, including user cancellation that drops out of
  /// the query filter. Keyed by ride id so multiple can run concurrently.
  void _subscribeToActiveRideDoc(String rideId) {
    _activeRideDocSubscriptions[rideId]?.cancel();

    _activeRideDocSubscriptions[rideId] = FirebaseFirestore.instance
        .collection('rideRequests')
        .doc(rideId)
        .snapshots()
        .listen((snapshot) async {
      if (!snapshot.exists) {
        _removeActiveRide(rideId);
        return;
      }

      final ride = RideRequest.fromFirestore(snapshot);

      if (ride.status == RideStatus.cancelled) {
        _rideCancelledByUser = true;
        _removeActiveRide(rideId);
        return;
      }

      if (ride.status.isTerminal) {
        if (ride.status == RideStatus.completed) {
          await _voiceNav.announceArrival();
        }
        _removeActiveRide(rideId);
        return;
      }

      final bool rideChanged = _activeRides[rideId]?.status != ride.status;
      _activeRides[rideId] = ride;
      // On a cold start / relaunch, _selectedRideId starts out null — this is
      // the only path that discovers an already-active ride via the query
      // stream (preSetActiveRide only runs for a ride accepted this session).
      // Without this, _activeRides is populated but `activeRide` (gated on
      // _selectedRideId) stays null, so the UI falls back to showing no
      // active trip even though one exists.
      _selectedRideId ??= rideId;

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
      if (rideChanged && rideId == _selectedRideId) {
        await _drawRouteForActiveRide();
      }
    }, onError: (error) {
      debugPrint("DriverHomeViewModel: Ride doc stream error: $error");
    });
  }

  /// Removes a ride from the active set (cancelled/completed/deleted) and,
  /// if it was the one currently being viewed, falls back to another active
  /// ride rather than dropping the driver back to the home screen while
  /// other trips are still in progress.
  void _removeActiveRide(String rideId) {
    _activeRides.remove(rideId);
    _activeRideDocSubscriptions[rideId]?.cancel();
    _activeRideDocSubscriptions.remove(rideId);
    if (_lastWazeRideId == rideId) {
      _lastWazeRideId = null;
      _lastWazeStatus = null;
    }

    if (_selectedRideId == rideId) {
      _lastVoiceRideId = null;
      _lastVoiceStatus = null;
      _lastWazeWaypointIndex = -1;
      _selectedRideId = _activeRides.keys.isNotEmpty ? _activeRides.keys.first : null;
      mapViewModel.clearRoute();
      if (_selectedRideId != null) {
        _drawRouteForActiveRide();
      }
    }
    notifyListeners();
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
    _lastRouteCalcTime = null;

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
      if (activeRide != null) {
        mapViewModel.followWithBearing(newPos, heading);
      }

      /* IN-APP VOICE NAVIGATION + ROUTE RECALCULATION — navigation now handled
         by Waze. Re-enable this block (and remove the Waze launch in
         _drawRouteForActiveRide) to restore in-app turn-by-turn navigation.

      if (activeRide != null) {
        await _voiceNav.onPositionUpdate(newPos);
        notifyListeners();
      }

      if (_voiceNav.needsRouteRefresh) {
        _lastRouteCalcPosition = null;
        _lastRouteCalcTime = null;
        _pendingReroute = true;
        _isRecalculating = true;
        notifyListeners();
      }

      final now = DateTime.now();
      final movedEnough = _lastRouteCalcPosition == null ||
          _metersApart(_lastRouteCalcPosition!, newPos) > 150;
      final waitedLongEnough = _lastRouteCalcTime == null ||
          now.difference(_lastRouteCalcTime!) >= const Duration(seconds: 30);

      if (movedEnough && waitedLongEnough) {
        _lastRouteCalcPosition = newPos;
        _lastRouteCalcTime = now;
        await _drawRouteForActiveRide();
        if (_isRecalculating) {
          _isRecalculating = false;
          notifyListeners();
        }
      }
      */

      // Keep the driver-position-dependent UI (ETA chip, status bar) current.
      if (activeRide != null) notifyListeners();
    });
  }

  /// Handles navigation setup when the selected ride's status changes.
  ///
  /// - accepted  → places pickup marker; launches Waze to pickup (once)
  /// - enroute   → driver is at pickup waiting; clears route, no Waze needed
  /// - ongoing   → places destination marker; launches Waze to destination (once)
  /// - anything else → clears route
  ///
  /// Navigation is delegated to Waze. Re-enable the commented block above and
  /// remove the Waze launch to restore in-app turn-by-turn navigation.
  Future<void> _drawRouteForActiveRide() async {
    final ride = activeRide;
    if (ride == null || _driverCurrentPosition == null) return;

    LatLng routeDestination;
    bool isHeadingToWaypoint = false;

    switch (ride.status) {
      case RideStatus.accepted:
        routeDestination = ride.pickupLocation;
        break;

      case RideStatus.ongoing:
        // currentWaypointIndex tracks the last *completed* stop (starts at
        // -1 = none completed yet), so the next leg targets index + 1.
        final nextWaypointIndex = ride.currentWaypointIndex + 1;
        if (ride.waypointsLocation.isNotEmpty &&
            nextWaypointIndex < ride.waypointsAddresses.length) {
          routeDestination = ride.waypointsLocation[nextWaypointIndex];
          isHeadingToWaypoint = true;
        } else {
          routeDestination = ride.destinationLocation;
        }
        break;

      default:
        mapViewModel.clearLiveRoute();
        return;
    }

    _updateDestinationMarker(routeDestination, ride, isHeadingToWaypoint);

    final isNewLeg = _lastWazeRideId != ride.id ||
        _lastWazeStatus != ride.status ||
        _lastWazeWaypointIndex != ride.currentWaypointIndex;

    if (isNewLeg) {
      _lastWazeRideId = ride.id;
      _lastWazeStatus = ride.status;
      _lastWazeWaypointIndex = ride.currentWaypointIndex;
      await _launchWaze(routeDestination);
    }
  }

  /// Opens Waze and navigates to [destination].
  /// Falls back to the Waze web URL if the app is not installed.
  Future<void> _launchWaze(LatLng destination) async {
    final fromParam = _driverCurrentPosition != null
      ? '&from=ll.${_driverCurrentPosition?.latitude},${_driverCurrentPosition?.longitude}'
      : '';
    final wazeApp = Uri.parse(
      'waze://?ll=${destination.latitude},${destination.longitude}&navigate=yes$fromParam',
    );
    final wazeWeb = Uri.parse(
      'https://waze.com/ul?ll=${destination.latitude},${destination.longitude}&navigate=yes$fromParam',
    );
    if (await canLaunchUrl(wazeApp)) {
      await launchUrl(wazeApp);
    } else {
      await launchUrl(wazeWeb, mode: LaunchMode.externalApplication);
    }
  }

  void _updateDestinationMarker(
    LatLng destination,
    RideRequest ride,
    bool isHeadingToWaypoint,
  ) {
    mapViewModel.markers.removeWhere(
          (marker) => marker.markerId == const MarkerId('destination'),
    );

    final String title;
    final double hue;
    if (ride.status != RideStatus.ongoing) {
      title = 'Pickup';
      hue = BitmapDescriptor.hueGreen;
    } else if (isHeadingToWaypoint) {
      final stopNumber = ride.currentWaypointIndex + 2; // 1-based, next stop
      title = 'Stop $stopNumber of ${ride.waypointsAddresses.length}';
      hue = BitmapDescriptor.hueOrange;
    } else {
      title = 'Destination';
      hue = BitmapDescriptor.hueRed;
    }

    mapViewModel.markers.add(
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: InfoWindow(title: title),
        icon: BitmapDescriptor.defaultMarkerWithHue(hue),
      ),
    );
    mapViewModel.notifyListeners();
  }

  void _stopListeningToActiveRide() {
    _activeRideSubscription?.cancel();
    _activeRideSubscription = null;
    for (final sub in _activeRideDocSubscriptions.values) {
      sub.cancel();
    }
    _activeRideDocSubscriptions.clear();
    _driverLocationSubscription?.cancel();
    _driverLocationSubscription = null;
    _activeRides.clear();
    _selectedRideId = null;
    _driverCurrentPosition = null;
    _lastRouteCalcPosition = null;
    _lastRouteCalcTime = null;
    _lastWazeRideId = null;
    _lastWazeStatus = null;
    _lastWazeWaypointIndex = -1;
  }

  Future<void> refreshStats() async {
    if (_driverProfile == null) return;

    try {
      final docs = await _databaseService.getTodaysTripsStream(_driverProfile!.uid).first;
      _todayTrips = docs.length;
       _todayEarnings = docs.fold(0.0, (sum, doc) {
        final fare = _parseFare(doc['fare']);
        return sum + FareCalculationService.driverEarnings(fare);
      });
      
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
    for (final sub in _activeRideDocSubscriptions.values) {
      sub.cancel();
    }
    _driverLocationSubscription?.cancel();
    _voiceNav.dispose();
    super.dispose();
  }
}