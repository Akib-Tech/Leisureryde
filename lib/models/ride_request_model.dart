// ignore_for_file: constant_identifier_names

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:leisureryde/viewmodel/home/home_view_model.dart';

enum RideStatus {
  scheduled,
  pending,
  accepted,
  enroute,
  ongoing,
  completed,
  failed,
  cancelled_by_driver,
  cancelled;

  static RideStatus fromString(String status) {
    return RideStatus.values.firstWhere(
      (e) => e.name == status,
      orElse: () => RideStatus.pending,
    );
  }
}

// NEW: Add this helper extension
extension RideStatusX on RideStatus {
  bool get isTerminal {
    return this == RideStatus.completed ||
        this == RideStatus.failed ||
        this == RideStatus.cancelled_by_driver ||
        this == RideStatus.cancelled;
  }
}



class RideRequest {
  final String id;
  final String userId;
  final String vehicleType;
  final RideStatus status;
  final String passengerName;
  final double passengerRating;
  final LatLng pickupLocation;
  final LatLng destinationLocation;
  final List<LatLng> waypointsLocation;
  final List<String> waypointsAddresses;
  final String pickupAddress;
  final String destinationAddress;
  final double fare;
  final double distance; // in miles
  final DateTime createdAt;
  final int currentWaypointIndex;

  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final double? driverRating;
  final String? amountPaid;
  final String? paymentId;
  final String? stripePaymentIntentId;

  final RideType? rideType;
  final DateTime? scheduledFor;

  final int estimatedDistanceMeters;
  final String estimatedDistanceText;

  final int estimatedDurationSeconds;
  final String estimatedDurationText;

  final DateTime? estimatedArrivalTime;

  RideRequest({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.status,
    required this.passengerName,
    required this.passengerRating,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.waypointsLocation,
    required this.waypointsAddresses,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.distance,
    required this.createdAt,
    this.rideType = RideType.instant,
    this.scheduledFor,
    required this.estimatedDistanceMeters,
    required this.estimatedDistanceText,
    required this.estimatedDurationSeconds,
    required this.estimatedDurationText,
    this.estimatedArrivalTime,
    this.currentWaypointIndex = -1,
    this.amountPaid,
    this.paymentId,
    this.stripePaymentIntentId,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverRating,
  });

  RideRequest copyWith({
    String? id,
    String? userId,
    String? vehicleType,
    RideStatus? status,
    RideType? rideType,
    DateTime? scheduledFor,
    String? passengerName,
    double? passengerRating,
    LatLng? pickupLocation,
    LatLng? destinationLocation,
    List<LatLng>? waypointsLocation,
    String? pickupAddress,
    String? destinationAddress,
    List<String>? waypointsAddresses,
    double? fare,
    double? distance,
    int? estimatedDistanceMeters,
    String? estimatedDistanceText,
    int? estimatedDurationSeconds,
    String? estimatedDurationText,
    DateTime? estimatedArrivalTime,
    DateTime? createdAt,
    String? driverId,
    String? driverName,
    String? driverPhone,
    double? driverRating,
    String? amountPaid,
    String? paymentId,
    String? stripePaymentIntentId,
    int? currentWaypointIndex,
  }) {
    return RideRequest(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      vehicleType: vehicleType ?? this.vehicleType,
      status: status ?? this.status,
      rideType: rideType ?? this.rideType,
      scheduledFor: scheduledFor ?? this.scheduledFor,
      passengerName: passengerName ?? this.passengerName,
      passengerRating: passengerRating ?? this.passengerRating,
      pickupLocation: pickupLocation ?? this.pickupLocation,
      destinationLocation: destinationLocation ?? this.destinationLocation,
      waypointsLocation: waypointsLocation ?? this.waypointsLocation,
      pickupAddress: pickupAddress ?? this.pickupAddress,
      destinationAddress: destinationAddress ?? this.destinationAddress,
      waypointsAddresses: waypointsAddresses ?? this.waypointsAddresses,
      fare: fare ?? this.fare,
      distance: distance ?? this.distance,
      estimatedDistanceMeters:
          estimatedDistanceMeters ?? this.estimatedDistanceMeters,
      estimatedDistanceText:
          estimatedDistanceText ?? this.estimatedDistanceText,
      estimatedDurationSeconds:
          estimatedDurationSeconds ?? this.estimatedDurationSeconds,
      estimatedDurationText:
          estimatedDurationText ?? this.estimatedDurationText,
      estimatedArrivalTime: estimatedArrivalTime ?? this.estimatedArrivalTime,
      createdAt: createdAt ?? this.createdAt,
      driverId: driverId ?? this.driverId,
      driverName: driverName ?? this.driverName,
      driverPhone: driverPhone ?? this.driverPhone,
      driverRating: driverRating ?? this.driverRating,
      amountPaid: amountPaid ?? this.amountPaid,
      paymentId: paymentId ?? this.paymentId,
      stripePaymentIntentId:
          stripePaymentIntentId ?? this.stripePaymentIntentId,
      currentWaypointIndex: currentWaypointIndex ?? this.currentWaypointIndex,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'vehicleType': vehicleType,
      'status': status.name,
      'passengerName': passengerName,
      'passengerRating': passengerRating,
      'pickup': {
        'latitude': pickupLocation.latitude,
        'longitude': pickupLocation.longitude
      },
      'destination': {
        'latitude': destinationLocation.latitude,
        'longitude': destinationLocation.longitude
      },
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'waypointsLocation': waypointsLocation
          .map((wp) => {'latitude': wp.latitude, 'longitude': wp.longitude})
          .toList(),
      'waypointsAddresses': waypointsAddresses,
      'rideType': rideType!.name,
      'scheduledFor':
          scheduledFor != null ? Timestamp.fromDate(scheduledFor!) : null,
      'estimatedDistanceMeters': estimatedDistanceMeters,
      'estimatedDistanceText': estimatedDistanceText,
      'estimatedDurationSeconds': estimatedDurationSeconds,
      'estimatedDurationText': estimatedDurationText,
      'estimatedArrivalTime': estimatedArrivalTime != null
          ? Timestamp.fromDate(
              estimatedArrivalTime!,
            )
          : null,
      'fare': fare,
      'distance': distance,
      'createdAt': Timestamp.fromDate(createdAt),
      'currentWaypointIndex': currentWaypointIndex,
      'amountPaid': amountPaid,
      'paymentId': paymentId,
      'stripePaymentIntentId': stripePaymentIntentId,
      if (driverId != null) 'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (driverPhone != null) 'driverPhone': driverPhone,
      if (driverRating != null) 'driverRating': driverRating
    };
  }

  factory RideRequest.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return RideRequest(
      id: doc.id,
      userId: data['userId'] ?? '',
      vehicleType: data['vehicleType'] ?? 'Leisure Comfort',
      status: RideStatus.fromString(data['status'] ?? 'pending'),
      passengerName: data['passengerName'] ?? 'Unknown',
      passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
      pickupLocation: LatLng(
        (data['pickup']?['latitude'] as num?)?.toDouble() ?? 0.0,
        (data['pickup']?['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      waypointsAddresses: List<String>.from(data['waypointsAddresses'] ?? []),
      waypointsLocation: (data['waypointsLocation'] as List<dynamic>? ?? [])
          .map((wp) => LatLng(
                (wp['latitude'] as num?)?.toDouble() ?? 0.0,
                (wp['longitude'] as num?)?.toDouble() ?? 0.0,
              ))
          .toList(),
      rideType: RideType.values.firstWhere(
        (e) => e.name == (data['rideType'] ?? 'instant'),
        orElse: () => RideType.instant,
      ),
      scheduledFor: (data['scheduledFor'] as Timestamp?)?.toDate(),
      estimatedDistanceMeters: (data['estimatedDistanceMeters'] ?? 0) as int,
      estimatedDistanceText: (data['estimatedDistanceText'] ?? '') as String,
      estimatedDurationSeconds: (data['estimatedDurationSeconds'] ?? 0) as int,
      estimatedDurationText: (data['estimatedDurationText'] ?? '') as String,
      estimatedArrivalTime:
          (data['estimatedArrivalTime'] as Timestamp?)?.toDate(),
      destinationLocation: LatLng(
        (data['destination']?['latitude'] as num?)?.toDouble() ?? 0.0,
        (data['destination']?['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      pickupAddress: data['pickupAddress'] ?? 'Unknown Address',
      destinationAddress: data['destinationAddress'] ?? 'Unknown Address',
      fare: (data['fare'] as num?)?.toDouble() ?? 0.0,
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentWaypointIndex:
          (data['currentWaypointIndex'] as num?)?.toInt() ?? -1,
      amountPaid: (data['amountPaid']),
      paymentId: data['paymentId'],
      stripePaymentIntentId: data['stripePaymentIntentId'],
      driverId: data['driverId'],
      driverName: data['driverName'],
      driverPhone: data['driverPhone'],
      driverRating: data['driverRating'],
    );
  }
}

class RideLocation {
  final String address;
  final double latitude;
  final double longitude;

  RideLocation({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  // Converts a RideLocation object into a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  // Creates a RideLocation object from a Map from Firestore
  factory RideLocation.fromMap(Map<String, dynamic> map) {
    return RideLocation(
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// RideDestination is structurally identical to RideLocation.
// You can define it in the same file for convenience.
class RideDestination {
  final String address;
  final double latitude;
  final double longitude;

  RideDestination({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toMap() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  factory RideDestination.fromMap(Map<String, dynamic> map) {
    return RideDestination(
      address: map['address'] ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
