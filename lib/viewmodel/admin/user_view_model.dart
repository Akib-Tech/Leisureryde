import 'package:flutter/material.dart';
import 'package:leisureryde/models/user_profile.dart';
import 'package:leisureryde/services/admin_service.dart';

class UsersViewModel extends ChangeNotifier {
  final AdminService _adminService = AdminService();

  bool _isLoading = true;
  bool get isLoading => _isLoading;

  List<UserProfile> _users = [];
  List<UserProfile> get users => _users;

  UsersViewModel() {
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    _isLoading = true;
    notifyListeners();
    try {
      _users = await _adminService.getUsers();
    } catch (e) {
      print("Error fetching users: $e");
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
    } catch (e) {
      print("Error updating user block status: $e");
    }
  }
}