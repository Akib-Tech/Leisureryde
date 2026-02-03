import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../viewmodel/earnings/earnings_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';

class EarningsScreen extends StatelessWidget {
  const EarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => EarningsViewModel(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Earnings')),
        body: Consumer<EarningsViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) return const CustomLoadingIndicator();

            final theme = Theme.of(context);

            return RefreshIndicator(
              onRefresh: vm.refresh,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // --- Summary Card ---
                  Card(
                    color: theme.primaryColor,
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        children: [
                          Text('Total Earnings',
                              style: TextStyle(
                                  color: theme.colorScheme.onPrimary,
                                  fontSize: 16)),
                          const SizedBox(height: 8),
                          Text(
                            '\$${vm.totalEarnings.toStringAsFixed(2)}',
                            style: TextStyle(
                              color: theme.colorScheme.onPrimary,
                              fontSize: 36,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceAround,
                            children: [
                              _statColumn('Trips', vm.totalTrips.toString(),
                                  theme.colorScheme.onPrimary),
                              _statColumn(
                                  'Hours',
                                  vm.hoursOnline.toStringAsFixed(1),
                                  theme.colorScheme.onPrimary),
                              _statColumn(
                                  'Rating',
                                  vm.rating.toStringAsFixed(1),
                                  theme.colorScheme.onPrimary),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  Text('Recent Trips',
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 12),

                  if (vm.recentTrips.isEmpty)
                    const Center(child: Text('No completed trips yet.'))
                  else
                    ...vm.recentTrips.map((trip) => _tripCard(context, trip)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _statColumn(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: TextStyle(
                color: color, fontSize: 20, fontWeight: FontWeight.bold)),
        Text(label,
            style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
      ],
    );
  }

  Widget _tripCard(BuildContext context, trip) {
    final fmt = DateFormat('EEE, MMM d • h:mm a');
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: const Icon(Icons.local_taxi),
        title: Text(
          trip.destinationAddress.split(',').first,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          '${fmt.format(trip.createdAt)} • ${(trip.distance).toStringAsFixed(1)} mi',
        ),
        trailing: Text(
          '\$${trip.fare.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
      ),
    );
  }
}