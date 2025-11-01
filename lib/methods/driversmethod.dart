import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/methods/commonMethods.dart';
import 'package:leisureryde/methods/maprecord.dart';
import 'package:leisureryde/methods/sharedpref.dart';

class Drivers{
    CommonMethods cMethods = CommonMethods();
    SharedPref pref = SharedPref();
    updateLocation(double lat, double lng,String? id) async{

      String? id = await pref.getUserId();

      if(id != null) {
        final userLocation =   cMethods.dBase.ref().child("driverlocation").child(id);

        userLocation.set({
          "lat" : lat,
          "lng" : lng,
          "driverId" : id
        });
      }
  }

  Future<List<Map<String, dynamic>?>> fetchLocation() async{
      DatabaseReference fetchData = cMethods.dBase.ref().child("driverlocation");

       final event = await fetchData.get();

      late List<Map<String, dynamic>? > result =[];

      for (var child in event.children) {
        Map<String, dynamic>? data = Map<String, dynamic>.from(child.value as Map);
        if(data['status'] == 'online' && data['lat'] != null && data['lng'] != null) {
          result.add({
            "lat": data['lat'],
            "lng": data['lng'],
            'driver': data['driverId']
          });
        }
      }
      return result;
  }

  changeDriver(reqId,id,lat,lng) async{

    DatabaseReference fetchData = cMethods.dBase.ref().child("driverlocation");

    final event = await fetchData.get();

    late List<Map<String, dynamic>? > result =[];

    for (var child in event.children) {
      Map<String, dynamic>? data = Map<String, dynamic>.from(child.value as Map);
      if(data['status'] == 'online' && data['driverId'] != id) {
        result.add({
          "lat": data['lat'],
          "lng": data['lng'],
          'driver': data['driverId']
        });
      }
    }

    LatLng dis = LatLng(lat, lng);

   Map<String,dynamic>? changedD = await MapRecord().findDrivers(dis, result);


    DatabaseReference rideRef = CommonMethods().dBase.ref().child("rideRequests").child(reqId);

    print(changedD);
    rideRef.update({
      "driverId" : changedD?['driverInfo'],
      "status" : "waiting...",
      "timestamp" :  DateTime.now().toIso8601String()
    });



/*


   LatLng picklocation = changedD?['location'];

    var pickup = {
      "lat" : dis.latitude,
      "lng" : dis.longitude
    };

    var destination = {
      "lat" : picklocation.latitude,
      "lng" : picklocation.longitude
    };

    DatabaseReference rideRef = CommonMethods().dBase.ref().child("rideRequests").child(reqId);

    var pickup = {
      "lat" : dis.latitude,
      "lng" : dis.longitude
    };

    var destination = {
      "lat" : changedD
      "lng" : destinationLoc?.longitude
    };



    rideRef.update({
      "driverId" : id,
      "requestId" : reqId,
      "pickup" : ,
      "destination" : destination,
      "status" : "waiting...",
      "timestamp" :  DateTime.now().toIso8601String()
    });





*/
   //return changedD;


  }


  void updateDriverStatus(currentStatus) async{
      DatabaseReference status = cMethods.dBase.ref().child("drivers");

      status.set({
        "status" : currentStatus
      });

  }


  void acceptRide(String id){
      final driveRef = cMethods.dBase.ref().child("rideRequests").child(id);

      driveRef.update({
        "status" : "driver_assigned"
      });
    }

  void rejectRide(String id){
    final driveRef = cMethods.dBase.ref().child("rideRequests").child(id);

    driveRef.update({
      "status" : "rejected"
    });
  }


 Stream<String>  knowBookingStatus(String id) async*{
    DatabaseReference rideRef = cMethods.dBase
        .ref()
        .child("rideRequests")
        .child(id);

    await for (final event in rideRef.onValue){
        final rideData = Map<String,dynamic>.from(event.snapshot as Map);
        String result ;
        if(rideData['status'] == 'accepted'){
            result = "accepted";
        }else if(rideData['status'] == 'rejected'){
            result = "rejected";
        }else{
            result = "completed";
        }
        yield result;
    }

  }



   Future<Map<String,dynamic>?> movement() async{
     String? id = await SharedPref().getUserId();
      DatabaseReference rideRef = cMethods.dBase
          .ref()
          .child("rideRequests")
          .child(id!);
      final fetchData = await rideRef.get();
      Map<String,dynamic>? rideData = Map<String,dynamic>.from(fetchData.value as Map);

        return rideData;

      }

      void setOffline(id) async{
        DatabaseReference locationRef =    cMethods.dBase.ref().child("driverlocation");
        await locationRef.child(id).update({
          "driverId" : id,
          "lat" : null,
          "lng" : null,
          "status" : "offline"
        });

      }


    void setOnline(id) async{
      DatabaseReference locationRef =    cMethods.dBase.ref().child("driverlocation");
      await locationRef.child(id).update({
        "driverId" : id,
        "status" : "online"
      });

    }



    Future<Map<String,dynamic>?> getOnlineStatus(id) async {
      DatabaseReference ref = FirebaseDatabase.instance.ref("driverlocation").child(id);

      final snapshot = await ref.get();

      if(snapshot.exists){
        Map<String, dynamic>? result = Map<String, dynamic>.from(snapshot.value as Map);
        return result;
      }else{
        return null;
      }
    }
}







