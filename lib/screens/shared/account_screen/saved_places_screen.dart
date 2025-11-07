
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../models/saved_places.dart';
import '../../../services/place_service.dart';

class AddSavedPlaceScreen extends StatefulWidget {
  final String placeType; // 'Home' or 'Work'

  const AddSavedPlaceScreen({super.key, required this.placeType});

  @override
  State<AddSavedPlaceScreen> createState() => _AddSavedPlaceScreenState();
}

class _AddSavedPlaceScreenState extends State<AddSavedPlaceScreen> {
  final TextEditingController _searchController = TextEditingController();
  final PlacesService _placesService = PlacesService();

  List<PlaceSuggestion> _suggestions = [];
  Timer? _debounce;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Add a listener to the controller to trigger the search
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  /// Called whenever the user types in the search field.
  /// It uses a debounce to avoid making an API call on every keystroke.
  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      if (_searchController.text.length > 2) {
        _getAutocompleteSuggestions(_searchController.text);
      } else {
        // Clear suggestions if the search text is too short
        if (mounted) setState(() => _suggestions = []);
      }
    });
  }

  /// Fetches autocomplete suggestions from the PlacesService.
  Future<void> _getAutocompleteSuggestions(String input) async {
    try {
      final results = await _placesService.getAutocomplete(input);
      if (mounted) {
        setState(() {
          _suggestions = results;
        });
      }
    } catch (e) {
      print("Error fetching autocomplete: $e");
      // Optionally show a snackbar here
    }
  }

  /// Called when a user taps on a suggestion tile.
  /// It fetches the full place details and returns the result to the previous screen.
  Future<void> _onPlaceSelected(PlaceSuggestion suggestion) async {
    if (mounted) setState(() => _isLoading = true);

    try {
      final placeDetails = await _placesService.getPlaceDetails(suggestion.placeId);

      if (placeDetails != null) {
        final newPlace = SavedPlace(
          id: widget.placeType, // Use the type ('Home' or 'Work') as the ID
          name: widget.placeType,
          address: placeDetails.address,
          latitude: placeDetails.location.latitude,
          longitude: placeDetails.location.longitude,
        );

        // Pop the screen and return the newly created SavedPlace object
        if (mounted) Navigator.of(context).pop(newPlace);

      } else {
        // Handle case where details could not be fetched
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get location details. Please try again.')),
          );
        }
      }
    } catch (e) {
      print("Error getting place details: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Set ${widget.placeType} Location', style: TextStyle(color: Theme.of(context).textTheme.bodySmall!.color),),
        leading: IconButton(onPressed: () => Navigator.pop(context), icon:  Icon(Icons.arrow_back_ios, color: Theme.of(context).textTheme.bodySmall!.color,)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 1,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'Enter address or place name',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.shade300),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Theme.of(context).primaryColor),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: _suggestions.length,
                  itemBuilder: (context, index) {
                    final suggestion = _suggestions[index];
                    return Column(
                      children: [
                        ListTile(
                          leading: const Icon(Icons.location_on_outlined),
                          title: Text(
                            suggestion.description.split(',')[0], // Main text
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            suggestion.description.substring(
                                suggestion.description.indexOf(',') + 1).trim(), // Secondary text
                          ),
                          onTap: () => _onPlaceSelected(suggestion),
                        ),
                        const Divider(height: 1, indent: 16, endIndent: 16),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          // Loading Overlay
          if (_isLoading)
            Container(
              color: Colors.black.withOpacity(0.5),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                    SizedBox(height: 16),
                    Text(
                      'Saving Location...',
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}