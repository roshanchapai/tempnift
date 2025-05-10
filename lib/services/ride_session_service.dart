import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/passenger/ongoing_ride_screen.dart';
import 'package:nift_final/screens/rider/ongoing_ride_screen.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Service to manage active ride sessions and ensure they persist
/// across app restarts
class RideSessionService {
  static const String _activePassengerRideKey = 'active_passenger_ride';
  static const String _activeRiderRideKey = 'active_rider_ride';
  static const String _activeUserKey = 'active_user';
  static const String _activeRiderPartnerKey = 'active_rider_partner';
  static const String _activePassengerPartnerKey = 'active_passenger_partner';
  
  final RideService _rideService = RideService();
  
  /// Saves the active passenger ride to persistent storage
  Future<void> saveActivePassengerRide({
    required RideRequest rideRequest,
    required UserModel passenger,
    required UserModel rider,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Store the ride request
    await prefs.setString(_activePassengerRideKey, jsonEncode(rideRequest.toMap()));
    
    // Store the user
    await prefs.setString(_activeUserKey, jsonEncode(passenger.toMap()));
    
    // Store the rider
    await prefs.setString(_activeRiderPartnerKey, jsonEncode(rider.toMap()));
  }
  
  /// Saves the active rider ride to persistent storage
  Future<void> saveActiveRiderRide({
    required RideRequest rideRequest,
    required UserModel rider,
    required UserModel passenger,
  }) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    // Store the ride request
    await prefs.setString(_activeRiderRideKey, jsonEncode(rideRequest.toMap()));
    
    // Store the user
    await prefs.setString(_activeUserKey, jsonEncode(rider.toMap()));
    
    // Store the passenger
    await prefs.setString(_activePassengerPartnerKey, jsonEncode(passenger.toMap()));
  }
  
  /// Clears the active passenger ride
  Future<void> clearActivePassengerRide() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activePassengerRideKey);
    await prefs.remove(_activeRiderPartnerKey);
  }
  
  /// Clears the active rider ride
  Future<void> clearActiveRiderRide() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeRiderRideKey);
    await prefs.remove(_activePassengerPartnerKey);
  }
  
  /// Checks if there's an active passenger ride and returns the data
  Future<Map<String, dynamic>?> getActivePassengerRide() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final String? rideJson = prefs.getString(_activePassengerRideKey);
    final String? userJson = prefs.getString(_activeUserKey);
    final String? riderJson = prefs.getString(_activeRiderPartnerKey);
    
    if (rideJson != null && userJson != null && riderJson != null) {
      try {
        final Map<String, dynamic> rideMap = jsonDecode(rideJson);
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        final Map<String, dynamic> riderMap = jsonDecode(riderJson);
        
        final RideRequest rideRequest = RideRequest.fromMap(rideMap, rideMap['id']);
        final UserModel passenger = UserModel.fromMap(userMap);
        final UserModel rider = UserModel.fromMap(riderMap);
        
        // Verify the ride is still active by checking the database
        final currentRide = await _rideService.getRideRequest(rideRequest.id);
        if (currentRide != null && 
            (currentRide.status == 'accepted' || 
             currentRide.status == 'in_progress')) {
          return {
            'rideRequest': rideRequest,
            'passenger': passenger,
            'rider': rider,
          };
        } else {
          // If ride is no longer active, clear it
          await clearActivePassengerRide();
        }
      } catch (e) {
        debugPrint('Error parsing active passenger ride: $e');
        await clearActivePassengerRide();
      }
    }
    
    return null;
  }
  
  /// Checks if there's an active rider ride and returns the data
  Future<Map<String, dynamic>?> getActiveRiderRide() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final String? rideJson = prefs.getString(_activeRiderRideKey);
    final String? userJson = prefs.getString(_activeUserKey);
    final String? passengerJson = prefs.getString(_activePassengerPartnerKey);
    
    if (rideJson != null && userJson != null && passengerJson != null) {
      try {
        final Map<String, dynamic> rideMap = jsonDecode(rideJson);
        final Map<String, dynamic> userMap = jsonDecode(userJson);
        final Map<String, dynamic> passengerMap = jsonDecode(passengerJson);
        
        final RideRequest rideRequest = RideRequest.fromMap(rideMap, rideMap['id']);
        final UserModel rider = UserModel.fromMap(userMap);
        final UserModel passenger = UserModel.fromMap(passengerMap);
        
        // Verify the ride is still active by checking the database
        final currentRide = await _rideService.getRideRequest(rideRequest.id);
        if (currentRide != null && 
            (currentRide.status == 'accepted' || 
             currentRide.status == 'in_progress')) {
          return {
            'rideRequest': rideRequest,
            'rider': rider,
            'passenger': passenger,
          };
        } else {
          // If ride is no longer active, clear it
          await clearActiveRiderRide();
        }
      } catch (e) {
        debugPrint('Error parsing active rider ride: $e');
        await clearActiveRiderRide();
      }
    }
    
    return null;
  }
  
  /// Navigates to the appropriate ongoing ride screen based on user role
  Future<void> checkAndNavigateToActiveRide(
    BuildContext context,
    UserModel user,
  ) async {
    if (user.userRole == UserRole.passenger) {
      final activeRide = await getActivePassengerRide();
      if (activeRide != null) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => PassengerOngoingRideScreen(
                rideRequest: activeRide['rideRequest'],
                passenger: activeRide['passenger'],
                rider: activeRide['rider'],
              ),
            ),
          );
        }
      }
    } else if (user.userRole == UserRole.rider) {
      final activeRide = await getActiveRiderRide();
      if (activeRide != null) {
        if (context.mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => RiderOngoingRideScreen(
                rideRequest: activeRide['rideRequest'],
                rider: activeRide['rider'],
                passenger: activeRide['passenger'],
              ),
            ),
          );
        }
      }
    }
  }
} 