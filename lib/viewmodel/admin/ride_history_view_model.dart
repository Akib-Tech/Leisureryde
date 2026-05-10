import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/admin_service.dart';

class RideHistoryViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<RideRequest> _rides = [];
  String _searchQuery = '';

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<String, List<RideRequest>> get groupedRides {
    final source = _searchQuery.isEmpty
        ? _rides
        : _rides.where((r) {
            final q = _searchQuery.toLowerCase();
            return r.passengerName.toLowerCase().contains(q) ||
                (r.driverName?.toLowerCase().contains(q) ?? false) ||
                r.pickupAddress.toLowerCase().contains(q) ||
                r.destinationAddress.toLowerCase().contains(q);
          }).toList();

    final grouped = <String, List<RideRequest>>{};
    for (final ride in source) {
      final key = DateFormat('MMMM yyyy').format(ride.createdAt);
      (grouped[key] ??= []).add(ride);
    }
    return grouped;
  }

  bool get hasRides => _rides.isNotEmpty;

  RideHistoryViewModel() {
    fetchRides();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchRides() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();
    try {
      _rides = await _adminService.getRideRequests();
    } catch (e) {
      _errorMessage = "Error fetching ride history: $e";
      debugPrint(_errorMessage);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
