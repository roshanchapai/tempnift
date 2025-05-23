import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nift_final/utils/constants.dart';

class UserModel {
  final String uid;
  final String phoneNumber;
  final String? name;
  final DateTime? dateOfBirth;
  final UserRole userRole;
  final String riderStatus; // 'not_applied', 'pending', 'approved', 'rejected'
  final DateTime createdAt;
  final String? profileImageUrl; // Added for profile image storage
  final int totalRatings; // Sum of all ratings received
  final int ratingCount; // Number of ratings received
  final double averageRating; // Calculated average rating

  UserModel({
    required this.uid,
    required this.phoneNumber,
    this.name,
    this.dateOfBirth,
    required this.userRole,
    this.riderStatus = 'not_applied',
    required this.createdAt,
    this.profileImageUrl,
    this.totalRatings = 0,
    this.ratingCount = 0,
    this.averageRating = 0.0,
  });

  // Convert UserModel to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'phoneNumber': phoneNumber,
      'name': name,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'userRole': userRole.toString().split('.').last, // Convert enum to string
      'riderStatus': riderStatus,
      'createdAt': Timestamp.fromDate(createdAt),
      'profileImageUrl': profileImageUrl,
      'totalRatings': totalRatings,
      'ratingCount': ratingCount,
      'averageRating': averageRating,
    };
  }

  // Create a copy of this UserModel with optional new values
  UserModel copyWith({
    String? uid,
    String? phoneNumber,
    String? name,
    DateTime? dateOfBirth,
    UserRole? userRole,
    String? riderStatus,
    DateTime? createdAt,
    String? profileImageUrl,
    int? totalRatings,
    int? ratingCount,
    double? averageRating,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      name: name ?? this.name,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      userRole: userRole ?? this.userRole,
      riderStatus: riderStatus ?? this.riderStatus,
      createdAt: createdAt ?? this.createdAt,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      totalRatings: totalRatings ?? this.totalRatings,
      ratingCount: ratingCount ?? this.ratingCount,
      averageRating: averageRating ?? this.averageRating,
    );
  }

  // Create UserModel from Firestore document
  factory UserModel.fromMap(Map<String, dynamic> map) {
    try {
      return UserModel(
        uid: map['uid'] as String? ?? '',
        phoneNumber: map['phoneNumber'] as String? ?? '',
        name: map['name'] as String?,
        dateOfBirth: map['dateOfBirth'] != null 
            ? (map['dateOfBirth'] as Timestamp).toDate() 
            : null,
        userRole: _parseUserRole(map['userRole'] as String?),
        riderStatus: map['riderStatus'] as String? ?? 'not_applied',
        createdAt: map['createdAt'] != null 
            ? (map['createdAt'] as Timestamp).toDate()
            : DateTime.now(),
        profileImageUrl: map['profileImageUrl'] as String?,
        totalRatings: map['totalRatings'] as int? ?? 0,
        ratingCount: map['ratingCount'] as int? ?? 0,
        averageRating: (map['averageRating'] as num?)?.toDouble() ?? 0.0,
      );
    } catch (e) {
      throw FormatException('Failed to create UserModel from map: $e');
    }
  }

  // Helper method to parse user role
  static UserRole _parseUserRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'rider':
        return UserRole.rider;
      case 'passenger':
        return UserRole.passenger;
      default:
        return UserRole.passenger; // Default role
    }
  }
}
