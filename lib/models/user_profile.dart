import 'package:cloud_firestore/cloud_firestore.dart';

import '../app/enums.dart';


class UserProfile {
  final String uid;
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final UserRole role;
  final String profileImageUrl;
  final bool isBlocked;
  final double rating;
  final bool pushNotificationsEnabled;
  final String dateOfBirth; // "YYYY-MM-DD" or ''
  final String gender;      // "Male" | "Female" | "Prefer not to say" | ''

  UserProfile({
    required this.uid,
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.role,
    this.profileImageUrl = '',
    required this.isBlocked,
    required this.rating,
    this.pushNotificationsEnabled = true,
    this.dateOfBirth = '',
    this.gender = '',
  });

  factory UserProfile.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map<String, dynamic>;
    return UserProfile(
      uid: doc.id,
      firstName: data['firstName'] ?? '',
      lastName: data['lastName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phone'] ?? '',
      role: UserRole.fromString(data['role'] ?? 'user'),
      profileImageUrl: data['profileImageUrl'] ?? '',
      isBlocked: data['isBlocked'] ?? false,
      rating: (data['rating'] ?? 5.0).toDouble(),
      pushNotificationsEnabled: data['pushNotificationsEnabled'] ?? true,
      dateOfBirth: data['dateOfBirth'] ?? '',
      gender: data['gender'] ?? '',
    );
  }

  String get fullName => '$firstName $lastName';

  UserProfile copyWith({
    String? uid,
    String? firstName,
    String? lastName,
    String? email,
    String? profileImageUrl,
    String? phone,
    UserRole? role,
    bool? isBlocked,
    double? rating,
    bool? pushNotificationsEnabled,
    String? dateOfBirth,
    String? gender,
  }) {
    return UserProfile(
      uid: uid ?? this.uid,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      email: email ?? this.email,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isBlocked: isBlocked ?? this.isBlocked,
      rating: rating ?? this.rating,
      pushNotificationsEnabled: pushNotificationsEnabled ?? this.pushNotificationsEnabled,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
    );
  }
}