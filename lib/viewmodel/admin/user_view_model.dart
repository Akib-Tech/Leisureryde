import 'package:flutter/material.dart';
import 'package:leisureryde/models/user_profile.dart';
import 'package:leisureryde/services/admin_service.dart';

class UsersViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<UserProfile> _users = [];
  String _searchQuery = '';

  List<UserProfile> get filteredUsers {
    if (_searchQuery.isEmpty) return _users;
    final q = _searchQuery.toLowerCase();
    return _users.where((u) =>
      u.fullName.toLowerCase().contains(q) ||
      u.email.toLowerCase().contains(q) ||
      u.phone.contains(q),
    ).toList();
  }

  UsersViewModel() {
    fetchUsers();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      _users = await _adminService.getUsers();
    } catch (e) {
      debugPrint('Error fetching users: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> updateUserBlockStatus(String userId, bool isBlocked) async {
    try {
      await _adminService.updateUserBlockStatus(userId, isBlocked);
      final index = _users.indexWhere((u) => u.uid == userId);
      if (index != -1) {
        _users[index] = _users[index].copyWith(isBlocked: isBlocked);
        notifyListeners();
      }
    } catch (e) {}
  }
}
