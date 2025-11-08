import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:provider/provider.dart';
import '../../../viewmodel/ride/active_trip_driver_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../shared/chat/chat_screen.dart';

class ActiveTripDriverBottomSheet extends StatelessWidget {
  final String rideId;
  const ActiveTripDriverBottomSheet({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActiveTripDriverViewModel(rideId: rideId),
      child: Consumer<ActiveTripDriverViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) return const CustomLoadingIndicator();
          if (vm.rideRequest == null || vm.passengerProfile == null) {
            return const SizedBox.shrink();
          }

          final passenger = vm.passengerProfile!;
          final t = Theme.of(context);

          // Determine which control button to show
          Widget? stateButton;
          switch (vm.rideRequest!.status) {
            case 'accepted':
              stateButton = _statusButton(
                  context, vm, "Arrived at Pickup", vm.markArrived);
              break;
            case 'enroute':
              stateButton = _statusButton(
                  context, vm, "Start Trip", vm.startTrip);
              break;
            case 'ongoing':
              stateButton = _statusButton(
                  context, vm, "End Trip", vm.completeTrip);
              break;
            case 'completed':
              stateButton = const SizedBox.shrink();
              break;
            default:
              stateButton = const SizedBox.shrink();
          }

          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            padding: const EdgeInsets.all(20),
            child: ListView(
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: Colors.grey[300],
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
                Center(
                  child: Text(
                    vm.statusLabel,
                    style: t.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: t.primaryColor),
                  ),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: CircleAvatar(
                    radius: 28,
                    backgroundImage: passenger.profileImageUrl.isNotEmpty
                        ? NetworkImage(passenger.profileImageUrl)
                        : null,
                    child: passenger.profileImageUrl.isEmpty
                        ? Text(
                      passenger.firstName[0].toUpperCase(),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    )
                        : null,
                  ),
                  title: Text(passenger.fullName,
                      style: t.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Icon(Icons.star,
                            size: 16, color: t.primaryColor),
                        Text(passenger.rating.toStringAsFixed(1))
                      ]),
                      Text(passenger.email,
                          style: TextStyle(color: Colors.grey[600])),
                    ],
                  ),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: () => vm.makeCall()),
                      IconButton(
                          icon: const Icon(Icons.chat, color: Colors.blue),
                          onPressed: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                  rideId: rideId,
                                  otherUserId: passenger.uid,
                                  otherUserName: passenger.fullName,
                                  otherUserImageUrl:
                                  passenger.profileImageUrl),
                            ),
                          )),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                if (stateButton != null) stateButton,
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red)),
                  onPressed: vm.cancelRide,
                  icon: const Icon(Icons.cancel_outlined),
                  label: const Text("Cancel Ride"),
                ),
              ],
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