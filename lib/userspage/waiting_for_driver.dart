import 'package:flutter/material.dart';

class WaitingForDriverPage extends StatelessWidget {
  const WaitingForDriverPage({super.key});

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
                    "Live Map (Placeholder)",
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
              ),
            ),

            // Driver Info Card
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
                  // ETA + Status
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Arriving in 3 mins",
                          style: TextStyle(color: gold, fontSize: 16)),
                      const Text("Searching nearby...",
                          style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Driver & Car Info
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

                  // Cancel Ride Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        foregroundColor: black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        // TODO: cancel ride logic
                      },
                      child: const Text("Cancel Ride",
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                    ),
                  )
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
