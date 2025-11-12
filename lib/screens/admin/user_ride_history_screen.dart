import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/screens/admin/ride_details_screen.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/admin/user_ride_history_view_model.dart';

class UserRideHistoryScreen extends StatelessWidget {
  final String? userId;
  final String? driverId;
  final String personName;

  const UserRideHistoryScreen({
    super.key,
    required this.personName,
    this.userId,
    this.driverId,
  }) : assert(userId != null || driverId != null, 'Either userId or driverId must be provided');

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UserRideHistoryViewModel(userId: userId, driverId: driverId),
      child: Scaffold(
        appBar: AppBar(
          title: Text("$personName's Rides"),
        ),
        body: Consumer<UserRideHistoryViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.errorMessage != null) {
              return Center(child: Text(viewModel.errorMessage!));
            }

            if (viewModel.groupedRides.isEmpty) {
              return const Center(
                child: Text("No ride history found for this person.", style: TextStyle(fontSize: 16)),
              );
            }

            final months = viewModel.groupedRides.keys.toList();

            return RefreshIndicator(
              onRefresh: viewModel.fetchRides,
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                itemCount: months.length,
                itemBuilder: (context, index) {
                  final month = months[index];
                  final ridesForMonth = viewModel.groupedRides[month]!;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                        child: Text(month, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      ),
                      ...ridesForMonth.map((ride) => _buildRideCard(context, ride)).toList(),
                    ],
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }

  // I've copied the beautiful ride card from your previous feedback to maintain UI consistency
  Widget _buildRideCard(BuildContext context, RideRequest ride) {
    // ... (This is the same beautiful _buildRideCard from the previous response)
    final theme = Theme.of(context);
    final statusColor = _getStatusColor(ride.status);

    return GestureDetector(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => RideDetailScreen(ride: ride))),
      child: Card(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        child: Row(
          children: [
            Container(
              width: 5,
              height: 100,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(12), bottomLeft: Radius.circular(12)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(child: Text(ride.passengerName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis)),
                        Text('\$${ride.fare.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(DateFormat('EEE, MMM d, yyyy h:mm a').format(ride.createdAt), style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600])),
                    const Divider(height: 16),
                    Row(
                      children: [
                        Icon(Icons.trip_origin, size: 16, color: theme.primaryColor),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ride.pickupAddress, overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.location_on, size: 16, color: Colors.green),
                        const SizedBox(width: 8),
                        Expanded(child: Text(ride.destinationAddress, overflow: TextOverflow.ellipsis, maxLines: 1)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.completed: return Colors.green;
      case RideStatus.cancelled:
      case RideStatus.cancelled_by_driver: return Colors.red;
      case RideStatus.failed: return Colors.orange;
      default: return Colors.blue;
    }
  }
}