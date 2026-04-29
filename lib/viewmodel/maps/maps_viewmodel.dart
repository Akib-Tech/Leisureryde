import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/services/directions_service.dart';

class MapViewModel extends ChangeNotifier {
  final DirectionsService _directionsService = locator<DirectionsService>();

  GoogleMapController? _mapController;
  Position? _currentPosition;
  DirectionsResult? _directionsResult;

  LatLng? _driverPosition;
  LatLng? get driverPosition => _driverPosition;

  bool _isFollowingDriver = false;
  bool get isFollowingDriver => _isFollowingDriver;

  // When true the user has manually panned the map; auto-camera moves pause
  // until recenterCamera() is called.
  bool _isUserInteracting = false;
  bool get isUserInteracting => _isUserInteracting;

  // Set to true immediately before any programmatic animateCamera call so the
  // onCameraMoveStarted callback can ignore it (it fires for both gestures and
  // programmatic moves; there is no built-in isGesture flag in google_maps_flutter).
  bool _isProgrammaticMove = false;

  StreamSubscription<LatLng>? _driverStreamSubscription;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Position? get currentPosition => _currentPosition;
  DirectionsResult? get directionsResult => _directionsResult;

  // Optional car-icon set by the parent ViewModel after async asset load.
  BitmapDescriptor? _driverIcon;

  static const PolylineId _bookingRouteId = PolylineId('booking_route');
  static const PolylineId _liveRouteId    = PolylineId('live_route');
  static const MarkerId   _driverMarkerId  = MarkerId('driver');

  Set<Marker>   _markers   = {};
  Set<Polyline> _polylines = {};

  Set<Marker>   get markers   => _markers;
  Set<Polyline> get polylines => _polylines;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  // ─── Initialisation ──────────────────────────────────────────────────────

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    await _getCurrentLocation();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location services are disabled.');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied.');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        await Geolocator.openAppSettings();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (error) {
      debugPrint('MapViewModel: Error getting location: $error');
    }
  }

  // ─── Map controller ───────────────────────────────────────────────────────

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  /// Called by the GoogleMap widget's onCameraMoveStarted callback.
  /// Distinguishes user gestures from programmatic moves.
  void onCameraMoveStarted() {
    if (_isProgrammaticMove) return; // ignore our own animateCamera calls
    _isUserInteracting = true;
    notifyListeners();
  }

  /// Called by the GoogleMap widget's onCameraIdle callback.
  /// Clears the programmatic-move guard so the next user gesture is detected.
  void onCameraIdle() {
    _isProgrammaticMove = false;
  }

  /// Re-enables auto-following and snaps the camera back.
  void recenterCamera() {
    _isUserInteracting = false;
    if (_isFollowingDriver && _driverPosition != null) {
      _animateToPosition(_driverPosition!);
    } else if (_currentPosition != null) {
      _animateToPosition(
          LatLng(_currentPosition!.latitude, _currentPosition!.longitude));
    }
    notifyListeners();
  }

  Future<Position?> getCurrentUserLocation() async {
    await _getCurrentLocation();
    return _currentPosition;
  }

  // ─── Driver icon ──────────────────────────────────────────────────────────

  /// Set from HomeViewModel after the car-icon asset is loaded.
  void setDriverIcon(BitmapDescriptor icon) {
    _driverIcon = icon;
  }

  // ─── Directions / polylines ───────────────────────────────────────────────

  Future<void> getDirections(LatLng origin, LatLng destination) async {
    clearRoute();
    notifyListeners();

    try {
      final result = await _directionsService.getDirections(
        origin: origin,
        destination: destination,
      );

      if (result != null) {
        _directionsResult = result;
        _setBookingRoutePolyline(result.polylinePoints);
        _addRouteMarkers(origin, destination);
        _moveCameraToRoute(result.polylinePoints);
      } else {
        _directionsResult = null;
        _errorMessage = 'Could not find a route. Please try different locations.';
      }
    } catch (error) {
      debugPrint('MapViewModel: getDirections error: $error');
      _directionsResult = null;
      _errorMessage = 'An unexpected error occurred. Please try again.';
    } finally {
      notifyListeners();
    }
  }

  void _setBookingRoutePolyline(List<LatLng> points) {
    _polylines.removeWhere((p) => p.polylineId == _bookingRouteId);
    _polylines.add(
      Polyline(
        polylineId: _bookingRouteId,
        points: points,
        color: Colors.blue,
        width: 5,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    );
  }

  /// Replaces the live driver-route polyline with [points].
  ///
  /// Uses a solid line with round caps so it renders smoothly and doesn't
  /// flash when redrawn on each GPS tick (dashed lines cause a visible
  /// phase-reset artifact on every update).
  void setLiveRoutePolyline(List<LatLng> points) {
    _polylines.removeWhere((p) => p.polylineId == _liveRouteId);
    _polylines.add(
      Polyline(
        polylineId: _liveRouteId,
        points: points,
        color: const Color(0xFF1565C0), // deep blue — distinct from the azure car marker
        width: 6,
        startCap: Cap.roundCap,
        endCap: Cap.roundCap,
        jointType: JointType.round,
      ),
    );
    notifyListeners();
  }

  /// Removes the live-route polyline without touching the booking route.
  void clearLiveRoute() {
    _polylines.removeWhere((p) => p.polylineId == _liveRouteId);
    notifyListeners();
  }

  /// Removes only the static booking route (origin → destination).
  /// Call this when the trip becomes ongoing so only the live route is visible.
  void clearBookingRoute() {
    _polylines.removeWhere((p) => p.polylineId == _bookingRouteId);
    notifyListeners();
  }

  void _addRouteMarkers(LatLng origin, LatLng destination) {
    _markers
      ..removeWhere((m) =>
          m.markerId == const MarkerId('origin') ||
          m.markerId == const MarkerId('destination'))
      ..add(Marker(
        markerId: const MarkerId('origin'),
        position: origin,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ))
      ..add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: const InfoWindow(title: 'Destination'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
      ));
  }

  void _moveCameraToRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    final bounds = _createBounds(points);
    _isProgrammaticMove = true;
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _createBounds(List<LatLng> positions) {
    double? minLat, maxLat, minLon, maxLon;
    for (final p in positions) {
      if (minLat == null || p.latitude < minLat) minLat = p.latitude;
      if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
      if (minLon == null || p.longitude < minLon) minLon = p.longitude;
      if (maxLon == null || p.longitude > maxLon) maxLon = p.longitude;
    }
    if (minLat == null) {
      return LatLngBounds(
          southwest: const LatLng(0, 0), northeast: const LatLng(0.1, 0.1));
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLon!),
      northeast: LatLng(maxLat!, maxLon!),
    );
  }

  void clearRoute() {
    _polylines.clear();
    _directionsResult = null;
    _errorMessage = null;
    _markers.removeWhere((m) =>
        m.markerId == const MarkerId('origin') ||
        m.markerId == const MarkerId('destination'));
    stopFollowingDriver();
  }

  // ─── Driver following ─────────────────────────────────────────────────────

  /// Subscribes to [driverLocationStream] and follows the driver.
  void startFollowingDriver(Stream<LatLng> driverLocationStream) {
    _driverStreamSubscription?.cancel();
    _isFollowingDriver = true;
    notifyListeners();

    _driverStreamSubscription = driverLocationStream.listen(
      (pos) => updateDriverPosition(pos),
      onError: (e) => debugPrint('MapViewModel: Driver stream error: $e'),
    );
  }

  /// Enables camera-following without opening a new Firestore subscription.
  /// Use when another component already manages driver-position updates.
  void enableFollowing() {
    _isFollowingDriver = true;
  }

  /// Updates the driver marker and, if following is active, moves the camera.
  ///
  /// [heading] rotates the marker to match the driver's bearing so the car
  /// icon always faces the direction of travel.
  void updateDriverPosition(LatLng newPosition, {double heading = 0.0}) {
    _driverPosition = newPosition;

    _markers.removeWhere((m) => m.markerId == _driverMarkerId);
    _markers.add(
      Marker(
        markerId: _driverMarkerId,
        position: newPosition,
        icon: _driverIcon ??
            BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        rotation: heading,
        anchor: const Offset(0.5, 0.5),
        flat: true,
        infoWindow: const InfoWindow(title: 'Your Driver'),
      ),
    );

    // Move camera only when following is active AND the user hasn't manually
    // panned the map (pausing auto-follow until they tap re-center).
    if (_isFollowingDriver && !_isUserInteracting && _mapController != null) {
      _animateToPosition(newPosition);
    }

    notifyListeners();
  }

  void stopFollowingDriver() {
    _driverStreamSubscription?.cancel();
    _driverStreamSubscription = null;
    _isFollowingDriver = false;
    _isUserInteracting = false;
    _driverPosition = null;
    _markers.removeWhere((m) => m.markerId == _driverMarkerId);
  }

  // ─── Camera helpers ───────────────────────────────────────────────────────

  /// Smoothly moves the camera to [position] without changing zoom.
  void animateCameraToPosition(LatLng position) {
    if (_isUserInteracting) return; // don't fight the user
    _animateToPosition(position);
  }

  Future<void> fitDriverAndDestination(
      LatLng driverLocation, LatLng destination) async {
    if (_mapController == null) return;
    final bounds = _createBounds([driverLocation, destination]);
    _isProgrammaticMove = true;
    await _mapController!
        .animateCamera(CameraUpdate.newLatLngBounds(bounds, 100));
  }

  // Internal helper — always fires the camera move and marks it as programmatic.
  void _animateToPosition(LatLng position) {
    if (_mapController == null) return;
    _isProgrammaticMove = true;
    _mapController!.animateCamera(CameraUpdate.newLatLng(position));
  }

  // ─── Dispose ─────────────────────────────────────────────────────────────

  @override
  void dispose() {
    _driverStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
