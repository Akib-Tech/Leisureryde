import 'package:firebase_database/firebase_database.dart';
import 'package:leisureryde/methods/commonMethods.dart';
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
        result.add({
          "lat" : data['lat'],
          "lng" : data['lng'],
          'driver' : data['driverId']
        });
      }
      return result;
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

      print(rideData);

        return rideData;

      }

    }







