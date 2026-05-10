import 'package:flutter/material.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/admin_service.dart';
import 'package:leisureryde/services/fare_calculation_service.dart';

class DriverEarningSummary {
  final String driverId;
  final String driverName;
  final int totalRides;
  final double totalEarnings;

  DriverEarningSummary({
    required this.driverId,
    required this.driverName,
    required this.totalRides,
    required this.totalEarnings,
  });
}

class DriverEarningsViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<DriverEarningSummary> _earnings = [];
  List<DriverEarningSummary> get earnings => _earnings;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  DriverEarningsViewModel() {
    fetchEarnings();
  }

  Future<void> fetchEarnings() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final results = await Future.wait([
        _adminService.getCompletedRides(),
        _adminService.getDrivers(),
      ]);
      final rides = results[0] as List<RideRequest>;
      final drivers = results[1] as List<DriverProfile>;
      final driverNames = {for (final d in drivers) d.uid: d.fullName};
      _earnings = _processRidesToEarnings(rides, driverNames);
    } catch (e) {
      _errorMessage = "Error fetching driver earnings: $e";
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<DriverEarningSummary> _processRidesToEarnings(
    List<RideRequest> rides,
    Map<String, String> driverNames,
  ) {
    final Map<String, List<RideRequest>> ridesByDriver = {};
    for (final ride in rides) {
      if (ride.driverId != null && ride.driverId!.isNotEmpty) {
        (ridesByDriver[ride.driverId!] ??= []).add(ride);
      }
    }

    final List<DriverEarningSummary> summaries = [];
    ridesByDriver.forEach((driverId, driverRides) {
      if (driverRides.isNotEmpty) {
        // Prefer driverName on the ride; fall back to the driver profile lookup
        final name = (driverRides.first.driverName?.isNotEmpty == true)
            ? driverRides.first.driverName!
            : driverNames[driverId] ?? 'Unknown Driver';

        final totalEarnings = driverRides.fold<double>(
          0,
          (sum, ride) => sum + ride.fare * FareCalculationService.driverShareRate,
        );
        summaries.add(DriverEarningSummary(
          driverId: driverId,
          driverName: name,
          totalRides: driverRides.length,
          totalEarnings: totalEarnings,
        ));
      }
    });

    summaries.sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));
    return summaries;
  }
}
