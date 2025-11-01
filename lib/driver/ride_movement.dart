import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/methods/driversmethod.dart';

import '../methods/maprecord.dart';
import '../methods/sharedpref.dart';

class RideMovement extends StatefulWidget{
  const RideMovement({super.key});

  @override
  State<RideMovement> createState()=> _RideMovementState();
}

class _RideMovementState extends State<RideMovement>{
  @override
  void initState() {
    super.initState();
  }


  final Color gold = const Color(0xFFd4af37);
  final Color black = Colors.black;
  BitmapDescriptor pickupIcon =
  BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueBlue);
  BitmapDescriptor destinationIcon = BitmapDescriptor.defaultMarker;
  late BitmapDescriptor driverIcon = driverIcon;
  MapRecord mapRecord = MapRecord();
  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Set<Polyline> polylines = {};
  List<LatLng> coordinates = [];
  final status = false;


  setCoordinate(coordinate){
      polylines.clear();
      polylines.add(
        Polyline(
          polylineId: const PolylineId("route"),
          color: Colors.blue,
          width: 5,
          points: coordinate,
        ),
      );
  }


  @override
  Widget build(BuildContext context) {

      return Scaffold(
        body:  status ? _mapStatic() : _mapMoving()
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
            height:  180,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
            ),
            child: Center(),
          ),
        ),
      ],
    );
  }


  Widget _mapMoving(){

    return Stack(
        children: [
          FutureBuilder<Map<String,dynamic>?>(
              future: Drivers().movement(),
              builder: (context,snapshot){
                if(snapshot.hasData && snapshot.data != null) {
                  final location = snapshot.data;

                  markers.removeWhere((m) => m.markerId.value == "Pickup");
                  markers.add(Marker(
                    markerId: const MarkerId("Pickup"),
                    position: mapRecord.pickup(location?['pickup']['lat'], location?['pickup']['lng']),
                    infoWindow: const InfoWindow(title: "Pickup"),
                    icon: pickupIcon,
                  ));


                  markers.removeWhere((m) => m.markerId.value == "Destination");
                  markers.add(Marker(
                    markerId: const MarkerId("Destination"),
                    position:mapRecord.pickup(location?['destination']['lat'], location?['destination']['lng']),
                    infoWindow: const InfoWindow(title: "Destination"),
                    icon: destinationIcon,
                  ));


                MapRecord().getRoute(
                      LatLng(location?['pickup']['lat'], location?['pickup']['lng']),
                      LatLng(location?['destination']['lat'], location?['destination']['lng']));


              return  FutureBuilder<List<LatLng>> (
                  future:  MapRecord().getRoute(
                      LatLng(location?['pickup']['lat'], location?['pickup']['lng']),
                      LatLng(location?['destination']['lat'], location?['destination']['lng'])),
                  builder: (context,snapshot){
                    if(snapshot.hasData && snapshot.data !=null){
                        coordinates = snapshot.data!;
                        setCoordinate(coordinates);
                        return GoogleMap(
                          onMapCreated: (controller) => mapController = controller,
                          initialCameraPosition: CameraPosition(
                              target: mapRecord.pickup(location?['destination']['lat'], location?['destination']['lng']),
                              zoom: 12
                          ),
                          markers: markers,
                          polylines: polylines,
                        );
                    }else{
                      return CircularProgressIndicator();
                    }
                  }

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
                height: 180,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                  boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 10, spreadRadius: 2)],
                ),
                child: Center()
            ),
          ),

        ]);
  }
}