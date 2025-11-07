import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

class PlacesService {
  static const String _apiKey = "AIzaSyBJIRixyDjY3bFicM3oG36yW0Vaj43FZWs";
  String _sessionToken = const Uuid().v4();

  Future<List<PlaceSuggestion>> getAutocomplete(String input) async {
    if (input.isEmpty) return [];

    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
          '?input=$input&key=$_apiKey&sessiontoken=$_sessionToken'
          '&components=country:us', // Optional: Restrict to a country
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          return (data['predictions'] as List)
              .map((p) => PlaceSuggestion.fromJson(p))
              .toList();
        }
      }
    } catch (e) {
      print("Autocomplete error: $e");
    }
    return [];
  }

  Future<PlaceDetails?> getPlaceDetails(String placeId) async {
    final url = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId&key=$_apiKey&sessiontoken=$_sessionToken'
          '&fields=name,formatted_address,geometry',
    );

    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['status'] == 'OK') {
          // Reset session token after a successful details call
          _sessionToken = const Uuid().v4();
          return PlaceDetails.fromJson(data['result']);
        }
      }
    } catch (e) {
      print("Place details error: $e");
    }
    return null;
  }
}

class PlaceSuggestion {
  final String placeId;
  final String description;
  PlaceSuggestion({required this.placeId, required this.description});
  factory PlaceSuggestion.fromJson(Map<String, dynamic> json) {
    return PlaceSuggestion(
      placeId: json['place_id'],
      description: json['description'],
    );
  }
}

class PlaceDetails {
  final String name;
  final String address;
  final LatLng location;
  PlaceDetails({required this.name, required this.address, required this.location});
  factory PlaceDetails.fromJson(Map<String, dynamic> json) {
    return PlaceDetails(
      name: json['name'],
      address: json['formatted_address'],
      location: LatLng(
        json['geometry']['location']['lat'],
        json['geometry']['location']['lng'],
      ),
    );
  }
}