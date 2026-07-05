// lib/screens/user/home/home_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../app/service_locator.dart';
import '../../../models/route_selection.dart';
import '../../../services/fare_calculation_service.dart';
import '../../../models/user_profile.dart';
import '../../../services/place_service.dart'; // For PlaceDetails
import '../../../viewmodel/home/home_view_model.dart'; // Your HomeViewModel
import '../../../widgets/custom_loading_indicator.dart';
import '../../../widgets/rating_dialog.dart';
import '../../shared/search/search_destination.dart';
import '../trip/active_trip_screen.dart';
import '../trip/finding_driver.dart'; // Your FindingDriverCard

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  bool _didScheduleInitialRefresh = false;
  bool _showingCancelDialog = false;
  bool _showingRatingDialog = false;
  bool _isActiveTripCardCollapsed = false;
  HomeViewModel? _vm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didScheduleInitialRefresh) {
      _didScheduleInitialRefresh = true;
      _vm = context.read<HomeViewModel>();
      _vm!.addListener(_onViewModelChanged);
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await _vm!.refreshOnScreenResume();
      });
    }
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    final vm = _vm;
    if (vm == null) return;

    if (vm.cancelledByDriver && !_showingCancelDialog) {
      _showingCancelDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20)),
            title: const Row(
              children: [
                Icon(Icons.cancel, color: Colors.red),
                SizedBox(width: 8),
                Text("Ride Cancelled"),
              ],
            ),
            content: Text(
              vm.cancelledByDriverName != null
                  ? "${vm.cancelledByDriverName} has cancelled your ride."
                  : "Your driver has cancelled the ride.",
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  vm.acknowledgeDriverCancellation();
                  _showingCancelDialog = false;
                },
                child: const Text("OK"),
              ),
            ],
          ),
        ).then((_) => _showingCancelDialog = false);
      });
    }

    if (vm.showRatingDialog && !_showingRatingDialog) {
      _showingRatingDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (_) => RatingDialog(
            driverName: vm.ratingDriverName,
            onSubmit: (rating) {
              Navigator.of(context).pop();
              vm.submitRating(rating);
              _showingRatingDialog = false;
            },
            onSkip: () {
              Navigator.of(context).pop();
              vm.dismissRatingDialog();
              _showingRatingDialog = false;
            },
          ),
        ).then((_) => _showingRatingDialog = false);
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _vm?.refreshOnScreenResume();
    }
  }

  @override
  void dispose() {
    _vm?.removeListener(_onViewModelChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: locator<HomeViewModel>(),
      child: Scaffold(
        body: Consumer<HomeViewModel>(
          builder: (context, viewModel, child) {
            debugPrint("🟢 [HomeScreen] Rebuilding. Current step is: ${viewModel.currentStep}");

            if (viewModel.isLoading || viewModel.mapViewModel.isLoading) {
              return const CustomLoadingIndicator();
            }
            if (viewModel.userProfile == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.person_off, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text(
                        "Could not load your profile",
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Check your connection and try again.",
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => viewModel.refresh(),
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (viewModel.mapViewModel.currentPosition == null) {
              return _buildLocationError(context, viewModel);
            }
            return Stack(
              children: [
                _buildMap(context, viewModel),
                _buildHeader(context, viewModel.userProfile!),
                if (viewModel.mapViewModel.isUserInteracting &&
                    viewModel.currentStep == HomeStep.activeTrip)
                  Positioned(
                    bottom: _isActiveTripCardCollapsed ? 110 : 400,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'user_recenter',
                      onPressed: viewModel.mapViewModel.recenterCamera,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location,
                          color: Colors.black87),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    switchInCurve: Curves.easeOutCubic,
                    switchOutCurve: Curves.easeInCubic,
                    transitionBuilder: (Widget child, Animation<double> animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.25),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    // === THIS IS THE KEY FIX ===
                    child: KeyedSubtree(
                      key: ValueKey(viewModel.currentStep),   // Force rebuild on step change
                      child: _buildBottomCardContent(context, viewModel),
                    ),
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
        // Shrink reserved space when the card is collapsed so the map has
        // more visible area; expand it when open so content is not hidden.
        bottomPadding = _isActiveTripCardCollapsed ? 90 : 380;
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
      onMapCreated: (controller){print("Map has been created");},
      onCameraMoveStarted: viewModel.mapViewModel.onCameraMoveStarted,
      onCameraIdle: viewModel.mapViewModel.onCameraIdle,
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
        return const FindingDriverCard(key: ValueKey(HomeStep.findingDriver));
      case HomeStep.activeTrip:
        debugPrint("Page already in active trip mode");
        return ActiveTripCard(
          key: const ValueKey(HomeStep.activeTrip),
          rideId: viewModel.currentRideId ?? '',
          onCollapseChanged: (isCollapsed) {
            setState(() => _isActiveTripCardCollapsed = isCollapsed);
          },
        );
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
                _buildQuickAction(context, icon: Icons.home, label: "Home", onTap: () => {}),
                const SizedBox(width: 24),
                _buildQuickAction(context, icon: Icons.work, label: "Work", onTap: () =>{}),
              ],
            ),
          ),
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
                _buildRouteInfo(context, icon: Icons.straighten, label: "Distance", value:  directions.distance ?? 'N/A'),
              ],
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                _buildRouteAddressRow(theme, directions.startAddress, directions.endAddress),
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
            const SizedBox(height: 4),
            _buildRouteAddressRow(theme, directions.startAddress, directions.endAddress),
            const Divider(height: 24),
            _buildVehicleOption(context, icon: Icons.directions_car, title: "Leisure Comfort", subtitle: "Affordable, everyday rides", price: fare.leisureComfort, isSelected: viewModel.selectedVehicle == 'Leisure Comfort', onTap: () => viewModel.selectVehicle('Leisure Comfort')),
            const Divider(),
            _buildVehicleOption(context, icon: Icons.airport_shuttle, title: "Leisure Plus", subtitle: "Extra space, premium rides", price: fare.leisurePlus, isSelected: viewModel.selectedVehicle == 'Leisure Plus', onTap: () => viewModel.selectVehicle('Leisure Plus')),
            const Divider(),
            _buildVehicleOption(context, icon: Icons.local_taxi, title: "Leisure Exec", subtitle: "Luxury cars, top-rated drivers", price: fare.leisureExec, isSelected: viewModel.selectedVehicle == 'Leisure Exec', onTap: () => viewModel.selectVehicle('Leisure Exec')),
            if (viewModel.selectedVehicle != null) ...[
              const SizedBox(height: 12),
              Builder(builder: (context) {
                final selectedFare = fare.getFareForVehicle(viewModel.selectedVehicle!);
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: theme.primaryColor.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: theme.primaryColor.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      _buildPaymentDetailRow(theme, "Subtotal", "\$${FareCalculationService.subtotalFromTotal(selectedFare).toStringAsFixed(2)}"),
                      const SizedBox(height: 6),
                      _buildPaymentDetailRow(theme, "Tax", "\$${FareCalculationService.taxFromTotal(selectedFare).toStringAsFixed(2)}"),
                      const Divider(height: 16),
                      _buildPaymentDetailRow(theme, "Total", "\$${selectedFare.toStringAsFixed(2)}", isBold: true),
                    ],
                  ),
                );
              }),
            ],
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
                _buildPaymentDetailRow(theme, "Subtotal", "\$${FareCalculationService.subtotalFromTotal(selectedVehicleFare).toStringAsFixed(2)}"),
                const SizedBox(height: 8),
                _buildPaymentDetailRow(theme, "Tax", "\$${FareCalculationService.taxFromTotal(selectedVehicleFare).toStringAsFixed(2)}"),
                const SizedBox(height: 8),
                _buildPaymentDetailRow(theme, "Total", "\$${selectedVehicleFare.toStringAsFixed(2)}", isBold: true),
                const SizedBox(height: 8),
                _buildPaymentDetailRow(theme, "Vehicle Type", viewModel.selectedVehicle!),
                const SizedBox(height: 12),
                _buildRouteAddressRow(theme, directions.startAddress, directions.endAddress),
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

  Widget _buildRouteAddressRow(ThemeData theme, String pickupAddress, String destinationAddress) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            const Icon(Icons.radio_button_checked, color: Colors.green, size: 18),
            Container(width: 2, height: 22, color: Colors.grey.shade300),
            Icon(Icons.location_on, color: theme.primaryColor, size: 18),
          ],
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                pickupAddress,
                style: theme.textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 10),
              Text(
                destinationAddress,
                style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetailRow(ThemeData theme, String label, String value, {bool isSubtitle = false, bool isBold = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isBold ? null : theme.textTheme.bodyMedium?.color?.withOpacity(0.7),
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            fontSize: isBold ? 16 : null,
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.end,
            maxLines: isSubtitle ? 2 : 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: (isSubtitle && !isBold) ? FontWeight.normal : FontWeight.bold,
              fontSize: isBold ? 16 : null,
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
    final subtotal = FareCalculationService.subtotalFromTotal(price);
    final tax = FareCalculationService.taxFromTotal(price);
    return ListTile(
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      tileColor: isSelected ? theme.primaryColor.withOpacity(0.1) : null,
      leading: Icon(icon, size: 40, color: theme.primaryColor),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(subtitle, style: theme.textTheme.bodySmall),
          Text(
            "\$${subtotal.toStringAsFixed(2)} + \$${tax.toStringAsFixed(2)} tax",
            style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[500], fontSize: 11),
          ),
        ],
      ),
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
