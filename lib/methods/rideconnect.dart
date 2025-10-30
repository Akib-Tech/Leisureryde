import 'package:firebase_database/firebase_database.dart';
import 'package:leisureryde/methods/commonMethods.dart';
import 'package:leisureryde/methods/sharedpref.dart';

class ConnectRide{

  CommonMethods cMethod = CommonMethods();

  void connectADriver(reqId, driverId, pickup,  destination,price,distance) async{
    await SharedPref().bookState(reqId);
    await SharedPref().setDriver(driverId);
    String? riderId = await SharedPref().getUserId();
    DatabaseReference rideRef = cMethod.dBase.ref().child("rideRequests").child(reqId);

    rideRef.set({
      "riderId": riderId,
      "driverId" : driverId,
      "requestId" : reqId,
      "pickup" : pickup,
      "destination" : destination,
      "status" : "waiting...",
      "payment_status" : "Paid",
      "price" : price,
      "distance" : distance,
      "timestamp" :  DateTime.now().toIso8601String()
    });
  }

  Future<List<Map<String,dynamic>?>> notifyDriver() async{
    final id = await SharedPref().getUserId();
    Map<String,dynamic>? result = {};

      final driverRef = cMethod.dBase
          .ref()
          .child('rideRequests')
          .orderByChild("driverId")
          .equalTo(id);

    await for (final event in driverRef.onValue) {
      if (event.snapshot.value != null) {
        // event.snapshot.value will contain ALL matching children
        final data = Map<String, dynamic>.from(event.snapshot.value as Map);

        // You can yield each ride one by one if you prefer:
        for (var ride in data.values) {
          final data = Map<String, dynamic>.from(event.snapshot.value as Map);
          final rides = data.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
          return rides;
        }
      } else {
        return []; // no requests
      }
    }
      return [];
  }

  Stream<Map<String, dynamic>?> driverOnWay(String? rideId) async*{

    final ref = FirebaseDatabase.instance.ref().child('rideRequests').child(rideId!);
    await for (final event in ref.onValue) {
      if (event.snapshot.value != null) {
        yield Map<String, dynamic>.from(event.snapshot.value as Map);
    } else {
    yield null;
    }
  }

  }


}