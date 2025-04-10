import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class RideOffer {
  final String id;
  final String riderId;
  final String riderName;
  final String riderPhone;
  final String fromAddress;
  final String toAddress;
  final GeoPoint fromLocation;
  final GeoPoint toLocation;
  final double offeredPrice;
  final int availableSeats;
  final DateTime departureTime;
  final DateTime timestamp;
  final String status; // 'active', 'completed', 'cancelled'
  final List<String> acceptedPassengerIds;
  
  RideOffer({
    required this.id,
    required this.riderId,
    required this.riderName,
    required this.riderPhone,
    required this.fromAddress,
    required this.toAddress,
    required this.fromLocation,
    required this.toLocation,
    required this.offeredPrice,
    required this.availableSeats,
    required this.departureTime,
    required this.timestamp,
    required this.status,
    required this.acceptedPassengerIds,
  });
  
  factory RideOffer.fromMap(Map<String, dynamic> map, String id) {
    return RideOffer(
      id: id,
      riderId: map['riderId'] ?? '',
      riderName: map['riderName'] ?? '',
      riderPhone: map['riderPhone'] ?? '',
      fromAddress: map['fromAddress'] ?? '',
      toAddress: map['toAddress'] ?? '',
      fromLocation: map['fromLocation'] ?? const GeoPoint(0, 0),
      toLocation: map['toLocation'] ?? const GeoPoint(0, 0),
      offeredPrice: (map['offeredPrice'] ?? 0).toDouble(),
      availableSeats: map['availableSeats'] ?? 1,
      departureTime: (map['departureTime'] as Timestamp?)?.toDate() ?? DateTime.now(),
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      status: map['status'] ?? 'active',
      acceptedPassengerIds: List<String>.from(map['acceptedPassengerIds'] ?? []),
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'riderId': riderId,
      'riderName': riderName,
      'riderPhone': riderPhone,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'offeredPrice': offeredPrice,
      'availableSeats': availableSeats,
      'departureTime': Timestamp.fromDate(departureTime),
      'timestamp': FieldValue.serverTimestamp(),
      'status': status,
      'acceptedPassengerIds': acceptedPassengerIds,
    };
  }
  
  RideOffer copyWith({
    String? id,
    String? riderId,
    String? riderName,
    String? riderPhone,
    String? fromAddress,
    String? toAddress,
    GeoPoint? fromLocation,
    GeoPoint? toLocation,
    double? offeredPrice,
    int? availableSeats,
    DateTime? departureTime,
    DateTime? timestamp,
    String? status,
    List<String>? acceptedPassengerIds,
  }) {
    return RideOffer(
      id: id ?? this.id,
      riderId: riderId ?? this.riderId,
      riderName: riderName ?? this.riderName,
      riderPhone: riderPhone ?? this.riderPhone,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      offeredPrice: offeredPrice ?? this.offeredPrice,
      availableSeats: availableSeats ?? this.availableSeats,
      departureTime: departureTime ?? this.departureTime,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      acceptedPassengerIds: acceptedPassengerIds ?? this.acceptedPassengerIds,
    );
  }
} 