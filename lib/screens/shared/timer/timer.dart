import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';

import '../../../services/trip_eta_service.dart';

/// Shows the estimated total trip time from pickup to destination.
/// The value is fetched once when the trip starts and displayed statically —
/// no countdown, no live driver-location tracking.
class TripEndTimer extends StatefulWidget {
  final LatLng? origin;       // pickup location
  final LatLng? destination;  // drop-off location

  // Kept for call-site compatibility but no longer used by the widget.
  final Stream<LatLng>? driverLocationStream;
  final VoidCallback? onTripAlmostEnded;

  const TripEndTimer({
    super.key,
    required this.origin,
    required this.destination,
    this.driverLocationStream,
    this.onTripAlmostEnded,
  });

  @override
  State<TripEndTimer> createState() => _TripEndTimerState();
}

class _TripEndTimerState extends State<TripEndTimer> {
  int _totalSeconds = 0;
  double _totalMiles = 0.0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchTripDuration();
  }

  Future<void> _fetchTripDuration() async {
    final result = await TripETAService.getRemainingTimeAndDistance(
      currentDriverLocation: widget.origin,
      destination: widget.destination,
    );

    if (!mounted) return;

    if (result['status'] == 'OK') {
      setState(() {
        _totalSeconds = result['remainingTimeSeconds'] as int;
        _totalMiles = result['remainingDistanceMiles'] as double;
        _isLoading = false;
      });
    } else {
      setState(() => _isLoading = false);
    }
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '—';
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '$minutes min';
  }

  String _formatArrivalTime(int seconds) {
    if (seconds <= 0) return '—';
    final arrival = DateTime.now().add(Duration(seconds: seconds));
    return DateFormat('h:mm a').format(arrival);
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
              'Calculating trip duration...',
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
            child: Icon(
              Icons.access_time_rounded,
              color: Colors.blue.shade700,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estimated trip time',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  _formatDuration(_totalSeconds),
                  style: const TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Arriving at ${_formatArrivalTime(_totalSeconds)}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.blue.shade700,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (_totalMiles > 0)
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Text('Distance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                Text(
                  '${_totalMiles.toStringAsFixed(1)} mi',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
