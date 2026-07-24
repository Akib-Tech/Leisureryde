import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/service_locator.dart';
import '../../models/ride_request_model.dart';
import '../../services/ride_service.dart';

class ScheduledTripViewModel extends ChangeNotifier {
  final String rideId;

  final RideService _rideService = locator<RideService>();

  late StreamSubscription<DocumentSnapshot> _rideSubscription;

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  RideRequest? _rideRequest;
  RideRequest? get rideRequest => _rideRequest;

  ScheduledTripViewModel({
    required this.rideId,
  }) {
    _initialize();
  }

  void _initialize() {
    _listenToRide();
  }

  void _listenToRide() {
    _rideSubscription =
        _rideService.getRideStream(rideId).listen((snapshot) {
      if (!snapshot.exists) return;

      _rideRequest = RideRequest.fromFirestore(snapshot);

      _isLoading = false;

      notifyListeners();
    });
  }

  String get formattedScheduleTime {
    if (_rideRequest?.scheduledFor == null) {
      return "--";
    }

    return DateFormat(
      "EEE, d MMM • h:mm a",
    ).format(_rideRequest!.scheduledFor!);
  }

  Future<void> cancelRide() async {
    await _rideService.cancelRide(
      rideId,
      cancelledBy: "user",
    );
  }

  @override
  void dispose() {
    _rideSubscription.cancel();
    super.dispose();
  }
}