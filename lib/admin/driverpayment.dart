import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';

class DriverEarningsScreen extends StatefulWidget {
  const DriverEarningsScreen({super.key});

  @override
  State<DriverEarningsScreen> createState() => _DriverEarningsScreenState();
}

class _DriverEarningsScreenState extends State<DriverEarningsScreen> {
  final DatabaseReference _earningsRef =
  FirebaseDatabase.instance.ref().child('driverEarnings');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(  UPGD76465
        title: const Text("Driver Earnings"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder(
        stream: _earningsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No earnings data found."));
          }

          final event = snapshot.data as DatabaseEvent;

          if (event.snapshot.value == null) {
            return const Center(child: Text("No data available."));
          }

          final data = event.snapshot.value as Map<dynamic, dynamic>;

          final List<Map<String, dynamic>> drivers = [];
          data.forEach((key, value) {
            final driver = Map<String, dynamic>.from(value);
            driver['id'] = key;
            drivers.add(driver);
          });

          return ListView.builder(
            itemCount: drivers.length,
            itemBuilder: (context, index) {
              final driver = drivers[index];
              final name = driver['driverName'] ?? 'Unknown Driver';
              final total = driver['totalEarnings'] ?? 0;
              final pending = driver['pendingEarnings'] ?? 0;
              final cleared = driver['clearedEarnings'] ?? 0;

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  title: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Total Earnings: ₦$total"),
                      Text("Pending: ₦$pending"),
                      Text("Cleared: ₦$cleared"),
                    ],
                  ),
                  trailing: ElevatedButton(
                    onPressed: () => _clearPayment(driver['id'], pending),
                    child: const Text("Clear Payment"),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _clearPayment(String driverId, int pendingAmount) async {
    if (pendingAmount <= 0) return;

    try {
      // Move pending to cleared
      await _earningsRef.child(driverId).update({
        'clearedEarnings': ServerValue.increment(pendingAmount),
        'pendingEarnings': 0,
      });

      // Optionally, add to clearedPayments node
      final clearedRef =
      FirebaseDatabase.instance.ref().child('clearedPayments');
      await clearedRef.push().set({
        'driverId': driverId,
        'amount': pendingAmount,
        'date': DateTime.now().toIso8601String(),
        'status': 'cleared',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Payment cleared successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}
