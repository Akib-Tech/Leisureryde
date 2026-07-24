// ignore_for_file: deprecated_member_use, duplicate_ignore

// ignore_for_file: deprecated_member_use

import 'package:flutter/material.dart';
import 'package:leisureryde/models/driver_profile.dart';
import 'package:leisureryde/screens/admin/user_ride_history_screen.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../viewmodel/admin/driver_view_model.dart';

class DriversListScreen extends StatefulWidget {
  const DriversListScreen({super.key});

  @override
  State<DriversListScreen> createState() => _DriversListScreenState();
}

class _DriversListScreenState extends State<DriversListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

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
            return RefreshIndicator(
              onRefresh: viewModel.fetchDrivers,
              child: Column(
                children: [
                  _buildSearchBar(context, viewModel),
                  Expanded(
                    child: viewModel.filteredDrivers.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isNotEmpty
                                  ? "No drivers match your search."
                                  : "No drivers found.",
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            itemCount: viewModel.filteredDrivers.length,
                            itemBuilder: (context, index) {
                              final driver = viewModel.filteredDrivers[index];
                              return _buildDriverCard(
                                  context, driver, viewModel);
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

  Widget _buildSearchBar(BuildContext context, DriversViewModel viewModel) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: TextField(
        controller: _searchController,
        onChanged: viewModel.setSearchQuery,
        decoration: InputDecoration(
          hintText: 'Search by name, email or phone...',
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
          contentPadding:
              const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildDriverCard(
      BuildContext context, DriverProfile driver, DriversViewModel viewModel) {
    final theme = Theme.of(context);
    final stats = viewModel.stats[driver.uid];
    final trips = stats?.trips ?? driver.totalTrips;
    final ratingStr = (stats != null && stats.rating > 0)
        ? stats.rating.toStringAsFixed(1)
        : (driver.rating > 0 ? driver.rating.toStringAsFixed(1) : 'N/A');

    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: driver.profileImageUrl.isNotEmpty
                      ? NetworkImage(driver.profileImageUrl)
                      : null,
                  child: driver.profileImageUrl.isEmpty
                      ? Text(
                          driver.firstName.isNotEmpty
                              ? driver.firstName[0].toUpperCase()
                              : 'D',
                          style: theme.textTheme.headlineSmall)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(driver.fullName,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold)),
                      Text(driver.email,
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildSectionHeader(context, "Account Details"),
            _buildDetailRow(context, Icons.phone_outlined, "Phone",
                driver.phone.isNotEmpty ? driver.phone : "—"),
            _buildDetailRow(context, Icons.cake_outlined, "Date of Birth",
                driver.dateOfBirth.isNotEmpty ? driver.dateOfBirth : "—"),
            _buildDetailRow(context, Icons.wc_outlined, "Gender",
                driver.gender.isNotEmpty ? driver.gender : "—"),
            const SizedBox(height: 8),
            _buildSectionHeader(context, "Vehicle"),
            _buildDetailRow(context, Icons.directions_car_outlined, "Car Model",
                driver.carModel.isNotEmpty ? driver.carModel : "—"),
            _buildDetailRow(
                context,
                Icons.confirmation_number_outlined,
                "Licence Plate",
                driver.licensePlate.isNotEmpty ? driver.licensePlate : "—"),
            const SizedBox(height: 8),
            _buildSectionHeader(context, "Stats"),
            Row(
              children: [
                Expanded(
                    child: _buildStatChip(
                        context, Icons.star, ratingStr, Colors.amber)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatChip(context, Icons.local_taxi,
                        "$trips trips", Colors.blue)),
                const SizedBox(width: 8),
                Expanded(
                    child: _buildStatChip(
                  context,
                  driver.isOnline ? Icons.circle : Icons.circle_outlined,
                  driver.isOnline ? "Online" : "Offline",
                  driver.isOnline ? Colors.green : Colors.grey,
                )),
              ],
            ),
            const SizedBox(height: 8),
            _buildSectionHeader(context, "Bank Details"),
            _buildDetailRow(
                context,
                Icons.person_outline,
                "Account Holder",
                driver.bankAccountName.isNotEmpty
                    ? driver.bankAccountName
                    : "—"),
            _buildDetailRow(
                context,
                Icons.account_balance_outlined,
                "Bank Name",
                driver.bankName.isNotEmpty ? driver.bankName : "—"),
            _buildDetailRow(context, Icons.numbers_outlined, "Account Number",
                driver.accountNumber.isNotEmpty ? driver.accountNumber : "—"),
            _buildDetailRow(
                context,
                Icons.swap_horiz_outlined,
                "Routing / Sort Code",
                driver.bankCode.isNotEmpty ? driver.bankCode : "—"),
            const Divider(height: 24),
            _buildSectionHeader(context, "Documents"),
            _buildDocumentLink(context, "Driver's License", driver.licenseUrl),
            _buildDocumentLink(
                context, "Vehicle Registration", driver.vehicleRegistrationUrl),
            _buildDocumentLink(
                context, "Proof of Insurance", driver.proofOfInsuranceUrl),
            const SizedBox(height: 8),
            _buildSectionHeader(context, "Admin Actions"),
           
            const SizedBox(height: 8),

            _buildApprovalSection(
  context: context,
  driver: driver,
  viewModel: viewModel,
),
const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserRideHistoryScreen(
                        driverId: driver.uid, personName: driver.firstName),
                  ),
                ),
                icon: const Icon(Icons.history),
                label: const Text("View Ride History"),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
      child: Text(title,
          style: Theme.of(context)
              .textTheme
              .titleSmall
              ?.copyWith(color: Colors.grey[700], fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildDetailRow(
      BuildContext context, IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3.0),
      child: Row(
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Text("$label: ",
              style: TextStyle(color: Colors.grey[700], fontSize: 13)),
          Expanded(
            child: Text(value,
                style:
                    const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildStatChip(
      BuildContext context, IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(label,
                style: TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w600, color: color),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
    );
  }

  Widget _buildDocumentLink(BuildContext context, String title, String url) {
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
            Text("Not Uploaded",
                style: TextStyle(
                    fontStyle: FontStyle.italic, color: Colors.grey[500])),
          ],
        ),
      );
    }
    return TextButton.icon(
      style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 0)),
      onPressed: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Could not open document: $url')));
          }
        }
      },
      icon: Icon(Icons.open_in_new, size: 18, color: theme.primaryColor),
      label: Text("View $title", style: TextStyle(color: theme.primaryColor)),
    );
  }


  Widget _buildApprovalSection({
    required BuildContext context,
    required DriverProfile driver,
    required DriversViewModel viewModel,
    Color? activeColor
  }) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Driver Category",
          style: theme.textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: driver.vehicleCategory!.isEmpty ? "standard" : driver.vehicleCategory,
          decoration: const InputDecoration(
            border: OutlineInputBorder(),
            hintText: "Select category",
          ),
          items: const [
            DropdownMenuItem(
              value: "standard",
              child: Text("Leisure Comfort"),
            ),
            DropdownMenuItem(
              value: "premium",
              child: Text("Leisure Plus"),
            ),
            DropdownMenuItem(
              value: "luxury",
              child: Text("Leisure Exec"),
            ),
          ],
          onChanged: (value) {
            if (value != null) {
              debugPrint("Category : $value");
             viewModel.updateVehicleCategory(
                driver.uid,
                value,
              );
            }
          },
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              driver.isApproved ? "Restrict" : "Approve",
              style: theme.textTheme.titleMedium,
            ),
            Switch(
              value: driver.isApproved,
              onChanged: (value) {
                if (value && (driver.vehicleCategory!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        "Please select a driver category first.",
                      ),
                    ),
                  );
                  return;
                }

                viewModel.updateDriverApproval(
                  driver.uid,
                  value,
                );
              },
              
            activeColor: activeColor ?? theme.primaryColor
            ),
          ],
        ),
      ],
    );
  }
}
