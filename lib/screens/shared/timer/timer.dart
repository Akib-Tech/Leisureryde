import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/trip_eta_service.dart';

class TripEndTimer extends StatefulWidget {
  final LatLng? destination;                    // fixed from DB
  final Stream<LatLng>? driverLocationStream;   // realtime driver location
  final VoidCallback? onTripAlmostEnded;       // optional callback when < 3 min

  const TripEndTimer({
    super.key,
    required this.destination,
    required this.driverLocationStream,
    this.onTripAlmostEnded,
  });

  @override
  State<TripEndTimer> createState() => _TripEndTimerState();
}

class _TripEndTimerState extends State<TripEndTimer> {
  int _timeLeft = 0;
  double _distanceMiles = 0.0;
  bool _isNearDestination = false;
  Timer? _refreshTimer;
  StreamSubscription<LatLng>? _locationSub;

  @override
  void initState() {
    super.initState();
    _listenToDriverLocation();
    _startPeriodicRefresh();
  }

  void _listenToDriverLocation() {
    _locationSub = widget.driverLocationStream?.listen((newLocation) async {
      await _updateETA(newLocation);
    });
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      // Fallback refresh in case stream is slow
      if (_locationSub == null) return;
    });
  }

  Future<void> _updateETA(LatLng currentLocation) async {
    final result = await TripETAService.getRemainingTimeAndDistance(
      currentDriverLocation: currentLocation,
      destination: widget.destination,
    );

    print("hi $result");
    if (result['status'] == 'OK') {
      setState(() {
        _timeLeft = result['remainingTimeSeconds']  as int;
        _distanceMiles = result['remainingDistanceMiles'] as double;
        _isNearDestination = _timeLeft < 300; // less than 5 minutes
      });

      if (_timeLeft < 180 && widget.onTripAlmostEnded != null) {
        widget.onTripAlmostEnded!(); // e.g., show banner or vibrate
      }
    }
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return "0:01";
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString()}';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isNear = _isNearDestination || _timeLeft < 300;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isNear ? Colors.orange.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isNear ? Colors.orange.shade300 : Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isNear ? Colors.orange.shade100 : Colors.blue.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.access_time_rounded,
              color: isNear ? Colors.orange.shade700 : Colors.blue.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isNear ? "Arriving soon" : "Time until drop-off",
                  style: TextStyle(
                    fontSize: 13,
                    color: isNear ? Colors.orange.shade700 : Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatTime(_timeLeft),
                  style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text("Left", style: TextStyle(fontSize: 12, color: Colors.grey)),
              Text("${_distanceMiles.toStringAsFixed(1)} mi",
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}