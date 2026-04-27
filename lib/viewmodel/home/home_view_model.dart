import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/models/saved_places.dart';
import 'package:leisureryde/models/user_profile.dart';
import 'package:leisureryde/screens/shared/account_screen/saved_places_screen.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart';
import 'package:leisureryde/services/fare_calculation_service.dart';
import 'package:leisureryde/services/place_service.dart';
import 'package:leisureryde/services/ride_service.dart';
import 'package:leisureryde/viewmodel/maps/maps_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../screens/user/payment/stripe_checkout.dart';
import '../payment/payment.dart';

enum HomeStep {
  initial,
  routePreview,
  vehicleSelection,
  payment,
  findingDriver,
  activeTrip,
}

class HomeViewModel extends ChangeNotifier {
  final _auth = locator<AuthService>();
  final _db = locator<DatabaseService>();
  final _rideService = locator<RideService>();
  final FareCalculationService fareService = locator<FareCalculationService>();
  final MapViewModel mapViewModel = MapViewModel();
  final PaymentViewModel _paymentViewModel = locator<PaymentViewModel>();

  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isRequestingRide = false;
  bool get isRequestingRide => _isRequestingRide;

  bool _isRefreshing = false;

  HomeStep _currentStep = HomeStep.initial;
  HomeStep get currentStep => _currentStep;

  String? _selectedVehicle;
  String? get selectedVehicle => _selectedVehicle;

  List<SavedPlace> _savedPlaces = [];
  List<SavedPlace> get savedPlaces => _savedPlaces;

  List<RideDestination> _recentDestinations = [];
  List<RideDestination> get recentDestinations => _recentDestinations;

  BitmapDescriptor? _greenCarIcon;
  final Map<String, Marker> _driverMarkers = {};
  Map<String, Marker> get driverMarkers => _driverMarkers;
  StreamSubscription<QuerySnapshot>? _driverSub;

  String? _rideId;
  String? get currentRideId => _rideId;
  StreamSubscription<DocumentSnapshot>? _rideListener;

  // Cancellation state — set when the driver cancels on the user's behalf
  bool _cancelledByDriver = false;
  bool get cancelledByDriver => _cancelledByDriver;
  String? _cancelledByDriverName;
  String? get cancelledByDriverName => _cancelledByDriverName;

  // Rating state — set after the trip completes
  bool _showRatingDialog = false;
  bool get showRatingDialog => _showRatingDialog;
  String? _ratingRideId;
  String? _ratingDriverId;
  String? _ratingDriverName;
  String? get ratingRideId => _ratingRideId;
  String? get ratingDriverId => _ratingDriverId;
  String? get ratingDriverName => _ratingDriverName;

  PaymentViewModel get paymentViewModel => _paymentViewModel;

  // SharedPreferences key — only used to persist the rideId across cold starts.
  // The step is ALWAYS derived from Firestore, never from SharedPreferences.
  static const String _kCurrentRideId = 'home_current_ride_id';

  HomeViewModel() {
    _initialize();
  }

  Future<void> _saveRideId(String? rideId) async {
    final prefs = await SharedPreferences.getInstance();
    if (rideId != null) {
      await prefs.setString(_kCurrentRideId, rideId);
    } else {
      await prefs.remove(_kCurrentRideId);
    }
  }

  Future<String?> _loadSavedRideId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kCurrentRideId);
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

      // On cold start, check Firestore first.
      // If Firestore finds nothing, fall back to SharedPreferences rideId
      // to handle the edge case where Firestore is slow.
      await _checkForActiveRide();
    } catch (error) {
      debugPrint("Error initializing HomeViewModel: $error");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> refresh() async {
    await _initialize();
  }

  Future<void> _initializeIcons() async {
    _greenCarIcon = await getMarkerIcon('assets/icons/bluecar.png', 96);
  }

  void _onPaymentStateChanged() {
    debugPrint("HomeViewModel: Detected PaymentState change -> ${_paymentViewModel.state}");

    switch (_paymentViewModel.state) {
      case PaymentState.success:
        _currentStep = HomeStep.findingDriver;
        notifyListeners();
        break;
      case PaymentState.failed:
        _currentStep = HomeStep.vehicleSelection;
        notifyListeners();
        break;
      case PaymentState.cancelled:
        _currentStep = HomeStep.vehicleSelection;
        notifyListeners();
        break;
      default:
        notifyListeners();
        break;
    }
  }

  void _listenToOnlineDrivers() {
    _driverSub?.cancel();
    _driverSub = _db.getOnlineDriversStream().listen((snapshot) {
      final markers = <String, Marker>{};
      for (final doc in snapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;
        if (data['latitude'] == null || data['longitude'] == null) continue;
        final id = doc.id;
        final position = LatLng(data['latitude'], data['longitude']);
        markers[id] = Marker(
          markerId: MarkerId(id),
          position: position,
          icon: _greenCarIcon ?? BitmapDescriptor.defaultMarker,
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

  Future<void> selectSavedPlace(BuildContext context, String placeName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    var place = _savedPlaces.firstWhere(
          (savedPlace) => savedPlace.name == placeName,
      orElse: () => SavedPlace.empty(),
    );

    if (place.id.isEmpty) {
      final newPlace = await Navigator.push<SavedPlace>(
        context,
        MaterialPageRoute(builder: (_) => AddSavedPlaceScreen(placeType: placeName)),
      );
      if (newPlace != null) {
        _savedPlaces = await _db.getSavedPlaces(uid);
        place = newPlace;
      } else {
        return;
      }
    }

    final origin = PlaceDetails.fromCurrentPosition(
      LatLng(mapViewModel.currentPosition!.latitude, mapViewModel.currentPosition!.longitude),
    );
    final destination = PlaceDetails.fromSavedPlace(place);
    await selectRoute(origin, destination);
  }

  Future<void> selectRecentDestination(RideDestination destination) async {
    if (mapViewModel.currentPosition == null) return;
    final origin = PlaceDetails.fromCurrentPosition(
      LatLng(mapViewModel.currentPosition!.latitude, mapViewModel.currentPosition!.longitude),
    );
    final placeDetails = PlaceDetails(
      name: destination.address.split(',').first,
      address: destination.address,
      location: LatLng(destination.latitude, destination.longitude),
    );
    await selectRoute(origin, placeDetails);
  }

  Future<void> selectRoute(PlaceDetails origin, PlaceDetails destination) async {
    await mapViewModel.getDirections(origin.location, destination.location);
    if (mapViewModel.directionsResult != null) {
      _currentStep = HomeStep.routePreview;
    } else {
      _currentStep = HomeStep.initial;
    }
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
    _paymentViewModel.resetPayment();
    notifyListeners();
  }

  void cancelPayment() {
    if (_paymentViewModel.state == PaymentState.processing) {
      _paymentViewModel.handlePaymentCancelled();
    }
    _currentStep = HomeStep.vehicleSelection;
    notifyListeners();
  }

  Future<void> proceedToPayment(BuildContext context) async {
    if (_selectedVehicle == null || _userProfile == null || mapViewModel.directionsResult == null) return;

    _currentStep = HomeStep.payment;
    notifyListeners();

    final directionsResult = mapViewModel.directionsResult!;
    if (directionsResult.distanceValue == null || directionsResult.durationValue == null) {
      _currentStep = HomeStep.routePreview;
      notifyListeners();
      return;
    }

    final fares = fareService.calculateFare(directionsResult.distanceValue!, directionsResult.durationValue!);
    final estimatedFare = fares.getFareForVehicle(_selectedVehicle!);
    final bookingId = 'ride_${_userProfile!.uid}_${DateTime.now().millisecondsSinceEpoch}';

    final sessionData = await _paymentViewModel.initializePayment(
      amount: estimatedFare.toStringAsFixed(2),
      currency: 'usd',
      bookingId: bookingId,
    );

    if (sessionData != null && sessionData['checkoutUrl'] != null && context.mounted) {
      final bool? paymentResult = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => StripeCheckoutScreen(
            checkoutUrl: sessionData['checkoutUrl'] as String,
          ),
        ),
      );

      if (paymentResult == true) {
        debugPrint("✅ Payment successful. Creating ride request...");
        _paymentViewModel.handlePaymentSuccess(sessionData['paymentId']);

        _currentStep = HomeStep.findingDriver;
        notifyListeners();

        await _createRideRequestAfterPayment();
      } else {
        debugPrint("🟡 Payment was cancelled or failed.");
        _paymentViewModel.handlePaymentCancelled();
        _currentStep = HomeStep.vehicleSelection;
        notifyListeners();
      }
    } else if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_paymentViewModel.errorMessage ?? 'Failed to start payment.')),
      );
      _currentStep = HomeStep.vehicleSelection;
      notifyListeners();
    }
  }

  Future<void> _createRideRequestAfterPayment() async {
    _isRequestingRide = true;
    notifyListeners();

    try {
      if (_selectedVehicle == null ||
          _userProfile == null ||
          mapViewModel.directionsResult == null ||
          mapViewModel.currentPosition == null ||
          _paymentViewModel.currentPaymentId == null) {
        throw Exception("Missing critical data for ride request.");
      }

      final directionsResult = mapViewModel.directionsResult!;
      final fares = fareService.calculateFare(directionsResult.distanceValue!, directionsResult.durationValue!);
      final fare = fares.getFareForVehicle(_selectedVehicle!);

      final rideRequest = RideRequest(
        id: '',
        userId: _userProfile!.uid,
        vehicleType: _selectedVehicle!,
        status: RideStatus.pending,
        passengerName: _userProfile!.fullName,
        passengerRating: _userProfile!.rating,
        pickupLocation: LatLng(mapViewModel.currentPosition!.latitude, mapViewModel.currentPosition!.longitude),
        destinationLocation: directionsResult.endLocation,
        pickupAddress: directionsResult.startAddress,
        destinationAddress: directionsResult.endAddress,
        fare: fare,
        distance: directionsResult.distanceValue! / 1000.0,
        createdAt: DateTime.now(),
        paymentId: _paymentViewModel.currentPaymentId!,
      );

      final newRideId = await _db.createRideRequest(rideRequest);
      _rideId = newRideId;

      // Save the rideId to SharedPreferences immediately.
      // This is our cold-start safety net.
      await _saveRideId(newRideId);

      _listenForRideStatus(newRideId!);
    } catch (error) {
      debugPrint("Error creating ride request: $error");
      _resetRide();
    } finally {
      _isRequestingRide = false;
      notifyListeners();
    }
  }

  void _listenForRideStatus(String rideId) {
    // Always cancel the old listener before attaching a new one.
    // This prevents duplicate listeners stacking up on resume.
    _rideListener?.cancel();
    _rideListener = null;

    debugPrint("🎧 Attaching ride listener for rideId: $rideId");

    _rideListener = _rideService.getRideStream(rideId).listen(
          (snapshot) {
        if (!snapshot.exists) {
          debugPrint("❌ Ride document no longer exists — resetting.");
          _resetRide();
          return;
        }

        final data = snapshot.data() as Map<String, dynamic>;
        final rawStatus = data['status'] ?? 'pending';
        final status = RideStatus.fromString(rawStatus);

        debugPrint("🔥 RIDE STATUS → Raw: '$rawStatus' | Enum: ${status.name} | Step: ${_currentStep.name}");

        if (status.isTerminal) {
          debugPrint("🛑 Terminal status — resetting ride.");
          if (status == RideStatus.cancelled_by_driver) {
            _cancelledByDriver = true;
            _cancelledByDriverName = data['driverName'] as String?;
          } else if (status == RideStatus.completed) {
            final driverId = data['driverId'] as String?;
            if (driverId != null) {
              _ratingRideId = rideId;
              _ratingDriverId = driverId;
              _ratingDriverName = data['driverName'] as String?;
              _showRatingDialog = true;
            }
          }
          _resetRide();
          return;
        }

        // Driver accepted or trip is underway → switch to ActiveTrip card.
        if (status == RideStatus.accepted ||
            status == RideStatus.enroute ||
            status == RideStatus.ongoing) {
          if (_currentStep != HomeStep.activeTrip) {
            debugPrint("✅ Switching to ActiveTripCard.");
            _currentStep = HomeStep.activeTrip;
            _rideId = rideId;

            final String? driverId = data['driverId'];
            final driverLocationStream = _db.getDriverLatLngStream(driverId);
            mapViewModel.startFollowingDriver(driverLocationStream);

            // Safe notify — schedule after current build frame completes.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!_isDisposed) notifyListeners();
            });
          }
        }
      },
      onError: (error) {
        debugPrint("❌ Ride listener error: $error");
      },
    );
  }

  Future<void> cancelRide() async {
    if (_rideId != null) {
      await _rideService.cancelRide(_rideId!, cancelledBy: 'user');
    }
    _resetRide();
  }

  void _resetRide() {
    _rideListener?.cancel();
    _rideListener = null;
    _rideId = null;
    _selectedVehicle = null;
    mapViewModel.clearRoute();
    _currentStep = HomeStep.initial;
    _paymentViewModel.resetPayment();
    _saveRideId(null); // Clear persisted rideId
    if (!_isDisposed) notifyListeners();
  }

  Future<void> _checkForActiveRide() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Step 1: Ask Firestore if there's an active ride for this user right now.
    String? activeRideId = await _db.getUserCurrentRide(uid);

    // Step 2: If Firestore returns nothing, fall back to the saved rideId.
    // This handles the edge case where the app was killed mid-ride and
    // Firestore hasn't been queried yet.
    if (activeRideId == null || activeRideId.isEmpty) {
      activeRideId = await _loadSavedRideId();
      debugPrint("🔁 Firestore had no active ride. SharedPrefs fallback: $activeRideId");
    }

    if (activeRideId != null && activeRideId.isNotEmpty) {
      // There's an active ride — always re-attach the listener.
      // Do NOT trust the saved step. Let the Firestore listener determine
      // the correct step based on the real ride status.
      _rideId = activeRideId;
      await _saveRideId(activeRideId);
      _listenForRideStatus(activeRideId);

      // Show FindingDriver while we wait for the listener to fire.
      // The listener will immediately update to activeTrip if already accepted.
      if (_currentStep == HomeStep.initial) {
        _currentStep = HomeStep.findingDriver;
        notifyListeners();
      }

      debugPrint("✅ Active ride found: $activeRideId");
    } else {
      // No active ride anywhere — make sure we're on the initial screen.
      // But only reset if we're not mid-booking (selecting route/vehicle/payment).
      if (_currentStep == HomeStep.findingDriver || _currentStep == HomeStep.activeTrip) {
        _currentStep = HomeStep.initial;
        notifyListeners();
      }
      debugPrint("ℹ️ No active ride found.");
    }
  }

  /// Called when the app comes back from background or the user returns to this screen.
  Future<void> refreshOnScreenResume() async {
    debugPrint("🔄 refreshOnScreenResume() called");

    // Re-initialize the map when the user returns from OS Settings after
    // granting location permission (currentPosition will be null until then).
    if (mapViewModel.currentPosition == null) {
      _isLoading = true;
      notifyListeners();
      await mapViewModel.initialize();
      _isLoading = false;
      notifyListeners();
    }

    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    if (_isRefreshing) return;
    _isRefreshing = true;

    try {
      await _checkForActiveRide();
    } finally {
      _isRefreshing = false;
    }
  }

  Future<BitmapDescriptor> getMarkerIcon(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final byteData = await frameInfo.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  void acknowledgeDriverCancellation() {
    _cancelledByDriver = false;
    _cancelledByDriverName = null;
    notifyListeners();
  }

  void dismissRatingDialog() {
    _showRatingDialog = false;
    _ratingRideId = null;
    _ratingDriverId = null;
    _ratingDriverName = null;
    notifyListeners();
  }

  Future<void> submitRating(double rating) async {
    if (_ratingRideId == null || _ratingDriverId == null) return;
    try {
      await _rideService.submitDriverRating(
        rideId: _ratingRideId!,
        driverId: _ratingDriverId!,
        rating: rating,
      );
    } catch (e) {
      debugPrint("HomeViewModel: Failed to submit rating: $e");
    }
    dismissRatingDialog();
  }

  bool _isDisposed = false;

  @override
  void dispose() {
    _isDisposed = true;
    mapViewModel.dispose();
    _driverSub?.cancel();
    _rideListener?.cancel();
    _paymentViewModel.removeListener(_onPaymentStateChanged);
    super.dispose();
  }
}