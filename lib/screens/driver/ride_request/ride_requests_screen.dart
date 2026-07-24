// In: lib/screens/driver/ride_requests_screen.dart (or your file path)

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:leisureryde/models/ride_request_model.dart';
import 'package:leisureryde/services/fare_calculation_service.dart';
import 'package:leisureryde/viewmodel/ride/ride_request_view_model.dart';
import 'package:leisureryde/widgets/custom_loading_indicator.dart';

class RideRequestsScreen extends StatelessWidget {
  const RideRequestsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RideRequestsViewModel(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ride Requests'),
          elevation: 0,
        ),
        body: Consumer<RideRequestsViewModel>(
          builder: (context, viewModel, child) {
            // First, check if the ViewModel is fetching the driver's profile
            if (viewModel.isInitializing) {
              return const CustomLoadingIndicator();
            }

            // Then, build the UI based on the stream of ride requests
            return StreamBuilder<List<RideRequest>>(
              stream: viewModel.rideRequestsStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const CustomLoadingIndicator();
                }
                if (snapshot.hasError) {
                  return const Center(child: Text('An error occurred. Please try again..'));
                }
                if (!snapshot.hasData || snapshot.data!.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.no_transfer, size: 80, color: Colors.grey),
                        SizedBox(height: 16),
                        Text('No pending ride requests'),
                      ],
                    ),
                  );
                }

                final requests = snapshot.data!;

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: requests.length,
                  itemBuilder: (context, index) {
                    return _RideRequestCard(
                      request: requests[index],
                      // Pass the approval status from the ViewModel to the card
                      isDriverApproved: viewModel.isDriverApproved,
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}

// --- RIDE REQUEST CARD WIDGET ---
// (This is the same widget as before, placed here for completeness)

class _RideRequestCard extends StatelessWidget {
  final RideRequest request;
  final bool isDriverApproved;

  bool get isScheduled =>
    request.status == RideStatus.scheduled;

bool get canAcceptScheduled {
  if (!isScheduled) return true;

  if (request.scheduledFor == null) return false;

  return DateTime.now().isAfter(
    request.scheduledFor!
        .subtract(const Duration(minutes: 20)),
  );
}

String get remainingTime {

  if (request.scheduledFor == null)
    return "";

  final difference =
      request.scheduledFor!
          .difference(DateTime.now());

  final hours = difference.inHours;

  final minutes =
      difference.inMinutes % 60;

  return "${hours}h ${minutes}m";
}

  const _RideRequestCard({
    required this.request,
    required this.isDriverApproved,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final viewModel = Provider.of<RideRequestsViewModel>(context, listen: false);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top section: Passenger info, vehicle type, and fare
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: theme.primaryColor.withOpacity(0.1),
                  child: Icon(Icons.person, color: theme.primaryColor),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.passengerName,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Icon(Icons.star, size: 14, color: Colors.amber),
                          const SizedBox(width: 3),
                          Text(
                            request.passengerRating.toStringAsFixed(1),
                            style: theme.textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.directions_car,
                                    size: 12, color: theme.primaryColor),
                                const SizedBox(width: 3),
                                Text(
                                  request.vehicleType,
                                  style: TextStyle(
                                    color: theme.primaryColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    "\$${FareCalculationService.driverEarnings(request.fare).toStringAsFixed(2)}",
                    style: const TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),

            // Pickup time
            _buildPickupTimeRow(theme),
            const SizedBox(height: 12),

            // Route details
            _buildRouteSection(request),
            const Divider(height: 24),

           if (!isDriverApproved)
  _buildApprovalMessage()

else if (request.status == RideStatus.pending)
  _buildActionButtons(
    context,
    viewModel,
  )

else if (request.status == RideStatus.scheduled)
  _buildScheduledSection(
    context,
    viewModel,
  )
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, RideRequestsViewModel viewModel) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () async {
          // Capture navigator before the async gap so it remains valid even if
          // the stream rebuilds this widget after the ride status changes.
          final navigator = Navigator.of(context);
          final success = await viewModel.acceptRide(request.id, context);
          if (success) {
            // Pop back to DriverHomeScreen passing the accepted ride so
            // it can be shown immediately without waiting for Firestore.
            navigator.pop(request);
          } else if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text("Failed to accept ride. Please try again."),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).primaryColor,
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        child: Text(
          "Accept (${request.distance.toStringAsFixed(1)} mi)",
        ),
      ),
    );
  }

  /// Shows when the passenger wants to be picked up.
  /// Scheduled rides display the booked time + countdown; instant rides say "Now".
  Widget _buildPickupTimeRow(ThemeData theme) {
    if (request.scheduledFor != null) {
      final formatted =
          DateFormat("EEE, MMM d • h:mm a").format(request.scheduledFor!);
      return Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.08),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            const Icon(Icons.schedule, size: 16, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                "Pickup: $formatted",
                style: const TextStyle(
                  color: Colors.orange,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (!canAcceptScheduled) ...[
              const SizedBox(width: 8),
              Text(
                "in $remainingTime",
                style: TextStyle(
                  color: Colors.orange.shade700,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Instant ride
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.green.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.green.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.bolt, size: 16, color: Colors.green),
          const SizedBox(width: 8),
          const Text(
            "Pickup: Now",
            style: TextStyle(
              color: Colors.green,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovalMessage() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.5)),
      ),
      child: const Text(
        "Your account requires approval to accept rides.",
        textAlign: TextAlign.center,
        style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w500),
      ),
    );
  }

  Widget _buildRouteSection(RideRequest request) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildRouteDetail(
          icon: Icons.my_location,
          title: "Pickup",
          address: request.pickupAddress,
          color: Colors.blue,
        ),

        if (request.waypointsAddresses.isNotEmpty) ...[
          const SizedBox(height: 12),
          ...request.waypointsAddresses.map((wp) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _buildRouteDetail(
                  icon: Icons.stop_circle,
                  title: "",
                  address: wp,
                  color: Colors.orange,
                ),
              )),
        ],

        const SizedBox(height: 8),
        _buildRouteDetail(
          icon: Icons.location_on,
          title: "Destination",
          address:request.destinationAddress,
          color: Colors.red,
        ),
      ],
    );
  }


  Widget _buildRouteDetail({
    required IconData icon,
    required String title,
    required String address,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                address,
                style: const TextStyle(fontWeight: FontWeight.w500),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildScheduledSection(
    BuildContext context,
    RideRequestsViewModel viewModel,
) {

   return _buildActionButtons(
      context,
      viewModel,
    );
  }

  /*return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.blue.shade50,
      borderRadius: BorderRadius.circular(10),
    ),
    child: Column(
      children: [

        const Icon(
          Icons.schedule,
          color: Colors.blue,
        ),

        const SizedBox(height: 8),

        Text(
          "Scheduled Ride",
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),

        const SizedBox(height: 6),

        Text(
          "Available in $remainingTime",
        ),

      ],
    ),
  );
  }
  */

}