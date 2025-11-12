import 'package:flutter/material.dart';
import 'package:leisureryde/app/service_locator.dart';
import 'package:leisureryde/screens/admin/ride_history_screen.dart';
import 'package:leisureryde/screens/admin/users_list_screen.dart';
import 'package:leisureryde/screens/shared/splash_screen/welcome_screen.dart';
import 'package:leisureryde/services/auth_service.dart';
import 'package:provider/provider.dart';

import '../../admin/driver_list.dart';
import '../../admin/user_list.dart';
import '../../viewmodel/admin/admin_view_model.dart';
import 'drivers_earning_screen.dart';
import 'drivers_list_screen.dart';

class AdminHomePage extends StatelessWidget {
  const AdminHomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AdminDashboardViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Dashboard"),
          actions: [
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: "Sign Out",
              onPressed: () async {
                // Show a confirmation dialog before signing out
                final confirmed = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text("Confirm Sign Out"),
                    content: const Text("Are you sure you want to sign out?"),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: const Text("Cancel"),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: const Text("Sign Out"),
                      ),
                    ],
                  ),
                );

                if (confirmed == true && context.mounted) {
                  final auth = locator<AuthService>();
                  await auth.signOut();
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => WelcomePage()),
                        (Route<dynamic> route) => false, // This predicate removes all previous routes
                  );                }
              },
            ),
          ],
        ),
        body: Consumer<AdminDashboardViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (viewModel.summary == null) {
              return const Center(child: Text("Could not load dashboard data."));
            }

            return RefreshIndicator(
              onRefresh: viewModel.fetchSummary,
              child: ListView(
                padding: const EdgeInsets.all(16.0),
                children: [
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 1.2,
                    children: [
                      _buildSummaryCard(context, title: "Total Users", value: viewModel.summary!.totalUsers.toString(), icon: Icons.people, color: Colors.blue),
                      _buildSummaryCard(context, title: "Total Drivers", value: viewModel.summary!.totalDrivers.toString(), icon: Icons.directions_car, color: Colors.green),
                      _buildSummaryCard(context, title: "Total Rides", value: viewModel.summary!.totalRides.toString(), icon: Icons.local_taxi, color: Colors.orange),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text("Management", style: Theme.of(context).textTheme.titleLarge),
                  const Divider(height: 24),
                  _buildNavigationTile(context, title: "Manage Drivers", icon: Icons.directions_car_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriversListScreen()))),
                  _buildNavigationTile(context, title: "Manage Users", icon: Icons.people_outline, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const UsersListScreen()))),
                  // --- UPDATED NAVIGATION ---
                  _buildNavigationTile(context, title: "Ride History", icon: Icons.receipt_long_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RideHistoryScreen()))),
                  _buildNavigationTile(context, title: "Driver Earnings", icon: Icons.account_balance_wallet_outlined, onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DriverEarningsScreen()))),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, {required String title, required String value, required IconData icon, required Color color}) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, size: 32, color: color),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value, style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
              Text(title, style: theme.textTheme.bodyMedium?.copyWith(color: color)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile(BuildContext context, {required String title, required IconData icon, required VoidCallback onTap}) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      child: ListTile(
        leading: Icon(icon, color: Theme.of(context).primaryColor),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: onTap,
      ),
    );
  }
}