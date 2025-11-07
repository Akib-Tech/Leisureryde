import 'package:flutter/material.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../viewmodel/admin/driver_view_model.dart';

class DriversListScreen extends StatelessWidget {
  const DriversListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => DriversViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manage Drivers"),
        ),
        body: Consumer<DriversViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.drivers.isEmpty) {
              return const Center(child: Text("No drivers found."));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: viewModel.drivers.length,
              itemBuilder: (context, index) {
                final driver = viewModel.drivers[index];
                return _buildDriverCard(context, driver, viewModel);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildDriverCard(BuildContext context, DriverProfile driver, DriversViewModel viewModel) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundImage: driver.profileImageUrl.isNotEmpty ? NetworkImage(driver.profileImageUrl) : null,
                  child: driver.profileImageUrl.isEmpty ? Text(driver.firstName.isNotEmpty ? driver.firstName[0] : 'D') : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.fullName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                      Text(driver.email, style: theme.textTheme.bodySmall),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            _buildInfoRow(Icons.phone, driver.phone),
            _buildInfoRow(Icons.directions_car, "${driver.carModel} • ${driver.licensePlate}"),
            if (driver.licenseUrl.isNotEmpty)
              TextButton.icon(
                onPressed: () => launchUrl(Uri.parse(driver.licenseUrl)),
                icon: Icon(Icons.description_outlined, size: 18, color: theme.primaryColor),
                label: Text("View License", style: TextStyle(color: theme.primaryColor)),
              ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Approved", style: theme.textTheme.titleSmall),
                Switch(
                  value: driver.isApproved,
                  onChanged: (newValue) => viewModel.updateDriverApproval(driver.uid, newValue),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: TextStyle(color: Colors.grey[800]))),
        ],
      ),
    );
  }
}