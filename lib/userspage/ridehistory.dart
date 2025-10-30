import 'package:flutter/material.dart';
import 'package:leisureryde/methods/commonMethods.dart';
import 'package:leisureryde/methods/maprecord.dart' show MapRecord;
import 'package:leisureryde/methods/usermethod.dart';
import 'package:leisureryde/userspage/chat.dart';

class History extends StatefulWidget{
  const History({super.key});

  @override
  State<History> createState () =>  _HistoryState();
}

class _HistoryState extends State<History> {

  //List<Map<String, dynamic>?> rideHistory = [];
  User userMethods = User();
  CommonMethods cMethods = CommonMethods();
  final Color gold = const Color(0xFFd4af37);
  final Color black = Colors.black;

  @override
  void initState() {
    getMyRequest();
    super.initState();
  }
  Future<List<Map<String,dynamic>?>> getMyRequest() async {
    List<Map<String, dynamic>?> rideHistory = await User().fetchRequest();

    print("Ride History: $rideHistory");
    return rideHistory;
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
    final String distance = data['distance'];

    final String price = data['price'];

    return {
      "driverId": driverId,
      "distance": distance,
      "requestId": reqId,
      "status": status,
      "price":price,
      "pickup": pickup,
      "destination": destination,
      "driverProfile": driverDetails
    };
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: gold,
        title: const Text(
          "Ride History",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: FutureBuilder(
          future: getMyRequest(),
          builder: (context,snapshot){
            if(snapshot.hasData && snapshot.data != null && snapshot.data! != []){
             final rideHistory = snapshot.data;
              return ListView.builder(
                itemCount: rideHistory!.length,
                itemBuilder: (context, index) {
                  final rideLists = rideHistory[index];
                  print("Ride list :  $rideLists");
                  return  FutureBuilder<Map<String,dynamic>?> (
                      future: getListValue(rideLists),
                      builder: (context,snapshot){
                        if(snapshot.hasData && snapshot.data != null && snapshot.data! !=
                            {}){
                          final  ride = snapshot.data;
                          print(ride);
                          return _rideHistory(ride);
                        }else{
                          return Center(
                            child: Text("No data available"),
                           );
                        }
                      }
                  );
                },
              );
            }else{
              return Center(
                child: Text("No Ride History Available"),
              );
            }
          }
      )
    );
  }



  void _cancelRide(rideId) {
    User().cancelRide(rideId);
  }

  void _completeRide(rideId) async{
    User().completeRide(rideId);
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

  Widget _rideHistory(ride){
    return Card(
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
                Text("Driver: ${ride?["driverProfile"]["username"] ?? "Username" }",
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(ride?["status"]),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    ride?["status"].toUpperCase(),
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
            Text("Destination: ${
                ride?["pickup"]}",
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold,fontSize: 15),
            ),

            // TIME AND PRICE
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "Phone: ${ride?["driverProfile"]["phone"]}",
                  style:
                  const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                Text(
                  "Distance: ${ride?["distance"]} miles",
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),


            // TIME AND PRICE
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  "RideID: ${ride?["requestId"]}",
                  style:
                  const TextStyle(fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
                Text(
                  "Price: \$ ${ride?["price"]}",
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Colors.black),
                ),
              ],
            ),

            const SizedBox(height: 10),


            const SizedBox(height: 10),

            // ACTION BUTTONS
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (ride?["status"] == "waiting..." ||
                    ride?["status"] == "on trip") ...[
                  ElevatedButton(
                    onPressed: () {
                      _completeRide(ride?["requestId"]);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:gold,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Ride Completed",style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: () {
                      _cancelRide(ride?['requestId']);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    child: const Text("Cancel",style: TextStyle(fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: Colors.black),),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }

}