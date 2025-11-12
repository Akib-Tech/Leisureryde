import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/admin_service.dart';

class UserRideHistoryViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();
  final String? userId;
  final String? driverId;

  UserRideHistoryViewModel({this.userId, this.driverId}) {
    fetchRides();
  }

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  Map<String, List<RideRequest>> _groupedRides = {};
  Map<String, List<RideRequest>> get groupedRides => _groupedRides;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Future<void> fetchRides() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      List<RideRequest> rides = [];
      if (userId != null) {
        rides = await _adminService.getRidesForUser(userId!);
      } else if (driverId != null) {
        rides = await _adminService.getRidesForDriver(driverId!);
      }
      _groupRidesByMonth(rides);
    } catch (e) {
      _errorMessage = "Error fetching ride history: $e";
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _groupRidesByMonth(List<RideRequest> rides) {
    final newGroupedRides = <String, List<RideRequest>>{};
    for (final ride in rides) {
      final monthKey = DateFormat('MMMM yyyy').format(ride.createdAt);
      (newGroupedRides[monthKey] ??= []).add(ride);
    }
    _groupedRides = newGroupedRides;
  }
}