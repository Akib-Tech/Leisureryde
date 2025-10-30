import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/admin/driver_list.dart';
import 'package:leisureryde/admin/driverpayment.dart';
import 'package:leisureryde/admin/transaction.dart';
import 'package:leisureryde/admin/user_list.dart';
import 'package:leisureryde/methods/adminmethod.dart';
import 'package:leisureryde/userspage/ridehistory.dart';

class AdminHomePage extends StatefulWidget {
  const AdminHomePage({super.key});

  @override
  State<AdminHomePage> createState() => _AdminHomePageState();
}

class _AdminHomePageState extends State<AdminHomePage> {
  int totalUsers = 0;
  int totalDrivers = 0;
  int totalRides = 0;

  @override
  void initState() {
    super.initState();
    _fetchSummaryData();
  }

  Future<void> _fetchSummaryData() async {
    // 🔹 Later you can fetch from Firebase here

    List<Map<String,dynamic>?> usersList = await AdminMethod().usersList();
    List<Map<String,dynamic>?> driversList = await AdminMethod().driversList();
    List<Map<String,dynamic>?> requestsList = await AdminMethod().requestList();

    // For now, we’ll just simulate data
    await Future.delayed(const Duration(seconds: 1));
    setState(() {
      totalUsers = usersList.isNotEmpty ? usersList.length : 0  ;
      totalDrivers = driversList.isNotEmpty ? driversList.length : 0  ;
      totalRides = requestsList.isNotEmpty ? requestsList.length : 0  ;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        centerTitle: true,
        backgroundColor: Colors.indigo,
      ),
      body: RefreshIndicator(
        onRefresh: _fetchSummaryData,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              _buildSummaryCard(
                title: "Total Users",
                value: totalUsers.toString(),
                icon: Icons.people,
                color: Colors.blue,
              ),
              _buildSummaryCard(
                title: "Total Drivers",
                value: totalDrivers.toString(),
                icon: Icons.directions_car,
                color: Colors.green,
              ),
              _buildSummaryCard(
                title: "Total Rides",
                value: totalRides.toString(),
                icon: Icons.local_taxi,
                color: Colors.orange,
              ),
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 12),
              const Text(
                "Manage Sections",
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87),
              ),
              const SizedBox(height: 16),
              _buildButton(
                title: "View Users",
                icon: Icons.person_outline,
                color: Colors.blueAccent,
                route: const UsersListScreen(),
              ),
              _buildButton(
                title: "View Drivers",
                icon: Icons.drive_eta_outlined,
                color: Colors.green,
                route: const DriversListScreen(),
              ),
              _buildButton(
                title: "Ride Requests",
                icon: Icons.local_taxi_outlined,
                color: Colors.orangeAccent,
                route: const DriverEarningsScreen(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.15),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: Text(
          value,
          style: TextStyle(
              color: color, fontSize: 18, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Widget _buildButton({
    required String title,
    required IconData icon,
    required Color color,
    required Widget route,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ElevatedButton.icon(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => route),
        ),
        icon: Icon(icon, color: Colors.white),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text(
            title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}
