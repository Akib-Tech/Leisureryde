import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/app/service_locator.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../models/driver_profile.dart';
import '../../models/ride_request_model.dart';
import '../../screens/user/payment/stripe_checkout.dart';
import '../../services/database_service.dart';
import '../../services/directions_service.dart';
import '../../services/ride_service.dart';
import '../payment/payment.dart';

class ActiveTripViewModel extends ChangeNotifier {
  final String rideId;
  final RideService _rideService = locator<RideService>();
  final DatabaseService _databaseService = locator<DatabaseService>();
  late StreamSubscription<DocumentSnapshot> _rideSubscription;
  StreamSubscription<DocumentSnapshot>? _driverLocationSubscription;
  final DirectionsService _directionsService = locator<
      DirectionsService>(); // Add this



  // State
  bool _isLoading = true;
  bool get isLoading => _isLoading;

  RideRequest? _rideRequest;
  RideRequest? get rideRequest => _rideRequest;

  DriverProfile? _driverProfile;
  DriverProfile? get driverProfile => _driverProfile;

  LatLng? _driverLocation;
  LatLng? get driverLocation => _driverLocation;

  DirectionsResult? _liveDirections;
  DirectionsResult? get liveDirections => _liveDirections;

  Set<Polyline> _polylines = {};
  Set<Polyline> get polylines => _polylines;

  DocumentSnapshot? _rideData;

  DocumentSnapshot? get rideData => _rideData;


  String get tripStatus => _rideData?['status'] ?? 'loading';

  ActiveTripViewModel({required this.rideId}) {
    _initialize();
  }

  void _initialize() {
    _listenToRideUpdates();
  }

  void _listenToRideUpdates() {
    _rideSubscription =
        _rideService.getRideStream(rideId).listen((snapshot) async {
          if (!snapshot.exists) {
            // Handle ride cancellation or deletion
            return;
          }

          _rideRequest = RideRequest.fromFirestore(snapshot);

          // Safely check for the nullable driverId before fetching driver details
          if (_driverProfile == null && _rideRequest?.driverId != null) {
            _driverProfile =
            await _databaseService.getDriverProfile(_rideRequest!.driverId!);
            _listenToDriverLocation(_rideRequest!.driverId!);
          }

          await _updateTripDirections();

          _isLoading = false;
          notifyListeners();
        });
  }

  void _listenToDriverLocation(String driverId) {
    _driverLocationSubscription =
        _databaseService.getDriverLocationStream(driverId).listen((
            snapshot) async {
          if (snapshot.exists) {
            final data = snapshot.data() as Map<String, dynamic>;
            _driverLocation = LatLng(data['latitude'], data['longitude']);
            await _updateTripDirections();
            notifyListeners();
          }
        });
  }

  Future<void> _updateTripDirections() async {
    if (_rideRequest == null || _driverLocation == null) return;

    LatLng origin;
    LatLng destination;

    switch (_rideRequest!.status) {
      case RideStatus.accepted:
      case RideStatus.enroute:
        origin = _driverLocation!;
        destination = _rideRequest!.pickupLocation;
        break;
      case RideStatus.ongoing:
      // STATE C: Show route from Driver/User's current location to Destination
        origin = _driverLocation!;
        destination = _rideRequest!.destinationLocation;
        break;
      default:
      // For pending, completed, or cancelled, we don't need a live route
        _polylines.clear();
        _liveDirections = null;
        return;
    }

    final result = await _directionsService.getDirections(origin: origin, destination: destination);

    if (result != null) {
      _liveDirections = result;
      _polylines = {
        Polyline(
          polylineId: const PolylineId('live_route'),
          points: result.polylinePoints,
          color: Colors.blue,
          width: 5,
        ),
      };
    }
  }
  Future<void> _fetchDriverProfile(String driverId) async {
    try {
      _driverProfile = await _databaseService.getDriverProfile(driverId);
    } catch (e) {
      print("Error fetching driver profile: $e");
    }
  }


  Future<void> _updateRoute() async {
    if (_driverLocation == null || _rideData == null) return;

    final data = _rideData!.data() as Map<String, dynamic>;
    LatLng destination;

    // Determine the route's destination based on the trip status
    if (tripStatus == 'accepted' || tripStatus == 'enroute') {
      final pickup = data['pickup'] as Map<String, dynamic>;
      destination = LatLng(pickup['latitude'], pickup['longitude']);
    } else if (tripStatus == 'ongoing') {
      final dest = data['destination'] as Map<String, dynamic>;
      destination = LatLng(dest['latitude'], dest['longitude']);
    } else {
      _polylines.clear();
      notifyListeners();
      return;
    }

    final directions = await _directionsService.getDirections(
      origin: _driverLocation!,
      destination: destination,
    );

    if (directions != null) {
      _polylines = {
        Polyline(
          polylineId: const PolylineId('live_route'),
          points: directions.polylinePoints,
          color: const Color(0xFFD4AF37),
          width: 5,
        ),
      };
    }
    notifyListeners();
  }



  Future<void> makePhoneCall() async {
    if (_driverProfile != null) {
      final Uri launchUri = Uri(
        scheme: 'tel',
        path: _driverProfile!.phone,
      );
      if (await canLaunchUrl(launchUri)) {
        await launchUrl(launchUri);
      } else {
        throw 'Could not launch $launchUri';
      }
    }
  }

  Future<void> cancelTrip() async {
    await _rideService.cancelRide(rideId, cancelledBy: 'user');
  }

  Future<void> startPaymentFlow(BuildContext context) async {
    final rideDataMap = rideData!.data() as Map<String, dynamic>;
    final fare = rideDataMap['fare'].toString(); // In dollars
    final int amountInCents = (double.parse(fare) * 100).toInt(); // Stripe uses cents
    final userId = rideDataMap['userId'];
    final bookingId = rideId;

    final paymentVm = locator<PaymentViewModel>();

    final session = await paymentVm.initializePayment(
      amount: amountInCents.toString(),
      currency: 'usd',
      userId: userId,
      bookingId: bookingId,
      metadata: {
        'rideId': rideId,
        'pickup': rideDataMap['pickupAddress'],
        'destination': rideDataMap['destinationAddress'],
      },
    );

    if (session == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not start payment.")),
        );
      }
      return;
    }

    if (!context.mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => StripeCheckoutScreen(
          checkoutUrl: session['checkoutUrl'],
          sessionId: session['sessionId'],
          paymentId: session['paymentId'],
          onPaymentSuccess: (sessionId, paymentId) async {
            await paymentVm.handlePaymentSuccess(sessionId, paymentId);
            if (context.mounted) _showPaymentResult(context, success: true);
          },
          onPaymentCancelled: (paymentId) async {
            await paymentVm.handlePaymentCancelled(paymentId);
            if (context.mounted) _showPaymentResult(context, success: false);
          },
        ),
      ),
    );
  }

  void _showPaymentResult(BuildContext context, {required bool success}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(
        success ? "Payment successful! Thank you." : "Payment cancelled or failed.",
      ),
    ));

    Navigator.popUntil(context, (route) => route.isFirst); // Back to Home
  }

  @override
  void dispose() {
    _rideSubscription.cancel();
    _driverLocationSubscription?.cancel();
    super.dispose();
  }
}