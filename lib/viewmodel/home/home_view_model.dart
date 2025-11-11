import 'dart:async';
import 'dart:ui' as ui;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/models/route_selection.dart';
import 'package:leisureryde/models/saved_places.dart';
import 'package:leisureryde/models/user_profile.dart';
import 'package:leisureryde/screens/shared/account_screen/saved_places_screen.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:leisureryde/services/database_service.dart';
import 'package:leisureryde/services/fare_calculation_service.dart';
import 'package:leisureryde/services/place_service.dart';
import 'package:leisureryde/services/ride_service.dart';
import 'package:leisureryde/viewmodel/maps/maps_viewmodel.dart';

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

  PaymentViewModel get paymentViewModel => _paymentViewModel;

  HomeViewModel() {
    _initialize();
    // _paymentViewModel.addListener(_onPaymentStateChanged);
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

  // --- METHOD THAT WAS MISSING ---
  Future<void> refresh() async {
    await _initialize();
  }
  // --- END OF MISSING METHOD ---

  Future<void> _initializeIcons() async {
    _greenCarIcon = await getMarkerIcon('assets/icons/bluecar.png', 96);
  }

  void _onPaymentStateChanged() {
    debugPrint("HomeViewModel: Detected PaymentState change -> ${_paymentViewModel.state}");

    switch (_paymentViewModel.state) {
      case PaymentState.success:
      // CRITICAL CHANGE: Don't call the async method directly.
      // Just change the step. The UI will react and show the "FindingDriverCard".
        _currentStep = HomeStep.findingDriver;
        notifyListeners();
        // We will create the ride request from the UI widget instead.
        break;
      case PaymentState.failed:
      // Go back to the previous step so the user can see the error and retry.
        _currentStep = HomeStep.vehicleSelection;
        notifyListeners();
        break;
      case PaymentState.cancelled:
      // Go back to the previous step.
        _currentStep = HomeStep.vehicleSelection;
        notifyListeners();
        break;
      default:
      // For states like 'loading' or 'processing', we might not need to change
      // the home step, but we still need to rebuild the UI to show loaders.
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
        final pos = LatLng(data['latitude'], data['longitude']);
        markers[id] = Marker(
          markerId: MarkerId(id),
          position: pos,
          icon: _greenCarIcon ?? BitmapDescriptor.defaultMarker,
          rotation: (data['heading'] ?? 0.0).toDouble(),
          flat: true,
          anchor: const Offset(0.5, 0.5),
        );
      }
      _driverMarkers..clear()..addAll(markers);
      notifyListeners();
    });
  }

  Future<void> selectSavedPlace(BuildContext context, String placeName) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    var place = _savedPlaces.firstWhere((p) => p.name == placeName, orElse: () => SavedPlace.empty());
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
    final origin = PlaceDetails.fromCurrentPosition(LatLng(mapViewModel.currentPosition!.latitude, mapViewModel.currentPosition!.longitude));
    final destination = PlaceDetails.fromSavedPlace(place);
    await selectRoute(origin, destination);
  }

  // --- METHOD THAT WAS MISSING ---
  Future<void> selectRecentDestination(RideDestination dest) async {
    if (mapViewModel.currentPosition == null) return;
    final origin = PlaceDetails.fromCurrentPosition(LatLng(mapViewModel.currentPosition!.latitude, mapViewModel.currentPosition!.longitude));
    final destination = PlaceDetails(
      name: dest.address.split(',').first,
      address: dest.address,
      location: LatLng(dest.latitude, dest.longitude),
    );
    await selectRoute(origin, destination);
  }
  // --- END OF MISSING METHOD ---

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

    final d = mapViewModel.directionsResult!;
    if (d.distanceValue == null || d.durationValue == null) {
      _currentStep = HomeStep.routePreview;
      notifyListeners();
      return;
    }

    final fares = fareService.calculateFare(d.distanceValue!, d.durationValue!);
    final estimatedFare = fares.getFareForVehicle(_selectedVehicle!);
    final bookingId = 'ride_${_userProfile!.uid}_${DateTime.now().millisecondsSinceEpoch}';

    final sessionData = await _paymentViewModel.initializePayment(
      amount: estimatedFare.toStringAsFixed(2),
      currency: 'usd',
      bookingId: bookingId,
    );

    if (sessionData != null && sessionData['checkoutUrl'] != null && context.mounted) {
      // Await the result from the StripeCheckoutScreen.
      final bool? paymentResult = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) => StripeCheckoutScreen(
            checkoutUrl: sessionData['checkoutUrl'] as String,
          ),
        ),
      );

      // --- THIS IS THE NEW, DIRECT LOGIC ---
      if (paymentResult == true) {
        // Payment was successful!
        debugPrint("✅ Payment successful. Creating ride request...");
        _paymentViewModel.handlePaymentSuccess(sessionData['paymentId']); // Update payment state

        // Change the UI state to show the finding driver screen *immediately*.
        _currentStep = HomeStep.findingDriver;
        notifyListeners();

        // Now, create the ride request on the backend.
        await _createRideRequestAfterPayment();
      } else {
        // Payment was cancelled or failed.
        debugPrint("🟡 Payment was cancelled or failed.");
        _paymentViewModel.handlePaymentCancelled(); // Update payment state
        _currentStep = HomeStep.vehicleSelection; // Go back to vehicle selection
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

  // Renamed from 'confirmAndRequestRide'. This is now a private helper.
  Future<void> _createRideRequestAfterPayment() async {
    _isRequestingRide = true;
    notifyListeners();

    try {
      if (_selectedVehicle == null || _userProfile == null || mapViewModel.directionsResult == null ||
          mapViewModel.currentPosition == null || _paymentViewModel.currentPaymentId == null) {
        throw Exception("Missing critical data for ride request.");
      }

      final d = mapViewModel.directionsResult!;
      final fares = fareService.calculateFare(d.distanceValue!, d.durationValue!);
      final fare = fares.getFareForVehicle(_selectedVehicle!);
      final rideRequest = RideRequest(
        id: '',
        userId: _userProfile!.uid,
        vehicleType: _selectedVehicle!,
        status: RideStatus.pending,
        passengerName: _userProfile!.fullName,
        passengerRating: _userProfile!.rating,
        pickupLocation: LatLng(mapViewModel.currentPosition!.latitude, mapViewModel.currentPosition!.longitude),
        destinationLocation: d.endLocation,
        pickupAddress: d.startAddress,
        destinationAddress: d.endAddress,
        fare: fare,
        distance: d.distanceValue! / 1000.0,
        createdAt: DateTime.now(),
        paymentId: _paymentViewModel.currentPaymentId!,
      );

      final newRideId = await _db.createRideRequest(rideRequest);
      _rideId = newRideId;
      _listenForRideStatus(newRideId!);

    } catch (e) {
      debugPrint("Error creating ride request: $e");
      // If creating the ride fails, reset everything.
      _resetRide();
    } finally {
      _isRequestingRide = false;
      notifyListeners();
      // Do NOT reset payment here. _resetRide handles it on failure/cancellation.
    }
  }

  void _listenForRideStatus(String id) {
    _rideListener?.cancel();
    _rideListener = _rideService.getRideStream(id).listen((snap) {
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>;
      final status = RideStatus.fromString(data['status']);
      if (status.isTerminal) {
        _resetRide();
      } else if (status != RideStatus.pending) {
        _currentStep = HomeStep.activeTrip;
      }
      notifyListeners();
    });
  }

  Future<void> cancelRide() async {
    if (_rideId != null) {
      await _rideService.cancelRide(_rideId!, cancelledBy: 'user');
    }
    _resetRide();
  }

  void _resetRide() {
    _rideId = null;
    _selectedVehicle = null;
    mapViewModel.clearRoute();
    _currentStep = HomeStep.initial;
    _paymentViewModel.resetPayment();
    notifyListeners();
  }

  Future<BitmapDescriptor> getMarkerIcon(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(data.buffer.asUint8List(), targetWidth: width);
    final ui.FrameInfo fi = await codec.getNextFrame();
    final byteData = await fi.image.toByteData(format: ui.ImageByteFormat.png);
    return BitmapDescriptor.fromBytes(byteData!.buffer.asUint8List());
  }

  @override
  void dispose() {
    mapViewModel.dispose();
    _driverSub?.cancel();
    _rideListener?.cancel();
    _paymentViewModel.removeListener(_onPaymentStateChanged);
    super.dispose();
  }
}