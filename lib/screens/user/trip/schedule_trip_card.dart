import 'package:flutter/material.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/viewmodel/ride/scheduled_trip_view_model.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../widgets/custom_loading_indicator.dart';
class ScheduledTripCard extends StatefulWidget {
  final String rideId;
  final void Function(bool isCollapsed)? onCollapseChanged;

  const ScheduledTripCard({
    super.key,
    required this.rideId,
    this.onCollapseChanged,
  });

  @override
  State<ScheduledTripCard> createState() => _ScheduledTripCardState();
}

class _ScheduledTripCardState extends State<ScheduledTripCard>
    with SingleTickerProviderStateMixin {
  bool _isCollapsed = false;

  late final AnimationController _animationController;
  late final Animation<double> _heightFactor;

  bool _openedActiveTrip = false;

  Future<void> _showCancelRideSheet(
  BuildContext context,
  ScheduledTripViewModel vm,
) async {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return Container(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 30),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(24),
          ),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [

              Container(
                width: 45,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),

              const SizedBox(height: 20),

              const CircleAvatar(
                radius: 28,
                backgroundColor: Color(0xffffebee),
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 32,
                ),
              ),

              const SizedBox(height: 18),

              const Text(
                "Cancel Scheduled Ride?",
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 10),

              Text(
                "Your scheduled booking will be cancelled and you'll need to create a new booking if you still need a ride.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.4,
                ),
              ),

              const SizedBox(height: 30),

              OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Keep Ride"),
              ),

              const SizedBox(height: 12),


              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);

                  await vm.cancelRide();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text("Yes, Cancel Ride"),
              ),
            ],
          ),
        ),
      );
    },
  );
}

  @override
  void initState() {
    super.initState();

    WakelockPlus.enable();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
      value: 1,
    );

    _heightFactor =
        _animationController.drive(CurveTween(curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _animationController.dispose();
    WakelockPlus.disable();
    super.dispose();
  }

  void _toggleCollapse() {
    setState(() => _isCollapsed = !_isCollapsed);

    widget.onCollapseChanged?.call(_isCollapsed);

    if (_isCollapsed) {
      _animationController.reverse();
    } else {
      _animationController.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ScheduledTripViewModel(
        rideId: widget.rideId,
      ),
      child: Consumer<ScheduledTripViewModel>(
        builder: (context, vm, child) {
          if (vm.isLoading) {
            return const CustomLoadingIndicator();
          }

          if (vm.rideRequest == null) {
            return const SizedBox.shrink();
          }

          final ride = vm.rideRequest!;
          final theme = Theme.of(context);

          /// Driver accepted.
        

          return Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(.15),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                )
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [

                /// HEADER
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleCollapse,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 10, 20, 8),
                    child: Column(
                      children: [

                        Row(
                          children: [

                            Container(
                              width: 40,
                              height: 5,
                              decoration: BoxDecoration(
                                color: Colors.grey[300],
                                borderRadius: BorderRadius.circular(20),
                              ),
                            ),

                            const Spacer(),

                            Icon(
                              _isCollapsed
                                  ? Icons.keyboard_arrow_up
                                  : Icons.keyboard_arrow_down,
                              color: Colors.grey,
                            ),

                          ],
                        ),

                        if (_isCollapsed) ...[
                          const SizedBox(height: 10),

                          Row(
                            children: [

                              const Icon(
                                Icons.schedule,
                                color: Colors.orange,
                              ),

                              const SizedBox(width: 10),

                              const Expanded(
                                child: Text(
                                  "Scheduled Ride",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.withOpacity(.15),
                                  borderRadius:
                                      BorderRadius.circular(30),
                                ),
                                child: const Text(
                                  "Scheduled",
                                  style: TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),

                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                SizeTransition(
                  sizeFactor: _heightFactor,
                  axisAlignment: -1,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      20,
                      6,
                      20,
                      20,
                    ),
                    child: Column(
                      children: [
Text(
  "Scheduled Ride",
  style: theme.textTheme.titleLarge?.copyWith(
    fontWeight: FontWeight.bold,
    color: theme.primaryColor,
  ),
),

const SizedBox(height: 6),

Text(
  "Your ride has been scheduled successfully.",
  textAlign: TextAlign.center,
  style: TextStyle(
    color: Colors.grey.shade600,
  ),
),

const SizedBox(height: 24),

Container(
  padding: const EdgeInsets.all(14),
  decoration: BoxDecoration(
    color: Colors.orange.withOpacity(.08),
    borderRadius: BorderRadius.circular(14),
  ),
  child: Row(
    children: [

      const Icon(
        Icons.schedule,
        color: Colors.orange,
      ),

      const SizedBox(width: 12),

      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [

            const Text(
              "Pickup Time",
              style: TextStyle(
                fontWeight: FontWeight.w600,
              ),
            ),

            const SizedBox(height: 3),

            Text(
              vm.formattedScheduleTime,
              style: const TextStyle(
                fontSize: 15,
              ),
            ),

          ],
        ),
      )
    ],
  ),
),

const SizedBox(height: 22),

Row(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [

    Column(
      children: [

        const Icon(
          Icons.radio_button_checked,
          color: Colors.green,
          size: 16,
        ),

        Container(
          width: 2,
          height: 26,
          color: Colors.grey.shade300,
        ),

        Icon(
          Icons.location_on,
          color: theme.primaryColor,
          size: 18,
        ),

      ],
    ),

    const SizedBox(width: 10),

    Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          Text(
            ride.pickupAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 12),

          Text(
            ride.destinationAddress,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),

        ],
      ),
    ),
  ],
),

const SizedBox(height: 22),

Container(
  width: double.infinity,
  padding: const EdgeInsets.all(16),
  decoration: BoxDecoration(
    color: Colors.blue.withOpacity(.08),
    borderRadius: BorderRadius.circular(15),
  ),
  child: Column(
    children: [

      const Icon(
        Icons.person_search,
        color: Colors.blue,
        size: 34,
      ),

      const SizedBox(height: 12),

      const Text(
        "Waiting for Driver",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),

      const SizedBox(height: 8),

      Text(
        "Driver matching will automatically begin shortly before your scheduled pickup time.",
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Colors.grey.shade700,
        ),
      ),

    ],
  ),
),

const SizedBox(height: 20),

if (vm.rideRequest!.status == RideStatus.scheduled || vm.rideRequest!.status == RideStatus.accepted) 
SizedBox(
  width: double.infinity,
  child: ElevatedButton.icon(
    onPressed:  () => _showCancelRideSheet(context, vm),
    style: ElevatedButton.styleFrom(
      backgroundColor: Colors.red,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(50),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
      ),
    ),
    icon: const Icon(Icons.close),
    label: const Text("Cancel Ride"),
  ),
),

const SizedBox(height: 5),
                      ]
),
),
),
],
),
);
  }
  )
    );
  } 
  }