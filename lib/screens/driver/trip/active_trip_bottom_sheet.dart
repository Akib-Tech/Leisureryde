import 'dart:async';
import 'package:flutter/material.dart';
import 'package:leisureryde/screens/shared/timer/timer.dart';
import 'package:provider/provider.dart';
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
              stateButton = _statusButton(t, "Start Trip", vm.startTrip);
              break;
            case RideStatus.ongoing:
              stateButton = _statusButton(t, "End Trip", vm.completeTrip);
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
                                  color: Colors.grey[300],
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              const Spacer(),
                              Icon(
                                _isCollapsed
                                    ? Icons.keyboard_arrow_up
                                    : Icons.keyboard_arrow_down,
                                color: Colors.grey[500],
                              ),
                            ],
                          ),
                          if (_isCollapsed) ...[
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage:
                                      passenger.profileImageUrl.isNotEmpty
                                          ? NetworkImage(
                                              passenger.profileImageUrl)
                                          : null,
                                  child: passenger.profileImageUrl.isEmpty
                                      ? Text(
                                          passenger.firstName[0].toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold))
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    passenger.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color:
                                        t.primaryColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    vm.statusLabel,
                                    style: TextStyle(
                                      color: t.primaryColor,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
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
                              passenger.fullName,
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
                                Text(passenger.email,
                                    style:
                                        TextStyle(color: Colors.grey[600])),
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
}
