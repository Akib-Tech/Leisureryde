import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/models/user_profile.dart';

import '../models/ride_request_model.dart';

class DashboardSummary {
  final int totalUsers;
  final int totalDrivers;
  final int totalRides;
  DashboardSummary({required this.totalUsers, required this.totalDrivers, required this.totalRides});
}

class AdminService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<DashboardSummary> getDashboardSummary() async {
    final usersCountQuery = _db.collection('users').where('role', isEqualTo: 'user').count().get();
    final driversCountQuery = _db.collection('users').where('role', isEqualTo: 'driver').count().get();
    final ridesCountQuery = _db.collection('rideRequests').count().get();

    final results = await Future.wait([usersCountQuery, driversCountQuery, ridesCountQuery]);

    return DashboardSummary(
      totalUsers: results[0].count?? 0,
      totalDrivers: results[1].count?? 0,
      totalRides: results[2].count ?? 0,
    );
  }

  Future<List<UserProfile>> getUsers() async {
    final snapshot = await _db.collection('users').where('role', isEqualTo: 'user').get();
    return snapshot.docs.map((doc) => UserProfile.fromFirestore(doc)).toList();
  }

  Future<List<DriverProfile>> getDrivers() async {
    final snapshot = await _db.collection('users').where('role', isEqualTo: 'driver').get();
    return snapshot.docs.map((doc) => DriverProfile.fromFirestore(doc)).toList();
  }

  Future<void> updateUserBlockStatus(String uid, bool isBlocked) async {
    await _db.collection('users').doc(uid).update({'isBlocked': isBlocked});
  }

  Future<void> updateDriverApprovalStatus(String uid, bool isApproved) async {
    await _db.collection('users').doc(uid).update({'isApproved': isApproved});
  }

  Future<List<RideRequest>> getRideRequests() async {
    final snapshot = await _db.collection('rideRequests').orderBy('createdAt', descending: true).limit(50).get();
    return snapshot.docs.map((doc) => RideRequest.fromFirestore(doc)).toList();
  }

  Future<List<RideRequest>> getCompletedRides() async {
    final snapshot = await _db
        .collection('rideRequests')
        .where('status', isEqualTo: RideStatus.completed.name)
        .get();
    return snapshot.docs.map((doc) => RideRequest.fromFirestore(doc)).toList();
  }
  // ... inside the AdminService class

  // NEW METHOD
  Future<List<RideRequest>> getRidesForUser(String userId) async {
    final snapshot = await _db
        .collection('rideRequests')
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snapshot.docs.map((doc) => RideRequest.fromFirestore(doc)).toList();
  }

  // NEW METHOD
  Future<List<RideRequest>> getRidesForDriver(String driverId) async {
    final snapshot = await _db
        .collection('rideRequests')
        .where('driverId', isEqualTo: driverId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .get();
    return snapshot.docs.map((doc) => RideRequest.fromFirestore(doc)).toList();
  }

// ... rest of the class
}