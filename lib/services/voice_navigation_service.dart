import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'directions_service.dart';

// Needed for Platform check
import 'dart:io' show Platform;

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
  bool _isArrivedAtDestinationSpoken = false;

  // Guards the initial "Starting navigation …" announcement.
  bool _startAnnounced = false;

  // Live distance to the next maneuver — updated on every GPS tick.
  int _distanceToNextTurnMeters = 0;

  // Route polyline used for off-route detection.
  List<LatLng> _polylinePoints = [];
  bool _deviationSpoken = false;
  bool _announceNextRefresh = false;

  // Whether the current leg is navigating to the pickup (true) or destination (false).
  bool _isPickupLeg = true;

  /// The step currently being navigated (first in the remaining list).
  RouteStep? get currentStep => _steps.isNotEmpty ? _steps.first : null;

  /// The first step in the list that carries a real maneuver (turn/uturn/etc).
  /// Used by the navigation banner to show the correct direction icon and
  /// instruction even when the active step is a straight/head segment.
  RouteStep? get nextManeuverStep {
    for (final step in _steps) {
      if (step.maneuver != null && step.maneuver != 'straight') return step;
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

    // iOS requires an audio session to be configured so TTS keeps working
    // after the app returns from background (otherwise the AVAudioSession
    // is interrupted and speech is silently dropped).
    if (Platform.isIOS) {
      await _tts.setSharedInstance(true);
      await _tts.setIosAudioCategory(
        IosTextToSpeechAudioCategory.playback,
        [
          IosTextToSpeechAudioCategoryOptions.allowBluetooth,
          IosTextToSpeechAudioCategoryOptions.allowBluetoothA2DP,
          IosTextToSpeechAudioCategoryOptions.mixWithOthers,
        ],
        IosTextToSpeechAudioMode.defaultMode,
      );
    }
  }

  /// Re-applies TTS settings after the app returns from background.
  /// On Android the TTS engine service can be killed by the OS while the app
  /// is backgrounded; calling this on AppLifecycleState.resumed ensures the
  /// engine is available again before the next announcement.
  Future<void> reinitialize() async {
    try {
      await _tts.stop();
      await _initTts();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Public API called by DriverHomeViewModel
  // ---------------------------------------------------------------------------

  /// Sets whether the current navigation leg is heading to the pickup (true)
  /// or the final destination (false). Must be called before [beginNewRoute].
  void setLegContext(bool isPickupLeg) {
    _isPickupLeg = isPickupLeg;
  }

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
    _isArrivedAtDestinationSpoken = false;
    _announceNextRefresh = false;
    _deviationSpoken = false;
    _distanceToNextTurnMeters = steps.isNotEmpty ? steps.first.distanceMeters : 0;
    _trackedEndLocation = steps.isNotEmpty ? steps.first.endLocation : null;

    if (!_isEnabled || steps.isEmpty) return;

    final first = steps.first;
    _startAnnounced = true;

    // Mark thresholds already covered so we don't double-announce.
    if (first.distanceMeters <= 300) _is300mSpoken = true;
    if (first.distanceMeters <= 50) _is50mSpoken = true;

    // For the destination leg, startTrip() has already finished its announcement
    // (it is awaited before _updateStatus fires). Announce the first upcoming turn
    // now so the driver knows immediately what to expect.
    // Pickup leg stays silent here — the acceptance announcement is still playing
    // when beginNewRoute fires (the Directions API call takes ~1-2 s), and calling
    // _speak() would stop() the TTS mid-sentence.
    if (!_isPickupLeg) {
      // Sum the distances of all straight/null-maneuver steps to find how far
      // away the first real turn is from the route start.
      double distToFirstTurn = 0;
      for (final s in steps) {
        if (s.maneuver != null && s.maneuver != 'straight') break;
        distToFirstTurn += s.distanceMeters;
      }
      final firstTurn = nextManeuverStep;
      if (firstTurn != null && distToFirstTurn > 300) {
        await _speak(
          'In ${_formatDistance(distToFirstTurn.round())}, ${firstTurn.instruction}.',
        );
        _is300mSpoken = true; // suppress the automatic 300 m re-announcement
      }
    }
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

    // Banner shows distance to the next REAL maneuver, skipping over any
    // intermediate straight/continue steps.
    _distanceToNextTurnMeters = _distanceToNextRealManeuver(position);

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
      if (distToRoute < 50) _deviationSpoken = false;
    }

    // Always announce arrival at the end of the route regardless of step type.
    if (_steps.length == 1 && dist <= 15 && !_isArrivedAtDestinationSpoken) {
      _isArrivedAtDestinationSpoken = true;
      _is15mSpoken = true;
      await _speak(_isPickupLeg
          ? 'You have arrived at the pickup location.'
          : 'You have arrived at your destination.');
      return;
    }

    // Look ahead through any straight/null steps to find the next real turn.
    // This is the same look-ahead used by the navigation banner (_distanceToNextTurnMeters),
    // applied now to voice so announcements fire even when the current step is straight.
    final upcomingTurn = nextManeuverStep;
    final int distToTurn = _distanceToNextTurnMeters;

    // Initial announcement fallback (fires if beginNewRoute ran before first tick).
    if (!_startAnnounced) {
      _startAnnounced = true;
      if (upcomingTurn != null) {
        await _speak('In ${_formatDistance(distToTurn)}, ${upcomingTurn.instruction}.');
        if (distToTurn <= 300) _is300mSpoken = true;
        if (distToTurn <= 50) _is50mSpoken = true;
        if (distToTurn <= 15) _is15mSpoken = true;
      }
      return;
    }

    if (upcomingTurn == null) return;

    // At-turn cue — spoken right as the driver reaches the maneuver point.
    if (distToTurn <= 15 && !_is15mSpoken) {
      _is15mSpoken = true;
      await _speak(upcomingTurn.instruction);
      return;
    }

    if (distToTurn <= 50 && !_is50mSpoken) {
      _is50mSpoken = true;
      await _speak('Now, ${upcomingTurn.instruction}.');
      return;
    }

    if (distToTurn <= 300 && !_is300mSpoken) {
      _is300mSpoken = true;
      await _speak('In ${_formatDistance(distToTurn)}, ${upcomingTurn.instruction}.');
    }
  }

  /// Speak a final arrival message when the trip is completed.
  Future<void> announceArrival() async {
    if (!_isEnabled) return;
    await _speak('You have arrived at your destination.');
    _steps = [];
  }

  /// True when off-route was detected and we're waiting for a fresh route.
  /// DriverHomeViewModel reads this to force an immediate Directions API call
  /// rather than waiting for the driver to move 30 m.
  bool get needsRouteRefresh => _announceNextRefresh;

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

  /// Returns the shortest distance (metres) from [position] to the polyline,
  /// measured perpendicularly to each segment rather than to individual points.
  /// Point-distance gives large false readings on long straight segments
  /// (e.g. highways), triggering bogus off-route "Recalculating" announcements.
  double _minDistanceToPolyline(LatLng position) {
    if (_polylinePoints.isEmpty) return 0;
    double min = double.infinity;
    for (int i = 0; i < _polylinePoints.length - 1; i++) {
      final d = _distanceToSegment(position, _polylinePoints[i], _polylinePoints[i + 1]);
      if (d < min) min = d;
    }
    // Fall back to the last point when only one point exists.
    if (min == double.infinity) return _metersApart(position, _polylinePoints.first);
    return min;
  }

  /// Perpendicular (or endpoint) distance from [p] to the segment [a]→[b].
  /// Uses a planar Cartesian approximation which is accurate enough for the
  /// short polyline segments produced by the Directions API (< 500 m each).
  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return _metersApart(p, a); // degenerate segment (same point)
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / len2;
    final closest = LatLng(
      a.latitude + t.clamp(0.0, 1.0) * dy,
      a.longitude + t.clamp(0.0, 1.0) * dx,
    );
    return _metersApart(p, closest);
  }

  // Returns metres from [position] to the nearest upcoming step that has a
  // real maneuver (turn, fork, ramp, roundabout, etc.), summing through any
  // intermediate straight/continue steps. Used to keep the banner accurate
  // even when the driver is currently on a straight segment.
  int _distanceToNextRealManeuver(LatLng position) {
    if (_steps.isEmpty) return 0;
    double dist = _metersApart(position, _steps.first.endLocation);
    final String? m = _steps.first.maneuver;
    if (m != null && m != 'straight') return dist.round();
    for (int i = 1; i < _steps.length; i++) {
      final s = _steps[i];
      final String? sm = s.maneuver;
      if (sm != null && sm != 'straight') return dist.round();
      dist += s.distanceMeters;
    }
    return dist.round();
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