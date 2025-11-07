import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../models/ride_request_model.dart';
import '../models/user_profile.dart';
import 'directions_service.dart';

class RideService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ============================================================
  // CREATE RIDE REQUEST (User)
  // ============================================================
  Future<String> createRideRequest({
    required UserProfile passenger,
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required DirectionsResult route,
    required Map<String, double> fareDetails,
    required String selectedVehicle,
  }) async {
    try {
      final docRef = await _db.collection('rideRequests').add({
        'passengerId': passenger.uid,
        'passengerName': passenger.fullName,
        'passengerRating': passenger.rating > 0 ? passenger.rating : 5.0,
        'pickup': {
          'latitude': pickupLocation.latitude,
          'longitude': pickupLocation.longitude,
        },
        'destination': {
          'latitude': destinationLocation.latitude,
          'longitude': destinationLocation.longitude,
        },
        'pickupAddress': route.startAddress,
        'destinationAddress': route.endAddress,
        'fareDetails': fareDetails,
        'selectedVehicle': selectedVehicle,
        'fare': fareDetails[selectedVehicle],
        'distance': route.distanceValue,
        'duration': route.durationValue,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
        'driverId': null,
      });
      return docRef.id;
    } catch (e) {
      print("🚨 Error creating ride request: $e");
      rethrow;
    }
  }

  // ============================================================
  // REAL‑TIME STREAMS
  // ============================================================

  /// Listen to a single ride document for live status (accepted / cancelled / completed)
  Stream<DocumentSnapshot<Map<String, dynamic>>> getRideStream(String rideId) {
    return _db.collection('rideRequests').doc(rideId).snapshots();
  }

  /// For drivers: listen for all pending rides (simple broadcast)
  Stream<List<RideRequest>> getRideRequestsStream() {
    return _db
        .collection('rideRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (query) =>
          query.docs.map((d) => RideRequest.fromFirestore(d)).toList(),
    );
  }

  // ============================================================
  // DRIVER ACTIONS
  // ============================================================

  Future<void> acceptRide(String rideId, String driverId) async {
    try {
      await _db.collection('rideRequests').doc(rideId).update({
        'driverId': driverId,
        'status': 'accepted',
        'acceptedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("🚨 Error accepting ride: $e");
      rethrow;
    }
  }

  Future<void> declineRide(String rideId) async {
    try {
      await _db.collection('rideRequests').doc(rideId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("🚨 Error declining ride: $e");
      rethrow;
    }
  }

  // ============================================================
  // CANCEL RIDE (User OR Driver)
  // ============================================================

  Future<void> cancelRide(String rideId, {required String cancelledBy}) async {
    try {
      await _db.collection('rideRequests').doc(rideId).update({
        'status':
        cancelledBy == 'driver' ? 'cancelled_by_driver' : 'cancelled',
        'cancelledBy': cancelledBy,
        'cancelledAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("🚨 Error cancelling ride $rideId: $e");
      rethrow;
    }
  }

  // ============================================================
  // GENERIC STATUS UPDATE (enroute, ongoing, completed)
  // ============================================================

  Future<void> updateRideStatus(
      String rideId,
      String newStatus, {
        Map<String, dynamic>? extraFields,
      }) async {
    try {
      final update = <String, dynamic>{
        'status': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (extraFields != null) update.addAll(extraFields);

      await _db.collection('rideRequests').doc(rideId).update(update);
    } catch (e) {
      print("🚨 Error updating ride status: $e");
      rethrow;
    }
  }

  // ============================================================
  // HELPER: Cancelled listener cleanup
  // ============================================================

  Future<void> removeRide(String rideId) async {
    try {
      await _db.collection('rideRequests').doc(rideId).delete();
    } catch (e) {
      print("🚨 Error deleting ride: $e");
      rethrow;
    }
  }
}