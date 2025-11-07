
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/enums.dart';
import '../models/driver_profile.dart';
import '../models/ride_request_model.dart';
import '../models/saved_places.dart';
import '../models/user_profile.dart';

class DatabaseService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
  }) async {
    try {
      await _db.collection('users').doc(uid).set({
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'role': UserRole.user.name,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error creating user profile: $e");
      rethrow;
    }
  }

  Future<void> createDriverProfile({
    required String uid,
    required String firstName,
    required String lastName,
    required String email,
    required String phone,
    required String licenseUrl,
  }) async {
    try {
      await _db.collection('users').doc(uid).set({ // <-- Same 'users' collection
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'phone': phone,
        'licenseUrl': licenseUrl,
        'role': UserRole.driver.name, // <-- Drivers get 'driver' role
        'isApproved': false,
        'isOnline': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print("Error creating driver profile: $e");
      rethrow;
    }
  }

  Future<UserProfile> getUserProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return UserProfile.fromFirestore(doc);
      } else {
        throw Exception("User profile not found!");
      }
    } catch (e) {
      print("Error fetching user profile: $e");
      rethrow;
    }
  }

  Future<DriverProfile> getDriverProfile(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        return DriverProfile.fromFirestore(doc);
      } else {
        throw Exception("Driver profile not found!");
      }
    } catch (e) {
      print("Error fetching driver profile: $e");
      rethrow;
    }
  }


  Future<void> updateDriverOnlineStatus(String uid, bool isOnline) async {
    try {
      final Map<String, dynamic> updateData = {'isOnline': isOnline};

      if (isOnline) {
        updateData['lastWentOnlineAt'] = FieldValue.serverTimestamp();
      }

      await _db.collection('users').doc(uid).update(updateData);
    } catch (e) {
      print("Error updating driver status: $e");
      rethrow;
    }
  }


  Stream<DocumentSnapshot> getDriverLocationStream(String driverId) {
    return _db.collection('drivers').doc(driverId).snapshots();
  }

  Stream<List<DocumentSnapshot>> getTodaysTripsStream(String driverId) {
    final now = DateTime.now();
    final startOfDay = Timestamp.fromDate(DateTime(now.year, now.month, now.day));

    return _db
        .collection('rideRequests')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .where('createdAt', isGreaterThanOrEqualTo: startOfDay)
        .snapshots()
        .map((snapshot) => snapshot.docs);
  }

  Future<void> updateUserProfileData(String uid, Map<String, dynamic> data) async {
    try {
      await _db.collection('users').doc(uid).update(data);
    } catch (e) {
      print("Error updating user profile data: $e");
      rethrow;
    }
  }

  Future<void> deleteUserProfile(String uid) async {
    try {
      await _db.collection('users').doc(uid).delete();
    } catch (e) {
      print("Error deleting user profile from Firestore: $e");
      rethrow;
    }
  }

  Future<List<SavedPlace>> getSavedPlaces(String uid) async {
    try {
      // FIX: Used _db.collection('users') directly instead of undefined variable.
      final snapshot = await _db.collection('users').doc(uid).collection('savedPlaces').get();
      return snapshot.docs.map((doc) => SavedPlace.fromMap(doc.id, doc.data())).toList();
    } catch (e) {
      print("Error getting saved places: $e");
      return [];
    }
  }

  Future<void> addOrUpdateSavedPlace(String uid, SavedPlace place) async {
    try {
      // FIX: Used _db.collection('users') directly.
      await _db.collection('users').doc(uid).collection('savedPlaces').doc(place.name).set(place.toMap());
    } catch (e) {
      print("Error adding/updating saved place: $e");
      rethrow;
    }
  }

  Future<void> deleteSavedPlace(String uid, String placeName) async {
    try {
      // FIX: Used _db.collection('users') directly.
      await _db.collection('users').doc(uid).collection('savedPlaces').doc(placeName).delete();
    } catch (e) {
      print("Error deleting saved place: $e");
      rethrow;
    }
  }

  Future<List<RideDestination>> getRecentDestinations(String uid) async {
    try {
      // Query the 10 most recent completed rides for the user
      final snapshot = await _db
          .collection('rideRequests')
          .where('userId', isEqualTo: uid)
          .where('status', isEqualTo: RideStatus.completed.toString())
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      if (snapshot.docs.isEmpty) {
        return [];
      }

      final rideRequests = snapshot.docs
          .map((doc) => RideRequest.fromFirestore(doc)) // Use your RideRequest model's factory
          .toList();

      // Use a Map to get unique destinations based on address, keeping the most recent
      final Map<String, RideDestination> uniqueDestinations = {};
      for (var ride in rideRequests) {
        // This ensures we only add each address once
        if (!uniqueDestinations.containsKey(ride.destinationAddress)) {
          uniqueDestinations[ride.destinationAddress] = RideDestination(address: ride.destinationAddress,
              latitude: ride.destinationLocation.latitude, longitude: ride.destinationLocation.longitude)
          ;
        }
      }

      // Return the unique destinations, up to a max of 3 for the UI
      return uniqueDestinations.values.take(3).toList();

    } catch (e) {
      print("Error fetching recent destinations: $e");
      return [];
    }
  }

  Future<String?> createRideRequest(RideRequest rideRequest) async {
    try {
      final docRef = await _db.collection('rideRequests').add(rideRequest.toMap());
      return docRef.id; // Return the ID of the new ride document
    } catch (e) {
      print("Error creating ride request: $e");
      rethrow;
    }
  }
  Future<List<RideRequest>> getUpcomingRides(String uid) async {
    try {
      final snapshot = await _db
          .collection('rideRequests')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: ['pending', 'accepted', 'enroute', 'ongoing'])
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) => RideRequest.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching upcoming rides: $e");
      return [];
    }
  }

  Future<List<RideRequest>> getPastRides(String uid) async {
    try {
      final snapshot = await _db
          .collection('rideRequests')
          .where('userId', isEqualTo: uid)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('createdAt', descending: true)
          .limit(20) // Limit to the last 20 past rides for performance
          .get();

      return snapshot.docs.map((doc) => RideRequest.fromFirestore(doc)).toList();
    } catch (e) {
      print("Error fetching past rides: $e");
      return [];
    }
  }

  Stream<QuerySnapshot> getOnlineDriversStream() {
    return _db.collection('drivers').where('isOnline', isEqualTo: true).snapshots();
  }
}