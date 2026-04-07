import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/screens/shared/timer/timer.dart';
import 'package:provider/provider.dart';
import '../../../models/ride_request_model.dart';
import '../../../viewmodel/ride/active_trip_driver_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../shared/chat/chat_screen.dart';
import '../../../services/database_service.dart';

class ActiveTripDriverBottomSheet extends StatelessWidget {
  final String rideId;
  const ActiveTripDriverBottomSheet({super.key, required this.rideId});

  @override

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActiveTripDriverViewModel(rideId: rideId),
      child: Consumer<ActiveTripDriverViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) {
            return const CustomLoadingIndicator();
          }

          if (vm.rideRequest == null || vm.passengerProfile == null) {
            return const SizedBox.shrink(); // or a nice loading state
          }

          final passenger = vm.passengerProfile!;
          final t = Theme.of(context);

          Widget? stateButton;
          switch (vm.rideRequest!.status) {
            case RideStatus.accepted:
              stateButton = _statusButton(context, vm, "Arrived at Pickup", vm.markArrived);
              break;
            case RideStatus.enroute:
              stateButton = _statusButton(context, vm, "Start Trip", vm.startTrip);
              break;
            case RideStatus.ongoing:
              stateButton = _statusButton(context, vm, "End Trip", vm.completeTrip);
              break;
            default:
              stateButton = const SizedBox.shrink();
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
                  // Drag Handle
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    width: 40,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),

                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                    child: Column(
                      children: [
                        // Status Label
                        Center(
                          child: Text(
                            vm.statusLabel,
                            style: t.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: t.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Passenger Info
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundImage: passenger.profileImageUrl.isNotEmpty
                                ? NetworkImage(passenger.profileImageUrl)
                                : null,
                            child: passenger.profileImageUrl.isEmpty
                                ? Text(passenger.firstName[0].toUpperCase(),
                                style: const TextStyle(fontWeight: FontWeight.bold))
                                : null,
                          ),
                          title: Text("${passenger.firstName} ${passenger.lastName}",
                            style: TextStyle(color: Colors.grey[900])),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                const Icon(Icons.star, size: 16, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(passenger.rating.toStringAsFixed(1)),
                              ]),
                              Text(passenger.email, style: TextStyle(color: Colors.grey[600])),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(icon: const Icon(Icons.call, color: Colors.green), onPressed: vm.makeCall),
                              IconButton(
                                icon: const Icon(Icons.chat, color: Colors.blue),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      rideId: rideId,
                                      otherUserId: passenger.uid,
                                      otherUserName: passenger.fullName,
                                      otherUserImageUrl: passenger.profileImageUrl,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 20),
          if(vm.rideRequest!.status == RideStatus.ongoing)
              TripEndTimer(
                destination: vm.userDestination,
                driverLocationStream: vm.driverLoc, // e.g., Firebase stream of driver position
                onTripAlmostEnded: () {
                  // Show "Almost there!" banner or notification
                },
              ),

                        const SizedBox(height: 24),

                        // Action Button
                        if (stateButton != null) stateButton,

                        const SizedBox(height: 12),

                        // Cancel Button
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(double.infinity, 54),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: vm.cancelRide,
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text("Cancel Ride", style: TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
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
  Widget _statusButton(BuildContext ctx, ActiveTripDriverViewModel vm,
      String label, Future<void> Function() action) {
    final theme = Theme.of(ctx);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
          backgroundColor: theme.primaryColor,
          minimumSize: const Size(double.infinity, 54),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
      onPressed: () async {
        await action();
      },
      child:
      Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
    );
  }
}