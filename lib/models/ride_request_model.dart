import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideRequest {
  final String id;
  final String passengerId;
  final String passengerName;
  final String passengerPhone;
  final String fromAddress;
  final String toAddress;
  final GeoPoint fromLocation;
  final GeoPoint toLocation;
  final double offeredPrice;
  final DateTime timestamp;
  final String status; // 'pending', 'accepted', 'completed', 'cancelled'
  final String? acceptedBy;
  
  RideRequest({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerPhone,
    required this.fromAddress,
    required this.toAddress,
    required this.fromLocation,
    required this.toLocation,
    required this.offeredPrice,
    required this.timestamp,
    required this.status,
    this.acceptedBy,
  });
  
  factory RideRequest.fromMap(Map<String, dynamic> map, String id) {
    return RideRequest(
      id: id,
      passengerId: map['passengerId'] ?? '',
      passengerName: map['passengerName'] ?? '',
      passengerPhone: map['passengerPhone'] ?? '',
      fromAddress: map['fromAddress'] ?? '',
      toAddress: map['toAddress'] ?? '',
      fromLocation: map['fromLocation'] ?? const GeoPoint(0, 0),
      toLocation: map['toLocation'] ?? const GeoPoint(0, 0),
      offeredPrice: (map['offeredPrice'] ?? 0).toDouble(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'pending',
      acceptedBy: map['acceptedBy'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'offeredPrice': offeredPrice,
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
      'acceptedBy': acceptedBy,
    };
  }
  
  RideRequest copyWith({
    String? id,
    String? passengerId,
    String? passengerName,
    String? passengerPhone,
    String? fromAddress,
    String? toAddress,
    GeoPoint? fromLocation,
    GeoPoint? toLocation,
    double? offeredPrice,
    DateTime? timestamp,
    String? status,
    String? acceptedBy,
  }) {
    return RideRequest(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhone: passengerPhone ?? this.passengerPhone,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      acceptedBy: acceptedBy ?? this.acceptedBy,
    );
  }
} 