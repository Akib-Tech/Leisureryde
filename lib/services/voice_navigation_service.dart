import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'directions_service.dart';

/// Manages turn-by-turn voice announcements during an active trip.
///
/// Sits entirely on top of the existing map/route stack — it reads the
/// [RouteStep] list produced by [DirectionsService] and speaks via TTS
/// when the driver approaches each maneuver. Nothing in [MapViewModel] or
/// the polyline rendering is touched by this service.
class VoiceNavigationService {
  final FlutterTts _tts = FlutterTts();

  List<RouteStep> _steps = [];

  // End-location of the step we are currently tracking so we can tell when
  // route recalculations advance us to a different maneuver.
  LatLng? _trackedEndLocation;

  bool _is300mSpoken = false;
  bool _is50mSpoken = false;
  bool _is15mSpoken = false;
  bool _isApproachingDestinationSpoken = false;
  bool _isArrivedAtDestinationSpoken = false;

  // Guards the initial "Starting navigation …" announcement.
  bool _startAnnounced = false;

  // Live distance to the next maneuver — updated on every GPS tick.
  int _distanceToNextTurnMeters = 0;

  // Route polyline used for off-route detection.
  List<LatLng> _polylinePoints = [];
  bool _deviationSpoken = false;
  bool _announceNextRefresh = false;

  /// The step currently being navigated (first in the remaining list).
  RouteStep? get currentStep => _steps.isNotEmpty ? _steps.first : null;

  /// The first step in the list that carries a real maneuver (turn/uturn/etc).
  /// Used by the navigation banner to show the correct direction icon and
  /// instruction even when the active step is a straight/head segment.
  RouteStep? get nextManeuverStep {
    for (final step in _steps) {
      if (step.maneuver != null) return step;
    }
    return _steps.isNotEmpty ? _steps.first : null;
  }

  /// Metres remaining until the next maneuver. Updated on every GPS tick.
  int get distanceToNextTurnMeters => _distanceToNextTurnMeters;

  bool _isEnabled = true;
  bool get isEnabled => _isEnabled;

  VoiceNavigationService() {
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage('en-US');
    await _tts.setSpeechRate(0.45);
    await _tts.setVolume(1.0);
    await _tts.setPitch(1.0);
  }

  // ---------------------------------------------------------------------------
  // Public API called by DriverHomeViewModel
  // ---------------------------------------------------------------------------

  /// Updates the route polyline used for off-route detection.
  /// Call this every time a new route is calculated, before [beginNewRoute]
  /// or [refreshSteps].
  void setPolyline(List<LatLng> points) {
    _polylinePoints = points;
    _deviationSpoken = false;
  }

  /// Called once when a brand-new route begins (new ride, or status changes
  /// from accepted → ongoing which means a different destination).
  Future<void> beginNewRoute(List<RouteStep> steps) async {
    _steps = steps;
    _startAnnounced = false;
    _is300mSpoken = false;
    _is50mSpoken = false;
    _is15mSpoken = false;
    _isApproachingDestinationSpoken = false;
    _isArrivedAtDestinationSpoken = false;
    _announceNextRefresh = false;
    _deviationSpoken = false;
    _distanceToNextTurnMeters = steps.isNotEmpty ? steps.first.distanceMeters : 0;
    _trackedEndLocation = steps.isNotEmpty ? steps.first.endLocation : null;

    if (!_isEnabled || steps.isEmpty) return;

    final first = steps.first;
  /*  await _speak(
      'Starting navigation. '
      'Head onto ${_formatDistance(first.distanceMeters)}, ${first.instruction}.',
    );*/
    _startAnnounced = true;

    // Mark thresholds already covered so we don't double-announce.
    if (first.distanceMeters <= 300) _is300mSpoken = true;
    if (first.distanceMeters <= 50) _is50mSpoken = true;
  }

  /// Called on every route recalculation (same ride, same status — just the
  /// driver has moved ~30 m). Steps are updated without resetting spoken flags
  /// unless the first maneuver has genuinely changed.
  Future<void> refreshSteps(List<RouteStep> steps) async {
    if (steps.isEmpty) {
      _steps = steps;
      return;
    }

    final newTarget = steps.first.endLocation;

    // If the closest maneuver's waypoint is more than 50 m away from what we
    // were tracking, the driver has passed the old turn — reset for the new one.
    if (_trackedEndLocation != null &&
        _metersApart(_trackedEndLocation!, newTarget) > 50) {
      _is300mSpoken = false;
      _is50mSpoken = false;
      _is15mSpoken = false;
      _trackedEndLocation = newTarget;
    }

    _steps = steps;

    // If the driver went off-route and we flagged a refresh announcement,
    // speak the updated first instruction now.
    if (_announceNextRefresh && _isEnabled) {
      _announceNextRefresh = false;
      final first = nextManeuverStep ?? steps.first;
      await _speak(
        'Route updated. In ${_formatDistance(steps.first.distanceMeters)}, '
        '${first.instruction}.',
      );
    }
  }

  /// Called on every driver GPS tick. Triggers voice announcements when the
  /// driver is 300 m or 50 m from the next maneuver, and detects off-route
  /// deviation.
  Future<void> onPositionUpdate(LatLng position) async {
    if (!_isEnabled || _steps.isEmpty) return;

    final step = _steps.first;
    final dist = _metersApart(position, step.endLocation);

    // Update live distance counter for the banner widget.
    _distanceToNextTurnMeters = dist.round();

    // Off-route detection — check if driver has strayed > 100 m from the
    // calculated polyline. Announce once; the ViewModel will recalculate and
    // call refreshSteps which then announces the updated route.
    if (_polylinePoints.isNotEmpty) {
      final distToRoute = _minDistanceToPolyline(position);
      if (distToRoute > 100 && !_deviationSpoken) {
        _deviationSpoken = true;
        _announceNextRefresh = true;
        await _speak('You have left the route. Recalculating.');
        return;
      }
      // Back on route — reset so the next deviation can be announced.
      if (distToRoute < 50) _deviationSpoken = false;
    }

    // Initial announcement if beginNewRoute hasn't fired yet
    // (can happen if steps arrive before the first GPS tick).
    if (!_startAnnounced) {
      _startAnnounced = true;
      await _speak(
        'In ${_formatDistance(step.distanceMeters)}, ${step.instruction}.',
      );
      if (step.distanceMeters <= 300) _is300mSpoken = true;
      if (step.distanceMeters <= 50) _is50mSpoken = true;
      if (step.distanceMeters <= 15) _is15mSpoken = true;
      return;
    }

    // On the final step, warn the driver they are near the destination so they
    // can prepare to end the trip before tapping the button.
    if (_steps.length == 1 && dist <= 100 && !_isApproachingDestinationSpoken) {
      _isApproachingDestinationSpoken = true;
      await _speak('You are approaching your destination. Please prepare to end the trip.');
      return;
    }

    // On the final step, announce exact arrival so the driver knows to end trip.
    if (_steps.length == 1 && dist <= 15 && !_isArrivedAtDestinationSpoken) {
      _isArrivedAtDestinationSpoken = true;
      _is15mSpoken = true;
      await _speak('You have arrived at your destination.');
      return;
    }

    // At-turn cue — spoken right as the driver reaches the maneuver.
    if (dist <= 15 && !_is15mSpoken) {
      _is15mSpoken = true;
      await _speak(step.instruction);
      return;
    }

    if (dist <= 50 && !_is50mSpoken) {
      _is50mSpoken = true;
      await _speak('Now, ${step.instruction}.');
      return;
    }

    if (dist <= 300 && !_is300mSpoken) {
      _is300mSpoken = true;
      await _speak('In ${_formatDistance(dist.round())}, ${step.instruction}.');
    }
  }

  /// Speak a final arrival message when the trip is completed.
  Future<void> announceArrival() async {
    if (!_isEnabled) return;
    await _speak('You have arrived at your destination.');
    _steps = [];
  }

  void toggle() {
    _isEnabled = !_isEnabled;
    if (!_isEnabled) _tts.stop();
    debugPrint('VoiceNavigation: ${_isEnabled ? "enabled" : "disabled"}');
  }

  Future<void> testSpeak() async {
    await _speak(
      'LeisureRyde navigation is ready. '
      'In 0.2 miles, turn right onto Main Street.',
    );
  }

  /// Speak any one-off status announcement (e.g. ride accepted, arrived, trip started).
  Future<void> announce(String text) => _speak(text);

  Future<void> dispose() async {
    await _tts.stop();
  }

  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  Future<void> _speak(String text) async {
    if (!_isEnabled) return;
    await _tts.stop();
    await _tts.speak(text);
  }

  String _formatDistance(int meters) {
    if (meters <= 0) return '0.1 miles';
    final miles = meters * 0.000621371;
    final milesStr = miles >= 0.1
        ? miles.toStringAsFixed(1)
        : miles.toStringAsFixed(2);
    return '$milesStr ${milesStr == '1.0' ? 'mile' : 'miles'}';
  }

  double _minDistanceToPolyline(LatLng position) {
    double min = double.infinity;
    for (final point in _polylinePoints) {
      final d = _metersApart(position, point);
      if (d < min) min = d;
    }
    return min == double.infinity ? 0 : min;
  }

  double _metersApart(LatLng a, LatLng b) {
    const r = 6371000.0;
    final lat1 = a.latitude * math.pi / 180;
    final lat2 = b.latitude * math.pi / 180;
    final dLat = (b.latitude - a.latitude) * math.pi / 180;
    final dLon = (b.longitude - a.longitude) * math.pi / 180;
    final sinLat = math.sin(dLat / 2);
    final sinLon = math.sin(dLon / 2);
    final aa =
        sinLat * sinLat + math.cos(lat1) * math.cos(lat2) * sinLon * sinLon;
    return r * 2 * math.atan2(math.sqrt(aa), math.sqrt(1 - aa));
  }
}
