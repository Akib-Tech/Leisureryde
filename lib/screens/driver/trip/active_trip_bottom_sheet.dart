import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:leisureryde/screens/shared/timer/timer.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../models/ride_request_model.dart';
import '../../../viewmodel/home/driver_home_view_model.dart';
import '../../../viewmodel/ride/active_trip_driver_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../shared/chat/chat_screen.dart';

class ActiveTripDriverBottomSheet extends StatefulWidget {
  final String rideId;
  final void Function(bool isCollapsed)? onCollapseChanged;

  const ActiveTripDriverBottomSheet({
    super.key,
    required this.rideId,
    this.onCollapseChanged,
  });

  @override
  State<ActiveTripDriverBottomSheet> createState() =>
      _ActiveTripDriverBottomSheetState();
}

class _ActiveTripDriverBottomSheetState
    extends State<ActiveTripDriverBottomSheet>
    with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0, // 1 = expanded
    );
    _heightFactor = _animCtrl.drive(CurveTween(curve: Curves.easeInOut));
  }

  void _toggleCollapse() {
    setState(() => _isCollapsed = !_isCollapsed);
    widget.onCollapseChanged?.call(_isCollapsed);
    if (_isCollapsed) {
      _animCtrl.reverse();
    } else {
      _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActiveTripDriverViewModel(rideId: widget.rideId),
      child: Consumer<ActiveTripDriverViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) return const CustomLoadingIndicator();

          if (vm.rideRequest == null || vm.passengerProfile == null) {
            return const SizedBox.shrink();
          }

          final passenger = vm.passengerProfile!;
          final t = Theme.of(context);

                   Widget? stateButton;
          switch (vm.rideRequest!.status) {
            case RideStatus.accepted:
              stateButton = _statusButton(t, "Arrived at Pickup", vm.markArrived);
              break;

            case RideStatus.enroute:
              // Check if there are waypoints to handle
              if (vm.rideRequest!.waypointsAddresses.isNotEmpty) {
                stateButton = _statusButton(
                  t, 
                  "Start Trip (with waypoints)", 
                  vm.startTrip
                );
              } else {
                stateButton = _statusButton(t, "Start Trip", vm.startTrip);
              }
              break;

            case RideStatus.ongoing:
              // Show "Arrived at Stop" while there are remaining waypoints.
              // currentWaypointIndex advances from -1 → 0 → 1 → … on each stop.
              if (vm.rideRequest!.waypointsAddresses.isNotEmpty &&
                  vm.rideRequest!.currentWaypointIndex <
                      vm.rideRequest!.waypointsAddresses.length - 1) {
                stateButton = ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () async {
                    final driverVm = context.read<DriverHomeViewModel>();
                    final success = await vm.advanceToNextWaypoint();
                    if (success && context.mounted) {
                      await _openWaze(context, driverVm, vm.rideRequest!);
                    }
                  },
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text(
                    "Arrived at Stop — Continue",
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                );
              } else {
                stateButton = _statusButton(t, "End Trip", vm.completeTrip);
              }
              break;

            default:
              stateButton = null;
          }

          return Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
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
                  // ── Drag handle + collapsed summary ──────────────────
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _toggleCollapse,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Container(
                                width: 40,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: Colors.blue[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _isCollapsed
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.blue[500],
                              ),
                            ],
                          ),
                          if (_isCollapsed) ...[
  const SizedBox(height: 8),
  Row(
    children: [
      CircleAvatar(
        radius: 16,
        backgroundImage: passenger.profileImageUrl.isNotEmpty
            ? NetworkImage(passenger.profileImageUrl)
            : null,
        child: passenger.profileImageUrl.isEmpty
            ? Text(
                passenger.firstName[0].toUpperCase(),
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              )
            : null,
      ),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              passenger.firstName,
              style: const TextStyle(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(Icons.location_on, size: 12, color: t.primaryColor),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    vm.rideRequest!.destinationAddress,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
      const SizedBox(width: 8),
      // Collapsed header only has room for a compact chip — the full
      // TripEndTimer card (32sp arrival text + distance column) doesn't
      // fit here and overflows the row, so it's reserved for the
      // expanded content below.
      if (vm.rideRequest!.status == RideStatus.ongoing)
        Flexible(
          child: Consumer<DriverHomeViewModel>(
            builder: (_, driverVm, __) {
              final etaText = driverVm.remainingSeconds > 0
                  ? _formatEtaChip(driverVm.remainingSeconds)
                  : vm.statusLabel;
              return Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  etaText,
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              );
            },
          ),
        )
      else
        Flexible(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: t.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              vm.statusLabel,
              style: TextStyle(
                color: t.primaryColor,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
    ],
  ),
  const SizedBox(height: 6),
],
                        ],
                      ),
                    ),
                  ),

                  // ── Expanded content ──────────────────────────────────
                  SizeTransition(
                    sizeFactor: _heightFactor,
                    axisAlignment: -1,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Text(
                              vm.statusLabel,
                              style: t.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: t.primaryColor,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Pickup → Destination route summary
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Column(
                                children: [
                                  const Icon(Icons.radio_button_checked,
                                      color: Colors.green, size: 16),
                                  Container(
                                      width: 2,
                                      height: 20,
                                      color: Colors.grey.shade300),
                                  Icon(Icons.location_on,
                                      color: t.primaryColor, size: 16),
                                ],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      vm.rideRequest!.pickupAddress,
                                      style: t.textTheme.bodyMedium,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      vm.rideRequest!.destinationAddress,
                                      style: t.textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w600),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),

                          // Pickup time chip
                          _buildPickupTimeChip(t, vm.rideRequest!),
                          const SizedBox(height: 16),

                          // Passenger info
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage:
                                  passenger.profileImageUrl.isNotEmpty
                                      ? NetworkImage(
                                          passenger.profileImageUrl)
                                      : null,
                              child: passenger.profileImageUrl.isEmpty
                                  ? Text(
                                      passenger.firstName[0].toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold))
                                  : null,
                            ),
                            title: Text(
                              passenger.firstName,
                              style: TextStyle(color: Colors.grey[900]),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(children: [
                                  const Icon(Icons.star,
                                      size: 16, color: Colors.amber),
                                  const SizedBox(width: 4),
                                  Text(passenger.rating.toStringAsFixed(1)),
                                ]),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                    icon: const Icon(Icons.call,
                                        color: Colors.green),
                                    onPressed: vm.makeCall),
                                IconButton(
                                  icon: const Icon(Icons.chat,
                                      color: Colors.blue),
                                  onPressed: () {
                                    final driverName = context
                                            .read<DriverHomeViewModel>()
                                            .driverProfile
                                            ?.fullName ??
                                        '';
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          rideId: widget.rideId,
                                          otherUserId: passenger.uid,
                                          otherUserName: passenger.fullName,
                                          otherUserImageUrl:
                                              passenger.profileImageUrl,
                                          currentUserName: driverName,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),

                          // Trip timer — shown during ongoing, fed with live
                          // ETA values from DriverHomeViewModel so it updates
                          // every time the route is recalculated (~30 m).
                          if (vm.rideRequest!.status == RideStatus.ongoing) ...[
                            const SizedBox(height: 12),
                            Consumer<DriverHomeViewModel>(
                              builder: (_, driverVm, __) => TripEndTimer(
                                origin: vm.rideRequest!.pickupLocation,
                                destination: vm.userDestination,
                                liveRemainingSeconds: driverVm.remainingSeconds > 0
                                    ? driverVm.remainingSeconds
                                    : null,
                                liveRemainingDistanceMiles: driverVm.remainingDistanceMiles > 0
                                    ? driverVm.remainingDistanceMiles
                                    : null,
                              ),
                            ),
                          ],

                          const SizedBox(height: 20),

                          if (stateButton != null) stateButton,
                          const SizedBox(height: 12),

                          // Waze navigation button — shown while navigating
                          // to pickup (accepted) or destination (ongoing).
                          if (vm.rideRequest!.status == RideStatus.accepted ||
                              vm.rideRequest!.status == RideStatus.ongoing)
                            Consumer<DriverHomeViewModel>(
                              builder: (ctx, driverVm, _) => OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: const Color(0xFF00B4D8),
                                  side: const BorderSide(color: Color(0xFF00B4D8)),
                                  minimumSize: const Size(double.infinity, 54),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: () => _openWaze(ctx, driverVm, vm.rideRequest!),
                                icon: const Icon(Icons.navigation_outlined),
                                label: const Text(
                                  "Navigate with Waze",
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),

                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.red,
                              side: const BorderSide(color: Colors.red),
                              minimumSize: const Size(double.infinity, 54),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: vm.cancelRide,
                            icon: const Icon(Icons.cancel_outlined),
                            label: const Text("Cancel Ride",
                                style:
                                    TextStyle(fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Compact row showing when the passenger wants to be picked up.
  /// For scheduled rides shows the booked time; for instant rides shows "Now".
  Widget _buildPickupTimeChip(ThemeData t, RideRequest ride) {
    if (ride.scheduledFor != null) {
      final formatted =
          DateFormat("EEE, MMM d • h:mm a").format(ride.scheduledFor!);
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 15, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Scheduled pickup: $formatted",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    // Instant ride
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 15, color: Colors.green),
          const SizedBox(width: 8),
          const Text(
            "Immediate pickup",
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  /// Compact "12 min left" / "1h 5m left" text for the collapsed header chip.
  String _formatEtaChip(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    if (hours > 0) return '${hours}h ${minutes}m left';
    return '$minutes min left';
  }

  Widget _statusButton(
      ThemeData t, String label, Future<void> Function() action) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: t.primaryColor,
        minimumSize: const Size(double.infinity, 54),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async => await action(),
      child: Text(label,
          style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }

  Future<void> _openWaze(
    BuildContext ctx,
    DriverHomeViewModel driverVm,
    RideRequest ride,
  ) async {
      LatLng nextDestination;

    if (ride.status == RideStatus.accepted) {
      // Always go to pickup first
      nextDestination = ride.pickupLocation;
    } 
    else if (ride.status == RideStatus.ongoing) {
      // currentWaypointIndex tracks the last *completed* stop (starts at
      // -1 = none completed yet), so the next leg targets index + 1.
      final nextWaypointIndex = ride.currentWaypointIndex + 1;
      if (ride.waypointsAddresses.isNotEmpty &&
          nextWaypointIndex < ride.waypointsAddresses.length) {
        nextDestination = ride.waypointsLocation[nextWaypointIndex];
      } else {
        // All waypoints completed or no waypoints → go to final destination
        nextDestination = ride.destinationLocation;
      }
    }
    else {
      nextDestination = ride.destinationLocation;
    }

  final origin = driverVm.driverCurrentPosition;
  final fromParam = origin != null
      ? '&from=ll.${origin.latitude},${origin.longitude}'
      : '';
    final wazeUri = Uri.parse(
      'waze://?ll=${nextDestination.latitude},${nextDestination.longitude}&navigate=yes$fromParam',
    );
    final fallbackUri = Uri.parse(
      'https://waze.com/ul?ll=${nextDestination.latitude},${nextDestination.longitude}&navigate=yes$fromParam',
    );

    driverVm.muteVoiceForExternalApp();

    if (await canLaunchUrl(wazeUri)) {
      await launchUrl(wazeUri);
    } else {
      await launchUrl(fallbackUri, mode: LaunchMode.externalApplication);
    }
  }
}
