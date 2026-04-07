import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TripETAService {
  static const String _apiKey = "AIzaSyBJIRixyDjY3bFicM3oG36yW0Vaj43FZWs";

  static Future<Map<String, dynamic>> getRemainingTimeAndDistance({
    required LatLng? currentDriverLocation,
    required LatLng? destination,
  }) async {
    if (currentDriverLocation == null || destination == null) {
      return _errorResult("Missing location data");
    }

    final origin = '${currentDriverLocation.latitude},${currentDriverLocation.longitude}';
    final dest = '${destination.latitude},${destination.longitude}';

    //final origin = '7.4133,3.8629';
    //final dest = '7.4220,3.8406';



    print("travelling $origin,$dest");
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/distancematrix/json'
          '?origins=$origin'
          '&destinations=$dest'
          '&mode=driving'
          '&traffic_model=best_guess'
          '&departure_time=now'
          '&key=$_apiKey',
    );

    try {
      final response = await http.get(url);

      if (response.statusCode != 200) {
        return _errorResult("HTTP error ${response.statusCode}");
      }

      final data = json.decode(response.body);

      // Uncomment for debugging if needed:
      // print("Distance Matrix Response: $data");



      if (data['status'] != 'OK') {
        return _errorResult(data['error_message'] ?? data['status'] ?? 'Unknown error');
      }

      final element = data['rows']?[0]?['elements']?[0];
      if (element == null || element['status'] != 'OK') {
        return _errorResult(element?['status'] ?? 'No element data');
      }

      if (element['status'] == 'ZERO_RESULTS' || element['status'] == 'NOT_FOUND') {
        return {
          'status': 'OK',
          'remainingTimeSeconds': 0,
          'remainingDistanceMiles': 0,
          'isAtDestination': true,
        };
      }

      // Safe parsing
      final durationInTraffic = element?['duration_in_traffic']?['value'] as int? ?? 0;
      final durationNormal = element?['duration']?['value'] as int? ?? 0;
      final durationSeconds = durationInTraffic > 0 ? durationInTraffic : durationNormal;

      final distanceMeters = element?['distance']?['value'] as int? ?? 0;


      return {
        'status': 'OK',
        'remainingTimeSeconds': durationSeconds,
        'remainingDistanceMiles': (distanceMeters * 0.0006214),
        'isAtDestination': false,
      };

    } catch (e, stack) {
      print('ETA Calculation Exception: $e');
      return _errorResult("Error here: ${e.toString()}");
    }
  }

  static Map<String, dynamic> _errorResult(String message) {
    return {
      'status': 'ERROR',
      'remainingTimeSeconds': 0,
      'remainingDistanceMiles': 0.0,
      'error': message,
    };
  }
}