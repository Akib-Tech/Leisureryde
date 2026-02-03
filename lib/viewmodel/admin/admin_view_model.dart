// In: lib/viewmodel/admin/admin_dashboard_viewmodel.dart

import 'package:flutter/material.dart';
import 'package:leisureryde/services/admin_service.dart';

class AdminDashboardViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  DashboardSummary? _summary;
  DashboardSummary? get summary => _summary;

  AdminDashboardViewModel() {
    fetchSummary();
  }

  Future<void> fetchSummary() async {
    _isLoading = true;
    notifyListeners();
    try {
      _summary = await _adminService.getDashboardSummary();
    } catch (e) {
      print("Error fetching admin summary: $e");
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}