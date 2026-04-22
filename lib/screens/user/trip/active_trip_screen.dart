import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../models/ride_request_model.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../../viewmodel/ride/active_trip_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../shared/chat/chat_screen.dart';

/// The user-facing active trip card shown at the bottom of HomeScreen.
///
/// IMPORTANT: We pass the shared [MapViewModel] from [HomeViewModel] into
/// [ActiveTripViewModel] so that all polylines and markers are drawn into
/// the same [GoogleMap] widget that HomeScreen is already displaying.
/// If we let ActiveTripViewModel create its own MapViewModel, it would draw
/// into a separate, invisible instance and nothing would appear on screen.
class ActiveTripCard extends StatelessWidget {
  final String rideId;

  const ActiveTripCard({super.key, required this.rideId});

  @override
  Widget build(BuildContext context) {
    // Read the shared HomeViewModel to get its MapViewModel.
    final homeViewModel = context.read<HomeViewModel>();

    return ChangeNotifierProvider(
      // Pass the SHARED mapViewModel so polylines go to the right place.
      create: (_) => ActiveTripViewModel(
        rideId: rideId,
        mapViewModel: homeViewModel.mapViewModel,
      ),
      child: Consumer<ActiveTripViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const CustomLoadingIndicator();
          }

          if (viewModel.rideRequest == null) {
            return const SizedBox.shrink();
          }

          final theme = Theme.of(context);
          final rideRequest = viewModel.rideRequest!;

          return Container(
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
                // Drag handle
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
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                  child: Column(
                    children: [
                      // Status label
                      Text(
                        _statusLabel(rideRequest.status),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.primaryColor,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Driver info
                      if (viewModel.driverProfile != null) ...[
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            radius: 28,
                            backgroundImage: viewModel.driverProfile!.profileImageUrl.isNotEmpty
                                ? NetworkImage(viewModel.driverProfile!.profileImageUrl)
                                : null,
                            child: viewModel.driverProfile!.profileImageUrl.isEmpty
                                ? Text(
                              viewModel.driverProfile!.firstName[0].toUpperCase(),
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            )
                                : null,
                          ),
                          title: Text(
                            viewModel.driverProfile!.fullName,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                          subtitle: Row(
                            children: [
                              const Icon(Icons.star, size: 14, color: Colors.amber),
                              const SizedBox(width: 4),
                              Text(viewModel.driverProfile!.rating.toStringAsFixed(1)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.call, color: Colors.green),
                                onPressed: () => _callDriver(viewModel.driverProfile!.phone),
                              ),
                              IconButton(
                                icon: const Icon(Icons.chat, color: Colors.blue),
                                onPressed: () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ChatScreen(
                                      rideId: rideId,
                                      otherUserId: viewModel.driverProfile!.uid,
                                      otherUserName: viewModel.driverProfile!.fullName,
                                      otherUserImageUrl: viewModel.driverProfile!.profileImageUrl,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 12),
                      ],

                      // Destination row
                      Row(
                        children: [
                          Icon(Icons.location_on, color: theme.primaryColor, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              rideRequest.destinationAddress,
                              style: theme.textTheme.bodyMedium,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),

                      // Cancel button — only shown before trip is ongoing
                      if (rideRequest.status == RideStatus.pending)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () => viewModel.cancelTrip(),
                          icon: const Icon(Icons.cancel_outlined),
                          label: const Text(
                            "Cancel Ride",
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(RideStatus status) {
    switch (status) {
      case RideStatus.accepted:
        return "Driver is on the way";
      case RideStatus.enroute:
        return "Driver is arriving";
      case RideStatus.ongoing:
        return "Trip in progress";
      default:
        return "Finding your driver...";
    }
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}