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

    _locationSub = location.onLocationChanged.listen((loc) {
      if (loc.latitude == null || loc.longitude == null) return;
      _db.collection('drivers').doc(driverId).set({
        'latitude': loc.latitude,
        'longitude': loc.longitude,
        'isOnline': true,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> stop() async {
    await _locationSub?.cancel();
    _locationSub = null;
  }
}