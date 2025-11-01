import 'package:flutter/material.dart';

class RideInProgressPage extends StatelessWidget {
  const RideInProgressPage({super.key});

  final Color gold = const Color(0xFFFFD700);
  final Color black = Colors.black;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: black,
      body: SafeArea(
        child: Column(
          children: [
            // Map Placeholder
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.grey[850],
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Center(
                  child: Text(
                    "Live Route Map (Placeholder)",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),

            // Ride Info Card
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius:
                const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ETA + Payment
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Arriving in 12 mins",
                          style: TextStyle(color: gold, fontSize: 16)),
                      Icon(Icons.account_balance_wallet,
                          color: gold, size: 28),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Driver Info Row
                  Row(
                    children: [
                      const CircleAvatar(
                        radius: 28,
                        backgroundImage:
                        AssetImage("assets/images/driver.jpg"), // placeholder
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            Text("John Doe",
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold)),
                            Text("Toyota Camry - Black",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                            Text("Plate: ABC-1234",
                                style: TextStyle(
                                    color: Colors.white70, fontSize: 14)),
                          ],
                        ),
                      ),
                      Icon(Icons.phone, color: gold, size: 28),
                      const SizedBox(width: 12),
                      Icon(Icons.message, color: gold, size: 28),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Destination Info
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.location_on, color: gold),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          "Destination: 15 Marina Road, Lagos Island",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // Safety Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: black,
                        foregroundColor: gold,
                        side: BorderSide(color: gold, width: 1.5),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // TODO: safety options
                      },
                      icon: const Icon(Icons.shield),
                      label: const Text("Safety Options",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
