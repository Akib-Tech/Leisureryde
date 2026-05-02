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

  // Guards the initial "Starting navigation …" announcement.
  bool _startAnnounced = false;

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

  /// Called once when a brand-new route begins (new ride, or status changes
  /// from accepted → ongoing which means a different destination).
  Future<void> beginNewRoute(List<RouteStep> steps) async {
    _steps = steps;
    _startAnnounced = false;
    _is300mSpoken = false;
    _is50mSpoken = false;
    _trackedEndLocation = steps.isNotEmpty ? steps.first.endLocation : null;

    if (!_isEnabled || steps.isEmpty) return;

    final first = steps.first;
    await _speak(
      'Starting navigation. '
      'In ${_formatDistance(first.distanceMeters)}, ${first.instruction}.',
    );
    _startAnnounced = true;

    // Mark thresholds already covered so we don't double-announce.
    if (first.distanceMeters <= 300) _is300mSpoken = true;
    if (first.distanceMeters <= 50) _is50mSpoken = true;
  }

  /// Called on every route recalculation (same ride, same status — just the
  /// driver has moved ~30 m). Steps are updated without resetting spoken flags
  /// unless the first maneuver has genuinely changed.
  void refreshSteps(List<RouteStep> steps) {
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
      _trackedEndLocation = newTarget;
    }

    _steps = steps;
  }

  /// Called on every driver GPS tick. Triggers voice announcements when the
  /// driver is 300 m or 50 m from the next maneuver.
  Future<void> onPositionUpdate(LatLng position) async {
    if (!_isEnabled || _steps.isEmpty) return;

    final step = _steps.first;
    final dist = _metersApart(position, step.endLocation);

    // Initial announcement if beginNewRoute hasn't fired yet
    // (can happen if steps arrive before the first GPS tick).
    if (!_startAnnounced) {
      _startAnnounced = true;
      await _speak(
        'In ${_formatDistance(step.distanceMeters)}, ${step.instruction}.',
      );
      if (step.distanceMeters <= 300) _is300mSpoken = true;
      if (step.distanceMeters <= 50) _is50mSpoken = true;
      return;
    }

    if (dist <= 50 && !_is50mSpoken) {
      _is50mSpoken = true;
      await _speak(step.instruction);
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
      'In 300 meters, turn right onto Main Street.',
    );
  }

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
    if (meters >= 1000) {
      return '${(meters / 1000.0).toStringAsFixed(1)} kilometers';
    }
    if (meters <= 0) return '50 meters';
    // Round to the nearest 50 m for natural speech.
    final rounded = ((meters / 50).round() * 50).clamp(50, 950);
    return '$rounded meters';
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
