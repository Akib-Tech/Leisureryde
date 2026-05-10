import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/ride_request_model.dart';
import '../../services/fare_calculation_service.dart';
import '../../viewmodel/admin/company_funds_view_model.dart';

class CompanyFundsScreen extends StatelessWidget {
  const CompanyFundsScreen({super.key});

  static const double _companyRate = 1 - FareCalculationService.driverShareRate;

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');
    final dateFormat = DateFormat('MMM d, y');

    return ChangeNotifierProvider(
      create: (_) => CompanyFundsViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Company Funds"),
        ),
        body: Consumer<CompanyFundsViewModel>(
          builder: (context, vm, _) {
            if (vm.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (vm.errorMessage != null) {
              return Center(child: Text(vm.errorMessage!));
            }
            if (!vm.hasRides) {
              return const Center(
                child: Text("No completed rides found.", style: TextStyle(fontSize: 16)),
              );
            }

            return RefreshIndicator(
              onRefresh: vm.fetchFunds,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _buildFilterBar(context, vm, dateFormat),
                  const SizedBox(height: 16),
                  _buildSummarySection(context, vm, currencyFormat),
                  const SizedBox(height: 24),
                  Text("Ride Breakdown", style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 20),
                  if (vm.filteredRides.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: Text("No rides in this period.", style: TextStyle(color: Colors.grey))),
                    )
                  else
                    ...vm.filteredRides.map(
                      (ride) => _buildRideCard(context, ride, currencyFormat, dateFormat),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildFilterBar(BuildContext context, CompanyFundsViewModel vm, DateFormat dateFmt) {
    final filters = [
      (DateFilter.allTime, 'All Time'),
      (DateFilter.thisMonth, 'This Month'),
      (DateFilter.lastMonth, 'Last Month'),
      (DateFilter.custom, 'Custom'),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: filters.map((entry) {
              final (filter, label) = entry;
              final isSelected = vm.selectedFilter == filter;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(label),
                  selected: isSelected,
                  onSelected: (_) async {
                    if (filter == DateFilter.custom) {
                      await _pickCustomRange(context, vm);
                    } else {
                      vm.setFilter(filter);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        if (vm.selectedFilter == DateFilter.custom && vm.customStart != null && vm.customEnd != null)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              "${dateFmt.format(vm.customStart!)} – ${dateFmt.format(vm.customEnd!)}",
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey),
            ),
          ),
      ],
    );
  }

  Future<void> _pickCustomRange(BuildContext context, CompanyFundsViewModel vm) async {
    final initialRange = (vm.customStart != null && vm.customEnd != null)
        ? DateTimeRange(start: vm.customStart!, end: vm.customEnd!)
        : DateTimeRange(
            start: DateTime.now().subtract(const Duration(days: 30)),
            end: DateTime.now(),
          );

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: initialRange,
    );

    if (picked != null) {
      vm.setCustomRange(picked.start, picked.end);
    }
  }

  Widget _buildSummarySection(BuildContext context, CompanyFundsViewModel vm, NumberFormat fmt) {
    return Column(
      children: [
        _buildSummaryCard(
          context,
          title: "Total Revenue",
          subtitle: "${vm.totalCompletedRides} completed rides",
          value: vm.totalRevenue,
          icon: Icons.attach_money,
          color: Colors.blue,
          fmt: fmt,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _buildSummaryCard(
                context,
                title: "Company Share",
                subtitle: "${(_companyRate * 100).toStringAsFixed(0)}% of fares",
                value: vm.companyShare,
                icon: Icons.business_center,
                color: Colors.purple,
                fmt: fmt,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildSummaryCard(
                context,
                title: "Driver Payouts",
                subtitle: "${(FareCalculationService.driverShareRate * 100).toStringAsFixed(0)}% of fares",
                value: vm.driverPayouts,
                icon: Icons.directions_car,
                color: Colors.green,
                fmt: fmt,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSummaryCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required double value,
    required IconData icon,
    required Color color,
    required NumberFormat fmt,
  }) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, size: 36, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  fmt.format(value),
                  style: theme.textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold),
                ),
                Text(title, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRideCard(BuildContext context, RideRequest ride, NumberFormat fmt, DateFormat dateFmt) {
    final companyEarning = ride.fare * _companyRate;
    final driverEarning = ride.fare * FareCalculationService.driverShareRate;
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(ride.passengerName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                Text(dateFmt.format(ride.createdAt), style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 2),
            Text(ride.vehicleType, style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            if (ride.driverName != null) ...[
              const SizedBox(height: 2),
              Text("Driver: ${ride.driverName}", style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey)),
            ],
            const Divider(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildFareChip(context, "Total Fare", ride.fare, Colors.blue, fmt),
                _buildFareChip(context, "Company (45%)", companyEarning, Colors.purple, fmt),
                _buildFareChip(context, "Driver (55%)", driverEarning, Colors.green, fmt),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFareChip(BuildContext context, String label, double amount, Color color, NumberFormat fmt) {
    return Column(
      children: [
        Text(fmt.format(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
        const SizedBox(height: 2),
        Text(label, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
      ],
    );
  }
}
