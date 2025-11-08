// lib/screens/user/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../models/route_selection.dart';
import '../../../models/user_profile.dart';
import '../../../services/place_service.dart'; // For PlaceDetails
import '../../../viewmodel/home/home_view_model.dart'; // Your HomeViewModel
import '../../../widgets/custom_loading_indicator.dart';
import '../../shared/account_screen/saved_places_screen.dart'; // For AddSavedPlaceScreen
import '../../shared/search/search_destination.dart';
import '../trip/active_trip_screen.dart';
import '../trip/finding_driver.dart'; // Your FindingDriverCard

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(),
      child: Scaffold(
        body: Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading || viewModel.mapViewModel.isLoading) {
              return const CustomLoadingIndicator();
            }
            if (viewModel.userProfile == null) {
              return const Center(child: Text("Could not load user profile."));
            }
            if (viewModel.mapViewModel.currentPosition == null) {
              return _buildLocationError(context, viewModel);
            }
            return Stack(
              children: [
                _buildMap(context, viewModel),
                _buildHeader(context, viewModel.userProfile!),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 250),
                    switchInCurve: Curves.easeInOut,
                    switchOutCurve: Curves.easeInOut,
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.2), // Slide up slightly from bottom
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    child: _buildBottomCardContent(context, viewModel),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildMap(BuildContext context, HomeViewModel viewModel) {
    double bottomPadding = 220; // Default for "Where To" card
    switch(viewModel.currentStep) {
      case HomeStep.initial:
        bottomPadding = viewModel.recentDestinations.isNotEmpty ? 320 : 220;
        break;
      case HomeStep.routePreview:
        bottomPadding = 280;
        break;
      case HomeStep.vehicleSelection:
        bottomPadding = 420;
        break;
      case HomeStep.payment:
        bottomPadding = 380; // Approximate height for payment card
        break;
      case HomeStep.findingDriver:
        bottomPadding = 260; // Approximate height for finding driver card
        break;
      case HomeStep.activeTrip:
        bottomPadding = 220; // Example height for active trip card
        break;
    }

    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          viewModel.mapViewModel.currentPosition!.latitude,
          viewModel.mapViewModel.currentPosition!.longitude,
        ),
        zoom: 15.0,
      ),
      onMapCreated: viewModel.mapViewModel.onMapCreated,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: {
        ...viewModel.mapViewModel.markers,
        ...viewModel.driverMarkers.values
      },
      polylines: viewModel.mapViewModel.polylines,
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 80,
        bottom: bottomPadding,
      ),
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile user) {
    final theme = Theme.of(context);
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: theme.scaffoldBackgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Hello,",
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
                    ),
                    Text(
                      user.firstName,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              CircleAvatar(
                radius: 22,
                backgroundColor: theme.primaryColor.withOpacity(0.1),
                backgroundImage: user.profileImageUrl.isNotEmpty
                    ? NetworkImage(user.profileImageUrl)
                    : null,
                child: user.profileImageUrl.isEmpty
                    ? Text(
                  user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                  style: TextStyle(color: theme.primaryColor, fontWeight: FontWeight.bold),
                )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomCardContent(BuildContext context, HomeViewModel viewModel) {
    switch (viewModel.currentStep) {
      case HomeStep.initial:
        return _buildWhereToCardContent(context, viewModel);
      case HomeStep.routePreview:
        return _buildRouteInfoCardContent(context, viewModel);
      case HomeStep.vehicleSelection:
        return _buildRideSelectionCardContent(context, viewModel);
      case HomeStep.payment:
        return _buildPaymentCardContent(context, viewModel);
      case HomeStep.findingDriver:
        return FindingDriverCard(key: const ValueKey('FindingDriverCard'), rideId: viewModel.currentRideId ?? '', onCancel: viewModel.cancelRide);
      case HomeStep.activeTrip:
        return ActiveTripCard(key: const ValueKey('ActiveTripCard'), rideId: viewModel.currentRideId ?? '');
    }
  }

  Widget _buildWhereToCardContent(BuildContext context, HomeViewModel viewModel) {
    final theme = Theme.of(context);
    return Container(
      key: const ValueKey('WhereToCard'),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () async {
              if (viewModel.mapViewModel.currentPosition == null) return;
              final initialPickup = PlaceDetails(
                name: "Current Location",
                address: "",
                location: LatLng(
                  viewModel.mapViewModel.currentPosition!.latitude,
                  viewModel.mapViewModel.currentPosition!.longitude,
                ),
              );
              final RouteSelectionResult? result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => SearchDestinationScreen(initialPickup: initialPickup)),
              );
              if (result != null) {
                // When SearchDestinationScreen returns a result, it should ideally
                // provide the full route details (duration, distance, etc.) if it
                // computed them. If not, HomeViewModel.selectRoute will call
                // mapViewModel.getDirections to get these.
                final actualResult = RouteSelectionResult(
                  origin: result.origin, // Always use current location as origin
                  destination: result.destination,
                  duration: result.duration,
                  distance: result.distance,
                  durationValue: result.durationValue,
                  distanceValue: result.distanceValue,
                  eta: result.eta,
                  polylinePoints: result.polylinePoints,
                );
                viewModel.selectRoute(result.origin, result.destination);
              }
            },
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: theme.primaryColor.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.search, color: theme.primaryColor, size: 24),
                  ),
                  const SizedBox(width: 16),
                  Text("Where to?", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios, color: theme.dividerColor, size: 16),
                ],
              ),
            ),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Row(
              children: [
                _buildQuickAction(context, icon: Icons.home, label: "Home", onTap: () => viewModel.selectSavedPlace(context, 'Home')),
                const SizedBox(width: 24),
                _buildQuickAction(context, icon: Icons.work, label: "Work", onTap: () => viewModel.selectSavedPlace(context, 'Work')),
              ],
            ),
          ),
          if (viewModel.recentDestinations.isNotEmpty) ...[
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Text("Recent", style: theme.textTheme.titleSmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7))),
            ),
            ...viewModel.recentDestinations.map((dest) => ListTile(
              leading: const Icon(Icons.history),
              title: Text(dest.address.split(',')[0], style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(dest.address, maxLines: 1, overflow: TextOverflow.ellipsis),
              onTap: () => viewModel.selectRecentDestination(dest),
            )),
          ]
        ],
      ),
    );
  }


  Widget _buildRouteInfoCardContent(BuildContext context, HomeViewModel viewModel) {
    final theme = Theme.of(context);
    final directions = viewModel.mapViewModel.directionsResult; // Removed '!'

    // CRITICAL FIX: Add null check for directions
    if (directions == null) {
      return Container(
        key: const ValueKey('LoadingRouteInfo'), // Unique key for AnimatedSwitcher
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(
              "Calculating route...",
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: viewModel.cancelRideSelection,
              child: const Text("Cancel"),
            ),
          ],
        ),
      );
    }

    // Now 'directions' is guaranteed to be non-null
    final etaTime = DateFormat.jm().format(directions.eta!); // eta is nullable, so use '!' after null check

    return Container(
      key: const ValueKey('RouteInfoCard'),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildRouteInfo(context, icon: Icons.access_time, label: "Trip ETA", value: etaTime),
                _buildRouteInfo(context, icon: Icons.directions_car, label: "Duration", value: directions.duration ?? 'N/A'),
                _buildRouteInfo(context, icon: Icons.straighten, label: "Distance", value: directions.distance ?? 'N/A'),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.location_on, color: theme.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        directions.endAddress,
                        style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          foregroundColor: theme.colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: viewModel.proceedToVehicleSelection,
                        child: const Text("Choose Your Ride", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(border: Border.all(color: theme.dividerColor), borderRadius: BorderRadius.circular(12)),
                      child: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: viewModel.cancelRideSelection,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }


  Widget _buildRideSelectionCardContent(BuildContext context, HomeViewModel viewModel) {
    final theme = Theme.of(context);
    final directions = viewModel.mapViewModel.directionsResult!;
    // Use null-aware operators for durationValue and distanceValue as they are nullable
    final fare = viewModel.fareService.calculateFare(directions.distanceValue!, directions.durationValue!);

    return Card(
      key: const ValueKey('RideSelectionCard'),
      margin: const EdgeInsets.all(16),
      elevation: 10,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: viewModel.cancelRideSelection),
                Expanded(child: Center(child: Text("Choose a Ride", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)))),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),
            _buildVehicleOption(context, icon: Icons.directions_car, title: "Leisure Comfort", subtitle: "Affordable, everyday rides", price: fare.leisureComfort, isSelected: viewModel.selectedVehicle == 'Leisure Comfort', onTap: () => viewModel.selectVehicle('Leisure Comfort')),
            const Divider(),
            _buildVehicleOption(context, icon: Icons.airport_shuttle, title: "Leisure Plus", subtitle: "Extra space, premium rides", price: fare.leisurePlus, isSelected: viewModel.selectedVehicle == 'Leisure Plus', onTap: () => viewModel.selectVehicle('Leisure Plus')),
            const Divider(),
            _buildVehicleOption(context, icon: Icons.local_taxi, title: "Leisure Exec", subtitle: "Luxury cars, top-rated drivers", price: fare.leisureExec, isSelected: viewModel.selectedVehicle == 'Leisure Exec', onTap: () => viewModel.selectVehicle('Leisure Exec')),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                disabledBackgroundColor: theme.disabledColor,
              ),
              onPressed: viewModel.selectedVehicle == null ? null : () => viewModel.proceedToPayment(context),
              child: const Text("Proceed to Payment", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentCardContent(BuildContext context, HomeViewModel viewModel) {
    final theme = Theme.of(context);
    final directions = viewModel.mapViewModel.directionsResult!;
    final fare = viewModel.fareService.calculateFare(directions.distanceValue!, directions.durationValue!);
    final selectedVehicleFare = fare.getFareForVehicle(viewModel.selectedVehicle!);

    return Container(
      key: const ValueKey('PaymentCard'),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: viewModel.cancelPayment,
              ),
              Expanded(
                child: Center(
                  child: Text(
                    "Confirm Payment",
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const Divider(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            child: Column(
              children: [
                _buildPaymentDetailRow(theme, "Trip Fare", "\$${selectedVehicleFare.toStringAsFixed(2)}"),
                const SizedBox(height: 8),
                _buildPaymentDetailRow(theme, "Vehicle Type", viewModel.selectedVehicle!),
                const SizedBox(height: 8),
                _buildPaymentDetailRow(theme, "Destination", directions.endAddress, isSubtitle: true),
                const SizedBox(height: 20),
                ListTile(
                  leading: Icon(Icons.credit_card, color: theme.primaryColor),
                  title: const Text("Payment Method"),
                  subtitle: const Text("Visa **** 1234"), // Replace with actual selected method
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Payment method selection not implemented yet!')),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: viewModel.paymentViewModel.isLoading
                ? null
                : () => viewModel.proceedToPayment(context), // Re-trigger payment if webview was closed/cancelled
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.primaryColor,
              foregroundColor: theme.colorScheme.onPrimary,
              minimumSize: const Size(double.infinity, 54),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              disabledBackgroundColor: theme.disabledColor,
            ),
            child: viewModel.paymentViewModel.isLoading
                ? CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.onPrimary))
                : const Text("Confirm & Pay", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          if (viewModel.paymentViewModel.errorMessage != null)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                viewModel.paymentViewModel.errorMessage!,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetailRow(ThemeData theme, String label, String value, {bool isSubtitle = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: isSubtitle ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: isSubtitle ? FontWeight.normal : FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickAction(BuildContext context, {required IconData icon, required String label, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          children: [
            Icon(icon, color: theme.primaryColor, size: 24),
            const SizedBox(height: 4),
            Text(label, style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  Widget _buildRouteInfo(BuildContext context, {required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Icon(icon, color: theme.primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.textTheme.bodySmall?.color?.withOpacity(0.7)),
        ),
      ],
    );
  }

  Widget _buildVehicleOption(BuildContext context, {required IconData icon, required String title, required String subtitle, required double price, required bool isSelected, required VoidCallback onTap}) {
    final theme = Theme.of(context);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? theme.primaryColor.withOpacity(0.1) : null,
      leading: Icon(icon, size: 40, color: theme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: theme.textTheme.bodySmall),
      trailing: Text("\$${price.toStringAsFixed(2)}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
    );
  }

  Widget _buildLocationError(BuildContext context, HomeViewModel viewModel) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: theme.disabledColor),
            const SizedBox(height: 16),
            const Text("Location Permission Required", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("Please enable location services to use LeisureRyde", style: TextStyle(color: theme.textTheme.bodySmall?.color), textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                viewModel.refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            ),
          ],
        ),
      ),
    );
  }
}