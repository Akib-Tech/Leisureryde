import 'package:flutter/material.dart';
import 'package:leisureryde/models/user_profile.dart';
import 'package:leisureryde/screens/admin/user_ride_history_screen.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/admin/user_view_model.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => UsersViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Manage Users"),
        ),
        body: Consumer<UsersViewModel>(
          builder: (context, viewModel, _) {
            if (viewModel.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            return RefreshIndicator(
              onRefresh: viewModel.fetchUsers,
              child: Column(
                children: [
                  _buildSearchBar(context, viewModel),
                  Expanded(
                    child: viewModel.filteredUsers.isEmpty
                        ? Center(
                            child: Text(
                              _searchController.text.isNotEmpty
                                  ? "No users match your search."
                                  : "No users found.",
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                            itemCount: viewModel.filteredUsers.length,
                            itemBuilder: (context, index) {
                              final user = viewModel.filteredUsers[index];
                              return _buildUserCard(context, user, viewModel);
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

  Widget _buildSearchBar(BuildContext context, UsersViewModel viewModel) {
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
          contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserProfile user, UsersViewModel viewModel) {
    final theme = Theme.of(context);
    return Card(
      elevation: 3,
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
                  child: user.profileImageUrl.isEmpty
                      ? Text(user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U', style: theme.textTheme.headlineSmall)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                      Text(user.email, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                      if (user.phone.isNotEmpty)
                        Text(user.phone, style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey[600])),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            _buildToggleRow(
              context: context,
              label: user.isBlocked ? "Unblock" : "Block",
              value: user.isBlocked,
              onChanged: (v) => viewModel.updateUserBlockStatus(user.uid, v),
              activeColor: Colors.red,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => UserRideHistoryScreen(userId: user.uid, personName: user.firstName),
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
        Switch(value: value, onChanged: onChanged, activeColor: activeColor ?? theme.primaryColor),
      ],
    );
  }
}
