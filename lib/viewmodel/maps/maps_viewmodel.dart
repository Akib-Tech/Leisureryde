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

  StreamSubscription<LatLng>? _driverStreamSubscription;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Position? get currentPosition => _currentPosition;
  DirectionsResult? get directionsResult => _directionsResult;

  // Two separate polyline IDs so booking route and live driver route
  // never overwrite each other.
  static const PolylineId _bookingRouteId = PolylineId('booking_route');
  static const PolylineId _liveRouteId = PolylineId('live_route');
  static const MarkerId _driverMarkerId = MarkerId('driver');

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> initialize() async {
    debugPrint("MapViewModel: Initializing...");
    _isLoading = true;
    notifyListeners();
    await _getCurrentLocation();
    _isLoading = false;
    debugPrint("MapViewModel: Ready. Position: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}");
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
        // On iOS the first denial is already permanent; on Android the user
        // ticked "Never ask again". Open OS settings so the user can flip the
        // toggle — when they return the resume listener re-calls initialize().
        await Geolocator.openAppSettings();
        return;
      }

      _currentPosition = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (error) {
      debugPrint("MapViewModel: Error getting location: $error");
    }
  }

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    debugPrint("MapViewModel: GoogleMapController set.");
  }

  Future<Position?> getCurrentUserLocation() async {
    await _getCurrentLocation();
    return _currentPosition;
  }

  /// Fetches and draws the booking route (origin → destination).
  /// Used during route preview and vehicle selection steps.
  Future<void> getDirections(LatLng origin, LatLng destination) async {
    debugPrint("MapViewModel: Requesting directions $origin → $destination");
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
        _errorMessage = "Could not find a route. Please try different locations.";
      }
    } catch (error) {
      debugPrint("MapViewModel: getDirections error: $error");
      _directionsResult = null;
      _errorMessage = "An unexpected error occurred. Please try again.";
    } finally {
      notifyListeners();
    }
  }

  void _setBookingRoutePolyline(List<LatLng> points) {
    _polylines.removeWhere((polyline) => polyline.polylineId == _bookingRouteId);
    _polylines.add(
      Polyline(
        polylineId: _bookingRouteId,
        points: points,
        color: Colors.blue,
        width: 5,
      ),
    );
  }

  /// Writes the live driver→pickup or driver→destination polyline into
  /// the shared polylines set so the GoogleMap widget renders it immediately.
  ///
  /// Called by ActiveTripViewModel every time the driver moves or the
  /// ride status changes. Drawing here (not in ActiveTripViewModel) is
  /// what makes the polyline survive screen navigation — it lives in the
  /// same object the GoogleMap widget reads from.
  void setLiveRoutePolyline(List<LatLng> points) {
    _polylines.removeWhere((polyline) => polyline.polylineId == _liveRouteId);
    _polylines.add(
      Polyline(
        polylineId: _liveRouteId,
        points: points,
        color: Colors.deepOrange,
        width: 6,
        patterns: [PatternItem.dash(20), PatternItem.gap(10)],
      ),
    );
    notifyListeners();
  }

  /// Removes only the live route polyline without touching the booking route.
  void clearLiveRoute() {
    _polylines.removeWhere((polyline) => polyline.polylineId == _liveRouteId);
    notifyListeners();
  }

  void _addRouteMarkers(LatLng origin, LatLng destination) {
    _markers
      ..removeWhere((marker) =>
      marker.markerId == const MarkerId('origin') ||
          marker.markerId == const MarkerId('destination'))
      ..add(
        Marker(
          markerId: const MarkerId('origin'),
          position: origin,
          infoWindow: const InfoWindow(title: 'Pickup'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        ),
      )
      ..add(
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        ),
      );
  }

  void _moveCameraToRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;
    final bounds = _createBounds(points);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _createBounds(List<LatLng> positions) {
    double? minLat, maxLat, minLon, maxLon;
    for (final position in positions) {
      if (minLat == null || position.latitude < minLat) minLat = position.latitude;
      if (maxLat == null || position.latitude > maxLat) maxLat = position.latitude;
      if (minLon == null || position.longitude < minLon) minLon = position.longitude;
      if (maxLon == null || position.longitude > maxLon) maxLon = position.longitude;
    }
    if (minLat == null || maxLat == null || minLon == null || maxLon == null) {
      return LatLngBounds(
        southwest: const LatLng(0, 0),
        northeast: const LatLng(0.1, 0.1),
      );
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  /// Clears everything — both polylines, all markers, stops driver following.
  /// Only call this on full ride reset (back to HomeStep.initial).
  void clearRoute() {
    _polylines.clear();
    _directionsResult = null;
    _errorMessage = null;
    _markers.removeWhere((marker) =>
    marker.markerId == const MarkerId('origin') ||
        marker.markerId == const MarkerId('destination'));
    stopFollowingDriver();
  }

  /// Starts following a driver via a LatLng stream.
  /// Used by HomeViewModel the moment a ride is accepted.
  void startFollowingDriver(Stream<LatLng> driverLocationStream) {
    _driverStreamSubscription?.cancel();
    _isFollowingDriver = true;
    notifyListeners();

    _driverStreamSubscription = driverLocationStream.listen(
          (newPosition) {
        updateDriverPosition(newPosition);
      },
      onError: (error) {
        debugPrint("MapViewModel: Driver stream error: $error");
      },
    );
  }

  /// Updates the driver marker on the map and moves the camera to follow.
  /// Also called directly by ActiveTripViewModel on each driver location tick.
  void updateDriverPosition(LatLng newPosition) {
    _driverPosition = newPosition;

    _markers.removeWhere((marker) => marker.markerId == _driverMarkerId);
    _markers.add(
      Marker(
        markerId: _driverMarkerId,
        position: newPosition,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
        anchor: const Offset(0.5, 0.5),
        flat: true,
        infoWindow: const InfoWindow(title: 'Your Driver'),
      ),
    );

    // Move camera center only — does not reset the user's zoom level.
    if (_isFollowingDriver && _mapController != null) {
      _mapController!.animateCamera(CameraUpdate.newLatLng(newPosition));
    }

    notifyListeners();
  }

  /// Stops following the driver and removes the driver marker from the map.
  void stopFollowingDriver() {
    _driverStreamSubscription?.cancel();
    _driverStreamSubscription = null;
    _isFollowingDriver = false;
    _driverPosition = null;
    _markers.removeWhere((marker) => marker.markerId == _driverMarkerId);
  }

  /// Fits both driver and destination into the camera view.
  /// Useful during an ongoing trip so the passenger can see progress.
  Future<void> fitDriverAndDestination(LatLng driverLocation, LatLng destination) async {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        driverLocation.latitude < destination.latitude ? driverLocation.latitude : destination.latitude,
        driverLocation.longitude < destination.longitude ? driverLocation.longitude : destination.longitude,
      ),
      northeast: LatLng(
        driverLocation.latitude > destination.latitude ? driverLocation.latitude : destination.latitude,
        driverLocation.longitude > destination.longitude ? driverLocation.longitude : destination.longitude,
      ),
    );

    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
  }

  @override
  void dispose() {
    debugPrint("MapViewModel: Disposing.");
    _driverStreamSubscription?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}