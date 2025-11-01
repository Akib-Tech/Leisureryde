
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuth;
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:leisureryde/driver/driveInfo.dart';
import 'package:leisureryde/driver/driver_dashboard.dart';
import 'package:leisureryde/driver/ride_movement.dart';
import 'package:leisureryde/methods/driversmethod.dart';
import 'package:leisureryde/methods/maprecord.dart';
import 'package:leisureryde/methods/rideconnect.dart';
import 'package:leisureryde/methods/sharedpref.dart';
import 'package:leisureryde/userspage/chat.dart';
import 'package:leisureryde/widgets/requestlist.dart';

import '../methods/commonMethods.dart' show CommonMethods;

class DriverRequest extends StatefulWidget{
  const DriverRequest({super.key});

@override
State<DriverRequest> createState() => _DriverRequestState();
}

class _DriverRequestState extends State<DriverRequest> {

  @override
  void initState(){
    super.initState();
    setString();
  }
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseDatabase dBase = FirebaseDatabase.instance;
   late final DatabaseReference rideRequestRef = dBase.ref("rideRequests");
  final bool isOnline = false;
   bool status = true;
  var request = [];

  String? id = "";

  setString() async{
    id = await SharedPref().getUserId();
  }


  Future<Map<String,dynamic>?> getListValue(data) async{
    final String pickup = await cMethods.getAddressFromCoordinates(data['pickup']['lat'],data['pickup']['lng']);
    final String destination = await  cMethods.getAddressFromCoordinates(data['destination']['lat'], data['destination']['lng']);
    final String rideId = data['riderId'];
    final String driverId = data['driverId'];
    final String distance = data['distance'];
    final String status = data['status'];
    final String reqId = data['requestId'];
    final String price = data['price'];
    //double distance =  MapRecord().calculateDistance(data['pickup']['lat'], data['pickup']['lng'], data['destination']['lat'], data['destination']['lng']);
    double lat = data['pickup']['lat'];
    double lng = data['pickup']['lng'];
    final String payment_status = data['payment_status'];

    return {
      "riderId" : rideId,
      "driverId" : driverId,
      "distance" : distance,
      "requestId" : reqId,
      "status" : status,
      "pickup" : pickup,
      "price" : price,
      "destination" : destination,
      "payment_status" : payment_status,
      "lat" : lat,
      "lng" : lng
    };
  }

  Stream<List<Map<String,dynamic>>> rideRequestStream(){

    return rideRequestRef.onValue.map((event){
      final data = event.snapshot.value;

      if(data == null) return [];

      final fetchData = Map<dynamic,dynamic>.from(data as Map);
      final fetchList = <Map<String,dynamic>>[];

      fetchData.forEach((key,value){
        fetchList.add({
          "pickup":  value["pickup"],
          "destination" : value['destination']
        });
      });

      return fetchList;
    });
  }


  CommonMethods cMethods = CommonMethods();
  DriveInfo ride = DriveInfo();
  final Color gold = const Color(0xFFD4AF37);
  final Color black = const Color(0xFF000000);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: gold,
        title: const Text(
          "Available Requests",
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
                MaterialPageRoute(builder: (_) => const RideMovement()),
              );
            },
          )
        ],
      ),

      body: listRequest() ,

    );
}

Widget listRequest(){
    return FutureBuilder<List<Map<String,dynamic>?>>(
        future: ConnectRide().notifyDriver(),
        builder: (context,snapshot){
          if(snapshot.hasError){
            return Center(
              child: Text("Error: ${snapshot.error}"),
            );
          }
          else if (snapshot.hasData && snapshot.data != null && snapshot.data!.isNotEmpty){
            final data = snapshot.data!;
            return ListView.builder(
                itemCount: data.length,
                itemBuilder: (context, index) {
                  final result = data[index];
                  return FutureBuilder<Map<String, dynamic>?>(
                      future: getListValue(result),
                      builder: (context, snapshot) {
                        final response =  snapshot.data;
                        final driverId = response?['driverId'];
                        final lat = response?['lat'];
                        final lng = response?['lng'];
                        final reqId = response?['requestId'];
                        final price = response?['price'];

                          return Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 4,
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "RequestID: ${response?['requestId']}",
                                    style: Theme
                                        .of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      const Text('Pickup:'),
                                      Expanded(
                                        child: Text(
                                          "${response?['pickup']}",
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      const Text('Destination:'),
                                      Expanded(
                                        child: Text(
                                          "${response?['destination']}",
                                          textAlign: TextAlign.right,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.w600),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      Text('Distance:'),
                                      Text("${response?['distance']} miles",
                                        textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),

                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      const Text('Price:'),
                                      Text('\$ $price',textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      const Text('Payment Status:'),
                                      Text('${response?['payment_status']}',textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),

                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      const Text('Availability:'),
                                      Text("${response?['status']}",textAlign: TextAlign.right,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600),
                                      ),
                                    ],
                                  ),
                                  const Divider(height: 20),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment
                                        .spaceBetween,
                                    children: [
                                      (
                                      response?['status'] == "waiting..." ?
                                   ElevatedButton.icon(
                                        onPressed: () =>
                                        {
                                          Drivers().acceptRide(
                                              "${response?['requestId']}"),
                                        },
                                        icon: const Icon(
                                            Icons.check_circle,
                                            color: Colors.white),
                                        label: const Text("Accept"),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                8),
                                          ),
                                        ),
                                      )
                                       :
                                      ElevatedButton.icon(
                                        onPressed: () =>
                                        {},
                                        icon: const Icon(
                                            Icons.check_circle,
                                            color: Colors.white),
                                        label: const Text('Accepted'),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.green,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                8),
                                          ),
                                        ),
                                      )
                                ),
                                      (
                                      response?['status'] == "waiting..." ?
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                        {
                                       Drivers().changeDriver(reqId,driverId,lat,lng)
                                        },
                                        icon: const Icon(
                                            Icons.cancel, color: Colors.red),
                                        label: const Text('Decline'),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Colors.red),
                                          foregroundColor: Colors.red,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                8),
                                          ),
                                        ),
                                      )
                                      :
                                      OutlinedButton.icon(
                                        onPressed: () =>
                                        {
                                          Navigator.push(context,MaterialPageRoute(builder: (c) =>
                                              ChatScreen(
                                                receiverName: "Ibraheem",
                                                receiverId: "${response?['riderId']}",

                                              )
                                          )
                                          )
                                         },
                                        icon: const Icon(
                                            Icons.message, color: Colors.red),
                                        label: const Text('Message'),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                              color: Colors.red),
                                          foregroundColor: Colors.red,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                                8),
                                          ),
                                        ),
                                      )
                                      )
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );


                      }
                  );
                });
          }
          else{
            return Center(child: Text('No Ride Request Available.'));
          }
        }
    );
}






}