import 'package:flutter/material.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/admin_service.dart';

class DriverStats {
  final int trips;
  final double rating; // 0.0 means no rated rides yet

  DriverStats({required this.trips, required this.rating});
}

class DriversViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<DriverProfile> _drivers = [];
  Map<String, DriverStats> _stats = {};
  Map<String, DriverStats> get stats => _stats;

  String _searchQuery = '';

  List<DriverProfile> get filteredDrivers {
    if (_searchQuery.isEmpty) return _drivers;
    final q = _searchQuery.toLowerCase();
    return _drivers.where((d) =>
      d.fullName.toLowerCase().contains(q) ||
      d.email.toLowerCase().contains(q) ||
      d.phone.contains(q),
    ).toList();
  }

  DriversViewModel() {
    fetchDrivers();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchDrivers() async {
    _isLoading = true;
    notifyListeners();
    try {
      final results = await Future.wait([
        _adminService.getDrivers(),
        _adminService.getCompletedRides(),
      ]);
      _drivers = results[0] as List<DriverProfile>;
      _stats = _computeStats(results[1] as List<RideRequest>);
    } catch (e) {
      debugPrint('Error fetching drivers: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Map<String, DriverStats> _computeStats(List<RideRequest> rides) {
    final Map<String, List<RideRequest>> byDriver = {};
    for (final r in rides) {
      if (r.driverId != null && r.driverId!.isNotEmpty) {
        (byDriver[r.driverId!] ??= []).add(r);
      }
    }
    return byDriver.map((id, driverRides) {
      final trips = driverRides.length;
      final rated = driverRides
          .where((r) => r.driverRating != null && r.driverRating! > 0)
          .toList();
      final avgRating = rated.isEmpty
          ? 0.0
          : rated.fold<double>(0, (s, r) => s + r.driverRating!) / rated.length;
      return MapEntry(id, DriverStats(trips: trips, rating: avgRating));
    });
  }

  Future<void> updateDriverApproval(String driverId, bool isApproved) async {
    try {
      await _adminService.updateDriverApprovalStatus(driverId, isApproved);
      final index = _drivers.indexWhere((d) => d.uid == driverId);
      if (index != -1) {
        _drivers[index] = _drivers[index].copyWith(isApproved: isApproved);
        notifyListeners();
      }
    } catch (e) {}
  }

  Future<void> updateDriverBlockStatus(String driverId, bool isBlocked) async {
    try {
      await _adminService.updateUserBlockStatus(driverId, isBlocked);
      final index = _drivers.indexWhere((d) => d.uid == driverId);
      if (index != -1) {
        _drivers[index] = _drivers[index].copyWith(isBlocked: isBlocked);
        notifyListeners();
      }
    } catch (e) {}
  }
}
