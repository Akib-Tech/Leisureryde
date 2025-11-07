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

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Position? get currentPosition => _currentPosition;
  DirectionsResult? get directionsResult => _directionsResult;

  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};

  Set<Marker> get markers => _markers;
  Set<Polyline> get polylines => _polylines;

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
      if (!serviceEnabled) {
        throw Exception('Location services are disabled.');
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Location permissions are denied');
        }
      }

      if (permission == LocationPermission.deniedForever) {
        throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      }

      _currentPosition = await Geolocator.getCurrentPosition();
    } catch (e) {
      print("Error getting current location: $e");
      // Handle error, maybe show a dialog to the user
    }
  }

  void onMapCreated(GoogleMapController controller) {
    _mapController = controller;
  }

  Future<void> getDirections(LatLng origin, LatLng destination) async {
    clearRoute(); // Clear previous route before fetching a new one

    final result = await _directionsService.getDirections(
      origin: origin,
      destination: destination,
    );

    if (result != null) {
      _directionsResult = result;
      _createRoutePolyline(result.polylinePoints);
      _addMarkers(origin, destination);
      _moveCameraToRoute(result.polylinePoints);
    }
    notifyListeners();
  }

  void _createRoutePolyline(List<LatLng> points) {
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: points,
      color: Colors.blue,
      width: 5,
    );
    _polylines.add(polyline);
  }

  void _addMarkers(LatLng origin, LatLng destination) {
    _markers = {
      Marker(
        markerId: const MarkerId('origin'),
        position: origin,
        infoWindow: const InfoWindow(title: 'Pickup'),
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
      ),
      Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        infoWindow: const InfoWindow(title: 'Destination'),
      ),
    };
  }

  void _moveCameraToRoute(List<LatLng> points) {
    if (_mapController == null || points.isEmpty) return;

    final bounds = _createBounds(points);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
  }

  LatLngBounds _createBounds(List<LatLng> positions) {
    final southwest = positions.reduce((value, element) => LatLng(
        value.latitude < element.latitude ? value.latitude : element.latitude,
        value.longitude < element.longitude ? value.longitude : element.longitude));
    final northeast = positions.reduce((value, element) => LatLng(
        value.latitude > element.latitude ? value.latitude : element.latitude,
        value.longitude > element.longitude ? value.longitude : element.longitude));
    return LatLngBounds(southwest: southwest, northeast: northeast);
  }

  void clearRoute() {
    _polylines.clear();
    _markers.clear();
    _directionsResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }
}