// lib/pages/search/search_destination_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../../models/route_selection.dart';
import '../../../services/place_service.dart';
import '../../../viewmodel/maps/maps_viewmodel.dart';           // ← your existing MapViewModel

class SearchDestinationScreen extends StatefulWidget {
  final PlaceDetails? initialPickup;

  const SearchDestinationScreen({super.key, this.initialPickup});

  @override
  State<SearchDestinationScreen> createState() => _SearchDestinationScreenState();
}

class _SearchDestinationScreenState extends State<SearchDestinationScreen> {
  final _placesService = PlacesService();
  final _mapViewModel = MapViewModel();   // ← fully reusable

  final _originController = TextEditingController();
  final _destinationController = TextEditingController();
  final _stopOverController = TextEditingController();
  final _originFocus = FocusNode();
  final _destinationFocus = FocusNode();
  final _selectStopOverFocus = FocusNode();

  Timer? _debounce;
  List<PlaceSuggestion> _suggestions = [];
  bool _isLoading = false;

  PlaceDetails? _selectedOrigin;
  PlaceDetails? _selectedDestination;
  PlaceDetails? _selectedStopOver;
  final List<PlaceDetails> _selectedStopOvers = [];
  bool _isStopOver = false;
  String? _activeField;

  @override
  void initState() {
    super.initState();
    if (widget.initialPickup != null && widget.initialPickup!.address.isNotEmpty) {
      _selectedOrigin = widget.initialPickup;
      _originController.text = widget.initialPickup!.address;
    }

    _originFocus.addListener(() => _activeField = 'origin');
    _destinationFocus.addListener(() => _activeField = 'destination');
    _selectStopOverFocus.addListener(() => _activeField = 'stopOver');
  }

  @override
  void dispose() {
    _originController.dispose();
    _destinationController.dispose();
    _stopOverController.dispose();
    _originFocus.dispose();
    _destinationFocus.dispose();
    _selectStopOverFocus.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  // ==================== REUSABLE CURRENT LOCATION ====================
  Future<void> _useCurrentLocation() async {
    setState(() => _isLoading = true);

    try {
      // 1. Reuse your exact MapViewModel logic
      final Position? position = await _mapViewModel.getCurrentUserLocation();

      if (position == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not get current location')),
          );
        }
        return;
      }

      // 2. Get real address using the new reusable method
      final PlaceDetails? currentPlace =
      await _placesService.getPlaceFromCoordinates(position.latitude,position.longitude);

      if (currentPlace != null && mounted) {
        _selectedOrigin = currentPlace;
        _originController.text = currentPlace.address;

        // Nice UX: auto-focus destination
        FocusScope.of(context).requestFocus(_destinationFocus);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Location error: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ==================== YOUR EXISTING METHODS (unchanged) ====================
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


  void _clearLocationDetails(){
     _selectedOrigin = null;
     _selectedDestination = null;
     _selectedStopOver = null;
  }

  Future<void> _onSuggestionTapped(PlaceSuggestion suggestion) async {
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    final capturedActiveField = _activeField;


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

  final isValidCoordinate = details.location.latitude >= -90 &&
      details.location.latitude <= 90 &&
      details.location.longitude >= -180 &&
      details.location.longitude <= 180 &&
      !(details.location.latitude == 0 && details.location.longitude == 0);

  if (!isValidCoordinate) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Invalid location returned. Please try a different address.")),
      );
    }
    setState(() => _isLoading = false);
    return;
  }

  if (capturedActiveField == 'destination' && _selectedOrigin != null) {
    final isSameAsOrigin = (details.location.latitude - _selectedOrigin!.location.latitude).abs() < 0.0001 &&
        (details.location.longitude - _selectedOrigin!.location.longitude).abs() < 0.0001;

    if (isSameAsOrigin) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Destination cannot be the same as pickup location.")),
        );
      }
      setState(() => _isLoading = false);
      return;
    }
  }

  if (capturedActiveField == 'origin' && _selectedDestination != null) {
    final isSameAsDestination = (details.location.latitude - _selectedDestination!.location.latitude).abs() < 0.0001 &&
        (details.location.longitude - _selectedDestination!.location.longitude).abs() < 0.0001;

    if (isSameAsDestination) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Pickup cannot be the same as destination.")),
        );
      }
      setState(() => _isLoading = false);
      return;
    }
  }


    if (capturedActiveField == 'origin') {
      _selectedOrigin = details;
      _originController.text = details.address;
      FocusScope.of(context).requestFocus(_destinationFocus);
    } 
    
     if (capturedActiveField == 'destination') {
      _selectedDestination = details;
      _destinationController.text = details.address;
    }

      if (capturedActiveField == 'stopOver') {
      _selectedStopOver = details;
      _stopOverController.text = details.address;
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
    final canConfirm = _selectedOrigin != null && _selectedDestination != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Set Your Route', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
      ),
      backgroundColor: theme.scaffoldBackgroundColor,

      // Floating button at bottom-right
      floatingActionButton: FloatingActionButton(
        onPressed: _useCurrentLocation,
        backgroundColor: theme.primaryColor,
        tooltip: 'Use my current location',
         child: const Icon(Icons.my_location, color: Colors.white),
      ),

      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            color: theme.cardColor,
            child: Column(children: [
               Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Column(
                  children: [
                    Icon(Icons.trip_origin, color: theme.primaryColor, size: 28),
                    SizedBox(height: 40, child: DashedLine(color: Colors.grey.shade400)),
                    Icon(Icons.location_on, color: Colors.red.shade400, size: 28),
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
                          hintText: _selectedOrigin == null ? 'Your current location' : 'Pickup location',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        ),
                      ),
                      const SizedBox(height: 4),
                      const Divider(height: 1),
                      const SizedBox(height: 4),
                      TextField(
                        controller: _destinationController,
                        focusNode: _destinationFocus,
                        onChanged: _onSearchChanged,
                        textInputAction: TextInputAction.done,
                        decoration: const InputDecoration(
                          hintText: 'Where to?',
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 14),
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
         
                Column(
  children: [
    if (_isStopOver) ...[
      SizedBox(height: 10,),
      showStopsWidget(
        onSearchChanged: _onSearchChanged, 
        selectStopOverFocus: _selectStopOverFocus,
        stopOverController: _stopOverController),
    ] ,addStopsButton(theme:theme, isStopOver: (){

      if(_stopOverController.text.isNotEmpty && _selectedStopOver != null){
         setState((){
           _selectedStopOvers.add(_selectedStopOver!);
         });
         _stopOverController.text ="";
         _selectedStopOver = null;
         
      }


        setState(() {
         _isStopOver ?
          _isStopOver = false :
           _isStopOver = true
           ;
        });
      }),
  ],
          ),




            ],)
          ),
          
        
          if (_isLoading) const LinearProgressIndicator(),

          Expanded(
            child: ListView.separated(
              itemCount: _suggestions.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) {
                final suggestion = _suggestions[index];
                final parts = suggestion.description.split(',');
                final mainText = parts[0];
                final secondaryText = parts.length > 1 ? parts.sublist(1).join(',').trim() : '';

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: theme.primaryColor.withOpacity(0.15),
                    child: Icon(Icons.location_on, color: theme.primaryColor, size: 18),
                  ),
                  title: Text(mainText, style: const TextStyle(fontWeight: FontWeight.w600)),
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
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: !canConfirm
              ? null
              : () {
                
           
        final result = RouteSelectionResult(
              origin: _selectedOrigin!,
              destination: _selectedDestination!,
              stopOvers : _selectedStopOvers,

            );

              debugPrint("========== ROUTE ==========");
  debugPrint("Origin: ${result.origin.address}");

  for (int i = 0; i < result.stopOvers!.length; i++) {
    debugPrint("Stop ${i + 1}: ${result.stopOvers?[i].address}");
  }

  debugPrint("Destination: ${result.destination.address}");
  debugPrint("===========================");

            
            _clearLocationDetails();
            Navigator.of(context).pop(result);
            
          },
          child: const Text('Confirm Route', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      ),
    );
  }
}

//
Widget addStopsButton({ThemeData? theme, VoidCallback? isStopOver}){
  return  Row(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: theme?.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: isStopOver,
          child: const Text('Add Stop Overs', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ),
      )
    ],
  );
}

//Stop Over Widgets

Widget showStopsWidget({
  TextEditingController? stopOverController,
  FocusNode? selectStopOverFocus,
  void Function(String)? onSearchChanged,
  String? selectedStops,
  ThemeData? theme,
  }){
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 28),
    child: TextField(
                     controller: stopOverController,
                        focusNode: selectStopOverFocus,
                        onChanged: onSearchChanged,
                        textInputAction: TextInputAction.next,
                        decoration: InputDecoration(
                          hintText: selectedStops == null ? 'Choose Stop Overs' : 'Add Stop',
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                        ),
                      )
  );
}
// DashedLine helper (unchanged)
class DashedLine extends StatelessWidget {
  final double height;
  final Color color;
  const DashedLine({super.key, this.height = 1, this.color = Colors.black});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
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