

import '../services/place_service.dart';

class RouteSelectionResult {
  final PlaceDetails origin;
  final PlaceDetails destination;

  RouteSelectionResult({required this.origin, required this.destination});
}