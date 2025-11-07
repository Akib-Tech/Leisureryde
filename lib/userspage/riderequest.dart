// import 'dart:async';
// import 'dart:math';
// import 'package:flutter/material.dart';
// import 'package:flutter_polyline_points/flutter_polyline_points.dart';
// import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:google_place/google_place.dart';
// import 'package:leisureryde/globa/global_var.dart';
// import 'package:leisureryde/methods/driversmethod.dart';
// import 'package:leisureryde/methods/sharedpref.dart';
// import '../widgets/buttomnav.dart';
// import '../methods/commonmethods.dart';
//
// class RideRequestPage extends StatefulWidget {
//   const RideRequestPage({super.key});
//
//   @override
//   State<RideRequestPage> createState() => _RideRequestPageState();
// }
//
// class _RideRequestPageState extends State<RideRequestPage> {
//   CommonMethods cMethods = CommonMethods();
//
//   // ──────────────────────────────── CONTROLLERS ────────────────────────────────
//   final TextEditingController pickupController = TextEditingController();
//   final TextEditingController destinationController = TextEditingController();
//
//   // ──────────────────────────────── MAP VARIABLES ──────────────────────────────
//   LatLng pickUpLocation = const LatLng(7.5207, 4.5303);
//   late LatLng destinationLoc;
//
//   BitmapDescriptor pickupIcon =
//   BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
//   BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
//   late BitmapDescriptor driverIcon = driverIcon;
//
//   GoogleMapController? mapController;
//   late GooglePlace googlePlace;
//
//   Set<Marker> markers = {};
//   Set<Polyline> polylines = {};
//   List<LatLng> polylineCoordinates = [];
//
//   // ──────────────────────────────── STATE VARIABLES ─────────────────────────────
//   bool isPickup = true;
//   bool driverFound = false;
//
//   final Color gold = const Color(0xFFd4af37);
//   final Color black = Colors.black;
//
//   List<AutocompletePrediction> predictions = [];
//
//
//   String driverName = "John Doe";
//   String driverCar = "Toyota Camry - ABC 123";
//   String driverPhone = "+234 801 234 5678";
//
//   Timer? carTimer;
//   int carIndex = 0;
//
//   // ──────────────────────────────── INIT ────────────────────────────────
//   @override
//   void initState() {
//     super.initState();
//     googlePlace = GooglePlace(googleMapKey);
//     tryMe();
//
//     BitmapDescriptor.asset(
//       const ImageConfiguration(size: Size(48, 48)),
//       "assets/images/driver.webp",
//     ).then((driver) => driverIcon = driver);
//   }
//
//
//
//   // ──────────────────────────────── AUTOCOMPLETE ────────────────────────────────
//   Future<void> autoCompleteSearch(String value) async {
//     var result = await googlePlace.autocomplete.get(value);
//     if (result != null && result.predictions != null) {
//       setState(() => predictions = result.predictions!);
//
//     }
//   }
//
//   Future<LatLng?> convertLoc(String placeId) async {
//     var details = await googlePlace.details.get(placeId);
//     if (details != null &&
//         details.result != null &&
//         details.result!.geometry != null) {
//       var loc = details.result!.geometry!.location;
//       return LatLng(loc!.lat!, loc.lng!);
//     }
//     return null;
//   }
//
//   // ──────────────────────────────── RIDE LOGIC ────────────────────────────────
//
//   Future<List<Map<String,dynamic>?>> findAvailableDrivers() async{
//     List<Map<String,dynamic>?> driverCoordinates = await Drivers().fetchLocation();
//     return driverCoordinates;
//   }
//
//
//
//
//   void bookRide(BuildContext context, ) async {
//     showDialog(
//       context: context,
//       barrierDismissible: false,
//       builder: (context) => const Center(child: CircularProgressIndicator()),
//     );
//
//    List<Map<String,dynamic>?> loca =await findAvailableDrivers();
//
//     await Future.delayed(const Duration(seconds: 3));
//     Navigator.pop(context);
//     LatLng? closestDriver = await findDrivers(pickUpLocation, loca);
//
//     setState(() {
//       markers.add(
//         Marker(
//           markerId: const MarkerId("Driver"),
//           position: closestDriver,
//           icon:
//           BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
//           infoWindow: const InfoWindow(title: "Closest Driver"),
//         ),
//       );
//     });
//
//     cMethods.findRider(
//         pickUpLocation.latitude,
//         pickUpLocation.longitude,
//         destinationLoc.latitude,
//         destinationLoc.longitude
//     );
//
//
//     cMethods.notifyDriver();
//
//     await getRoute(pickUpLocation,closestDriver);
//     startMovement();
//
//   }
//
//   Future<void> getRoute(LatLng start, LatLng end) async {
//     PolylinePoints polylinePoints = PolylinePoints();
//
//     final result = await polylinePoints.getRouteBetweenCoordinates(
//       googleMapKey,
//       PointLatLng(end.latitude, end.longitude),
//       PointLatLng(start.latitude, start.longitude),
//       travelMode: TravelMode.driving,
//     );
//
//     if (result.points.isNotEmpty) {
//       polylineCoordinates.clear();
//       for (var point in result.points) {
//         polylineCoordinates.add(LatLng(point.latitude, point.longitude));
//       }
//
//       setState(() {
//         polylines.clear();
//         polylines.add(
//           Polyline(
//             polylineId: const PolylineId("route"),
//             color: Colors.blue,
//             width: 5,
//             points: polylineCoordinates,
//           ),
//         );
//       });
//     }
//   }
//
//   // ──────────────────────────────── MAP UTILITIES ────────────────────────────────
//   void goToCurrentLocation(LatLng location) {
//     mapController?.animateCamera(
//       CameraUpdate.newCameraPosition(
//         CameraPosition(target: location, zoom: 14),
//       ),
//     );
//   }
//
//   void startMovement() {
//     if (polylineCoordinates.isEmpty) return;
//     carTimer?.cancel();
//     carIndex = 0;
//
//     carTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
//       if (carIndex < polylineCoordinates.length) {
//         LatLng nextPosition = polylineCoordinates[carIndex];
//
//         setState(() {
//           markers.removeWhere((m) => m.markerId.value == "car");
//           markers.add(
//             Marker(
//               markerId: const MarkerId("Driver"),
//               position: nextPosition,
//               icon: driverIcon,
//             ),
//           );
//         });
//
//         mapController?.animateCamera(CameraUpdate.newLatLng(nextPosition));
//         carIndex += 5;
//       } else {
//         timer.cancel();
//       }
//     });
//   }
//
//   double calcDistance(lat1, lon1, lat2, lon2) {
//     const p = pi / 180;
//     final a = 0.5 -
//         cos((lat2 - lat1) * p) / 2 +
//         cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;
//
//     return 12742 * asin(sqrt(a));
//   }
//
//
//
//   Future<LatLng> findDrivers(LatLng userDist, List<Map<String,dynamic>?> driversDist) async{
//     double minDistance = double.infinity;
//     LatLng closest = pickUpLocation;
//
//     for (var driverDist in driversDist) {
//       double distDiff = calcDistance(
//         userDist.latitude,
//         userDist.longitude,
//         driverDist?['lat'],
//         driverDist?['lng'],
//       );
//       if (distDiff < minDistance) {
//         minDistance = distDiff;
//         closest = LatLng(driverDist?['lat'], driverDist?['lng']);
//         await SharedPref().setDriver(driverDist?['driverId']);
//
//       }
//
//     }
//     return closest;
//   }
//
//   void tryMe() async{
//     //String? id = await SharedPref().getUserId();
//     await Drivers().updateLocation(7.3912, 3.8848, "992817Mc55");
//   }
//
//
//   // ──────────────────────────────── UI BUILD ────────────────────────────────
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.white,
//       body: Stack(
//         children: [
//           // ─── Google Map ───────────────────────────────────────────
//           GoogleMap(
//             onMapCreated: (controller) => mapController = controller,
//             initialCameraPosition: CameraPosition(target: pickUpLocation, zoom: 12),
//             markers: markers,
//             polylines: polylines,
//           ),
//
//           // ─── Search Bars ──────────────────────────────────────────
//           Positioned(
//             top: 40,
//             left: 20,
//             right: 20,
//             child: Column(
//               children: [
//                 _buildSearchField(
//                   controller: pickupController,
//                   hint: "Pickup Location",
//                   icon: Icons.location_searching,
//                   isPickupField: true,
//                 ),
//                 const SizedBox(height: 10),
//                 _buildSearchField(
//                   controller: destinationController,
//                   hint: "Destination",
//                   icon: Icons.location_on,
//                   isPickupField: false,
//                 ),
//                 _buildPredictionsList(),
//               ],
//             ),
//           ),
//
//           // ─── Center Location Button ───────────────────────────────
//           Positioned(
//             bottom: 220,
//             right: 16,
//             child: FloatingActionButton(
//               backgroundColor: Colors.white,
//               onPressed: () => goToCurrentLocation(pickUpLocation),
//               child: Icon(Icons.location_searching, color: gold),
//             ),
//           ),
//
//           // ─── Bottom Sheet (Ride Options or Driver Info) ───────────
//           Align(
//             alignment: Alignment.bottomCenter,
//             child: Container(
//               padding: const EdgeInsets.all(16),
//               height: driverFound ? 180 : 100,
//               decoration: const BoxDecoration(
//                 color: Colors.white,
//                 borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
//                 boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
//               ),
//               child: driverFound ? _buildDriverInfo() : _buildFindRideButton(),
//             ),
//           ),
//         ],
//       ),
//       bottomNavigationBar: const ButtomNav(),
//     );
//   }
//
//   // ──────────────────────────────── UI HELPERS ────────────────────────────────
//   Widget _buildSearchField({
//     required TextEditingController controller,
//     required String hint,
//     required IconData icon,
//     required bool isPickupField,
//   }) {
//     return TextField(
//       controller: controller,
//       style: const TextStyle(color: Colors.black),
//       onChanged: (value) {
//         setState(() => isPickup = isPickupField);
//         if (value.isNotEmpty) {
//           autoCompleteSearch(value);
//         } else {
//           setState(() => predictions = []);
//         }
//       },
//       decoration: InputDecoration(
//         hintText: hint,
//         prefixIcon: Icon(icon, color: gold),
//         filled: true,
//         fillColor: Colors.white,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: BorderSide.none,
//         ),
//         contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
//       ),
//     );
//   }
//
//   Widget _buildPredictionsList() {
//     return SizedBox(
//       height: 200,
//       child: ListView.builder(
//         shrinkWrap: true,
//         itemCount: predictions.length,
//         itemBuilder: (context, index) {
//           return ListTile(
//             leading: const Icon(Icons.location_on, color: Colors.black),
//             title: Text(predictions[index].description ?? ""),
//             onTap: () async {
//               var placeId = predictions[index].placeId;
//               if (placeId == null) return;
//
//               LatLng? newLocation = await convertLoc(placeId);
//               if (newLocation == null) return;
//
//               setState(() {
//                 if (isPickup) {
//                   pickupController.text = predictions[index].description ?? "";
//                   pickUpLocation = newLocation;
//                   markers.removeWhere((m) => m.markerId.value == "Pickup");
//                   markers.add(Marker(
//                     markerId: const MarkerId("Pickup"),
//                     position: newLocation,
//                     infoWindow: const InfoWindow(title: "Pickup"),
//                     icon: pickupIcon,
//                   ));
//                 } else {
//                   destinationController.text = predictions[index].description ?? "";
//                   destinationLoc = newLocation;
//                   markers.removeWhere((m) => m.markerId.value == "Destination");
//                   markers.add(Marker(
//                     markerId: const MarkerId("Destination"),
//                     position: newLocation,
//                     infoWindow: const InfoWindow(title: "Destination"),
//                     icon: destinationIcon,
//                   ));
//                 }
//                 predictions = [];
//               });
//
//               goToCurrentLocation(newLocation);
//               getRoute(pickUpLocation, destinationLoc);
//             },
//           );
//         },
//       ),
//     );
//   }
//
//   Widget _buildFindRideButton() {
//     return Column(
//       children: [
//         Container(
//           height: 4,
//           width: 50,
//           margin: const EdgeInsets.only(bottom: 12),
//           decoration: BoxDecoration(
//             color: Colors.grey[400],
//             borderRadius: BorderRadius.circular(10),
//           ),
//         ),
//         const Spacer(),
//         SizedBox(
//           width: double.infinity,
//           child: ElevatedButton(
//             style: ElevatedButton.styleFrom(
//               backgroundColor: gold,
//               foregroundColor: black,
//               padding: const EdgeInsets.symmetric(vertical: 14),
//               shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
//             ),
//             onPressed: () {
//               if (pickupController.text.isNotEmpty &&
//                   destinationController.text.isNotEmpty) {
//                 bookRide(context);
//                 setState(() => driverFound = true);
//               } else {
//                 showDialog(
//                   context: context,
//                   barrierDismissible: true,
//                   builder: (context) => AlertDialog(
//                     shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12)),
//                     title: const Text("Missing Information"),
//                     content:
//                     const Text("Please fill in both Pickup and Destination."),
//                     actions: [
//                       TextButton(
//                         onPressed: () => Navigator.of(context).pop(),
//                         child: const Text("OK"),
//                       ),
//                     ],
//                   ),
//                 );
//               }
//             },
//             child: const Text(
//               "Find Ride",
//               style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
//             ),
//           ),
//         ),
//       ],
//     );
//   }
//
//   Widget _buildDriverInfo() {
//
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Row(
//           children: [
//             const CircleAvatar(
//               backgroundImage: AssetImage("assets/images/car1.jpg"),
//               radius: 25,
//             ),
//             const SizedBox(width: 10),
//             Expanded(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   Text(driverName,
//                       style: const TextStyle(
//                           fontSize: 16, fontWeight: FontWeight.bold)),
//                   Text(driverCar, style: const TextStyle(color: Colors.grey)),
//                 ],
//               ),
//             ),
//             IconButton(
//               icon: const Icon(Icons.phone, color: Colors.green),
//               onPressed: () {},
//             ),
//             IconButton(
//               icon: const Icon(Icons.message, color: Colors.blue),
//               onPressed: () {},
//             ),
//             IconButton(
//               icon: const Icon(Icons.person, color: Colors.black),
//               onPressed: () {},
//             ),
//           ],
//         ),
//       ],
//     );
//   }
// }
