import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
//import 'package:intl/intl.dart';

class TransactionListScreen extends StatefulWidget {
  const TransactionListScreen({super.key});

  @override
  State<TransactionListScreen> createState() => _TransactionListScreenState();
}

class _TransactionListScreenState extends State<TransactionListScreen> {
  final DatabaseReference _rideRequestsRef =
  FirebaseDatabase.instance.ref().child('rideRequests');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Ride Requests"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder(
        stream: _rideRequestsRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No transactions found."));
          }

          final event = snapshot.data as DatabaseEvent;
          if (event.snapshot.value == null) {
            return const Center(child: Text("No transactions found."));
          }

          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final List<Map<String, dynamic>> transactions = [];

          data.forEach((key, value) {
            final ride = Map<String, dynamic>.from(value);
            ride['id'] = key;
            transactions.add(ride);
          });

          transactions.sort((a, b) {
            final dateA = DateTime.tryParse(a['date'] ?? '') ?? DateTime(2000);
            final dateB = DateTime.tryParse(b['date'] ?? '') ?? DateTime(2000);
            return dateB.compareTo(dateA);
          });

          return ListView.builder(
            itemCount: transactions.length,
            itemBuilder: (context, index) {
              final ride = transactions[index];

              final pickup = ride['pickup'] ?? 'Unknown pickup';
              final destination = ride['destination'] ?? 'Unknown destination';
              final distance = ride['distance']?.toString() ?? '0';
              final price = ride['price']?.toString() ?? '0';
              final driverName = ride['driverId'] ?? 'Unknown driver';
              final riderName = ride['riderId'] ?? 'Unknown rider';
              final status = ride['status'] ?? 'pending';
             // final dateRaw = ride['date'] ?? '';
              final formattedDate ="";



              /*dateRaw.isNotEmpty
                  ? DateFormat('dd MMM yyyy, hh:mm a')
                  .format(DateTime.parse(dateRaw))
                  : 'No date';
*/
              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                  title: Text(
                    "$pickup → $destination",
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text("Driver: $driverName"),
                      Text("Rider: $riderName"),
                      Text("Distance: $distance km"),
                      Text("Price: \$ $price"),

                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text("Status: ",
                              style: TextStyle(fontWeight: FontWeight.bold)),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'completed'
                                  ? Colors.green
                                  : status == 'cancelled'
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
