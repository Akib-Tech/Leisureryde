import 'package:flutter/material.dart';
import 'package:leisureryde/methods/commonMethods.dart';
import 'package:leisureryde/methods/maprecord.dart';
import 'package:leisureryde/methods/usermethod.dart';

class RideHistoryPage extends StatefulWidget {
  const RideHistoryPage({Key? key}) : super(key: key);

  @override
  State<RideHistoryPage> createState() => _RideHistoryPageState();
}

class _RideHistoryPageState extends State<RideHistoryPage> {

  CommonMethods cMethods = CommonMethods();
  List<Map<String, dynamic>?> rideHistory = [];


  Future<void> getMyRequest() async {
    rideHistory = await User().fetchRequest();
  }


  Future<Map<String, dynamic>?> getListValue(data) async {
    final String pickup = await cMethods.getAddressFromCoordinates(
        data['pickup']['lat'], data['pickup']['lng']);
    final String destination = await cMethods.getAddressFromCoordinates(
        data['destination']['lat'], data['destination']['lng']);
    final String rideId = data['riderId'];
    final String driverId = data['driverId'];
    final String status = data['status'];
    final String reqId = data['requestId'] ?? "HEloo";
    final Map<String, dynamic>? driverDetails = await User().fetchDriverData(
        driverId);
    double distance = MapRecord().calculateDistance(
        data['pickup']['lat'], data['pickup']['lng'],
        data['destination']['lat'], data['destination']['lng']);

    return {
      "driverId": driverId,
      "distance": distance,
      "requestId": reqId,
      "status": status,
      "pickup": pickup,
      "destination": destination,
      "driverProfile": driverDetails
    };
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ride History'),
        backgroundColor: Colors.indigo,
        centerTitle: true,
      ),
      body: ListView.builder(
        itemCount: rideHistory.length,
        itemBuilder: (context, index) {
          final ride = rideHistory[index];
          print(ride!);
          return Center();
          /* return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 3,
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // DRIVER NAME & STATUS ROW
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        ride["driverName"],
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ride["status"]),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          ride["status"].toUpperCase(),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // VEHICLE DETAILS
                  Text(
                    ride["vehicle"],
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),

                  // TIME AND PRICE
                  const SizedBox(height: 6),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Time: ${ride["time"]}",
                        style:
                        const TextStyle(fontSize: 13, color: Colors.black54),
                      ),
                      Text(
                        "₦${ride["price"].toStringAsFixed(0)}",
                        style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: Colors.indigo),
                      ),
                    ],
                  ),

                  const SizedBox(height: 10),

                  // ACTION BUTTONS
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      if (ride["status"] == "waiting" ||
                          ride["status"] == "on trip") ...[
                        ElevatedButton(
                          onPressed: () {
                            _startRide(index);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Start Ride"),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () {
                            _cancelRide(index);
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text("Cancel"),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          );

          */
        },
      ),
    );
  }

/*
  void _cancelRide(int index) {
    setState(() {
      rideHistory[index]["status"] = "cancelled";
    });
  }

  void _startRide(int index) {
    setState(() {
      rideHistory[index]["status"] = "on trip";
    });
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case "waiting":
        return Colors.orange;
      case "on trip":
        return Colors.blue;
      case "completed":
        return Colors.green;
      case "cancelled":
        return Colors.red;
      default:
        return Colors.grey;
    }
}
  */

}
