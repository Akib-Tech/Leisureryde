import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';

import '../../services/place_service.dart';

class SearchViewModel extends ChangeNotifier {
  final PlacesService _placesService = locator<PlacesService>();

  List<PlaceSuggestion> _suggestions = [];
  List<PlaceSuggestion> get suggestions => _suggestions;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> search(String input) async {
    _isLoading = true;
    notifyListeners();

    _suggestions = await _placesService.getAutocomplete(input);

    _isLoading = false;
    notifyListeners();
  }

  Future<PlaceDetails?> selectSuggestion(String placeId) async {
    return await _placesService.getPlaceDetails(placeId);
  }
}