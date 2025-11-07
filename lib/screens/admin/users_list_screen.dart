import 'package:flutter/material.dart';
import 'package:leisureryde/models/user_profile.dart';
import 'package:provider/provider.dart';

import '../../viewmodel/admin/user_view_model.dart';

class UsersListScreen extends StatelessWidget {
  const UsersListScreen({super.key});

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
            if (viewModel.users.isEmpty) {
              return const Center(child: Text("No users found."));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: viewModel.users.length,
              itemBuilder: (context, index) {
                final user = viewModel.users[index];
                return _buildUserCard(context, user, viewModel);
              },
            );
          },
        ),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, UserProfile user, UsersViewModel viewModel) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
              child: user.profileImageUrl.isEmpty ? Text(user.firstName.isNotEmpty ? user.firstName[0] : 'U') : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(user.fullName, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text(user.email, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'block') {
                  viewModel.updateUserBlockStatus(user.uid, !user.isBlocked);
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'block',
                  child: Text(user.isBlocked ? "Unblock User" : "Block User"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}