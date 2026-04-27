import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../services/trip_eta_service.dart';

class TripEndTimer extends StatefulWidget {
  final LatLng? destination;
  final Stream<LatLng>? driverLocationStream;
  final VoidCallback? onTripAlmostEnded;

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
  bool _isLoading = true;
  Timer? _refreshTimer;
  Timer? _countdownTimer;
  StreamSubscription<LatLng>? _locationSub;
  LatLng? _lastKnownDriverLocation;

  @override
  void initState() {
    super.initState();
    _listenToDriverLocation();
    _startPeriodicRefresh();
  }

  void _listenToDriverLocation() {
    _locationSub = widget.driverLocationStream?.listen((newLocation) async {
      _lastKnownDriverLocation = newLocation;
      await _updateETA(newLocation);
    });
  }

  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 20), (_) async {
      if (_lastKnownDriverLocation != null) {
        await _updateETA(_lastKnownDriverLocation!);
      }
    });
  }

  // Counts down _timeLeft every second between API refreshes so the
  // display doesn't appear frozen between GPS/ETA updates.
  void _startCountdown() {
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      if (_timeLeft > 0) setState(() => _timeLeft--);
    });
  }

  Future<void> _updateETA(LatLng currentLocation) async {
    final result = await TripETAService.getRemainingTimeAndDistance(
      currentDriverLocation: currentLocation,
      destination: widget.destination,
    );

    if (!mounted) return;

    if (result['status'] == 'OK') {
      setState(() {
        _timeLeft = result['remainingTimeSeconds'] as int;
        _distanceMiles = result['remainingDistanceMiles'] as double;
        _isNearDestination = _timeLeft < 300;
        _isLoading = false;
      });

      _startCountdown();

      if (_timeLeft < 180 && widget.onTripAlmostEnded != null) {
        widget.onTripAlmostEnded!();
      }
    }
  }

  String _formatTime(int seconds) {
    if (seconds <= 0) return "0:00";
    final min = seconds ~/ 60;
    final sec = seconds % 60;
    return '$min:${sec.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    _countdownTimer?.cancel();
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade100,
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.blue.shade700,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Text(
              "Calculating ETA...",
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
                color: Colors.grey.shade600,
              ),
            ),
          ],
        ),
      );
    }

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
              Text(
                "${_distanceMiles.toStringAsFixed(1)} mi",
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ],
      ),
    );
  }
}