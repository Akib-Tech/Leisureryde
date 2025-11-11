import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leisureryde/viewmodel/account/account_view_model.dart';

class NotificationSettingsScreen extends StatelessWidget {
  const NotificationSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AccountViewModel>(
      builder: (context, viewModel, child) {
        final userProfile = viewModel.userProfile;
        if (userProfile == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: const Text('Notification Settings'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              Card(
                child: SwitchListTile(
                  title: const Text('Push Notifications'),
                  subtitle: const Text('Receive alerts for ride updates and promotions.'),
                  value: userProfile.pushNotificationsEnabled,
                  onChanged: (bool value) {
                    viewModel.updateNotificationPreference(value);
                  },
                  secondary: const Icon(Icons.notifications_active),
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Text(
                  'Turning off notifications may prevent you from receiving important updates about your ride status, messages from your driver, and special offers.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}