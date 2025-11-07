
import 'package:flutter/material.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/services/admin_service.dart';

class DriversViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<DriverProfile> _drivers = [];
  List<DriverProfile> get drivers => _drivers;

  DriversViewModel() {
    fetchDrivers();
  }

  Future<void> fetchDrivers() async {
    _isLoading = true;
    notifyListeners();
    try {
      _drivers = await _adminService.getDrivers();
    } catch (e) {
      print("Error fetching drivers: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateDriverApproval(String driverId, bool isApproved) async {
    try {
      await _adminService.updateDriverApprovalStatus(driverId, isApproved);
      final index = _drivers.indexWhere((d) => d.uid == driverId);
      if (index != -1) {
        _drivers[index] = _drivers[index].copyWith(isApproved: isApproved);
        notifyListeners();
      }
    } catch (e) {
      print("Error updating driver approval: $e");
    }
  }
}