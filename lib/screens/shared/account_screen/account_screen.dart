// In: lib/screens/account/account_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:leisureryde/models/driver_profile.dart' show DriverProfile;
import 'package:leisureryde/models/saved_places.dart';
import 'package:leisureryde/viewmodel/account/account_view_model.dart';
import 'package:leisureryde/widgets/custom_loading_indicator.dart';
import '../../driver/vehicle/vehicle_info_screen.dart';
import '../splash_screen/welcome_screen.dart';
import 'notications.dart';


class AccountScreen extends StatefulWidget {
  final bool isDriver;
  const AccountScreen({super.key, required this.isDriver});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final AccountViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = AccountViewModel(isDriver: widget.isDriver);
    _viewModel.addListener(_handleProfileState);
  }

  void _handleProfileState() {
    if (!mounted) return;
    if (!_viewModel.isLoading && _viewModel.userProfile == null) {
      _viewModel.removeListener(_handleProfileState);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomePage()),
            (route) => false,
      );
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_handleProfileState);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // We provide the _viewModel instance created in initState.
    // This is important for the fix below.
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Account', style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          elevation: 0,
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Consumer<AccountViewModel>(
          builder: (context, viewModel, child) {
            if (viewModel.isLoading) {
              return const CustomLoadingIndicator();
            }

            if (viewModel.userProfile == null) {
              return const SizedBox.shrink();
            }

            return ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              children: [
                _buildProfileHeader(context, viewModel),
                const SizedBox(height: 24),
                _buildSavedPlacesSection(context, viewModel),
                const SizedBox(height: 24),
                _buildSettingsSection(context, viewModel),
                const SizedBox(height: 24),
                _buildActionsSection(context, viewModel),
              ],
            );
          },
        ),
      ),
    );
  }

  // --- THIS WIDGET CONTAINS THE FIX ---
  Widget _buildSettingsSection(BuildContext context, AccountViewModel viewModel) {
    return _SettingsGroup(
      title: 'Settings & Preferences',
      children: [
        if (viewModel.isDriver) ...[
          _SettingsTile(
            icon: Icons.directions_car,
            title: 'Vehicle Information',
            onTap: () {
              // THE FIX IS HERE:
              // We wrap the new screen in a ChangeNotifierProvider.value.
              // This ensures the EXISTING viewModel instance is passed into the new route,
              // making it available to VehicleInfoScreen.
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => ChangeNotifierProvider.value(
                    value: viewModel,
                    child: const VehicleInfoScreen(),
                  ),
                ),
              );
            },
          ),
          const _Divider(),
        ],
        _SettingsTile(
          icon: Icons.notifications,
          title: 'Notification Settings',
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChangeNotifierProvider.value(
                  value: viewModel,
                  child: const NotificationSettingsScreen(),
                ),
              ),
            );
          },
        ),
        const _Divider(),
        // _SettingsTile(
        //   icon: Icons.lock,
        //   title: 'Security',
        //   onTap: () => Navigator.of(context).push(
        //     MaterialPageRoute(builder: (_) => const SecurityScreen()),
        //   ),
        // ),
        const _Divider(),
        _SettingsTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          onTap: () => viewModel.launchUrlHelper('https://leisureryde.com/help', context),
        ),
        const _Divider(),
        _SettingsTile(
          icon: Icons.gavel,
          title: 'Legal',
          onTap: () => viewModel.launchUrlHelper('https://leisureryde.com/legal/terms', context),
        ),
      ],
    );
  }

  // --- NO OTHER CHANGES ARE NEEDED BELOW THIS LINE ---

  Widget _buildProfileHeader(BuildContext context, AccountViewModel viewModel) {
    final theme = Theme.of(context);
    final user = viewModel.userProfile!;

    return Row(
      children: [
        Stack(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              backgroundImage: user.profileImageUrl.isNotEmpty ? NetworkImage(user.profileImageUrl) : null,
              child: user.profileImageUrl.isEmpty
                  ? Text(
                user.firstName.isNotEmpty ? user.firstName[0].toUpperCase() : 'U',
                style: TextStyle(fontSize: 32, color: theme.primaryColor),
              )
                  : null,
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: GestureDetector(
                onTap: viewModel.pickAndUploadProfilePicture,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: theme.dividerColor),
                  ),
                  child: viewModel.isUploading
                      ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : Icon(Icons.edit, color: theme.iconTheme.color, size: 16),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName,
                style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                user.email,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.grey.shade600),
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              if (user is DriverProfile)
                Row(
                  children: [
                    Icon(Icons.star, color: Colors.amber, size: 18),
                    const SizedBox(width: 4),
                    Text(
                      user.rating.toStringAsFixed(1),
                      style: theme.textTheme.titleMedium,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSavedPlacesSection(BuildContext context, AccountViewModel viewModel) {
    final home = viewModel.savedPlaces.where((p) => p.name == 'Home').firstOrNull;
    final work = viewModel.savedPlaces.where((p) => p.name == 'Work').firstOrNull;

    return _SettingsGroup(
      title: 'Saved Places',
      children: [
        _buildSavedPlaceTile(context, viewModel, icon: Icons.home, name: 'Home', place: home),
        const _Divider(),
        _buildSavedPlaceTile(context, viewModel, icon: Icons.work, name: 'Work', place: work),
      ],
    );
  }

  Widget _buildSavedPlaceTile(BuildContext context, AccountViewModel viewModel,
      {required IconData icon, required String name, SavedPlace? place}) {
    return Dismissible(
      key: Key(name),
      direction: place != null ? DismissDirection.endToStart : DismissDirection.none,
      onDismissed: (_) => viewModel.deleteSavedPlace(name),
      background: Container(
        color: Colors.red,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Icon(Icons.delete_forever, color: Colors.white),
      ),
      child: ListTile(
        leading: Icon(icon),
        title: Text(place?.address ?? 'Add $name'),
        subtitle: place != null ? Text(name) : null,
        onTap: () {
          if (place == null) {
            viewModel.addOrUpdateSavedPlace(context, name);
          }
        },
      ),
    );
  }

  Widget _buildActionsSection(BuildContext context, AccountViewModel viewModel) {
    return _SettingsGroup(
      children: [
        _SettingsTile(
          icon: Icons.logout,
          title: 'Sign Out',
          color: Theme.of(context).primaryColor,
          hideArrow: true,
          onTap: () => viewModel.signOut(context),
        ),
        const _Divider(),
        _SettingsTile(
          icon: Icons.delete_forever,
          title: 'Delete Account',
          color: Theme.of(context).colorScheme.error,
          hideArrow: true,
          onTap: () => viewModel.deleteAccount(context),
        ),
      ],
    );
  }
}

// Helper Widgets
class _SettingsGroup extends StatelessWidget {
  final String? title;
  final List<Widget> children;
  const _SettingsGroup({this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (title != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(8.0, 0, 8.0, 8.0),
            child: Text(
              title!.toUpperCase(),
              style: Theme.of(context).textTheme.labelMedium?.copyWith(color: Colors.grey.shade600),
            ),
          ),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(children: children),
        ),
      ],
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final Color? color;
  final bool hideArrow;

  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.color,
    this.hideArrow = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w500)),
      trailing: hideArrow ? null : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
      onTap: onTap,
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();
  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 56, endIndent: 16);
  }
}