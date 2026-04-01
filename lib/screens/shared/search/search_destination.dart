// lib/pages/search/search_destination_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';

import '../../../models/route_selection.dart';
import '../../../services/place_service.dart';

class SearchDestinationScreen extends StatefulWidget {
  final PlaceDetails? initialPickup;

  const SearchDestinationScreen({super.key, this.initialPickup});

  @override
  State<SearchDestinationScreen> createState() => _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends State<SearchDestinationScreen> {
  final _placesService = PlacesService();
  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;

  PlaceDetails? _selectedOrigin;
  PlaceDetails? _selectedDestination;
  String? _activeField; // "origin" or "destination"

  @override
  void initState() {
    super.initState();

    /// Pre‑fill with pickup only if we actually have one.
    if (widget.initialPickup != null &&
        widget.initialPickup!.address.isNotEmpty) {
      _selectedOrigin = widget.initialPickup;
      _originController.text = widget.initialPickup!.address;
    }

    /// Listen for focus changes
    _originFocus.addListener(() {
      if (_originFocus.hasFocus) {
        _activeField = 'origin';
      }
    });
    _destinationFocus.addListener(() {
      if (_destinationFocus.hasFocus) {
        _activeField = 'destination';
      }
    });
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String input) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () async {
      if (input.length > 2) {
        setState(() => _isLoading = true);
        final results = await _placesService.getAutocomplete(input);
        if (mounted) {
          setState(() {
            _suggestions = results;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _suggestions = []);
      }
    });
  }

  Future<void> _onSuggestionTapped(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final details = await _placesService.getPlaceDetails(suggestion.placeId);
    if (details == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Could not get location details.")),
        );
      }
      setState(() => _isLoading = false);
      return;
    }

    if (_activeField == 'origin') {
      _selectedOrigin = details;
      _originController.text = details.address;
      FocusScope.of(context).requestFocus(_destinationFocus);
    } else if (_activeField == 'destination') {
      _selectedDestination = details;
      _destinationController.text = details.address;
    }

    setState(() {
      _suggestions = [];
      _isLoading = false;
    });
  }

  void _swapLocations() {
    final tempPlace = _selectedOrigin;
    _selectedOrigin = _selectedDestination;
    _selectedDestination = tempPlace;

    final tempText = _originController.text;
    _originController.text = _destinationController.text;
    _destinationController.text = tempText;

    if (_originController.text.isEmpty || _destinationController.text.isEmpty) {
      setState(() => _suggestions = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final canConfirm =
        _selectedOrigin != null && _selectedDestination != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Set Your Route',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: theme.cardColor,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(Icons.trip_origin, color: theme.primaryColor, size: 28),
                    SizedBox(
                      height: 40,
                      child: DashedLine(color: Colors.grey.shade400),
                    ),
                    Icon(Icons.location_on,
                        color: Colors.red.shade400, size: 28),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    children: [
                      TextField(
                        controller: _originController,
                        focusNode: _originFocus,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: _selectedOrigin == null
                              ? 'Your current location'
                              : 'Pickup location',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                        ),
                      ),
                      SizedBox(height: 4,),
                      const Divider(height: 1),
                      SizedBox(height: 4,),

                      TextField(
                        controller: _destinationController,
                        focusNode: _destinationFocus,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'Where to?',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.swap_vert, color: Colors.grey),
                  tooltip: 'Swap pickup & destination',
                  onPressed: _swapLocations,
                ),
              ],
            ),
          ),

          if (_isLoading) const LinearProgressIndicator(),

          Expanded(
            child: ListView.separated(
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) =>
              const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                final parts = suggestion.description.split(',');
                final mainText = parts[0];
                final secondaryText = parts.length > 1
                    ? parts.sublist(1).join(',').trim()
                    : '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.15),
                    child: Icon(Icons.location_on,
                        color: theme.primaryColor, size: 18),
                  ),
                  title: Text(
                    mainText,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(secondaryText),
                  onTap: () => _onSuggestionTapped(suggestion),
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: !canConfirm
              ? null
              : () {
            final result = RouteSelectionResult(
              origin: _selectedOrigin!,
              destination: _selectedDestination!,
            );
            Navigator.of(context).pop(result);
          },
          child: const Text(
            'Confirm Route',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

/// Helper widget for dashed line between the origin and destination icons
class DashedLine extends StatelessWidget {
  final double height;
  final Color color;
  const DashedLine({super.key, this.height = 1, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxHeight = constraints.constrainHeight();
        const dashWidth = 5.0;
        final dashHeight = height;
        final dashCount = (boxHeight / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.vertical,
          children: List.generate(dashCount, (_) {
            return SizedBox(
              width: dashHeight,
              height: dashWidth,
              child: DecoratedBox(decoration: BoxDecoration(color: color)),
            );
          }),
        );
      },
    );
  }
}