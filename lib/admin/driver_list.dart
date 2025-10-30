import 'package:flutter/material.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:url_launcher/url_launcher.dart'; // for opening license link

class DriversListScreen extends StatefulWidget {
  const DriversListScreen({super.key});

  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  final DatabaseReference _driversRef =
  FirebaseDatabase.instance.ref().child('drivers');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Manage Drivers"),
        centerTitle: true,
        backgroundColor: Colors.blueAccent,
      ),
      body: StreamBuilder(
        stream: _driversRef.onValue,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data == null) {
            return const Center(child: Text("No drivers found."));
          }

          final event = snapshot.data as DatabaseEvent;
          if (event.snapshot.value == null) {
            return const Center(child: Text("No drivers found."));
          }

          final data = event.snapshot.value as Map<dynamic, dynamic>;
          final List<Map<String, dynamic>> driversList = [];

          data.forEach((key, value) {
            final driver = Map<String, dynamic>.from(value);
            driver['id'] = key;
            driversList.add(driver);
          });

          return ListView.builder(
            itemCount: driversList.length,
            itemBuilder: (context, index) {
              final driver = driversList[index];

              final first = driver['firstname'] ?? '';
              final last = driver['lastname'] ?? '';
              final name = (first.isEmpty && last.isEmpty)
                  ? 'No Name'
                  : '$first $last';
              final email = driver['email'] ?? 'No Email';
              final phone = driver['phone'] ?? 'No Phone';
              final status = driver['status'] ?? 'pending';
              final driverStatus = driver['id'] ?? '';
              final lat = driver['lat'] ?? 'unknown';
              final lng = driver['lng'] ?? 'unknown';
              final licenseUrl = driver['licence'] ?? '';
              final profile = driver['profileImage'] ??
                  'https://cdn-icons-png.flaticon.com/512/149/149071.png';

              return Card(
                margin:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ListTile(
                /*  leading: CircleAvatar(
                    backgroundImage: NetworkImage(profile),
                    radius: 26,
                  ),*/
                  title: Text(
                    name,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 16),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(email),
                      Text("Phone: $phone"),
                      Text("Driver Identity: $driverStatus"),
                      Text("Location: ($lat, $lng)"),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Text(
                            "Account: ",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: status == 'approved'
                                  ? Colors.green
                                  : status == 'blocked'
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                        ],
                      ),
                      if (licenseUrl.isNotEmpty)
                        TextButton.icon(
                          onPressed: () => _openLicense(licenseUrl),
                          icon: const Icon(Icons.picture_as_pdf),
                          label: const Text("View License"),
                        ),
                    ],
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) =>
                        _updateDriverStatus(driver['id'], value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                          value: 'approved', child: Text("Approve Driver")),
                      PopupMenuItem(
                          value: 'blocked', child: Text("Block Driver")),
                      PopupMenuItem(
                          value: 'pending', child: Text("Set Pending")),
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

  Future<void> _updateDriverStatus(String driverId, String newStatus) async {
    try {
      await _driversRef.child(driverId).update({'status': newStatus});
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Driver status updated to $newStatus")),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error updating status: $e")),
      );
    }
  }

  Future<void> _openLicense(String url) async {
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Could not open license link")),
      );
    }
  }
}
