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
        .where('status', whereIn: ['pending','scheduled'],)
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

  Future<void> acceptRide(
    String rideId,
    String driverId, {
    String? driverName,
    String? driverPhone,
  }) async {
    await _db.collection('rideRequests').doc(rideId).update({
      'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (driverPhone != null) 'driverPhone': driverPhone,
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }


// ============================================================
  // ADVANCE TO NEXT WAYPOINT (NEW)
  // ============================================================
  Future<bool> advanceToNextWaypoint(String rideId) async {
    try {
      final docRef = _db.collection('rideRequests').doc(rideId);
      final doc = await docRef.get();

      if (!doc.exists) return false;

      final data = doc.data()!;
      final currentIndex = (data['currentWaypointIndex'] as num?)?.toInt() ?? -1;

      final nextIndex = currentIndex + 1;

      await docRef.update({
        'currentWaypointIndex': nextIndex,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      print("✅ Advanced to waypoint index: $nextIndex");
      return true;
    } catch (e) {
      print("❌ Error advancing waypoint: $e");
      return false;
    }
  }
  

  Future<void> declineRide(String rideId) async {
    try {
      await _db.collection('rideRequests').doc(rideId).update({
        'status': 'declined',
        'declinedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
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
      print("Error message: ${e.toString()}");
      //rethrow;
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
      print("Error Message: ${e.toString()}");
     // rethrow;
    }
  }

  // ============================================================
  // RATING
  // ============================================================

  Future<void> submitTip({
    required String rideId,
    required double tipAmount,
  }) async {
    await _db.collection('rideRequests').doc(rideId).update({
      'tipAmount': tipAmount,
      'tippedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Writes the driver rating to the ride document and updates the driver's
  /// rolling average rating in the users collection.
  Future<void> submitDriverRating({
    required String rideId,
    required String driverId,
    required double rating,
  }) async {
    await _db.collection('rideRequests').doc(rideId).update({
      'driverRating': rating,
      'ratedAt': FieldValue.serverTimestamp(),
    });

    await _db.runTransaction((tx) async {
      final driverRef = _db.collection('users').doc(driverId);
      final driverDoc = await tx.get(driverRef);
      if (!driverDoc.exists) return;
      final currentRating =
          (driverDoc.data()?['rating'] as num?)?.toDouble() ?? 5.0;
      final ratingCount =
          (driverDoc.data()?['ratingCount'] as num?)?.toInt() ?? 0;
      final newCount = ratingCount + 1;
      final newRating =
          ((currentRating * ratingCount) + rating) / newCount;
      tx.update(driverRef, {
        'rating': double.parse(newRating.toStringAsFixed(2)),
        'ratingCount': newCount,
      });
    });
  }

  // ============================================================
  // HELPER: Cancelled listener cleanup
  // ============================================================

  Future<void> removeRide(String rideId) async {
    try {
      await _db.collection('rideRequests').doc(rideId).delete();
    } catch (e) {
      rethrow;
    }
  }
}