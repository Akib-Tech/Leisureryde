import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';

import '../../../models/route_selection.dart';
import '../../../models/user_profile.dart';
import '../../../services/place_service.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../shared/search/search_destination.dart';
import '../trip/active_trip_screen.dart';
import '../trip/finding_driver.dart';
    // new themed overlay

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HomeViewModel(),
      child: Scaffold(
        body: Consumer<HomeViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading || vm.mapViewModel.isLoading) {
              return const CustomLoadingIndicator();
            }
            if (vm.userProfile == null) {
              return const Center(child: Text("Could not load user profile."));
            }
            if (vm.mapViewModel.currentPosition == null) {
              return _buildLocationError(context, vm);
            }

            return Stack(
              children: [
                _buildMap(context, vm),
                _buildHeader(context, vm.userProfile!),
                // Overlay card controlled by currentStep
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: _buildStepCard(context, vm),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildMap(BuildContext context, HomeViewModel vm) {
    return GoogleMap(
      initialCameraPosition: CameraPosition(
        target: LatLng(
          vm.mapViewModel.currentPosition!.latitude,
          vm.mapViewModel.currentPosition!.longitude,
        ),
        zoom: 15,
      ),
      onMapCreated: vm.mapViewModel.onMapCreated,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      markers: {...vm.mapViewModel.markers, ...vm.driverMarkers.values},
      polylines: vm.mapViewModel.polylines,
      padding: const EdgeInsets.only(top: 120, bottom: 260),
    );
  }

  Widget _buildHeader(BuildContext context, UserProfile user) {
    final theme = Theme.of(context);
    return SafeArea(
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
                  Text("Hello,",
                      style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.textTheme.bodySmall?.color
                              ?.withOpacity(0.6))),
                  Text(user.firstName,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold))
                ],
              ),
            ),
            CircleAvatar(
              radius: 22,
              backgroundColor: theme.primaryColor.withOpacity(0.15),
              backgroundImage: user.profileImageUrl.isNotEmpty
                  ? NetworkImage(user.profileImageUrl)
                  : null,
              child: user.profileImageUrl.isEmpty
                  ? Text(user.firstName.isNotEmpty
                  ? user.firstName[0].toUpperCase()
                  : 'U')
                  : null,
            )
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------

  Widget _buildStepCard(BuildContext context, HomeViewModel vm) {
    switch (vm.currentStep) {
      case HomeStep.initial:
        return _buildWhereToCard(context, vm);
      case HomeStep.routePreview:
        return _buildRoutePreviewCard(context, vm);
      case HomeStep.vehicleSelection:
        return _buildVehicleCard(context, vm);
      case HomeStep.findingDriver:
        return FindingDriverCard(onCancel: vm.cancelRide);
      case HomeStep.activeTrip:
        return ActiveTripCard(rideId: vm.currentRideId ?? '');
    }
  }

  // ------------------ WHERE‑TO card ------------------
  Widget _buildWhereToCard(BuildContext context, HomeViewModel vm) {
    final theme = Theme.of(context);
    return _overlayCard(
      theme,
      child: InkWell(
        onTap: () async {
          final initPickup = PlaceDetails(
            name: "Current Location",
            address: "",
            location: LatLng(
              vm.mapViewModel.currentPosition!.latitude,
              vm.mapViewModel.currentPosition!.longitude,
            ),
          );
          final result = await Navigator.push<RouteSelectionResult?>(
            context,
            MaterialPageRoute(
              builder: (_) => SearchDestinationScreen(initialPickup: initPickup),
            ),
          );
          if (result != null) vm.selectRoute(result);
        },
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.search, color: theme.primaryColor),
              ),
              const SizedBox(width: 16),
              Text("Where to?",
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const Spacer(),
              Icon(Icons.arrow_forward_ios,
                  size: 16, color: theme.dividerColor)
            ],
          ),
        ),
      ),
    );
  }

  // ------------------ ROUTE PREVIEW ------------------
  Widget _buildRoutePreviewCard(BuildContext context, HomeViewModel vm) {
    final theme = Theme.of(context);
    final dir = vm.mapViewModel.directionsResult!;
    final eta = DateFormat.jm().format(dir.eta);

    return _overlayCard(
      theme,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.primaryColor.withOpacity(0.1),
              borderRadius:
              const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _routeInfo(theme, Icons.access_time, "ETA", eta),
                _routeInfo(theme, Icons.directions_car, "Duration", dir.duration),
                _routeInfo(theme, Icons.straighten, "Distance", dir.distance),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
            child: Row(
              children: [
                Icon(Icons.location_on, color: theme.primaryColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(dir.endAddress,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: ElevatedButton(
              onPressed: vm.proceedToVehicleSelection,
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text("Choose Your Ride",
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _routeInfo(
      ThemeData t, IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(icon, color: t.primaryColor),
        const SizedBox(height: 4),
        Text(value,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: t.textTheme.bodySmall
                ?.copyWith(color: t.textTheme.bodySmall?.color?.withOpacity(0.7)))
      ],
    );
  }

  // ------------------ VEHICLE SELECTION ------------------
  Widget _buildVehicleCard(BuildContext context, HomeViewModel vm) {
    final theme = Theme.of(context);
    final d = vm.mapViewModel.directionsResult!;
    final fares =
    vm.fareService.calculateFare(d.distanceValue, d.durationValue);
    Widget tile(String title, String subtitle, double price) => ListTile(
      onTap: () => vm.selectVehicle(title),
      tileColor:
      vm.selectedVehicle == title ? theme.primaryColor.withOpacity(0.1) : null,
      leading: Icon(Icons.directions_car, color: theme.primaryColor, size: 36),
      title: Text(title,
          style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: Text("\$${price.toStringAsFixed(2)}",
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );

    return _overlayCard(
      theme,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              IconButton(
                  icon: const Icon(Icons.arrow_back),
                  onPressed: vm.cancelRideSelection),
              Expanded(
                child: Center(
                  child: Text("Choose Ride",
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            tile("Leisure Comfort", "Affordable, everyday rides",
                fares.leisureComfort),
            const Divider(),
            tile("Leisure Plus", "Extra space, premium rides",
                fares.leisurePlus),
            const Divider(),
            tile("Leisure Exec", "Luxury, top‑rated drivers",
                fares.leisureExec),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: vm.selectedVehicle == null || vm.isRequestingRide
                  ? null
                  : () => vm.requestRide(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: theme.primaryColor,
                foregroundColor: theme.colorScheme.onPrimary,
                minimumSize: const Size(double.infinity, 54),
              ),
              child: vm.isRequestingRide
                  ? CircularProgressIndicator(
                color: theme.colorScheme.onPrimary,
              )
                  : const Text("Confirm Ride",
                  style:
                  TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------ Helpers ------------------
  Widget _overlayCard(ThemeData theme, {required Widget child}) {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4))
          ],
        ),
        child: child,
      ),
    );
  }

  Widget _buildLocationError(BuildContext context, HomeViewModel vm) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.location_off, size: 80, color: theme.disabledColor),
            const SizedBox(height: 16),
            const Text("Location Permission Required",
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text("Please enable location services to use LeisureRyde",
                style: theme.textTheme.bodyMedium, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                vm.refresh();
              },
              icon: const Icon(Icons.refresh),
              label: const Text("Retry"),
            )
          ],
        ),
      ),
    );
  }
}