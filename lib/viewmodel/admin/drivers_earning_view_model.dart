import 'package:flutter/material.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/admin_service.dart';

// A helper class to hold the processed earnings data for one driver
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
      final completedRides = await _adminService.getCompletedRides();
      _earnings = _processRidesToEarnings(completedRides);
    } catch (e) {
      _errorMessage = "Error fetching driver earnings: $e";
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  List<DriverEarningSummary> _processRidesToEarnings(List<RideRequest> rides) {
    final Map<String, List<RideRequest>> ridesByDriver = {};

    // Group rides by driverId
    for (final ride in rides) {
      if (ride.driverId != null && ride.driverId!.isNotEmpty) {
        (ridesByDriver[ride.driverId!] ??= []).add(ride);
      }
    }

    // Calculate summary for each driver
    final List<DriverEarningSummary> summaries = [];
    ridesByDriver.forEach((driverId, driverRides) {
      if (driverRides.isNotEmpty) {
        final totalEarnings = driverRides.fold<double>(0, (sum, ride) => sum + ride.fare);
        summaries.add(
          DriverEarningSummary(
            driverId: driverId,
            driverName: driverRides.first.driverName ?? 'Unknown Driver',
            totalRides: driverRides.length,
            totalEarnings: totalEarnings,
          ),
        );
      }
    });

    // Sort by highest earnings
    summaries.sort((a, b) => b.totalEarnings.compareTo(a.totalEarnings));

    return summaries;
  }
}