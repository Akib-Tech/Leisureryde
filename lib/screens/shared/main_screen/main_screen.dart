import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../../../app/enums.dart';
import '../../../services/auth_service.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../driver/earnings/earnings_screen.dart';
import '../../driver/home/driver_home_screen.dart';
import '../../user/home_screen/home_screen.dart';
import '../account_screen/account_screen.dart';
import '../activity_screen/activity_screen.dart';


class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _selectedIndex = 0;
  UserRole? _userRole;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserRole();
  }

  Future<void> _loadUserRole() async {
    final authService = Provider.of<AuthService>(context, listen: false);
    final role = await authService.getCurrentUserRole();
    setState(() {
      _userRole = role;
      _isLoading = false;
    });
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: CustomLoadingIndicator());
    }

    // Define pages based on role
    final List<Widget> pages = _userRole == UserRole.driver
        ? const [
      DriverHomeScreen(),
      EarningsScreen(),
      AccountScreen(isDriver: true),
    ]
        : const [
      HomeScreen(),
      ActivityScreen(),
      AccountScreen(isDriver: false),
    ];

    // Define bottom nav items based on role
    final List<BottomNavigationBarItem> navItems = _userRole == UserRole.driver
        ? const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.attach_money_outlined),
        activeIcon: Icon(Icons.attach_money),
        label: 'Earnings',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Account',
      ),
    ]
        : const [
      BottomNavigationBarItem(
        icon: Icon(Icons.home_outlined),
        activeIcon: Icon(Icons.home),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.receipt_long_outlined),
        activeIcon: Icon(Icons.receipt_long),
        label: 'Activity',
      ),
      BottomNavigationBarItem(
        icon: Icon(Icons.person_outline),
        activeIcon: Icon(Icons.person),
        label: 'Account',
      ),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        items: navItems,
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).primaryColor,
        unselectedItemColor: Colors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
        onTap: _onItemTapped,
      ),
    );
  }
}