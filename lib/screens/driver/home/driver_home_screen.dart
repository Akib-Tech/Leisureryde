import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../models/ride_request_model.dart';
import '../../../viewmodel/home/driver_home_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../../widgets/navigation_banner.dart';
import '../ride_request/ride_requests_screen.dart';
import '../trip/active_trip_bottom_sheet.dart';

class DriverHomeScreen extends StatefulWidget {
  const DriverHomeScreen({super.key});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen>
    with WidgetsBindingObserver {
  bool _showingCancelDialog = false;
  bool _isActiveSheetCollapsed = false;
  int _mapRebuildKey = 0;
  DriverHomeViewModel? _vm;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
      final vm = _vm;
    if (state == AppLifecycleState.resumed && mounted) {

      if (vm == null) return;
      // Restore voice if the driver was in Waze; otherwise just re-init TTS.
      if (vm.mutedByWaze) {
        vm.restoreVoiceAfterExternalApp();
      } else {
        vm.reinitializeVoice();
      }
      if (vm.mapViewModel.currentPosition == null) {
        vm.requestLocationPermission();
      } else {
        // Force map tile redraw — fixes the blank/static map after backgrounding.
        vm.mapViewModel.refreshMap();
      }
      setState(() => _mapRebuildKey++);
        vm.restoreVoiceAfterExternalApp();
    }

    if (state == AppLifecycleState.inactive && mounted) {
    setState(() => _mapRebuildKey++);
    if (vm != null) vm.restoreVoiceAfterExternalApp();
     }
  }

  void _onViewModelChanged() {
    if (!mounted) return;
    final vm = _vm;
    if (vm == null) return;

    WakelockPlus.toggle(enable: vm.isOnline);

    if (vm.rideCancelledByUser && !_showingCancelDialog) {
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
                Icon(Icons.cancel, color: Colors.orange),
                SizedBox(width: 8),
                Text("Ride Cancelled"),
              ],
            ),
            content: const Text(
                "The passenger has cancelled this ride request."),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  vm.acknowledgePassengerCancellation();
                  _showingCancelDialog = false;
                },
                child: const Text("OK"),
              ),
            ],
          ),
        ).then((_) => _showingCancelDialog = false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DriverHomeViewModel(),
      child: Scaffold(
        body: Consumer<DriverHomeViewModel>(
          builder: (context, viewModel, child) {
            // Store a direct reference for the lifecycle observer.
            _vm = viewModel;
            // Register the listener once the ViewModel is available.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              viewModel.removeListener(_onViewModelChanged);
              viewModel.addListener(_onViewModelChanged);
            });

            if (viewModel.isLoading || viewModel.mapViewModel.isLoading) {
              return const CustomLoadingIndicator();
            }

            if (viewModel.driverProfile == null) {
              return const Center(
                child: Text("Could not load driver profile."),
              );
            }

            if (viewModel.mapViewModel.currentPosition == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.location_off,
                        size: 80,
                        color: Colors.grey[400],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "Location Permission Required",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Please enable location services to receive ride requests",
                        style: TextStyle(color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          // Retry getting location
                          viewModel.requestLocationPermission();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text("Retry"),
                      ),
                    ],
                  ),
                ),
              );
            }

            return Stack(
              children: [
                _buildMap(context, viewModel),
                // Show turn-by-turn banner during active trip; normal header otherwise.
                if (viewModel.activeRide != null)
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    child: NavigationBanner(
                      step: viewModel.currentNavStep,
                      distanceMeters: viewModel.distanceToNextTurnMeters,
                      upcomingTurnStep: viewModel.nextNavManeuverStep,
                      isRecalculating: viewModel.isRecalculating,
                    ),
                  )
                else
                  _buildHeader(context, viewModel),
                if (viewModel.isOnline)
                  viewModel.activeRide != null
                      ? ActiveTripDriverBottomSheet(
                          rideId: viewModel.activeRide!.id,
                          onCollapseChanged: (isCollapsed) {
                            setState(() => _isActiveSheetCollapsed = isCollapsed);
                          },
                        )
                      : _buildOnlineStatusCard(context, viewModel)
                else
                  _buildOfflineCard(context, viewModel),
                if (viewModel.mapViewModel.isUserInteracting &&
                    viewModel.activeRide != null)
                  Positioned(
                    bottom: _isActiveSheetCollapsed ? 120 : 440,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'driver_recenter',
                      onPressed: viewModel.mapViewModel.recenterCamera,
                      backgroundColor: Colors.white,
                      child: const Icon(Icons.my_location,
                          color: Colors.black87),
                    ),
                  ),
                if (viewModel.activeRide != null)
                  Positioned(
                    bottom: _isActiveSheetCollapsed ? 174 : 494,
                    right: 16,
                    child: FloatingActionButton.small(
                      heroTag: 'driver_voice',
                      onPressed: viewModel.toggleVoice,
                      backgroundColor: viewModel.voiceEnabled
                          ? Colors.blue
                          : Colors.white,
                      child: Icon(
                        viewModel.voiceEnabled
                            ? Icons.volume_up
                            : Icons.volume_off,
                        color: viewModel.voiceEnabled
                            ? Colors.white
                            : Colors.black54,
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

  Widget _buildMap(BuildContext context, DriverHomeViewModel viewModel) {
    double bottomPadding;
    if (viewModel.activeRide != null) {
      // Give the map enough room so polylines/markers are not hidden behind
      // the active trip sheet. Use a smaller value when it is collapsed.
      bottomPadding = _isActiveSheetCollapsed ? 100 : 420;
    } else {
      bottomPadding = 280; // height of the online/offline status card
    }

    return GoogleMap( 
      key: ValueKey(_mapRebuildKey),
      initialCameraPosition: CameraPosition(
        target: viewModel.mapViewModel.currentPosition != null
            ? LatLng(
                viewModel.mapViewModel.currentPosition!.latitude,
                viewModel.mapViewModel.currentPosition!.longitude,
              )
            : const LatLng(33.7490, -84.3880),
        zoom: 15.0,
      ),
      onMapCreated: viewModel.mapViewModel.onMapCreated,
      onCameraMoveStarted: viewModel.mapViewModel.onCameraMoveStarted,
      onCameraIdle: viewModel.mapViewModel.onCameraIdle,
      myLocationEnabled: true,
      myLocationButtonEnabled: false,
      zoomControlsEnabled: false,
      compassEnabled: false,
      mapToolbarEnabled: false,
      markers: viewModel.mapViewModel.markers,
      polylines: viewModel.mapViewModel.polylines,
      padding: EdgeInsets.only(
        // During navigation the banner is ~100 dp tall; normal header is ~160.
        top: viewModel.activeRide != null
            ? MediaQuery.of(context).padding.top + 100
            : MediaQuery.of(context).padding.top + 160,
        bottom: bottomPadding,
      ),
    );
  }

  // ========== Top Header with Online Toggle ==========
  Widget _buildHeader(BuildContext context, DriverHomeViewModel viewModel) {
    final theme = Theme.of(context);

    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        child: Column(
          children: [
            // Driver Info Card
            Container(
              margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
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
                  CircleAvatar(
                    backgroundColor: theme.primaryColor,
                    radius: 24,
                    child: Text(
                      viewModel.driverProfile!.firstName[0].toUpperCase(),
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.bold,
                        fontSize: 20,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          viewModel.driverProfile!.fullName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: viewModel.isOnline
                                    ? Colors.green
                                    : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              viewModel.isOnline ? "Online" : "Offline",
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: viewModel.isOnline
                                    ? Colors.green
                                    : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: theme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.star,
                          color: theme.primaryColor,
                          size: 16,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          viewModel.driverProfile!.rating.toStringAsFixed(1),
                          style: TextStyle(
                            color: theme.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: 'Test voice',
                    child: IconButton(
                      icon: const Icon(Icons.record_voice_over, size: 22),
                      color: Colors.blue,
                      onPressed: viewModel.testVoice,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ),
                ],
              ),
            ),

            // Online/Offline Toggle Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: viewModel.isOnline
                    ? Colors.green.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: viewModel.isOnline ? Colors.green : Colors.grey[400]!,
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, 2),
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
                          viewModel.isOnline
                              ? "You're Online"
                              : "You're Offline",
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: Colors.grey[600],

                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          viewModel.isOnline
                              ? "Ready to accept ride requests"
                              : "Go online to start earning",
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: viewModel.isOnline,
                    activeColor: Colors.green,
                    onChanged: (value) {
                      viewModel.toggleOnlineStatus();
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ========== Online Status Card (Bottom) ==========
  Widget _buildOnlineStatusCard(
      BuildContext context, DriverHomeViewModel viewModel) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
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
        child: _buildTripDetails(context, viewModel)
      ),
    );
  }

  Widget _buildOfflineCard(BuildContext context, DriverHomeViewModel viewModel) {
    final theme = Theme.of(context);

    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
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
            Icon(
              Icons.offline_bolt,
              size: 64,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              "You're Offline",
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              "Go online to start receiving ride requests and earning money",
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                viewModel.toggleOnlineStatus();
              },
              icon: const Icon(Icons.power_settings_new),
              label: const Text(
                "Go Online",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }



  Widget _buildTripDetails(BuildContext context, DriverHomeViewModel viewModel) {
    final theme = Theme.of(context);

    return  Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Stats Row
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: theme.primaryColor.withOpacity(0.05),
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                context,
                icon: Icons.directions_car,
                label: "Trips Today",
                value: viewModel.todayTrips.toString(),
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              _buildStatItem(
                context,
                icon: Icons.attach_money,
                label: "Earned Today",
                value: "\$${viewModel.todayEarnings.toStringAsFixed(1)}",
              ),
              Container(
                width: 1,
                height: 40,
                color: Colors.grey[300],
              ),
              _buildStatItem(
                context,
                icon: Icons.access_time,
                label: "Hours",
                value: "${viewModel.hoursOnline.toStringAsFixed(1)}h",
              ),
            ],
          ),
        ),

        // Ride Requests Section
        Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Ride Requests",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  if (viewModel.pendingRequestsCount > 0)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        "${viewModel.pendingRequestsCount} Pending",
                        style: const TextStyle(
                          color: Colors.orange,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  minimumSize: const Size(double.infinity, 54),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RideRequestsScreen(),
                    ),
                  ).then((result) {
                    // When the driver accepts a ride, RideRequestsScreen pops
                    // with the accepted RideRequest so we can show the active
                    // trip sheet immediately without waiting for Firestore.
                    if (result is RideRequest && mounted) {
                      viewModel.preSetActiveRide(result);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Ride accepted! Navigate to pickup."),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                    viewModel.refreshStats();
                  });
                },
                icon: const Icon(Icons.list_alt),
                label: Text(
                  viewModel.pendingRequestsCount > 0
                      ? "View Requests (${viewModel.pendingRequestsCount})"
                      : "View All Requests",
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
/*
   Widget _backgroundLocationPermission(BuildContext context){
      return Card(
        child:Column(
          children: [
            Text("Leisure ryde App collects location data to enable users identify online drivers location during ride booking,even when your app is closed or not in use."),
            Row(children: [
            ],)
          ],
        )
      );
  }
*/
  Widget _buildStatItem(
      BuildContext context, {
        required IconData icon,
        required String label,
        required String value,
      }) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Icon(icon, color: theme.primaryColor, size: 24),
        const SizedBox(height: 4),
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: Colors.grey[600],
          ),
        ),
      ],
    );
  }

 
}
