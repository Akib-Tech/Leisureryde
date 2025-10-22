import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:leisureryde/driver/driverlogin.dart';
import 'package:leisureryde/driver/ride_requests.dart';
import 'package:leisureryde/methods/commonmethods.dart';
import 'package:leisureryde/methods/maprecord.dart';
import 'package:leisureryde/methods/sharedpref.dart';

class DriverDashboard extends StatefulWidget {
  const DriverDashboard({super.key});

  @override
  State<DriverDashboard> createState() => _DriverDashboardState();
}

class _DriverDashboardState extends State<DriverDashboard> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool isOnline = false;

  CommonMethods cMethods = CommonMethods();

  final Color gold = const Color(0xFFD4AF37);
  final Color black = const Color(0xFF000000);

  setAvailability(isOnline){
    cMethods.setDriverStatus(isOnline);
  }

  @override @override
  void initState() {
    super.initState();
    setDriverLocation();
  }

  void setDriverLocation() async{
    String? id = await SharedPref().getUserId();

    MapRecord().checkLocationPermissions(id);
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: gold,
        title: const Text(
          "Driver Dashboard",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.black),
            onPressed: () async {
              await _auth.signOut();
              if (!mounted) return;
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (_) => const DriverLogin()),
              );
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 20),

            // Greeting
            Text(
              "Welcome, ${user?.email ?? 'Driver'}",
              style: TextStyle(
                color: black,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 30),

            // Online/Offline toggle
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isOnline ? gold.withOpacity(0.2) : Colors.grey[200],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: gold, width: 1),
              ),
              child: Column(
                children: [
                  Text(
                    isOnline ? "You are Online" : "You are Offline",
                    style: TextStyle(
                      color: isOnline ? Colors.green : Colors.red,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Switch(
                    value: isOnline,
                    activeThumbColor: gold,
                    onChanged: (val) {
                      setAvailability(val);
                      setState(() {
                        isOnline = val;
                      });
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 40),

            // Ride Requests placeholder
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: gold,
                foregroundColor: black,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                Navigator.push(context, MaterialPageRoute(builder: (c) => DriverRequest()));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text("Ride requests feature coming soon!")),
                );
              },
              icon: const Icon(Icons.directions_car),
              label: const Text(
                "View Ride Requests",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),

            const SizedBox(height: 20),

            // Earnings placeholder
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
              onPressed: () {
                     FutureBuilder<Map<dynamic,dynamic>?>(
                        future:  cMethods.driverOnline(),
                        builder: (context,snapshot){
                          final requestList = snapshot.data;
                          return CircularProgressIndicator();
                          }
                    );
                },
              icon: const Icon(Icons.attach_money),
              label: const Text(
                "Earnings",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),

    );
  }
}
