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
  final String status; // 'pending', 'accepted', 'in_progress', 'completed', 'cancelled'
  final String? acceptedBy;
  final String? riderName;
  final String? riderPhone;
  final double? finalPrice;
  final double? estimatedDistance;
  final Map<String, dynamic>? priceFactors;
  final DateTime? completedAt;
  
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
    this.riderName,
    this.riderPhone,
    this.finalPrice,
    this.estimatedDistance,
    this.priceFactors,
    this.completedAt,
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
      riderName: map['riderName'],
      riderPhone: map['riderPhone'],
      finalPrice: map['finalPrice']?.toDouble(),
      estimatedDistance: map['estimatedDistance']?.toDouble(),
      priceFactors: map['priceFactors'] as Map<String, dynamic>?,
      completedAt: (map['completedAt'] as Timestamp?)?.toDate(),
    );
  }
  
  Map<String, dynamic> toMap() {
    final map = {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhone': passengerPhone,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'offeredPrice': offeredPrice,
      'timestamp': Timestamp.fromDate(timestamp),
      'status': status,
      'acceptedBy': acceptedBy,
    };
    
    // Only add these fields if they're not null
    if (riderName != null) map['riderName'] = riderName;
    if (riderPhone != null) map['riderPhone'] = riderPhone;
    if (finalPrice != null) map['finalPrice'] = finalPrice;
    if (estimatedDistance != null) map['estimatedDistance'] = estimatedDistance;
    if (priceFactors != null) map['priceFactors'] = priceFactors;
    if (completedAt != null) map['completedAt'] = Timestamp.fromDate(completedAt!);

    return map;
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
    String? riderName,
    String? riderPhone,
    double? finalPrice,
    double? estimatedDistance,
    Map<String, dynamic>? priceFactors,
    DateTime? completedAt,
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
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      finalPrice: finalPrice ?? this.finalPrice,
      estimatedDistance: estimatedDistance ?? this.estimatedDistance,
      priceFactors: priceFactors ?? this.priceFactors,
      completedAt: completedAt ?? this.completedAt,
    );
  }
} 