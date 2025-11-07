import 'package:leisureryde/methods/commonMethods.dart';
import 'package:leisureryde/methods/sharedpref.dart';

// class User{
//   CommonMethods cMethod = CommonMethods();
//
//   Future<List<Map<String,dynamic>?>> fetchRequest() async{
//     final id = await SharedPref().getUserId();
//     final driverRef = cMethod.dBase
//         .ref()
//         .child('rideRequests')
//         .orderByChild("riderId")
//         .equalTo(id);
//
//     await for (final event in driverRef.onValue) {
//       if (event.snapshot.value != null) {
//         // event.snapshot.value will contain ALL matching children
//         final data = Map<String, dynamic>.from(event.snapshot.value as Map);
//
//         // You can yield each ride one by one if you prefer:
//         for (var ride in data.values) {
//           final data = Map<String, dynamic>.from(event.snapshot.value as Map);
//           final rides = data.values.map((e) => Map<String, dynamic>.from(e as Map)).toList();
//           return rides  ;
//         }
//       } else {
//         return []; // no requests
//       }
//     }
//
//     return [];
//
//   }
//
//   Future<Map<String,dynamic>?> fetchDriverData(id) async{
//     if(id != null){
//       final event = await cMethod.dBase.ref().child("drivers").child(id).once();
//       if (event.snapshot.value != null) {
//         return Map<String, dynamic>.from(event.snapshot.value as Map);
//       }
//     }
//     return null;
//   }
//
//
//   void beginJourney(String id){
//     final driveRef = cMethod.dBase.ref().child("rideRequests").child(id);
//
//     driveRef.update({
//       "status" : "Moving"
//     });
//   }
//
//
//   void cancelRide(String id){
//     final driveRef = cMethod.dBase.ref().child("rideRequests").child(id);
//     driveRef.update({
//       "status" : "Cancelled"
//     });
//   }
//
//   void completeRide(String id){
//     final driveRef = cMethod.dBase.ref().child("rideRequests").child(id);
//     driveRef.update({
//       "status" : "Completed"
//     });
//   }
//
// }