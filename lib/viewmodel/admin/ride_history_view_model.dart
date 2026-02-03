import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/admin_service.dart';


class RideHistoryViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<RideRequest> _rides = [];
  Map<String, List<RideRequest>> _groupedRides = {};
  Map<String, List<RideRequest>> get groupedRides => _groupedRides;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  RideHistoryViewModel() {
    fetchRides();
  }

  Future<void> fetchRides() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _rides = await _adminService.getRideRequests();
      _groupRidesByMonth();
    } catch (e) {
      _errorMessage = "Error fetching ride history: $e";
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _groupRidesByMonth() {
    final newGroupedRides = <String, List<RideRequest>>{};
    for (final ride in _rides) {
      // Format date to a "Month Year" string to use as a key
      final monthKey = DateFormat('MMMM yyyy').format(ride.createdAt);
      if (newGroupedRides[monthKey] == null) {
        newGroupedRides[monthKey] = [];
      }
      newGroupedRides[monthKey]!.add(ride);
    }
    _groupedRides = newGroupedRides;
  }
}