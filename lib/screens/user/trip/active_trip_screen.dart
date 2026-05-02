import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../models/ride_request_model.dart';
import '../../../screens/shared/timer/timer.dart';
import '../../../viewmodel/home/home_view_model.dart';
import '../../../viewmodel/ride/active_trip_view_model.dart';
import '../../../widgets/custom_loading_indicator.dart';
import '../../shared/chat/chat_screen.dart';

/// The user-facing active trip card shown at the bottom of HomeScreen.
///
/// IMPORTANT: We pass the shared [MapViewModel] from [HomeViewModel] into
/// [ActiveTripViewModel] so that all polylines and markers are drawn into
/// the same [GoogleMap] widget that HomeScreen is already displaying.
class ActiveTripCard extends StatefulWidget {
  final String rideId;
  final void Function(bool isCollapsed)? onCollapseChanged;

  const ActiveTripCard({
    super.key,
    required this.rideId,
    this.onCollapseChanged,
  });

  @override
  State<ActiveTripCard> createState() => _ActiveTripCardState();
}

class _ActiveTripCardState extends State<ActiveTripCard>
    with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;
  late final AnimationController _animCtrl;
  late final Animation<double> _heightFactor;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1.0,
    );
    _heightFactor = _animCtrl.drive(CurveTween(curve: Curves.easeInOut));
    WakelockPlus.enable();
  }

  void _toggleCollapse() {
    setState(() => _isCollapsed = !_isCollapsed);
    widget.onCollapseChanged?.call(_isCollapsed);
    if (_isCollapsed) {
      _animCtrl.reverse();
    } else {
      _animCtrl.forward();
    }
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final homeViewModel = context.read<HomeViewModel>();

    return ChangeNotifierProvider(
      create: (_) => ActiveTripViewModel(
        rideId: widget.rideId,
        mapViewModel: homeViewModel.mapViewModel,
      ),
      child: Consumer<ActiveTripViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return const CustomLoadingIndicator();
          }

          if (viewModel.rideRequest == null) {
            return const SizedBox.shrink();
          }

          final theme = Theme.of(context);
          final rideRequest = viewModel.rideRequest!;

          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // ── Drag handle + collapsed summary ──────────────────
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleCollapse,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 6),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            const Spacer(),
                            Consumer<HomeViewModel>(
                              builder: (ctx, hvm, _) => IconButton(
                                icon: Icon(
                                  hvm.voiceEnabled
                                      ? Icons.volume_up
                                      : Icons.volume_off,
                                  size: 20,
                                  color: hvm.voiceEnabled
                                      ? Theme.of(ctx).primaryColor
                                      : Colors.grey[400],
                                ),
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                                onPressed: hvm.toggleVoice,
                                tooltip: hvm.voiceEnabled
                                    ? 'Mute voice'
                                    : 'Unmute voice',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              _isCollapsed
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey[500],
                            ),
                          ],
                        ),
                        if (_isCollapsed) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (viewModel.driverProfile != null) ...[
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: viewModel
                                          .driverProfile!
                                          .profileImageUrl
                                          .isNotEmpty
                                      ? NetworkImage(viewModel
                                          .driverProfile!.profileImageUrl)
                                      : null,
                                  child: viewModel.driverProfile!
                                          .profileImageUrl.isEmpty
                                      ? Text(
                                          viewModel.driverProfile!
                                              .firstName[0]
                                              .toUpperCase(),
                                          style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold))
                                      : null,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    viewModel.driverProfile!.fullName,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ] else
                                const Expanded(child: SizedBox()),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color:
                                      theme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  _statusLabel(rideRequest.status),
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                        ],
                      ],
                    ),
                  ),
                ),

                // ── Expanded content ──────────────────────────────────
                SizeTransition(
                  sizeFactor: _heightFactor,
                  axisAlignment: -1,
                  child: Padding(


                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 20),
                    child: Column(
                      children: [
                        // Status label
                        Text(
                          _statusLabel(rideRequest.status),
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.primaryColor,
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Driver info
                        if (viewModel.driverProfile != null) ...[
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(
                              radius: 28,
                              backgroundImage: viewModel
                                      .driverProfile!
                                      .profileImageUrl
                                      .isNotEmpty
                                  ? NetworkImage(viewModel
                                      .driverProfile!.profileImageUrl)
                                  : null,
                              child: viewModel
                                      .driverProfile!.profileImageUrl.isEmpty
                                  ? Text(
                                      viewModel.driverProfile!.firstName[0]
                                          .toUpperCase(),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.bold),
                                    )
                                  : null,
                            ),
                            title: Text(
                              viewModel.driverProfile!.fullName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold),
                            ),
                            subtitle: Row(
                              children: [
                                const Icon(Icons.star,
                                    size: 14, color: Colors.amber),
                                const SizedBox(width: 4),
                                Text(viewModel.driverProfile!.rating
                                    .toStringAsFixed(1)),
                              ],
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.call,
                                      color: Colors.green),
                                  onPressed: () => _callDriver(
                                      viewModel.driverProfile!.phone),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.chat,
                                      color: Colors.blue),
                                  onPressed: () {
                                    final userName = context
                                            .read<HomeViewModel>()
                                            .userProfile
                                            ?.fullName ??
                                        '';
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (_) => ChatScreen(
                                          rideId: widget.rideId,
                                          otherUserId:
                                              viewModel.driverProfile!.uid,
                                          otherUserName: viewModel
                                              .driverProfile!.fullName,
                                          otherUserImageUrl: viewModel
                                              .driverProfile!.profileImageUrl,
                                          currentUserName: userName,
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),
                        ],

                        // Destination row
                        Row(
                          children: [
                            Icon(Icons.location_on,
                                color: theme.primaryColor, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                rideRequest.destinationAddress,
                                style: theme.textTheme.bodyMedium,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // Trip timer — shown to the user when the trip is ongoing
                        if (rideRequest.status == RideStatus.ongoing) ...[
                          const SizedBox(height: 16),
                          TripEndTimer(
                            origin: rideRequest.pickupLocation,
                            destination: rideRequest.destinationLocation,
                          ),
                        ],

                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  String _statusLabel(RideStatus status) {
    switch (status) {
      case RideStatus.accepted:
        return "Driver is on the way";
      case RideStatus.enroute:
        return "Driver is arriving";
      case RideStatus.ongoing:
        return "Trip in progress";
      default:
        return "Finding your driver...";
    }
  }

  Future<void> _callDriver(String phone) async {
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }
}
