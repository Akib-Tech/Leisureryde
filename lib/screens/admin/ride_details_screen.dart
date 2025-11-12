import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:leisureryde/models/ride_request_model.dart';

class RideDetailScreen extends StatelessWidget {
  final RideRequest ride;
  const RideDetailScreen({super.key, required this.ride});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Ride #${ride.id.substring(0, 6)}"),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSectionCard(
            context,
            title: "Ride Summary",
            children: [
              _buildDetailRow("Status", ride.status.name.toUpperCase(), color: _getStatusColor(ride.status)),
              _buildDetailRow("Date & Time", DateFormat.yMMMd().add_jm().format(ride.createdAt)),
              _buildDetailRow("Vehicle Type", ride.vehicleType),
            ],
          ),
          _buildSectionCard(
            context,
            title: "Route",
            children: [
              _buildDetailRow("From", ride.pickupAddress),
              _buildDetailRow("To", ride.destinationAddress),
              _buildDetailRow("Distance", "${ride.distance.toStringAsFixed(2)} km"),
            ],
          ),
          _buildSectionCard(
            context,
            title: "Financials",
            children: [
              _buildDetailRow("Fare", "\$${ride.fare.toStringAsFixed(2)}", isBold: true),
              _buildDetailRow("Payment ID", ride.paymentId ?? "N/A"),
            ],
          ),
          _buildSectionCard(
            context,
            title: "Passenger",
            children: [
              _buildDetailRow("Name", ride.passengerName),
              _buildDetailRow("User ID", ride.userId),
              _buildDetailRow("Rating", ride.passengerRating.toString()),
            ],
          ),
          if (ride.driverId != null)
            _buildSectionCard(
              context,
              title: "Driver",
              children: [
                _buildDetailRow("Name", ride.driverName ?? "N/A"),
                _buildDetailRow("Driver ID", ride.driverId!),
                _buildDetailRow("Phone", ride.driverPhone ?? "N/A"),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildSectionCard(BuildContext context, {required String title, required List<Widget> children}) {
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(color: theme.primaryColor),
            ),
            const Divider(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: color,
                fontSize: 15,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(RideStatus status) {
    switch (status) {
      case RideStatus.completed: return Colors.green;
      case RideStatus.cancelled:
      case RideStatus.cancelled_by_driver: return Colors.red;
      case RideStatus.failed: return Colors.orange;
      default: return Colors.blue;
    }
  }
}