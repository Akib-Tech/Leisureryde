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

// Current driver position (latest value from the stream)
  LatLng? _driverPosition;
  LatLng? get driverPosition => _driverPosition;

  bool _isFollowingDriver = false;
  bool get isFollowingDriver => _isFollowingDriver;

// Hold the subscription so you can cancel it later
  StreamSubscription<LatLng>? _driverStreamSubscription;


  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Position? get currentPosition => _currentPosition;
  DirectionsResult? get directionsResult => _directionsResult;

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
    debugPrint("MapViewModel: Initialization complete. Current location: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}");
    notifyListeners();
  }

  Future<void> _getCurrentLocation() async {
    debugPrint("MapViewModel: Getting current location...");
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        debugPrint("MapViewModel: Location services are disabled.");
        throw Exception('Location services are disabled.');
      }
      debugPrint("MapViewModel: Location services enabled.");

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        debugPrint("MapViewModel: Location permission denied, requesting...");
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          debugPrint("MapViewModel: Location permission still denied after request.");
          throw Exception('Location permissions are denied');
        }
      }
      debugPrint("MapViewModel: Location permission status: $permission");

      if (permission == LocationPermission.deniedForever) {
        debugPrint("MapViewModel: Location permissions permanently denied.");
        throw Exception('Location permissions are permanently denied, we cannot request permissions.');
      }

      _currentPosition = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high // Request high accuracy
      );
      debugPrint("MapViewModel: Current location fetched: ${_currentPosition?.latitude}, ${_currentPosition?.longitude}");
    } catch (e) {
      debugPrint("MapViewModel: Error getting current location: $e");
      // Consider adding a user-facing notification here, like a SnackBar
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

  Future<void> getDirections(LatLng origin, LatLng destination) async {
    debugPrint("MapViewModel: Requesting directions from $origin to $destination");
    clearRoute(); // This also clears the old error message
    notifyListeners();

    try {
      final result = await _directionsService.getDirections(
        origin: origin,
        destination: destination,
      );

      if (result != null) {
        debugPrint("MapViewModel: DirectionsService returned a valid result.");
        _directionsResult = result;
        _createRoutePolyline(result.polylinePoints);
        _addMarkers(origin, destination);
        _moveCameraToRoute(result.polylinePoints);
        debugPrint("MapViewModel: Route, markers, and camera updated successfully.");
      } else {
        // THIS IS THE KEY CHANGE
        debugPrint("MapViewModel: DirectionsService returned NULL. Route not found or API error.");
        _directionsResult = null; // Ensure it's null
        // SET A USER-FRIENDLY ERROR MESSAGE
        _errorMessage = "Could not find a route for the selected locations. Please try different points.";
      }
    } catch (e) {
      debugPrint("MapViewModel: Error during getDirections: $e");
      _directionsResult = null; // Ensure it's null on error
      _errorMessage = "An unexpected error occurred. Please try again.";
    } finally {
      notifyListeners(); // Always notify to update UI (show route or show error)
    }
  }

  void _createRoutePolyline(List<LatLng> points) {
    debugPrint("MapViewModel: Creating route polyline with ${points.length} points.");
    final polyline = Polyline(
      polylineId: const PolylineId('route'),
      points: points,
      color: Colors.blue,
      width: 5,
    );
    _polylines.clear(); // Clear existing polylines
    _polylines.add(polyline);
  }

  void _addMarkers(LatLng origin, LatLng destination) {
    debugPrint("MapViewModel: Adding origin and destination markers.");
    _markers.clear(); // Clear existing markers
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
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Added hue for destination
      ),
    };
  }

  void _moveCameraToRoute(List<LatLng> points) {
    debugPrint("MapViewModel: Moving camera to route bounds.");
    if (_mapController == null || points.isEmpty) {
      debugPrint("MapViewModel: _mapController is null or points are empty. Cannot move camera.");
      return;
    }

    final bounds = _createBounds(points);
    _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 100.0));
    debugPrint("MapViewModel: Camera animation requested.");
  }

  LatLngBounds _createBounds(List<LatLng> positions) {
    debugPrint("MapViewModel: Creating LatLngBounds for ${positions.length} positions.");
    double? minLat, maxLat, minLon, maxLon;
    for (var p in positions) {
      if (minLat == null || p.latitude < minLat) minLat = p.latitude;
      if (maxLat == null || p.latitude > maxLat) maxLat = p.latitude;
      if (minLon == null || p.longitude < minLon) minLon = p.longitude;
      if (maxLon == null || p.longitude > maxLon) maxLon = p.longitude;
    }
    if (minLat == null || maxLat == null || minLon == null || maxLon == null) {
      // This should ideally not happen if points is not empty.
      debugPrint("MapViewModel: Error creating bounds, some min/max values are null.");
      // Fallback to a default small bound or throw. For now, returning a default.
      return LatLngBounds(southwest: LatLng(0,0), northeast: LatLng(0.1,0.1));
    }
    return LatLngBounds(
      southwest: LatLng(minLat, minLon),
      northeast: LatLng(maxLat, maxLon),
    );
  }

  void clearRoute() {
    debugPrint("MapViewModel: Clearing route, markers, and directions result.");
    _polylines.clear();
    _markers.clear();
    _directionsResult = null;
    // No notifyListeners here, as getDirections will call it in its finally block.
    // If you call clearRoute from outside getDirections, you might need notifyListeners.
  }

  /// Call this when entering activeTrip step (from HomeViewModel)
  Future<void> moveToDriver(LatLng driverLocation) async {
    _driverPosition = driverLocation;
    _isFollowingDriver = true;
    notifyListeners();

    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(driverLocation, 16.5),
      );
      debugPrint("MapViewModel: Moved camera to driver position: $driverLocation");
    } else {
      debugPrint("MapViewModel: mapController is null, cannot move to driver yet.");
    }
  }

  /// Optional: Smooth follow with padding (shows driver + route or destination)
  Future<void> fitDriverAndDestination(LatLng driverLoc, LatLng destination) async {
    if (_mapController == null) return;

    final bounds = LatLngBounds(
      southwest: LatLng(
        driverLoc.latitude < destination.latitude ? driverLoc.latitude : destination.latitude,
        driverLoc.longitude < destination.longitude ? driverLoc.longitude : destination.longitude,
      ),
      northeast: LatLng(
        driverLoc.latitude > destination.latitude ? driverLoc.latitude : destination.latitude,
        driverLoc.longitude > destination.longitude ? driverLoc.longitude : destination.longitude,
      ),
    );

    await _mapController!.animateCamera(
      CameraUpdate.newLatLngBounds(bounds, 80), // padding in pixels
    );
  }

  /// Call this when leaving activeTrip or cancelling
  void stopFollowingDriver() {
    _isFollowingDriver = false;
    _driverPosition = null;
    notifyListeners();
  }

  /// Update driver position in realtime (called from HomeViewModel listener)
  void updateDriverPosition(LatLng newPosition) {
    _driverPosition = newPosition;

    if (_isFollowingDriver && _mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(newPosition),
      );
    }
    notifyListeners();
  }




  /// Call this when you enter activeTrip and have a stream of driver location
  void startFollowingDriver(Stream<LatLng> driverLocationStream) {
    _driverStreamSubscription?.cancel(); // cancel old one if any

    _isFollowingDriver = true;
    notifyListeners();

    _driverStreamSubscription = driverLocationStream.listen((newPosition) {
      _driverPosition = newPosition;

      // Auto-move the camera to the driver in real-time
      if (_mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newLatLngZoom(newPosition, 16.5), // or newLatLng() for smoother following
        );
      }

      notifyListeners();
    }, onError: (e) {
      debugPrint("Driver location stream error: $e");
    });
  }



  @override
  void dispose() {
    debugPrint("MapViewModel: Disposing MapViewModel.");
    _mapController?.dispose();
    super.dispose();
  }
}