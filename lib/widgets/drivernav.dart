import 'package:flutter/material.dart';
import 'package:leisureryde/driver/driver_profile.dart';
import 'package:leisureryde/driver/edit_driver_profile.dart';
import 'package:leisureryde/driver/ride_requests.dart';
import 'package:leisureryde/userspage/ridehistory.dart';
import 'package:leisureryde/userspage/rideprocess.dart';
import 'package:leisureryde/userspage/home.dart';
import 'package:leisureryde/userspage/profile.dart';

class DriverNav extends StatefulWidget {
  const DriverNav({super.key});

  @override
  State<DriverNav> createState() => _DriverNavState();
}

class _DriverNavState extends State<DriverNav> {
  int _selectedIndex = 0;

  // Pages
  final List<Widget> _pages = [
    const HomePage(),
    const DriverRequest(), // Booking Page
    const DriverProfile(),
    const HomePage()
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    Navigator.push(context, MaterialPageRoute(builder: (c) => _pages[index] ));
  }

  final Color gold = const Color(0xFFFFD700);
  final Color black = Colors.black;

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      type: BottomNavigationBarType.fixed,
      currentIndex: _selectedIndex,
      onTap: _onItemTapped,
      backgroundColor: Colors.white,
      selectedItemColor: black,
      unselectedItemColor: Colors.grey,
      items: const [
        BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
        BottomNavigationBarItem(icon: Icon(Icons.local_taxi), label: "Requests"),
        BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        BottomNavigationBarItem(icon: Icon(Icons.history), label: "History"),
      ],
    );
  }
}
