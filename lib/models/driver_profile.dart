// In: lib/models/driver_profile.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:leisureryde/models/user_profile.dart'; // Make sure this path is correct

import '../app/enums.dart'; // Make sure this path is correct

class DriverProfile extends UserProfile {
  final String licenseUrl;
  final bool isApproved;
  final bool isOnline;
  final int totalTrips;
  final String carModel;
  final String licensePlate;
  final Timestamp? lastWentOnlineAt;

  DriverProfile({
    required super.uid,
    required super.firstName,
    required super.lastName,
    required super.email,
    required super.phone,
    required super.isBlocked,
    required super.profileImageUrl,
    required this.licenseUrl,
    required this.isApproved,
    required this.isOnline,
    required super.rating,
    this.totalTrips = 0,
    required this.carModel,
    required this.licensePlate,
    this.lastWentOnlineAt,
  }) : super(role: UserRole.driver);

  // The factory constructor needs to pass the profile image URL to the main constructor
  factory DriverProfile.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return DriverProfile(
      uid: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      profileImageUrl: data['profileImageUrl'] ?? '',
      licenseUrl: data['licenseUrl'] ?? '',
      isApproved: data['isApproved'] ?? false,
      isOnline: data['isOnline'] ?? false,
      rating: (data['rating'] ?? 0.0).toDouble(),
      isBlocked: data['isBlocked'] ?? false,
      totalTrips: data['totalTrips'] ?? 0,
      carModel: data['carModel'] ?? '',
      licensePlate: data['licensePlate'] ?? '',
      lastWentOnlineAt: data['lastWentOnlineAt'] as Timestamp?,
    );
  }

  @override
  DriverProfile copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? phone,
    UserRole? role, // Add this to match the parent's signature
    String? profileImageUrl,

    String? licenseUrl,
    bool? isApproved,
    bool? isOnline,
    double? rating,
    int? totalTrips,
    String? carModel,
    String? licensePlate,
    Timestamp? lastWentOnlineAt,
    bool? isBlocked,
  }) {
    return DriverProfile(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl, // <-- FIX 2: NOW THIS WORKS
      licenseUrl: licenseUrl ?? this.licenseUrl,
      isApproved: isApproved ?? this.isApproved,
      isOnline: isOnline ?? this.isOnline,
      rating: rating ?? this.rating,
      totalTrips: totalTrips ?? this.totalTrips,
      carModel: carModel ?? this.carModel,
      licensePlate: licensePlate ?? this.licensePlate,
      lastWentOnlineAt: lastWentOnlineAt ?? this.lastWentOnlineAt,
      isBlocked: isBlocked ?? this.isBlocked


    );
  }
}