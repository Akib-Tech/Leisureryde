import 'package:flutter/material.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../viewmodel/admin/driver_view_model.dart';

import 'package:flutter/material.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/screens/admin/user_ride_history_screen.dart';
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
            return RefreshIndicator(
              onRefresh: viewModel.fetchDrivers,
              child: ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: viewModel.drivers.length,
                itemBuilder: (context, index) {
                  final driver = viewModel.drivers[index];
                  return _buildDriverCard(context, driver, viewModel);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildDriverCard(BuildContext context, DriverProfile driver, DriversViewModel viewModel) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Section
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: driver.profileImageUrl.isNotEmpty ? NetworkImage(driver.profileImageUrl) : null,
                  child: driver.profileImageUrl.isEmpty ? Text(driver.firstName.isNotEmpty ? driver.firstName[0].toUpperCase() : 'D', style: theme.textTheme.headlineSmall) : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.fullName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(driver.email, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            // Documents Section
            _buildSectionHeader(context, "Documents"),
            _buildDocumentLink(context, "Driver's License", driver.licenseUrl),
            _buildDocumentLink(context, "Vehicle Registration", driver.vehicleRegistrationUrl),
            _buildDocumentLink(context, "Proof of Insurance", driver.proofOfInsuranceUrl),
            const SizedBox(height: 8),
            // Admin Actions Section
            _buildSectionHeader(context, "Admin Actions"),
            _buildToggleRow(
              context: context,
              label: driver.isApproved ? "Restrict" : "Approve", // DYNAMIC LABEL
              value: driver.isApproved,
              onChanged: (newValue) => viewModel.updateDriverApproval(driver.uid, newValue),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => UserRideHistoryScreen(
                        driverId: driver.uid,
                        personName: driver.firstName,
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.history),
                label: const Text("View Ride History"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Helper widgets remain the same as the previous response...
  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey[700], fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDocumentLink(BuildContext context, String title, String url) {
    // ... (same as before)
    final theme = Theme.of(context);
    if (url.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(Icons.description_outlined, size: 18, color: Colors.grey[400]),
            const SizedBox(width: 8),
            Text(title, style: TextStyle(color: Colors.grey[700])),
            const Spacer(),
            Text("Not Uploaded", style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey[500])),
          ],
        ),
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0)),
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open document: $url')));
        }
      },
      icon: Icon(Icons.open_in_new, size: 18, color: theme.primaryColor),
      label: Text("View $title", style: TextStyle(color: theme.primaryColor)),
    );
  }

  Widget _buildToggleRow({
    required BuildContext context,
    required String label,
    required bool value,
    required Function(bool) onChanged,
    Color? activeColor,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.textTheme.titleMedium),
        Switch(
          value: value,
          onChanged: onChanged,
          activeColor: activeColor ?? theme.primaryColor,
        ),
      ],
    );
  }
}