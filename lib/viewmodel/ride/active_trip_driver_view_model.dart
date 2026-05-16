import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../app/service_locator.dart';
import '../../models/ride_request_model.dart';
import '../../models/user_profile.dart';
import '../../services/database_service.dart';
import '../../services/ride_service.dart';
import '../../services/voice_navigation_service.dart';

class ActiveTripDriverViewModel extends ChangeNotifier {
  final String rideId;
  final RideService _rideService = locator<RideService>();
  final DatabaseService _db = locator<DatabaseService>();

  bool _loading = true;
  bool get isLoading => _loading;

  RideRequest? _ride;
  RideRequest? get rideRequest => _ride;

  LatLng? _destination;
  LatLng? get userDestination => _destination;

  Stream<LatLng>? _driverLocation;
  Stream<LatLng>? get driverLoc => _driverLocation;

  UserProfile? _passenger;
  UserProfile? get passengerProfile => _passenger;

  StreamSubscription<DocumentSnapshot>? _rideSub;
  bool _acceptedAnnouncementMade = false;

  ActiveTripDriverViewModel({required this.rideId}) {
    _initialize();
  }

  String get statusLabel {
    switch (_ride?.status) {
      case RideStatus.accepted:
        return "Navigating to pickup";
      case RideStatus.enroute:
        return "Arrived at pickup – waiting for passenger";
      case RideStatus.ongoing:
        return "Trip in progress";
      case RideStatus.completed:
        return "Trip complete";
      default:
        return "Loading...";
    }
  }

  Future<void> _initialize() async {
    _rideSub = _rideService.getRideStream(rideId).listen((doc) async {
      if (!doc.exists) return;
      _ride = RideRequest.fromFirestore(doc);
      if (_ride!.userId.isNotEmpty && _passenger == null) {
        _passenger = await _db.getUserProfile(_ride!.userId);
      }

      if (_ride!.driverId != null){
        _driverLocation = _db.getDriverLatLngStream(_ride!.driverId);

        _destination = _ride!.destinationLocation;
      }

      _loading = false;
      notifyListeners();

      if (!_acceptedAnnouncementMade && _ride!.status == RideStatus.accepted) {
        _acceptedAnnouncementMade = true;
        locator<VoiceNavigationService>().announce(
          "Head on to your pickup at ${_ride!.pickupAddress}",
        );
      }
    });



  }

  Future<void> markArrived() async {
    // Voice navigation already announced "You have arrived at the pickup
    // location" based on GPS proximity. No duplicate announcement needed here.
    await _updateStatus('enroute');
  }

  Future<void> startTrip() async {
    final destination = _ride?.destinationAddress ?? '';
    // Await so the TTS finishes before the status update triggers route
    // recalculation — otherwise a GPS tick could interrupt this announcement.
    await locator<VoiceNavigationService>().announce(
        "Trip started. Heading to $destination.");
    await _updateStatus('ongoing');
  }

  Future<void> completeTrip() async {
    await _updateStatus('completed');
  }

  Future<void> cancelRide() async {
    await _updateStatus('cancelled_by_driver');
  }

  Future<void> _updateStatus(String newStatus) async {
    if (_ride == null) return;
    //await _rideService.updateRideStatus(rideId, newStatus);
    try {
      await _rideService.updateRideStatus(rideId, newStatus);
    } catch (e) {
    }
    // Force UI refresh even if DB call fails or is slow
    //notifyListeners();
  }

  Future<void> makeCall() async {
    final phone = _passenger?.phone;
    if (phone == null) return;
    final uri = Uri.parse('tel:$phone');
    await launchUrl(uri);
  }


  @override
  void dispose() {
    _rideSub?.cancel();
    super.dispose();
  }
}