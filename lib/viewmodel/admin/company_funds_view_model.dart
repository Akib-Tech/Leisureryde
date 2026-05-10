import 'package:flutter/material.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/admin_service.dart';
import 'package:leisureryde/services/fare_calculation_service.dart';

enum DateFilter { allTime, thisMonth, lastMonth, custom }

class CompanyFundsViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  List<RideRequest> _completedRides = [];

  DateFilter _selectedFilter = DateFilter.allTime;
  DateFilter get selectedFilter => _selectedFilter;

  DateTime? _customStart;
  DateTime? _customEnd;
  DateTime? get customStart => _customStart;
  DateTime? get customEnd => _customEnd;

  List<RideRequest> get filteredRides {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case DateFilter.allTime:
        return _completedRides;
      case DateFilter.thisMonth:
        return _completedRides
            .where((r) => r.createdAt.year == now.year && r.createdAt.month == now.month)
            .toList();
      case DateFilter.lastMonth:
        final lastMonth = DateTime(now.year, now.month - 1);
        return _completedRides
            .where((r) => r.createdAt.year == lastMonth.year && r.createdAt.month == lastMonth.month)
            .toList();
      case DateFilter.custom:
        if (_customStart == null || _customEnd == null) return _completedRides;
        final endOfDay = DateTime(_customEnd!.year, _customEnd!.month, _customEnd!.day, 23, 59, 59);
        return _completedRides
            .where((r) => !r.createdAt.isBefore(_customStart!) && !r.createdAt.isAfter(endOfDay))
            .toList();
    }
  }

  double get totalRevenue => filteredRides.fold(0, (sum, r) => sum + r.fare);
  double get companyShare => totalRevenue * (1 - FareCalculationService.driverShareRate);
  double get driverPayouts => totalRevenue * FareCalculationService.driverShareRate;
  int get totalCompletedRides => filteredRides.length;

  bool get hasRides => _completedRides.isNotEmpty;

  CompanyFundsViewModel() {
    fetchFunds();
  }

  Future<void> fetchFunds() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _completedRides = await _adminService.getCompletedRides();
    } catch (e) {
      _errorMessage = "Error fetching company funds: $e";
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void setFilter(DateFilter filter) {
    _selectedFilter = filter;
    notifyListeners();
  }

  void setCustomRange(DateTime start, DateTime end) {
    _customStart = start;
    _customEnd = end;
    _selectedFilter = DateFilter.custom;
    notifyListeners();
  }
}
