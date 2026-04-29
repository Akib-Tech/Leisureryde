import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';

class DriverLocationUpdater {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String driverId;

  StreamSubscription<LocationData>? _locationSub;

  DriverLocationUpdater(this.driverId);

  Future<void> start() async {
    final location = Location();

    bool perm = await location.requestPermission() == PermissionStatus.granted;
    if (!perm) return;

    // Navigation accuracy for ride-sharing: high precision, update every 3 s,
    // only when the driver has moved at least 5 m (avoids pointless Firestore writes).
    await location.changeSettings(
      accuracy: LocationAccuracy.navigation,
      interval: 3000,
      distanceFilter: 5,
    );

    _locationSub = location.onLocationChanged.listen((loc) {
      if (loc.latitude == null || loc.longitude == null) return;
      _db.collection('drivers').doc(driverId).set({
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'heading': loc.heading ?? 0.0,
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> stop() async {
    await _locationSub?.cancel();
    _locationSub = null;
    // Mark driver as offline in the live-location collection so they disappear
    // from passengers' maps immediately.
    try {
      await _db.collection('drivers').doc(driverId).set(
        {'isOnline': false, 'updatedAt': FieldValue.serverTimestamp()},
        SetOptions(merge: true),
      );
    } catch (_) {}
  }
}
