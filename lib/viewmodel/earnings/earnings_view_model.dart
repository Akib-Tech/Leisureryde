import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../../app/service_locator.dart';
import '../../models/ride_request_model.dart';
import '../../models/driver_profile.dart';
import '../../services/auth_service.dart';
import '../../services/database_service.dart';

class EarningsViewModel extends ChangeNotifier {
  final _db = FirebaseFirestore.instance;
  final AuthService _authService = locator<AuthService>();
  final DatabaseService _databaseService = locator<DatabaseService>();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  double _totalEarnings = 0.0;
  double get totalEarnings => _totalEarnings;

  int _totalTrips = 0;
  int get totalTrips => _totalTrips;

  double _hoursOnline = 0.0;
  double get hoursOnline => _hoursOnline;

  double _rating = 0.0;
  double get rating => _rating;

  List<RideRequest> _recentTrips = [];
  List<RideRequest> get recentTrips => _recentTrips;

  DriverProfile? _driverProfile;
  DriverProfile? get driverProfile => _driverProfile;

  EarningsViewModel() {
    _initialize();
  }

  Future<void> _initialize() async {
    _isLoading = true;
    notifyListeners();

    try {
      final uid = _authService.currentUser?.uid;
      if (uid == null) {
        _isLoading = false;
        notifyListeners();
        return;
      }

      _driverProfile = await _databaseService.getDriverProfile(uid);
      _rating = _driverProfile?.rating ?? 0.0;

      await _fetchEarnings(uid);
    } catch (e) {
      debugPrint("Error initializing EarningsViewModel: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _fetchEarnings(String driverId) async {
    try {
      // Get all completed trips
      final completed = await _db
          .collection('rideRequests')
          .where('driverId', isEqualTo: driverId)
          .where('status', isEqualTo: 'completed')
          .orderBy('createdAt', descending: true)
          .get();

      _totalTrips = completed.docs.length;
      _totalEarnings = completed.docs.fold(
          0.0, (sum, doc) => sum + (doc['fare'] ?? 0.0) as double);

      // Simple hours logic — based on driver's last online entry
      if (_driverProfile?.lastWentOnlineAt != null) {
        final duration = DateTime.now()
            .difference(_driverProfile!.lastWentOnlineAt!.toDate());
        _hoursOnline = duration.inMinutes / 60.0;
      }

      _recentTrips = completed.docs
          .take(10)
          .map((doc) => RideRequest.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint("Error fetching earnings: $e");
    }
  }

  Future<void> refresh() async {
    final uid = _authService.currentUser?.uid;
    if (uid != null) await _fetchEarnings(uid);
    notifyListeners();
  }
}