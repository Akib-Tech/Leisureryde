
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:leisureryde/viewmodel/activity/activity_view_model.dart';
import 'package:leisureryde/widgets/custom_loading_indicator.dart';

import '../../../models/ride_request_model.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ActivityViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Activity', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Consumer<ActivityViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const CustomLoadingIndicator();
            }

            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildSectionHeader(context, 'Upcoming'),
                const SizedBox(height: 12),
                viewModel.upcomingRides.isEmpty
                    ? _buildEmptyState(context, 'You have no upcoming rides.')
                    : Column(
                  children: viewModel.upcomingRides
                      .map((ride) => _buildRideCard(context, ride))
                      .toList(),
                ),
                const SizedBox(height: 24),
                _buildSectionHeader(context, 'Past Rides'),
                const SizedBox(height: 12),
                viewModel.pastRides.isEmpty
                    ? _buildEmptyState(context, 'Your ride history is empty.')
                    : Column(
                  children: viewModel.pastRides
                      .map((ride) => _buildRideCard(context, ride))
                      .toList(),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleLarge?.copyWith(
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, String message) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 48),
      decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor)
      ),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.map_outlined, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(color: Colors.grey[600], fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, RideRequest ride) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat('MMM d, yyyy').format(ride.createdAt);
    final formattedTime = DateFormat('h:mm a').format(ride.createdAt);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: theme.dividerColor.withOpacity(0.5)),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to a RideDetailsScreen(rideId: ride.id)
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Tapped on ride to ${ride.destinationAddress}')),
          );
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Date and Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$formattedDate at $formattedTime',
                    style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                  ),
                  Text(
                    '\$${ride.fare.toStringAsFixed(2)}',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Middle Row: Route Info
              Row(
                children: [
                  // Route visual
                  Column(
                    children: [
                      Icon(Icons.trip_origin, color: theme.primaryColor, size: 20),
                      Container(
                        height: 40,
                        width: 1,
                        color: Colors.grey.shade300,
                      ),
                      Icon(Icons.location_on, color: Colors.red.shade400, size: 20),
                    ],
                  ),
                  const SizedBox(width: 12),
                  // Addresses
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ride.pickupAddress,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 24),
                        Text(
                          ride.destinationAddress,
                          style: theme.textTheme.bodyMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Bottom Row: Vehicle and Status
              Row(
                children: [
                  Icon(Icons.directions_car, color: Colors.grey[600], size: 20),
                  const SizedBox(width: 8),
                  Text(
                    ride.vehicleType,
                    style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[700]),
                  ),
                  const Spacer(),
                  _buildStatusChip(context, ride.status),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusChip(BuildContext context, RideStatus status) {
    Color chipColor;
    String statusText;
    switch (status) {
      case RideStatus.completed:
        chipColor = Colors.green;
        statusText = 'Completed';
        break;
      case RideStatus.cancelled:
        chipColor = Colors.red;
        statusText = 'Cancelled';
        break;
      default:
        chipColor = Theme.of(context).primaryColor;
        statusText = status.name[0].toUpperCase() + status.name.substring(1); // Capitalize
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        statusText,
        style: TextStyle(
          color: chipColor,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    );
  }
}