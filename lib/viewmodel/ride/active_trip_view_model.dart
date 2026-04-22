import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../models/driver_profile.dart';
import '../../models/ride_request_model.dart';
import '../../services/database_service.dart';
import '../../services/directions_service.dart';
import '../../services/ride_service.dart';
import '../maps/maps_viewmodel.dart';

class ActiveTripViewModel extends ChangeNotifier {
  final String? rideId;

  // Injected from HomeViewModel so we draw into the SAME MapViewModel
  // that the GoogleMap widget on screen is reading from.
  final MapViewModel mapViewModel;

  final RideService _rideService = locator<RideService>();
  final DatabaseService _databaseService = locator<DatabaseService>();
  final DirectionsService _directionsService = locator<DirectionsService>();

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

      // Recalculate and draw the polyline into the shared MapViewModel.
      await _updateLiveRoute();
    });
  }

  void _listenToDriverLocation(String driverId) {
    _driverLocationSubscription?.cancel();

    _driverLocationSubscription = _databaseService
        .getDriverLocationStream(driverId)
        .listen((snapshot) async {
      if (!snapshot.exists) return;

      final data = snapshot.data() as Map<String, dynamic>;
      final latitude = data['latitude'] as double?;
      final longitude = data['longitude'] as double?;

      if (latitude == null || longitude == null) return;

      _driverLocation = LatLng(latitude, longitude);

      // Write driver marker and move camera via the shared MapViewModel.
      // This is the key: we update the SAME mapViewModel the GoogleMap reads.
      mapViewModel.updateDriverPosition(_driverLocation!);

      // Recalculate the live route every time the driver moves.
      await _updateLiveRoute();
    });
  }

  /// Calculates the route from driver to the correct destination based on
  /// the current ride status, then writes it into the shared MapViewModel.
  ///
  /// - accepted / enroute  → driver to passenger pickup
  /// - ongoing             → driver to passenger destination
  /// - anything else       → clear the live route polyline
  Future<void> _updateLiveRoute() async {
    if (_rideRequest == null || _driverLocation == null) return;

    LatLng routeOrigin;
    LatLng routeDestination;

    switch (_rideRequest!.status) {
      case RideStatus.accepted:
      case RideStatus.enroute:
        routeOrigin = _driverLocation!;
        routeDestination = _rideRequest!.pickupLocation;
        break;

      case RideStatus.ongoing:
        routeOrigin = _driverLocation!;
        routeDestination = _rideRequest!.destinationLocation;
        break;

      default:
      // Terminal or unknown status — clear the live polyline.
        mapViewModel.clearLiveRoute();
        notifyListeners();
        return;
    }

    final result = await _directionsService.getDirections(
      origin: routeOrigin,
      destination: routeDestination,
    );

    if (result != null) {
      // Write the live polyline directly into the shared MapViewModel.
      // The GoogleMap widget will re-render automatically because
      // MapViewModel calls notifyListeners().
      mapViewModel.setLiveRoutePolyline(result.polylinePoints);
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