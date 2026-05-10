import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/admin/ride_history_view_model.dart';
import 'ride_details_screen.dart';

class RideHistoryScreen extends StatefulWidget {
  const RideHistoryScreen({super.key});

  @override
  State<RideHistoryScreen> createState() => _RideHistoryScreenState();
}

class _RideHistoryScreenState extends State<RideHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RideHistoryViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Ride History"),
        ),
        body: Consumer<RideHistoryViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.errorMessage != null) {
              return Center(child: Text(viewModel.errorMessage!));
            }
            if (!viewModel.hasRides) {
              return const Center(child: Text("No ride history found.", style: TextStyle(fontSize: 16)));
            }

            final grouped = viewModel.groupedRides;
            final months = grouped.keys.toList();

            return RefreshIndicator(
              onRefresh: viewModel.fetchRides,
              child: Column(
                children: [
                  _buildSearchBar(context, viewModel),
                  Expanded(
                    child: grouped.isEmpty
                        ? const Center(
                            child: Padding(
                              padding: EdgeInsets.all(32),
                              child: Text("No rides match your search.", style: TextStyle(color: Colors.grey)),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.only(bottom: 8),
                            itemCount: months.length,
                            itemBuilder: (context, index) {
                              final month = months[index];
                              final ridesForMonth = grouped[month]!;
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                                    child: Text(
                                      month,
                                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  ...ridesForMonth.map((ride) => _buildRideCard(context, ride)),
                                ],
                              );
                            },
                          ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSearchBar(BuildContext context, RideHistoryViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: viewModel.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search by passenger, driver or address...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    viewModel.setSearchQuery('');
                  },
                )
              : null,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, RideRequest ride) {
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
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  bottomLeft: Radius.circular(12),
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(ride.passengerName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                        Text('\$${ride.fare.toStringAsFixed(2)}', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEE, MMM d, yyyy  h:mm a').format(ride.createdAt),
                      style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
                    ),
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
                        const Icon(Icons.location_on, size: 16, color: Colors.green),
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
