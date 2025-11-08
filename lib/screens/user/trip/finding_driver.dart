import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:leisureryde/app/service_locator.dart';
import '../../../services/ride_service.dart';
// lib/screens/trip/finding_driver.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:leisureryde/app/service_locator.dart';
import '../../../services/ride_service.dart'; // Adjust path if needed

class FindingDriverCard extends StatefulWidget {
  final String rideId; // <-- ADDED THIS PARAMETER
  final VoidCallback onCancel;

  const FindingDriverCard({
    super.key,
    required this.rideId, // <-- MARKED AS REQUIRED
    required this.onCancel,
  });

  @override
  State<FindingDriverCard> createState() => _FindingDriverCardState();
}

class _FindingDriverCardState extends State<FindingDriverCard> {
  final RideService _rideService = locator<RideService>();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _driverAccepted = false;

  @override
  void initState() {
    super.initState();
    // Start listening to the ride status when the card is active
    _listenToRideStatus();
  }

  void _listenToRideStatus() {
    if (widget.rideId.isNotEmpty) {
      _sub = _rideService.getRideStream(widget.rideId).listen((snapshot) {
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          final status = data['status'] as String;
          if (status == 'accepted' && !_driverAccepted) {
            setState(() {
              _driverAccepted = true;
            });
            // HomeViewModel will handle the step change to activeTrip
          }
          // You might also want to handle 'cancelled' or 'failed' statuses here
        }
      }, onError: (error) {
        debugPrint("Error listening to ride status in FindingDriverCard: $error");
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 20),
            decoration: BoxDecoration(
              color: theme.dividerColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          SpinKitPulse(color: theme.primaryColor, size: 90),
          const SizedBox(height: 24),
          Text(
            _driverAccepted
                ? "Driver found! Connecting..."
                : "Finding your driver...",
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _driverAccepted
                ? "Please wait while we finalize your trip."
                : "Please wait while we match you to a nearby driver.",
            style: theme.textTheme.bodyMedium?.copyWith(
                color:
                theme.textTheme.bodySmall?.color?.withOpacity(0.8)),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor:
              theme.colorScheme.errorContainer.withOpacity(0.25),
              foregroundColor: theme.colorScheme.error,
              minimumSize: const Size(double.infinity, 50),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: widget.onCancel,
            child: const Text(
              "Cancel Ride",
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}