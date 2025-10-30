import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:google_place/google_place.dart';
import 'package:leisureryde/methods/maprecord.dart';
import 'package:leisureryde/methods/rideconnect.dart';
import 'package:leisureryde/methods/sharedpref.dart';
import 'package:leisureryde/payment.dart';
import 'package:leisureryde/userspage/chat.dart';
import 'package:leisureryde/userspage/home.dart';
import 'package:leisureryde/widgets/requestlist.dart';
import 'package:random_string/random_string.dart';

class RideProcess extends StatefulWidget{
  const RideProcess({super.key});

  @override
  State<RideProcess> createState () =>  _RideProcessState();
}

class _RideProcessState extends State<RideProcess>{


  @override
  void initState(){
    super.initState();
    setDefault();
    //connectRoad(pickUpLocation!, destinationLoc!);

    BitmapDescriptor.asset(
      const ImageConfiguration(size: Size(48, 48)),
      "assets/images/driver.webp",
    ).then((driver) => driverIcon = driver);
  }

  BitmapDescriptor pickupIcon =
  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
  late BitmapDescriptor driverIcon = driverIcon;
  MapRecord mapRecord = MapRecord();
  GoogleMapController? mapController;
  bool isPickup = true;
  final TextEditingController pickupController = TextEditingController();
  final TextEditingController destinationController = TextEditingController();
  final Color gold = const Color(0xFFd4af37);
  final Color black = Colors.black;
  bool driverFound = false;
  String? driverId = "";
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};

   List<AutocompletePrediction>? predictions = [];
   List<LatLng> coordinates = [];

   LatLng? pickUpLocation;
   LatLng? destinationLoc;

Future<void> setDefault() async{
    final String check = await SharedPref().getBookStatus();
     driverId = await SharedPref().getDriver();

 if(check != "")  {
      Map<String,dynamic>? currentBook = await cMethods.checkMapState();

      driverFound = true;
      pickUpLocation = LatLng(currentBook?['pickup']['lat'], currentBook?['pickup']['lng']);
      destinationLoc = LatLng(currentBook?['destination']['lat'], currentBook?['destination']['lng']);
      availableDrivers  = await MapRecord().findAvailableDrivers();

        markers.removeWhere((m) => m.markerId.value == "Pickup");
        markers.add(Marker(
          markerId: const MarkerId("Pickup"),
          position: pickUpLocation!,
          infoWindow: const InfoWindow(title: "Pickup"),
          icon: pickupIcon,
        ));

        markers.removeWhere((m) => m.markerId.value == "Destination");
        markers.add(Marker(
          markerId: const MarkerId("Destination"),
          position: destinationLoc!,
          infoWindow: const InfoWindow(title: "Destination"),
          icon: destinationIcon,
        ));


    }else{
      driverFound = false;
    }



}



  void setPrediction(value) async{
      predictions = await MapRecord().autoCompleteSearch(value);
  }

  void connectRoad(start,end) async{
   List<LatLng> coordinates = await MapRecord().getRoute(start, end);
    setState(() {
      polylines.clear();
      polylines.add(
       Polyline(
          polylineId: const PolylineId("route"),
          color: Colors.blue,
          width: 5,
          points: coordinates,
        ),
      );
    });
  }

  void goToCurrentLocation(LatLng location) {
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 14),
      ),
    );
  }

  void locateDriver(LatLng closestDriver){
    markers.add(
      Marker(
        markerId: const MarkerId("Driver"),
        position: closestDriver,
        icon: driverIcon,
        infoWindow: const InfoWindow(title: "Closest Driver"),
      ),
    );
  }

  List<Map<String,dynamic>?> availableDrivers=[];

  LatLng  closestDriver = LatLng(0.0, 0.0);

   String journeyDist = "";
   String journeyprice = "";


  void bookRide(BuildContext context) async {
    // show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    try {
      // simulate delay (e.g. for route calculation)
      await Future.delayed(const Duration(seconds: 3));
      Navigator.pop(context); // close dialog

      // get route details (distance, duration, etc.)
      final distance = await MapRecord().getRouteDetails(
        pickUpLocation!.latitude,
        pickUpLocation!.longitude,
        destinationLoc!.latitude,
        destinationLoc!.longitude,
      );

      if (distance != null && distance['distance_value'] != null) {
        final distanceInMeters = distance['distance_value']; // e.g. 12000
        final distanceInMiles = distanceInMeters / 1609.34;
        final roundedMiles = distanceInMiles.toStringAsFixed(2);

        // calculate price
        final price = distanceInMiles * 2000;
        final int priceInCents = (price * 100).toInt();
        final String priceString = priceInCents.toString();

        // 🔹 Check driver availability first
        bool driversAvailable = await MapRecord().checkAvailability();

        if (!driversAvailable) {
          // ❌ No drivers available, show message and return
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("No drivers are currently available. Please try again later."),
              backgroundColor: Colors.red,
            ),
          );
          return; // stop here, no payment
        }

        // ✅ If drivers are available, proceed to payment
        final bool paymentSuccess = await Payment().makePayment(priceString, "usd");

        if (paymentSuccess) {
          // update state only if payment and driver assignment succeed
          journeyDist = roundedMiles;
          journeyprice = priceString;

          availableDrivers = await MapRecord().findAvailableDrivers();
/*
         while(availableDrivers.isEmpty){
            availableDrivers = await MapRecord().findAvailableDrivers();
            if(availableDrivers.isNotEmpty){
              break;
            }
         }

*/
          setState(() {
            driverFound = true;
          });

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Ride booked successfully! Searching for a driver..."),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text("Payment failed. Please try again."),
              backgroundColor: Colors.red,
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Unable to calculate distance. Try again."),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      Navigator.pop(context);
      print('Error booking ride: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Error: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }



  @override
  Widget build(BuildContext context) {
   return Scaffold(
              backgroundColor: Colors.white,
              body: driverFound ?  _buildDriverInfo() : _mapStatic(),
            );

  }


  Widget _buildSearchField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    required bool isPickupField,
  }) {
    return TextField(
      controller: controller,
      style: const TextStyle(color: Colors.black),
      onChanged: (value) {
        setState(() => isPickup = isPickupField);
        if (value.isNotEmpty) {
          setPrediction(value);
        }
      },
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon, color: gold),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      ),
    );
  }


  Widget _buildPredictionsList() {
    return SizedBox(
      height: 200,
      child: ListView.builder(
        shrinkWrap: true,
        itemCount: predictions?.length,
        itemBuilder: (context, index) {
          return ListTile(
            leading: const Icon(Icons.location_on, color: Colors.black),
            title: Text(predictions?[index].description ?? ""),
            onTap: () async {
              var placeId = predictions?[index].placeId;
              if (placeId == null) return;
              LatLng? newLocation = await MapRecord().convertLoc(placeId);
              if (newLocation == null) return;
              setState(() {
                if (isPickup) {
                  pickupController.text = predictions?[index].description ?? "";
                  pickUpLocation = newLocation;
                  markers.removeWhere((m) => m.markerId.value == "Pickup");
                  markers.add(Marker(
                    markerId: const MarkerId("Pickup"),
                    position: newLocation,
                    infoWindow: const InfoWindow(title: "Pickup"),
                    icon: pickupIcon,
                  ));
                } else {
                  destinationController.text = predictions?[index].description ?? "";
                  destinationLoc = newLocation;
                  markers.removeWhere((m) => m.markerId.value == "Destination");
                  markers.add(Marker(
                    markerId: const MarkerId("Destination"),
                    position: newLocation,
                    infoWindow: const InfoWindow(title: "Destination"),
                    icon: destinationIcon,
                  ));
                }
                predictions = [];
              });

              goToCurrentLocation(newLocation);
              connectRoad(pickUpLocation, destinationLoc);
                }
                );

            },
          )
    );
        }


  Widget _buildFindRideButton() {
    return Column(
      children: [
        Container(
          height: 4,
          width: 50,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.grey[400],
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        const Spacer(),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: gold,
              foregroundColor: black,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              //driverFound = true;
              if (pickupController.text.isNotEmpty &&
                  destinationController.text.isNotEmpty) {
                setState(() {
                  req = true;
                });



                bookRide(context);

                //pickupController.text = "";
                //destinationController.text = "";
              } else {
                showDialog(
                  context: context,
                  barrierDismissible: true,
                  builder: (context) => AlertDialog(
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    title: const Text("Missing Information"),
                    content:
                    const Text("Please fill in both Pickup and Destination."),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text("OK"),
                      ),
                    ],
                  ),
                );
              }
            },
            child: const Text(
              "Find Ride",
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ),
        ),
      ],
    );
  }

  var req = true;
  Widget _buildDriverInfo() {
    return FutureBuilder<Map<String,dynamic>?>(
        future: MapRecord().findDrivers(pickUpLocation!, availableDrivers),
        builder: (context,snapshot){
           if (snapshot.hasData && snapshot.data != null) {
           final data = snapshot.data!;
             closestDriver= data['location'];
             locateDriver(closestDriver);

             var pickup = {
               "lat" : pickUpLocation?.latitude,
               "lng" : pickUpLocation?.longitude
             };

          var destination = {
            "lat" : destinationLoc?.latitude,
            "lng" : destinationLoc?.longitude
          };


          if(req) {
            String reqId = randomAlphaNumeric(10);
            ConnectRide().connectADriver(reqId,
                data['driverInfo'], pickup, destination,journeyprice,journeyDist);
              req = false;
            }
            return _mapMoving(data['driverInfo']);

          } else {
          return  Center(
            child: CircularProgressIndicator()
          );
          }
        }
    );
  }



  Widget _changeDriver(String rideId){
   return StreamBuilder<Map<String,dynamic>?>(
      stream: ConnectRide().driverOnWay(rideId),
      builder: (context,snapshot){
        final rideStatus = snapshot.data;
      if(rideStatus != null){
        print(rideStatus);
        return Center();
      }else{
        return CircularProgressIndicator();
      }

      },
    );
  }

  Widget _driverProfile(String id){

    return FutureBuilder<Map<String,dynamic>?>(
        future: cMethods.getProfile(id),
        builder: (context,snapshot) {
       if (snapshot.hasData && snapshot.data != null) {
            final data = snapshot.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const CircleAvatar(
                      backgroundImage: AssetImage("assets/images/car1.jpg"),
                      radius: 25,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(data['username'],
                              style: const TextStyle(
                                  fontSize: 16, fontWeight: FontWeight.bold)),
                          Text(data['phone'], style: const TextStyle(color: Colors.grey)),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.phone, color: Colors.green),
                      onPressed: () {},
                    ),
                    IconButton(
                      icon: const Icon(Icons.message, color: Colors.blue),
                      onPressed: () {
                        Navigator.push(context, MaterialPageRoute(builder: (c) =>
                            ChatScreen(
                          receiverName : data['username'],
                           receiverId: id,
                        ) ));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.person, color: Colors.black),
                      onPressed: () {},
                    ),
                  ],
                ),
                SizedBox(height: 15,),
                _journeyMovement(id)
                ,

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // 🟢 Start Journey Button
                    ElevatedButton.icon(
                      onPressed: () {

                      },
                      icon: const Icon(Icons.play_arrow),
                      label: const Text("Driver Arrived"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: gold,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),

                    // 🕓 Driver minutes away
                    Column(
                      children: [
                       /* const Icon(Icons.access_time, color: Colors.blueGrey),*/
                        _showDetails(),
                      ],
                    ),

                    // 🔴 End Journey Button
                    ElevatedButton.icon(
                      onPressed: () {
                        SharedPref().bookState("");
                        Navigator.push(context, MaterialPageRoute(builder: (c) => HomePage()));
                      },
                      icon: const Icon(Icons.stop),
                      label: const Text("Cancel Ride"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                )

              ],
            );
          }else{
            return const Center(child: Text('No driver data found.'));
          }
        }
    );

  }


  Widget _journeyMovement(rideId){

    return StreamBuilder<Map<String,dynamic>?>(
      stream:ConnectRide().driverOnWay(rideId) ,
      builder:(context,snapshot){
        final data = snapshot.data;
        print("Data status: ${data?['status']}  : $data");

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Journey Status: ", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),),
            Text("${data?['status']}",style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),)
          ],
        );

      }
    );
  }


  Widget _showDetails(){

    return FutureBuilder<Map<String,dynamic>?>(
        future: MapRecord().getRouteDetails(pickUpLocation!.latitude, pickUpLocation!.longitude,
            destinationLoc!.latitude, destinationLoc!.longitude),
        builder: (context,snapshot){
          if(snapshot.hasData && snapshot.data != null){
            final data = snapshot.data;
            return Column(
              children: [
                Text("${data?['distance_value']} m",style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),),

                Text("${data?['duration_text']}",style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),)
              ],
            );

          }else{
            return CircularProgressIndicator();
          }
        }
    );

  }

  Widget _mapStatic(){
    return  Stack(
      children: [
        FutureBuilder<Map<String,dynamic>?>(
            future: MapRecord().findMe(),
            builder: (context,snapshot){
              if(snapshot.hasData && snapshot.data != null) {
                final location = snapshot.data;

                return GoogleMap(
                  onMapCreated: (controller) => mapController = controller,
                  initialCameraPosition: CameraPosition(
                      target: mapRecord.pickup(
                          location?['lat'], location?['lng']),
                      zoom: 12
                  ),
                  markers: markers,
                  polylines: polylines,
                );

              }else{
                return Center(child: CircularProgressIndicator());
              }
            }
        ),
        Positioned(
            top: 40,
            left: 20,
            right: 20,
            child: Column(
              children: [
                _buildSearchField(
                  controller: pickupController,
                  hint: "Pickup Location",
                  icon: Icons.location_searching,
                  isPickupField: true,
                ),
                const SizedBox(height: 10),
                _buildSearchField(
                  controller: destinationController,
                  hint: "Destination",
                  icon: Icons.location_on,
                  isPickupField: false,
                ),
                _buildPredictionsList()
              ],
            )
        ),

        Positioned(
          bottom: 220,
          right: 16,
          child: FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: ()async{
              String? id =  await SharedPref().getUserId();
              MapRecord().setMyLocation(id!);
            },
            child: Icon(Icons.location_searching, color: gold),
          ),
        ),

        Align(
          alignment: Alignment.bottomCenter,
          child: Container(
            padding: const EdgeInsets.all(16),
            height: driverFound ? 180 : 100,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
            ),
            child: _buildFindRideButton(),
          ),
        ),
      ],
    );
  }


  Widget _mapMoving(String? id){

    return Stack(
        children: [

      FutureBuilder<Map<String,dynamic>?>(
        future: MapRecord().getUserLocation(id),
        builder: (context,snapshot){
          if(snapshot.hasData && snapshot.data != null) {
            final location = snapshot.data;
            return GoogleMap(
              onMapCreated: (controller) => mapController = controller,
              initialCameraPosition: CameraPosition(
                  target: mapRecord.pickup(location?['lat'], location?['lng']),
                  zoom: 12
              ),
              markers: markers,
              polylines: polylines,
            );
          }else{
            return Center(
              child: CircularProgressIndicator()
            );
          }
        }
    ),

          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              padding: const EdgeInsets.all(16),
              height: driverFound ? 180 : 100,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
              ),
              child: _driverProfile(id!)
            ),
          ),



    ]);
  }


}