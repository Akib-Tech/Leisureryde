import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:firebase_database/firebase_database.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:google_place/google_place.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:leisureryde/methods/sharedpref.dart';
import 'package:leisureryde/widgets/requestlist.dart';
import '../globa/global_var.dart';
import 'driversmethod.dart';

class MapRecord{

  GooglePlace googlePlace = GooglePlace(googleMapKey);
  GoogleMapController? mapController;

  List<LatLng> polylineCoordinates = [];
  Set<Polyline> polylines = {};

  LatLng pickup(lat,lng){
      return LatLng(lat, lng);
  }

  LatLng? _currentLocation;
  StreamSubscription<Position>? _positionStream;

  void setMyLocation(String id){

    const LocationSettings locationSettings = LocationSettings(
      accuracy: LocationAccuracy.high,
      distanceFilter: 100,
    );


    _positionStream = Geolocator.getPositionStream(locationSettings: locationSettings)
        .listen((Position? position) {
      if (position == null) return;
        _currentLocation = LatLng(position.latitude, position.longitude);


    DatabaseReference locationRef =    cMethods.dBase.ref().child("driverlocation").child(id);
        locationRef.set({
          "lat" : _currentLocation?.latitude,
          "lng" : _currentLocation?.longitude,
          "driverId" : id,
        });

    });
   }



  void checkLocationPermissions(id) async {
    await _positionStream?.cancel();

    LocationPermission permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      print("Permission denied");
      permission = await Geolocator.requestPermission();
    } else if (permission == LocationPermission.whileInUse
        || permission == LocationPermission.always) {
        setMyLocation(id);
        print("Position set");
    } else {
        print("❌ Location permissions not granted.");
    }


  }


  Future<List<AutocompletePrediction>?> autoCompleteSearch(String value) async {
    var result = await googlePlace.autocomplete.get(value);
      return result?.predictions;
  }

  Future<LatLng?> convertLoc(String placeId) async {
    var details = await googlePlace.details.get(placeId);
    if (details != null &&
        details.result != null &&
        details.result!.geometry != null) {
      var loc = details.result!.geometry!.location;
      return LatLng(loc!.lat!, loc.lng!);
    }
    return null;
  }



  void goToCurrentLocation(LatLng location) {
    mapController?.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(target: location, zoom: 14),
      ),
    );
  }

  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    PolylinePoints polylinePoints = PolylinePoints();

    final result = await polylinePoints.getRouteBetweenCoordinates(
      googleMapKey,
      PointLatLng(end.latitude, end.longitude),
      PointLatLng(start.latitude, start.longitude),
      travelMode: TravelMode.driving,
    );

    if (result.points.isNotEmpty) {
      polylineCoordinates.clear();
      for (var point in result.points) {
        polylineCoordinates.add(LatLng(point.latitude, point.longitude));
      }
    }

    return polylineCoordinates;
  }


  double calcDistance(lat1, lon1, lat2, lon2) {
    const p = pi / 180;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) * cos(lat2 * p) * (1 - cos((lon2 - lon1) * p)) / 2;

    return 12742 * asin(sqrt(a));
  }

  Future<Map<String,dynamic>?> findDrivers(LatLng userDist, List<Map<String,dynamic>?> driversDist) async {
    double minDistance = double.infinity;
     LatLng? closest;
     Map<String,dynamic> result = {};

    while(true) {
      for (var driverDist in driversDist) {
        double distDiff = calculateDistance(
          userDist.latitude,
          userDist.longitude,
          driverDist?['lat'],
          driverDist?['lng'],
        );
        if (distDiff <= minDistance) {
          minDistance = distDiff;
          closest = LatLng(driverDist?['lat'], driverDist?['lng']);
          result = {
            "driverInfo": driverDist?['driver'],
            "location": closest
          };
        }
      }
      return result;

      await Future.delayed(const Duration(seconds: 3));

    }

  }

  Future<List<Map<String,dynamic>?>> findAvailableDrivers() async{
    List<Map<String,dynamic>?> driverCoordinates = await Drivers().fetchLocation();

    return driverCoordinates;
  }

  
  Future<Map<String,dynamic>?> getUserLocation(String? id) async{
      DatabaseReference userLocDb =  cMethods.dBase.ref().child("driverlocation").child(id!);
      final fetchLoc = await userLocDb.get();
      Map<String,dynamic>? result = Map<String,dynamic>.from(fetchLoc.value as Map);
     return {
        "lat" : result['lat'],
        "lng" : result['lng']
      };
  }



  Future<Map<String,dynamic>?> findMe()async {
    final position = await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );

    // Build and return the result
    return {
      "lat": position.latitude,
      "lng": position.longitude,
    };

  }



  double calculateDistance(double startLatitude, double startLongitude, double endLatitude, double endLongitude) {
    const double earthRadius = 6371.0;

    double dLat = _degreesToRadians(endLatitude - startLatitude);
    double dLon = _degreesToRadians(endLongitude - startLongitude);

    double a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_degreesToRadians(startLatitude)) *
            cos(_degreesToRadians(endLatitude)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    double c = 2 * atan2(sqrt(a), sqrt(1 - a));

    return earthRadius * c;
  }

  double _degreesToRadians(double degrees) {
    return degrees * pi / 180;
  }



  Future<Map<String, dynamic>?> getRouteDetails(
     double originLat,
     double originLng,
     double destLat,
     double destLng,
  ) async {
    final url = Uri.parse(
      "https://maps.googleapis.com/maps/api/directions/json"
          "?origin=$originLat,$originLng"
          "&destination=$destLat,$destLng"
          "&key=$googleMapKey",
    );

    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);

      if (data['status'] == 'OK') {
        final route = data['routes'][0];
        final leg = route['legs'][0];

        return {
          'polyline': route['overview_polyline']['points'],
          'distance_text': leg['distance']['text'], // "12.3 km"
          'distance_value': leg['distance']['value'], // meters
          'duration_text': leg['duration']['text'],   // "18 mins"
          'duration_value': leg['duration']['value'], // seconds
        };
      }
    }

    return null;
  }






}