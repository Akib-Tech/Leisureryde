import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'directions_service.dart';

import 'dart:io' show Platform;

/// Manages turn-by-turn voice announcements during an active trip.
///
/// Announcement schedule (per turn):
///   • 50 m  — "Now, turn left onto Oak Street."   (advance warning)
///   • 15 m  — "Turn left onto Oak Street."         (action cue)
///   • arrival — "You have arrived at …"
///
/// Maneuvers treated as silent (no voice, visual banner only):
///   null maneuver (departure/head steps), 'straight', 'turn-slight-left',
///   'turn-slight-right' — these are road curves and drifts, not real turns.
class VoiceNavigationService {
  final FlutterTts _tts = FlutterTts();

  List<RouteStep> _steps = [];

  // Maneuvers that produce no voice announcement — banner still shows them.
  static const _silentManeuvers = {
    'straight',
    'turn-slight-left',
    'turn-slight-right',
  };

  // End-location of the step we are currently tracking so we can tell when
  // route recalculations advance us to a different maneuver.
  LatLng? _trackedEndLocation;

  bool _is50mSpoken = false;
  bool _is15mSpoken = false;
  bool _isArrivedAtDestinationSpoken = false;

  // Guards the initial departure announcement.
  bool _startAnnounced = false;

  // Live distance to the next real maneuver — updated on every GPS tick.
  int _distanceToNextTurnMeters = 0;

  // Route polyline used for off-route detection.
  List<LatLng> _polylinePoints = [];
  bool _deviationSpoken = false;
  bool _announceNextRefresh = false;

  // Whether the current leg is navigating to the pickup (true) or destination (false).
  bool _isPickupLeg = true;

  /// The step currently being navigated (first in the remaining list).
  RouteStep? get currentStep => _steps.isNotEmpty ? _steps.first : null;

  /// The first step with a genuine turn maneuver (not a drift/straight/departure).
  /// Used by the navigation banner and voice threshold checks.
  RouteStep? get nextManeuverStep {
    for (final step in _steps) {
      if (step.maneuver != null && !_silentManeuvers.contains(step.maneuver)) {
        return step;
      }
    }
    return _steps.isNotEmpty ? _steps.first : null;
  }

  /// Metres remaining until the next real maneuver. Updated on every GPS tick.
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
  /// is backgrounded.
  Future<void> reinitialize() async {
    try {
      await _tts.stop();
      await _initTts();
    } catch (_) {}
  }

  // ---------------------------------------------------------------------------
  // Public API called by DriverHomeViewModel
  // ---------------------------------------------------------------------------

  void setLegContext(bool isPickupLeg) {
    _isPickupLeg = isPickupLeg;
  }

  void setPolyline(List<LatLng> points) {
    _polylinePoints = points;
    _deviationSpoken = false;
  }

  /// Called once when a brand-new route begins (new ride, accepted→ongoing leg
  /// change, or an off-route reroute). Resets announcement flags and speaks the
  /// first upcoming turn so the driver knows what to do next.
  ///
  /// [isRerouting] — true when called after an off-route recalculation.
  /// On reroutes the pickup-leg silence is lifted so the driver still hears the
  /// new direction even when heading to pickup.
  Future<void> beginNewRoute(List<RouteStep> steps, {bool isRerouting = false}) async {
    _steps = steps;
    _startAnnounced = false;
    _is50mSpoken = false;
    _is15mSpoken = false;
    _isArrivedAtDestinationSpoken = false;
    _announceNextRefresh = false;
    _deviationSpoken = false;
    _distanceToNextTurnMeters = steps.isNotEmpty ? steps.first.distanceMeters : 0;
    _trackedEndLocation = steps.isNotEmpty ? steps.first.endLocation : null;

    if (!_isEnabled || steps.isEmpty) return;

    _startAnnounced = true;

    // Pre-suppress thresholds already covered at route start.
    if (steps.first.distanceMeters <= 50) _is50mSpoken = true;

    // Speak the first upcoming real turn when:
    //   • destination leg (always), or
    //   • pickup leg rerouted (the acceptance announcement is long past)
    // Pickup-leg initial route stays silent — acceptance announcement still playing.
    final bool shouldAnnounce = !_isPickupLeg || isRerouting;
    if (shouldAnnounce) {
      double distToFirstTurn = 0;
      for (final s in steps) {
        if (s.maneuver != null && !_silentManeuvers.contains(s.maneuver)) break;
        distToFirstTurn += s.distanceMeters;
      }
      final firstTurn = nextManeuverStep;
      // Only announce if the first real turn is further than 50 m —
      // the 50m/15m cues handle it automatically when very close.
      if (firstTurn != null && distToFirstTurn > 50) {
        await _speak(
          'In ${_formatDistance(distToFirstTurn.round())}, ${firstTurn.instruction}.',
        );
      }
    }
  }

  /// Called on every route recalculation (driver moved ~30 m, same ride/status).
  /// Steps are updated; announcement flags are preserved unless the tracked
  /// maneuver waypoint has genuinely changed (driver passed a turn).
  Future<void> refreshSteps(List<RouteStep> steps) async {
    if (steps.isEmpty) {
      _steps = steps;
      return;
    }

    final newTarget = steps.first.endLocation;

    // Driver has passed the old maneuver — reset for the next one.
    if (_trackedEndLocation != null &&
        _metersApart(_trackedEndLocation!, newTarget) > 50) {
      _is50mSpoken = false;
      _is15mSpoken = false;
      _trackedEndLocation = newTarget;
    }

    _steps = steps;

    // Off-route recalculation: clear the flag silently.
    // The 50m/15m cues will announce the updated turn when the driver is close.
    if (_announceNextRefresh) {
      _announceNextRefresh = false;
    }
  }

  /// Called on every driver GPS tick. Triggers voice announcements at 50 m and
  /// 15 m from the next real maneuver, and detects off-route deviation.
  Future<void> onPositionUpdate(LatLng position) async {
    if (!_isEnabled || _steps.isEmpty) return;

    final step = _steps.first;
    final dist = _metersApart(position, step.endLocation);

    _distanceToNextTurnMeters = _distanceToNextRealManeuver(position);

    // Off-route detection.
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

    // Arrival at the final waypoint of the current leg.
    if (_steps.length == 1 && dist <= 15 && !_isArrivedAtDestinationSpoken) {
      _isArrivedAtDestinationSpoken = true;
      _is15mSpoken = true;
      await _speak(_isPickupLeg
          ? 'You have arrived at the pickup location.'
          : 'You have arrived at your destination.');
      return;
    }

    // Look ahead to the next genuine turn, skipping silent maneuvers.
    final upcomingTurn = nextManeuverStep;
    final int distToTurn = _distanceToNextTurnMeters;

    // Initial fallback — fires if beginNewRoute ran before the first GPS tick.
    if (!_startAnnounced) {
      _startAnnounced = true;
      if (upcomingTurn != null) {
        await _speak('In ${_formatDistance(distToTurn)}, ${upcomingTurn.instruction}.');
        if (distToTurn <= 50) _is50mSpoken = true;
        if (distToTurn <= 15) _is15mSpoken = true;
      }
      return;
    }

    if (upcomingTurn == null) return;

    // 15 m — action cue: speak the turn instruction now.
    if (distToTurn <= 15 && !_is15mSpoken) {
      _is15mSpoken = true;
      await _speak(upcomingTurn.instruction);
      return;
    }

    // 50 m — advance warning: one cue before the turn.
    if (distToTurn <= 50 && !_is50mSpoken) {
      _is50mSpoken = true;
      await _speak('In ${_formatDistance(distToTurn)}, ${upcomingTurn.instruction}.');
    }
  }

  /// Speaks the final arrival announcement when the driver taps "End Trip".
  Future<void> announceArrival() async {
    if (!_isEnabled) return;
    await _speak('You have arrived at your destination.');
    _steps = [];
  }

  /// True when off-route was detected and we need a fresh route immediately.
  /// DriverHomeViewModel reads this to bypass the 30m recalculation throttle.
  bool get needsRouteRefresh => _announceNextRefresh;

  void toggle() {
    _isEnabled = !_isEnabled;
    if (!_isEnabled) _tts.stop();
    debugPrint('VoiceNavigation: ${_isEnabled ? "enabled" : "disabled"}');
  }

  /// Silences voice without changing the user-facing toggle state.
  /// Used when an external nav app (Waze) is opened.
  void mute() {
    _tts.stop();
    _isEnabled = false;
  }

  /// Re-enables voice. Paired with [mute].
  void unmute() {
    _isEnabled = true;
  }

  Future<void> testSpeak() async {
    await _speak(
      'LeisureRyde navigation is ready. '
      'In 0.2 miles, turn right onto Main Street.',
    );
  }

  /// Speak any one-off status announcement (ride accepted, trip started, etc.).
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
    if (_polylinePoints.isEmpty) return 0;
    double min = double.infinity;
    for (int i = 0; i < _polylinePoints.length - 1; i++) {
      final d = _distanceToSegment(position, _polylinePoints[i], _polylinePoints[i + 1]);
      if (d < min) min = d;
    }
    if (min == double.infinity) return _metersApart(position, _polylinePoints.first);
    return min;
  }

  double _distanceToSegment(LatLng p, LatLng a, LatLng b) {
    final dx = b.longitude - a.longitude;
    final dy = b.latitude - a.latitude;
    final len2 = dx * dx + dy * dy;
    if (len2 == 0) return _metersApart(p, a);
    final t = ((p.longitude - a.longitude) * dx + (p.latitude - a.latitude) * dy) / len2;
    final closest = LatLng(
      a.latitude + t.clamp(0.0, 1.0) * dy,
      a.longitude + t.clamp(0.0, 1.0) * dx,
    );
    return _metersApart(p, closest);
  }

  /// Metres from [position] to the nearest step with a real maneuver,
  /// accumulating through silent steps (straight, null, slight turns).
  int _distanceToNextRealManeuver(LatLng position) {
    if (_steps.isEmpty) return 0;
    double dist = _metersApart(position, _steps.first.endLocation);
    final String? m = _steps.first.maneuver;
    if (m != null && !_silentManeuvers.contains(m)) return dist.round();
    for (int i = 1; i < _steps.length; i++) {
      final s = _steps[i];
      final String? sm = s.maneuver;
      if (sm != null && !_silentManeuvers.contains(sm)) return dist.round();
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
