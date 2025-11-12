import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/admin/drivers_earning_view_model.dart';

class DriverEarningsScreen extends StatelessWidget {
  const DriverEarningsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(locale: 'en_US', symbol: '\$');

    return ChangeNotifierProvider(
      create: (_) => DriverEarningsViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Driver Earnings"),
        ),
        body: Consumer<DriverEarningsViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }

            if (viewModel.errorMessage != null) {
              return Center(child: Text(viewModel.errorMessage!));
            }

            if (viewModel.earnings.isEmpty) {
              return const Center(
                child: Text("No completed rides found to calculate earnings.", style: TextStyle(fontSize: 16)),
              );
            }

            return RefreshIndicator(
              onRefresh: viewModel.fetchEarnings,
              child: ListView.builder(
                itemCount: viewModel.earnings.length,
                itemBuilder: (context, index) {
                  final summary = viewModel.earnings[index];
                  return Card(
                    margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text((index + 1).toString()),
                      ),
                      title: Text(summary.driverName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text('${summary.totalRides} completed rides'),
                      trailing: Text(
                        currencyFormat.format(summary.totalEarnings),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}