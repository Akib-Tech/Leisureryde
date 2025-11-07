// In: screens/account/account_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../models/driver_profile.dart' show DriverProfile;
import '../../../models/saved_places.dart';
import '../../../viewmodel/account/account_view_model.dart';
import '../../../viewmodel/theme_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../splash_screen/welcome_screen.dart';

class AccountScreen extends StatefulWidget {
  final bool isDriver;
  const AccountScreen({super.key, required this.isDriver});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  // It's good practice to create the ViewModel once.
  late final AccountViewModel _viewModel;

  // STEP 2: Override initState to set up the ViewModel and listener
  @override
  void initState() {
    super.initState();
    _viewModel = AccountViewModel(isDriver: widget.isDriver);

    // Add a listener that will be called after the state changes, but outside the build method.
    _viewModel.addListener(_handleProfileState);
  }

  // A separate function to handle the logic. This is the safe place to navigate.
  void _handleProfileState() {
    // We only want to navigate if the profile is null AND we are done loading.
    if (!mounted) return; // Always check if the widget is still in the tree.

    if (!_viewModel.isLoading && _viewModel.userProfile == null) {
      // It's also good practice to remove the listener before navigating away.
      _viewModel.removeListener(_handleProfileState);
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (route) => false,
      );
    }
  }

  // Don't forget to remove the listener in dispose to prevent memory leaks!
  @override
  void dispose() {
    _viewModel.removeListener(_handleProfileState);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Use the viewModel created in initState
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

            // STEP 3: Remove the navigation logic from the build method.
            // If we get here, it means the profile is not null (because the listener
            // would have navigated us away already). We can safely build the UI.
            if (viewModel.userProfile == null) {
              // Return an empty container while the listener navigates away.
              // This prevents a flicker of an error message.
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
              backgroundImage: user.profileImageUrl.isNotEmpty
                  ? NetworkImage(user.profileImageUrl,
              )
                  : null,
              child: user.profileImageUrl.isEmpty
                  ? Text(
                user.firstName.isNotEmpty ? user.firstName[0] : 'U',
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
              ),
              Text(
                user.email,
                style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w400, fontSize: 12 ),
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

  // --- NEW WIDGET FOR SAVED PLACES ---
  Widget _buildSavedPlacesSection(BuildContext context, AccountViewModel viewModel) {
    final home = viewModel.savedPlaces.where((p) => p!.name == 'Home').firstOrNull;
    final work = viewModel.savedPlaces.where((p) => p!.name == 'Work').firstOrNull;

    return _SettingsGroup(
      title: 'Saved Places',
      children: [
        _buildSavedPlaceTile(context, viewModel, icon: Icons.home, name: 'Home', place: home),
        const _Divider(),
        _buildSavedPlaceTile(context, viewModel, icon: Icons.work, name: 'Work', place: work),
      ],
    );
  }

  Widget _buildSavedPlaceTile(BuildContext context, AccountViewModel viewModel, {required IconData icon, required String name, SavedPlace? place}) {
    return Dismissible(
      key: Key(name), // Unique key for the dismissible
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
          } else {
            // TODO: Maybe navigate to an edit screen?
          }
        },
      ),
    );
  }
  // --- END NEW WIDGET ---

  Widget _buildSettingsSection(BuildContext context, AccountViewModel viewModel) {
    final themeVM = Provider.of<ThemeViewModel>(context);
    return _SettingsGroup(
      title: 'Settings',
      children: [
        if (viewModel.isDriver) ...[
          _SettingsTile(
            icon: Icons.directions_car,
            title: 'Vehicle Information',
            onTap: () {},
          ),
          const _Divider(),
        ],
        _SettingsTile(
          icon: Icons.help_outline,
          title: 'Help & Support',
          onTap: () {},
        ),
        SwitchListTile(
          secondary: Icon(
            themeVM.themeMode == ThemeMode.dark ? Icons.dark_mode : Icons.light_mode,
          ),
          title: const Text('Dark Mode'),
          value: themeVM.themeMode == ThemeMode.dark,
          onChanged: (value) {
            themeVM.setThemeMode(value ? ThemeMode.dark : ThemeMode.light);
          },
        ),
      ],
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

// --- HELPER WIDGETS FOR A CLEANER BUILD METHOD ---

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
            padding: const EdgeInsets.only(left: 8.0, bottom: 8.0),
            child: Text(
              title!,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.grey),
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
      title: Text(title, style: TextStyle(color: color)),
      trailing: hideArrow ? null : const Icon(Icons.arrow_forward_ios, size: 16),
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