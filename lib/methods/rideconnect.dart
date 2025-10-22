import 'package:firebase_database/firebase_database.dart';
import 'package:leisureryde/methods/commonMethods.dart';
import 'package:leisureryde/methods/sharedpref.dart';

class ConnectRide{

  CommonMethods cMethod = CommonMethods();

  void connectADriver(reqId, driverId, pickup,  destination) async{
    await SharedPref().bookState(reqId);
    String? riderId = await SharedPref().getUserId();
    DatabaseReference rideRef = cMethod.dBase.ref().child("rideRequests").child(reqId);

    rideRef.set({
      "riderId": riderId,
      "driverId" : driverId,
      "pickup" : pickup,
      "destination" : destination,
      "status" : "waiting...",
      "timestamp" :  DateTime.now().toIso8601String()
    });
  }

  Stream<Map<String,dynamic>?> notifyDriver() async*{
    final id = await SharedPref().getUserId();
    Map<String,dynamic>? result = {};

      final driverRef = cMethod.dBase
          .ref()
          .child('rideRequests')
          .orderByChild("driverId")
          .equalTo(id);


    await for (final event in driverRef.onChildAdded) {
      if (event.snapshot.value != null) {
        final rideData = Map<String, dynamic>.from(event.snapshot.value as Map);
        yield rideData;
      } else {
        yield null; // No data yet
      }
    }

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