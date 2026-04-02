import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../viewmodel/ride/active_trip_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../shared/chat/chat_screen.dart';

class ActiveTripCard extends StatelessWidget {
  final String rideId;
  const ActiveTripCard({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ChangeNotifierProvider(
      create: (_) => ActiveTripViewModel(rideId: rideId),
      child: Consumer<ActiveTripViewModel>(
        builder: (context, vm, _) {
          if (vm.isLoading) return const CustomLoadingIndicator();

          if (vm.driverProfile == null || vm.rideRequest == null) {
            return Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: const [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text("Connecting to driver..."),
                ],
              ),
            );
          }

          final driver = vm.driverProfile!;
          final String label = _statusLabel(vm.tripStatus);
          final bool isOngoing = vm.tripStatus == 'accepted' || vm.tripStatus == 'ongoing' || vm.tripStatus == 'enroute' ;
          final bool canCancel = vm.tripStatus == 'pending' ;
          return Container(
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
                Container(
                  width: 40,
                  height: 5,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: theme.dividerColor,
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
                Text(
                  label,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),

                // Driver Info
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundImage: driver.profileImageUrl.isNotEmpty
                          ? NetworkImage(driver.profileImageUrl)
                          : null,
                      child: driver.profileImageUrl.isEmpty
                          ? Text(
                        driver.firstName[0].toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(driver.fullName,
                              style: theme.textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.bold)),
                          Row(children: [
                            Icon(Icons.star, size: 16, color: theme.primaryColor),
                            Text(driver.rating.toStringAsFixed(1)),
                          ]),
                          Text('${driver.carModel} • ${driver.licensePlate}',
                              style: theme.textTheme.bodySmall
                                  ?.copyWith(color: Colors.grey[600])),
                        ],
                      ),
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.call, color: Colors.green),
                          onPressed: vm.makePhoneCall,
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat, color: Colors.blue),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  rideId: rideId,
                                  otherUserId: driver.uid,
                                  otherUserName: driver.fullName,
                                  otherUserImageUrl: driver.profileImageUrl,
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Cancel Button with conditional logic
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: canCancel
                        ? theme.colorScheme.error
                        : Colors.grey,
                    side: BorderSide(
                      color: canCancel
                          ? theme.colorScheme.error
                          : Colors.grey,
                    ),
                    minimumSize: const Size(double.infinity, 50),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: canCancel
                      ? () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Cancel Trip?"),
                        content: const Text(
                            'Are you sure you want to cancel this trip?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('No'),
                          ),
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text("Yes"),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true && context.mounted) {
                      await vm.cancelTrip();
                    }
                  }
                      : null,   // Button disabled when cannot cancel

                  icon: const Icon(Icons.cancel_outlined),
                  label: Text(
                    isOngoing ? 'Cannot Cancel - Trip in Progress' : 'Cancel Trip',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),

                // Optional helpful message when trip is ongoing
                if (isOngoing)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      "You can no longer cancel once the trip has started.\n"
                          "Please contact the driver if needed.",
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: Colors.grey[600],
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(String? code) {
    switch (code) {
      case 'accepted':
        return 'Driver is on the way';
      case 'enroute':
        return 'Driver arriving';
      case 'ongoing':
        return 'Trip in progress';
      case 'completed':
        return 'Trip completed';
      default:
        return 'Connecting...';
    }
  }
}