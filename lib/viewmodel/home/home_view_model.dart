import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/models/user_profile.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart';
import 'package:leisureryde/services/fare_calculation_service.dart';
import '../../models/ride_request_model.dart';
import '../../models/route_selection.dart';
import '../../models/saved_places.dart';
import '../../screens/shared/account_screen/saved_places_screen.dart';
import '../../services/ride_service.dart';
import '../../services/place_service.dart';
import '../maps/maps_viewmodel.dart';

enum HomeStep {
  initial,
  routePreview,
  vehicleSelection,
  findingDriver,
  activeTrip,
}

class HomeViewModel extends ChangeNotifier {
  final _auth = locator<AuthService>();
  final _db = locator<DatabaseService>();
  final _rideService = locator<RideService>();
  final FareCalculationService fareService =
  locator<FareCalculationService>();
  final MapViewModel mapViewModel = MapViewModel();

  // USER PROFILE
  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  // UI STATE
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRequestingRide = false;
  bool get isRequestingRide => _isRequestingRide;

  HomeStep _currentStep = HomeStep.initial;
  HomeStep get currentStep => _currentStep;

  String? _selectedVehicle;
  String? get selectedVehicle => _selectedVehicle;

  // SAVED / RECENT PLACES
  List<SavedPlace> _savedPlaces = [];
  List<SavedPlace> get savedPlaces => _savedPlaces;
  List<RideDestination> _recentDestinations = [];
  List<RideDestination> get recentDestinations => _recentDestinations;

  // DRIVER MAP ICONS
  BitmapDescriptor? _greenCarIcon;
  BitmapDescriptor? _goldCarIcon;
  final Map<String, Marker> _driverMarkers = {};
  Map<String, Marker> get driverMarkers => _driverMarkers;
  StreamSubscription<QuerySnapshot>? _driverSub;

  // RIDE DATA
  String? _rideId;
  String? get currentRideId => _rideId;
  StreamSubscription<DocumentSnapshot>? _rideListener;
  String? activeDriverId;

  HomeViewModel() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    await mapViewModel.initialize();
    await _initializeIcons();

    final uid = _auth.currentUser?.uid;
    if (uid == null) {
      _isLoading = false;
      notifyListeners();
      return;
    }

    try {
      final results = await Future.wait([
        _db.getUserProfile(uid),
        _db.getSavedPlaces(uid),
        _db.getRecentDestinations(uid),
      ]);
      _userProfile = results[0] as UserProfile;
      _savedPlaces = results[1] as List<SavedPlace>;
      _recentDestinations = results[2] as List<RideDestination>;
      _listenToOnlineDrivers();
    } catch (e) {
      debugPrint("Error initializing HomeViewModel: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _initializeIcons() async {
    _greenCarIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/bluecar.png',
    );
    _goldCarIcon = await BitmapDescriptor.fromAssetImage(
      const ImageConfiguration(size: Size(48, 48)),
      'assets/icons/goldcar.png',
    );
  }

  Future<void> refresh() async {
    await _initialize();    // calls the private init again
  }

  // ---------------------------------------------------------------------------
  // LISTEN TO ONLINE DRIVERS
  // ---------------------------------------------------------------------------
  void _listenToOnlineDrivers() {
    _driverSub?.cancel();
    _driverSub = _db.getOnlineDriversStream().listen((snapshot) {
      final markers = <String, Marker>{};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['latitude'] == null || data['longitude'] == null) continue;
        final id = doc.id;
        final pos = LatLng(data['latitude'], data['longitude']);
        markers[id] = Marker(
          markerId: MarkerId(id),
          position: pos,
          icon: (activeDriverId != null && id == activeDriverId)
              ? _goldCarIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueOrange)
              : _greenCarIcon ??
              BitmapDescriptor.defaultMarkerWithHue(
                  BitmapDescriptor.hueGreen),
          rotation: (data['heading'] ?? 0.0).toDouble(),
          flat: true,
          anchor: const Offset(0.5, 0.5),
        );
      }
      _driverMarkers
        ..clear()
        ..addAll(markers);
      notifyListeners();
    });
  }

  void setActiveDriver(String driverId) {
    activeDriverId = driverId;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // PLACES / ROUTES
  // ---------------------------------------------------------------------------
  Future<void> selectSavedPlace(
      BuildContext context, String placeName) async {
    final p = _savedPlaces.firstWhere(
            (pl) => pl.name == placeName,
        orElse: () => SavedPlace(
            id: '', name: '', address: '', latitude: 0, longitude: 0));

    if (p.id.isEmpty) {
      // go add new saved place
      final added = await Navigator.push<SavedPlace>(
        context,
        MaterialPageRoute(
          builder: (_) => AddSavedPlaceScreen(placeType: placeName),
        ),
      );
      if (added != null) await _reloadPlaces();
      return;
    }

    final origin = PlaceDetails(
      name: "Current Location",
      address: "Current Location",
      location: LatLng(mapViewModel.currentPosition!.latitude,
          mapViewModel.currentPosition!.longitude),
    );
    final dest = PlaceDetails(
      name: p.name,
      address: p.address,
      location: LatLng(p.latitude, p.longitude),
    );
    await selectRoute(RouteSelectionResult(origin: origin, destination: dest));
  }

  Future<void> selectRecentDestination(RideDestination dest) async {
    final origin = PlaceDetails(
      name: "Current Location",
      address: "Current Location",
      location: LatLng(mapViewModel.currentPosition!.latitude,
          mapViewModel.currentPosition!.longitude),
    );
    final destination = PlaceDetails(
      name: dest.address.split(',').first,
      address: dest.address,
      location: LatLng(dest.latitude, dest.longitude),
    );
    await selectRoute(
        RouteSelectionResult(origin: origin, destination: destination));
  }

  Future<void> _reloadPlaces() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    final results = await Future.wait([
      _db.getSavedPlaces(uid),
      _db.getRecentDestinations(uid),
    ]);
    _savedPlaces = results[0] as List<SavedPlace>;
    _recentDestinations = results[1] as List<RideDestination>;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // FLOW CONTROL
  // ---------------------------------------------------------------------------

  Future<void> selectRoute(RouteSelectionResult result) async {
    await mapViewModel.getDirections(
        result.origin.location, result.destination.location);
    _currentStep = HomeStep.routePreview;
    notifyListeners();
  }

  void proceedToVehicleSelection() {
    _currentStep = HomeStep.vehicleSelection;
    notifyListeners();
  }

  void selectVehicle(String vehicleType) {
    _selectedVehicle = vehicleType;
    notifyListeners();
  }

  void cancelRideSelection() {
    mapViewModel.clearRoute();
    _selectedVehicle = null;
    _currentStep = HomeStep.initial;
    notifyListeners();
  }

  // ---------------------------------------------------------------------------
  // REQUEST RIDE  (User)
  // ---------------------------------------------------------------------------

  Future<void> requestRide(BuildContext context) async {
    if (_isRequestingRide) return;
    _isRequestingRide = true;
    notifyListeners();

    try {
      if (_selectedVehicle == null ||
          _userProfile == null ||
          mapViewModel.directionsResult == null) {
        throw Exception("Cannot request ride – incomplete data.");
      }

      final d = mapViewModel.directionsResult!;
      final fares =
      fareService.calculateFare(d.distanceValue, d.durationValue);
      double fare;
      switch (_selectedVehicle!) {
        case 'Leisure Plus':
          fare = fares.leisurePlus;
          break;
        case 'Leisure Exec':
          fare = fares.leisureExec;
          break;
        default:
          fare = fares.leisureComfort;
      }

      final rideRequest = RideRequest(
        id: '',
        userId: _userProfile!.uid,
        vehicleType: _selectedVehicle!,
        status: RideStatus.pending,
        passengerName: _userProfile!.fullName,
        passengerRating: 5.0,
        pickupLocation: LatLng(mapViewModel.currentPosition!.latitude,
            mapViewModel.currentPosition!.longitude),
        destinationLocation: d.polylinePoints.last,
        pickupAddress: d.startAddress,
        destinationAddress: d.endAddress,
        fare: fare,
        distance: d.distanceValue * 0.000621371,
        createdAt: DateTime.now(),
      );

      final id = await _db.createRideRequest(rideRequest);
      _rideId = id;
      _currentStep = HomeStep.findingDriver;
      _listenForRideStatus(id!);
    } catch (e) {
      debugPrint("Ride creation error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("An error occurred: $e")),
      );
      _currentStep = HomeStep.initial;
    } finally {
      _isRequestingRide = false;
      notifyListeners();
    }
  }

  // ---------------------------------------------------------------------------
  // RIDE STATUS LISTENER
  // ---------------------------------------------------------------------------

  void _listenForRideStatus(String id) {
    _rideListener?.cancel();
    _rideListener = _rideService.getRideStream(id).listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final status = data['status'];
      if (status == 'accepted') {
        activeDriverId = data['driverId'];
        _currentStep = HomeStep.activeTrip;
      } else if (status == 'cancelled' ||
          status == 'cancelled_by_driver' ||
          status == 'completed') {
        _resetRide();
      }
      notifyListeners();
    });
  }

  // ---------------------------------------------------------------------------
  // CANCEL RIDE
  // ---------------------------------------------------------------------------

  Future<void> cancelRide() async {
    if (_rideId != null) {
      await _rideService.cancelRide(_rideId!, cancelledBy: 'user');
    }
    _resetRide();
    notifyListeners();
  }

  // Reset state once ride ends/cancels
  void _resetRide() {
    _rideId = null;
    activeDriverId = null;
    _selectedVehicle = null;
    mapViewModel.clearRoute();
    _currentStep = HomeStep.initial;
  }

  // ---------------------------------------------------------------------------
  @override
  void dispose() {
    mapViewModel.dispose();
    _driverSub?.cancel();
    _rideListener?.cancel();
    super.dispose();
  }
}