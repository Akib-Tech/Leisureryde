import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


enum RideStatus {
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
  final String pickupAddress;
  final String destinationAddress;
  final double fare;
  final double distance; // in miles
  final DateTime createdAt;

  final String? driverId;
  final String? driverName;
  final String? driverPhone;
  final double? driverRating;
  final String? amountPaid;
  final String? paymentId;
  final String? stripePaymentIntentId;

  RideRequest({
    required this.id,
    required this.userId,
    required this.vehicleType,
    required this.status,
    required this.passengerName,
    required this.passengerRating,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.pickupAddress,
    required this.destinationAddress,
    required this.fare,
    required this.distance,
    required this.createdAt,

     this.amountPaid,
     this.paymentId,
     this.stripePaymentIntentId,
    this.driverId,
    this.driverName,
    this.driverPhone,
    this.driverRating,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'vehicleType': vehicleType,
      'status': status.name,
      'passengerName': passengerName,
      'passengerRating': passengerRating,
      'pickup': {'latitude': pickupLocation.latitude, 'longitude': pickupLocation.longitude},
      'destination': {'latitude': destinationLocation.latitude, 'longitude': destinationLocation.longitude},
      'pickupAddress': pickupAddress,
      'destinationAddress': destinationAddress,
      'fare': fare,
      'distance': distance,
      'createdAt': Timestamp.fromDate(createdAt),
      'amountPaid': amountPaid,
      'paymentId': paymentId,
      'stripePaymentIntentId': stripePaymentIntentId,
      if (driverId != null) 'driverId': driverId,
      if (driverName != null) 'driverName': driverName,
      if (driverPhone != null) 'driverPhone': driverPhone,
      if(driverRating!=null) 'driverRating': driverRating
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
      destinationLocation: LatLng(
        (data['destination']?['latitude'] as num?)?.toDouble() ?? 0.0,
        (data['destination']?['longitude'] as num?)?.toDouble() ?? 0.0,
      ),
      pickupAddress: data['pickupAddress'] ?? 'Unknown Address',
      destinationAddress: data['destinationAddress'] ?? 'Unknown Address',
      fare: (data['fare'] as num?)?.toDouble() ?? 0.0,
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
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