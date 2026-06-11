import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/driver_profile.dart';
import '../../models/ride_request_model.dart';
import '../../services/database_service.dart';
import '../../services/ride_service.dart';
import '../maps/maps_viewmodel.dart';

class ActiveTripViewModel extends ChangeNotifier {
  final String? rideId;

  // Injected from HomeViewModel so we draw into the SAME MapViewModel
  // that the GoogleMap widget on screen is reading from.
  final MapViewModel mapViewModel;

  final RideService _rideService = locator<RideService>();
  final DatabaseService _databaseService = locator<DatabaseService>();

  late StreamSubscription<DocumentSnapshot> _rideSubscription;
  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  RideRequest? _rideRequest;
  RideRequest? get rideRequest => _rideRequest;

  DriverProfile? _driverProfile;
  DriverProfile? get driverProfile => _driverProfile;

  LatLng? _driverLocation;
  LatLng? get driverLocation => _driverLocation;

  LatLng? _destination;
  LatLng? get userDestination => _destination;

  /// Lazily-created stream of the driver's LatLng — used by TripEndTimer on
  /// the user side. Null until the driverId is known from the ride document.
  Stream<LatLng>? get driverLatLngStream {
    final driverId = _rideRequest?.driverId;
    if (driverId == null) return null;
    return _databaseService.getDriverLatLngStream(driverId);
  }

  // We no longer maintain a separate _polylines set here.
  // All polylines are written directly into mapViewModel so the
  // GoogleMap widget on HomeScreen actually renders them.

  DocumentSnapshot? _rideData;
  DocumentSnapshot? get rideData => _rideData;

  String get tripStatus => _rideData?['status'] ?? 'loading';

  ActiveTripViewModel({required this.rideId, required this.mapViewModel}) {
    _initialize();
  }

  void _initialize() {
    if (rideId == null || rideId!.trim().isEmpty) {
      _isLoading = false;
      notifyListeners();
      return;
    }
    _listenToRideUpdates();
  }

  void _listenToRideUpdates() {
    _rideSubscription = _rideService.getRideStream(rideId!).listen((snapshot) async {
      if (!snapshot.exists) return;

      _rideData = snapshot;
      _rideRequest = RideRequest.fromFirestore(snapshot);

      notifyListeners();

      if (_driverProfile == null && _rideRequest?.driverId != null) {
        _isLoading = true;
        notifyListeners();

        _driverProfile = await _databaseService.getDriverProfile(_rideRequest!.driverId!);
        _destination = _rideRequest!.destinationLocation;

        // Start listening to driver location — this writes the driver
        // marker into mapViewModel so it appears on the shared map.
        _listenToDriverLocation(_rideRequest!.driverId!);

        _isLoading = false;
        notifyListeners();
      }

      // Manage polyline visibility based on the updated ride status.
      await _updateLiveRoute();
    });
  }

  void _listenToDriverLocation(String driverId) {
    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = _databaseService
        .getDriverLocationStream(driverId)
        .listen((snapshot) {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final latitude = (data['latitude'] as num?)?.toDouble();
      final longitude = (data['longitude'] as num?)?.toDouble();
      final heading = (data['heading'] as num?)?.toDouble() ?? 0.0;

      if (latitude == null || longitude == null) return;

      _driverLocation = LatLng(latitude, longitude);
      mapViewModel.updateDriverPosition(_driverLocation!, heading: heading);
      notifyListeners();
    });
  }

  /// Manages the map polylines on the passenger side based on ride status.
  ///
  /// - accepted / enroute  → booking polyline stays; driver marker is live
  /// - ongoing             → clears pre-booking polyline; driver marker is live
  /// - anything else       → clears all live route polylines
  ///
  /// The Directions API is NOT called here — the booking polyline was already
  /// fetched once during route selection and that single call is sufficient
  /// for the passenger view. Removing per-tick API calls eliminates the bulk
  /// of Directions API charges during long rides.
  Future<void> _updateLiveRoute() async {
    if (_rideRequest == null) return;

    switch (_rideRequest!.status) {
      case RideStatus.ongoing:
        // Trip is underway — remove the pre-booking polyline; the driver
        // marker position is sufficient for the passenger view.
        mapViewModel.clearBookingRoute();
        break;

      case RideStatus.accepted:
      case RideStatus.enroute:
        // Booking polyline already visible; nothing to change.
        break;

      default:
        mapViewModel.clearLiveRoute();
        break;
    }

    notifyListeners();
  }

  Future<void> makePhoneCall() async {
    if (_driverProfile == null) return;
    final uri = Uri(scheme: 'tel', path: _driverProfile!.phone);
    await launchUrl(uri);
  }

  Future<void> cancelTrip() async {
    if (rideId == null || rideId!.isEmpty) return;
    await _rideService.cancelRide(rideId!, cancelledBy: 'user');
  }

  @override
  void dispose() {
    _rideSubscription.cancel();
    _driverLocationSubscription?.cancel();
    // Do NOT clear the polyline from mapViewModel here.
    // HomeViewModel owns mapViewModel and will clear it when appropriate
    // (e.g. when _resetRide() is called). Clearing here would erase the
    // polyline every time the widget rebuilds, which is exactly the
    // "leaves screen → polyline disappears" bug.
    super.dispose();
  }
}