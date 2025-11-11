import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:leisureryde/viewmodel/home/home_view_model.dart'; // --- ADDED ---
import 'package:provider/provider.dart'; // --- ADDED ---

class FindingDriverCard extends StatefulWidget {
  // --- REMOVED ---
  // The card no longer needs to receive the rideId.
  // final String rideId;

  final VoidCallback onCancel;

  const FindingDriverCard({
    super.key,
    // required this.rideId, // <-- REMOVED
    required this.onCancel,
  });

  @override
  State<FindingDriverCard> createState() => _FindingDriverCardState();
}

class _FindingDriverCardState extends State<FindingDriverCard> {
  // --- REMOVED ---
  // The HomeViewModel is now the single source of truth for the ride status,
  // so this card doesn't need its own listener or state.
  // final RideService _rideService = locator<RideService>();
  // StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  // bool _driverAccepted = false;

  @override
  void initState() {
    super.initState();


  }

  // --- REMOVED ---
  // The listener logic is now centralized in the HomeViewModel.
  // void _listenToRideStatus() { ... }

  @override
  void dispose() {
    // _sub?.cancel(); // No longer needed
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
            // --- SIMPLIFIED ---
            // The card's only job is finding a driver. When one is found,
            // the HomeViewModel will change the step and this card will be
            // replaced by the ActiveTripCard.
            "Finding your driver...",
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.primaryColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            "Please wait while we match you to a nearby driver.",
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