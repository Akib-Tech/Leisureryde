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
import '../../screens/user/payment/stripe_checkout.dart';
import '../../services/ride_service.dart';
import '../../services/place_service.dart';
import '../maps/maps_viewmodel.dart';
import '../payment/payment.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart';

enum HomeStep {
  initial,
  routePreview,
  vehicleSelection,
  payment, // NEW STEP: Payment comes after vehicle selection
  findingDriver,
  activeTrip,
}

class HomeViewModel extends ChangeNotifier {
  final _auth = locator<AuthService>();
  final _db = locator<DatabaseService>();
  final _rideService = locator<RideService>();
  final FareCalculationService fareService = locator<FareCalculationService>();
  final MapViewModel mapViewModel = MapViewModel(); // Initialized directly

  // USER PROFILE
  UserProfile? _userProfile;
  UserProfile? get userProfile => _userProfile;

  // UI STATE
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  bool _isInitiatingRideRequest = false; // Renamed to avoid confusion with payment loading
  bool get isInitiatingRideRequest => _isInitiatingRideRequest;

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

  // PAYMENT INTEGRATION
  final PaymentViewModel _paymentViewModel = locator<PaymentViewModel>(); // Injected YOUR PaymentViewModel
  PaymentViewModel get paymentViewModel => _paymentViewModel; // Expose PaymentViewModel

  HomeViewModel() {
    _initialize();
    _paymentViewModel.addListener(_onPaymentStateChanged); // Listen to payment state changes
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    await mapViewModel.initialize(); // Initialize MapViewModel
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
    const int iconWidth = 96;

    _greenCarIcon = await getMarkerIcon('assets/icons/bluecar.png', iconWidth);
    _goldCarIcon = await getMarkerIcon('assets/icons/goldcar.png', iconWidth);
  }

  // --- Payment State Change Handler ---
  void _onPaymentStateChanged() {
    debugPrint("HomeViewModel: Detected PaymentState change: ${_paymentViewModel.state}");
    switch (_paymentViewModel.state) {
      case PaymentState.success:
        debugPrint("Payment successful. Proceeding to ride request.");
        _requestRideInternal(); // Request ride AFTER successful payment
        _paymentViewModel.resetPayment(); // Reset payment VM for next use
        break;
      case PaymentState.failed:
        debugPrint("Payment failed: ${_paymentViewModel.errorMessage}");
        // Optionally show a dialog/snackbar in the UI, which will observe this state
        // Revert to payment step, UI should show error.
        _currentStep = HomeStep.payment;
        notifyListeners();
        break;
      case PaymentState.cancelled:
        debugPrint("Payment cancelled.");
        // Revert to vehicle selection
        _currentStep = HomeStep.vehicleSelection;
        _paymentViewModel.resetPayment();
        notifyListeners();
        break;
      case PaymentState.loading:
      case PaymentState.processing:
      case PaymentState.idle:
      default:
      // UI will react to paymentViewModel.isLoading for progress indicators
        notifyListeners(); // Ensure HomeViewModel also updates its listeners
        break;
    }
  }

  Future<void> refresh() async {
    await _initialize();
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
              ? _goldCarIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange)
              : _greenCarIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
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
  Future<void> selectSavedPlace(BuildContext context, String placeName) async {
    final p = _savedPlaces.firstWhere(
            (pl) => pl.name == placeName,
        orElse: () => SavedPlace(
            id: '', name: '', address: '', latitude: 0, longitude: 0));

    if (p.id.isEmpty) {
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
    // When selecting a saved place, we create a basic RouteSelectionResult
    // The actual directions (duration, distance, polyline) will be fetched by mapViewModel.getDirections
    await selectRoute(origin, dest);
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
    // When selecting a recent destination, create a basic RouteSelectionResult
    await selectRoute(origin, destination);
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

  Future<void> selectRoute(PlaceDetails origin, PlaceDetails destination) async {
    if (mapViewModel.currentPosition == null) {
      // Potentially show a snackbar or error here
      debugPrint("Current position is null, cannot select route.");
      return;
    }

    await mapViewModel.getDirections(origin.location, destination.location);

    // CRITICAL FIX: Only change step to routePreview IF directions were successfully fetched.
    if (mapViewModel.directionsResult != null) {
      _currentStep = HomeStep.routePreview;
    } else {
      // If directions failed, revert to initial or show error.
      debugPrint("Failed to get directions for the selected route.");
      _currentStep = HomeStep.initial; // Revert to initial step
      // Optionally show a user-friendly error message via a snackbar.
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
    _paymentViewModel.resetPayment(); // Reset payment state on early exit
    notifyListeners();
  }

  // NEW: Method to proceed to the payment screen and initiate Stripe Checkout
  Future<void> proceedToPayment(BuildContext context) async {
    if (_selectedVehicle == null || _userProfile == null || mapViewModel.directionsResult == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing details for payment.')),
      );
      return;
    }

    _currentStep = HomeStep.payment; // Move to payment card
    notifyListeners();

    final d = mapViewModel.directionsResult!;
    // Ensure durationValue and distanceValue are not null before passing to calculateFare
    if (d.durationValue == null || d.distanceValue == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing route details for fare calculation.')),
      );
      _currentStep = HomeStep.routePreview; // Revert
      notifyListeners();
      return;
    }

    final fares = fareService.calculateFare(d.distanceValue!, d.durationValue!);
    double estimatedFare = fares.getFareForVehicle(_selectedVehicle!);

    // A unique identifier for this booking/ride before it's even created in RideService
    final tempBookingId = 'temp_ride_${_userProfile!.uid}_${DateTime.now().millisecondsSinceEpoch}';

    final paymentSessionData = await _paymentViewModel.initializePayment(
      amount: estimatedFare.toStringAsFixed(2), // Amount as string
      currency: 'USD',
      userId: _userProfile!.uid,
      bookingId: tempBookingId, // This will be stored in Firestore 'payments' collection
      metadata: {
        'vehicleType': _selectedVehicle!,
        'destinationAddress': d.endAddress,
      },
    );

    if (paymentSessionData != null && paymentSessionData['checkoutUrl'] != null) {
      // Launch Stripe Checkout WebView
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (ctx) => StripeCheckoutScreen(
            checkoutUrl: paymentSessionData['checkoutUrl']!,
            sessionId: paymentSessionData['sessionId']!,
            paymentId: paymentSessionData['paymentId']!,
            onPaymentSuccess: _paymentViewModel.handlePaymentSuccess,
            onPaymentCancelled: _paymentViewModel.handlePaymentCancelled,
          ),
        ),
      );
    } else {
      // Payment initialization failed, revert
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_paymentViewModel.errorMessage ?? 'Failed to initialize payment.')),
      );
      _currentStep = HomeStep.vehicleSelection; // Go back if initialization failed
      _paymentViewModel.resetPayment();
      notifyListeners();
    }
  }


  // ---------------------------------------------------------------------------
  // REQUEST RIDE (User) - Called AFTER Payment is successful
  // ---------------------------------------------------------------------------
  Future<void> _requestRideInternal() async {
    _isInitiatingRideRequest = true;
    notifyListeners();

    try {
      if (_selectedVehicle == null ||
          _userProfile == null ||
          mapViewModel.directionsResult == null ||
          mapViewModel.currentPosition == null ||
          _paymentViewModel.paymentDetails == null) {
        throw Exception("Cannot request ride – missing payment or ride data.");
      }

      final d = mapViewModel.directionsResult!;
      // Ensure durationValue and distanceValue are not null
      if (d.durationValue == null || d.distanceValue == null) {
        throw Exception("Missing route details for fare calculation during ride request.");
      }

      final fares = fareService.calculateFare(d.distanceValue!, d.durationValue!);
      double calculatedFare = fares.getFareForVehicle(_selectedVehicle!);

      // Extract payment details from PaymentViewModel
      final String? paymentId = _paymentViewModel.currentPaymentId;
      final String? stripePaymentIntentId = _paymentViewModel.paymentDetails!['stripePaymentIntent'];
      // Convert amountTotal from cents to dollars for storage in RideRequest
      final double? amountTotalCents = (_paymentViewModel.paymentDetails!['amountTotal'] as double);
      final String? amountPaid = amountTotalCents != null ? (amountTotalCents / 100.0).toStringAsFixed(2) : null;


      final rideRequest = RideRequest(
        id: '', // Firestore will generate this
        userId: _userProfile!.uid,
        vehicleType: _selectedVehicle!,
        status: RideStatus.pending,
        passengerName: _userProfile!.fullName,
        passengerRating: _userProfile!.rating, // Use actual user rating
        pickupLocation: LatLng(mapViewModel.currentPosition!.latitude, mapViewModel.currentPosition!.longitude),
        destinationLocation: d.polylinePoints.last, // Use endLocation from DirectionsResult
        pickupAddress: d.startAddress,
        destinationAddress: d.endAddress,
        fare: calculatedFare,
        distance: d.distanceValue! / 1000.0, // distance in km
        createdAt: DateTime.now(),
        paymentId: paymentId,
        stripePaymentIntentId: stripePaymentIntentId,
        amountPaid: amountPaid,
      );

      final id = await _db.createRideRequest(rideRequest);
      _rideId = id;
      _currentStep = HomeStep.findingDriver;
      _listenForRideStatus(id!);
    } catch (e) {
      debugPrint("Ride creation error after payment: $e");
      // On error, revert to payment or vehicle selection
      _currentStep = HomeStep.payment; // Or HomeStep.vehicleSelection
      // Optionally update payment status in Firestore if ride creation fails after payment
    } finally {
      _isInitiatingRideRequest = false;
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
      final statusString = data['status'] as String;
      final status = RideStatus.values.firstWhere((e) => e.name == statusString, orElse: () => RideStatus.pending);

      debugPrint("Ride $id status updated to: $status");

      if (status == RideStatus.accepted) {
        activeDriverId = data['driverId'];
        _currentStep = HomeStep.activeTrip;
      } else if (status == RideStatus.cancelled ||
          status == RideStatus.cancelled_by_driver ||
          status == RideStatus.completed ||
          status == RideStatus.failed) {
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

  // **The missing `cancelPayment` method, now fully implemented:**
  void cancelPayment() {
    debugPrint("HomeViewModel: cancelPayment called.");
    // If a payment process was active, inform the PaymentViewModel it was cancelled
    if (_paymentViewModel.state == PaymentState.loading || _paymentViewModel.state == PaymentState.processing) {
      _paymentViewModel.handlePaymentCancelled(_paymentViewModel.currentPaymentId ?? 'unknown_payment_id');
    }
    // Always revert to vehicle selection when backing out of payment
    _currentStep = HomeStep.vehicleSelection;
    notifyListeners();
  }


  // Reset state once ride ends/cancels
  void _resetRide() {
    _rideId = null;
    activeDriverId = null;
    _selectedVehicle = null;
    mapViewModel.clearRoute();
    _currentStep = HomeStep.initial;
    _paymentViewModel.resetPayment(); // Reset payment state
    notifyListeners();
  }
  // Helper function to get a resized custom marker icon
  Future<BitmapDescriptor> getMarkerIcon(String path, int width) async {
    final ByteData data = await rootBundle.load(path);
    final ui.Codec codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: width,
    );
    final ui.FrameInfo fi = await codec.getNextFrame();
    final byteData = await fi.image.toByteData(format: ui.ImageByteFormat.png);
    final resizedBytes = byteData!.buffer.asUint8List();
    return BitmapDescriptor.fromBytes(resizedBytes);
  }

  @override
  void dispose() {
    mapViewModel.dispose();
    _driverSub?.cancel();
    _rideListener?.cancel();
    _paymentViewModel.removeListener(_onPaymentStateChanged); // Remove listener
    _paymentViewModel.dispose(); // Dispose the injected ViewModel
    super.dispose();
  }
}