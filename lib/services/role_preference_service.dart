import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Service for managing and persisting role-specific preferences and view states
class RolePreferenceService {
  // Keys for preference storage
  static const String _riderPrefsKey = 'rider_preferences';
  static const String _passengerPrefsKey = 'passenger_preferences';
  static const String _lastRiderViewKey = 'last_rider_view';
  static const String _lastPassengerViewKey = 'last_passenger_view';

  /// Save preferences specific to the rider role
  Future<void> saveRiderPreferences(Map<String, dynamic> preferences) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_riderPrefsKey, jsonEncode(preferences));
  }

  /// Get preferences for the rider role
  Future<Map<String, dynamic>> getRiderPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? prefsJson = prefs.getString(_riderPrefsKey);
    
    if (prefsJson != null) {
      try {
        return jsonDecode(prefsJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing rider preferences: $e');
      }
    }
    
    // Return default preferences
    return {
      'mapZoomLevel': 14.0,
      'showOfflineAreas': false,
      'autoAcceptRides': false,
      'notificationsEnabled': true,
    };
  }

  /// Save preferences specific to the passenger role
  Future<void> savePassengerPreferences(Map<String, dynamic> preferences) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setString(_passengerPrefsKey, jsonEncode(preferences));
  }

  /// Get preferences for the passenger role
  Future<Map<String, dynamic>> getPassengerPreferences() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? prefsJson = prefs.getString(_passengerPrefsKey);
    
    if (prefsJson != null) {
      try {
        return jsonDecode(prefsJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing passenger preferences: $e');
      }
    }
    
    // Return default preferences
    return {
      'defaultPaymentMethod': 'cash',
      'defaultPickupLocation': null,
      'favoriteDestinations': [],
      'notificationsEnabled': true,
    };
  }

  /// Save the last view/screen the user was on in rider role
  Future<void> saveLastRiderView(String viewName, {Map<String, dynamic>? viewState}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final Map<String, dynamic> data = {
      'viewName': viewName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (viewState != null) {
      data['viewState'] = viewState;
    }
    
    await prefs.setString(_lastRiderViewKey, jsonEncode(data));
  }

  /// Get the last view the user was on in rider role
  Future<Map<String, dynamic>?> getLastRiderView() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? viewJson = prefs.getString(_lastRiderViewKey);
    
    if (viewJson != null) {
      try {
        return jsonDecode(viewJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing last rider view: $e');
      }
    }
    
    return null;
  }

  /// Save the last view/screen the user was on in passenger role
  Future<void> saveLastPassengerView(String viewName, {Map<String, dynamic>? viewState}) async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    
    final Map<String, dynamic> data = {
      'viewName': viewName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    
    if (viewState != null) {
      data['viewState'] = viewState;
    }
    
    await prefs.setString(_lastPassengerViewKey, jsonEncode(data));
  }

  /// Get the last view the user was on in passenger role
  Future<Map<String, dynamic>?> getLastPassengerView() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final String? viewJson = prefs.getString(_lastPassengerViewKey);
    
    if (viewJson != null) {
      try {
        return jsonDecode(viewJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint('Error parsing last passenger view: $e');
      }
    }
    
    return null;
  }
  
  /// Get the appropriate preferences for the current user role
  Future<Map<String, dynamic>> getPreferencesForRole(UserRole role) async {
    if (role == UserRole.rider) {
      return getRiderPreferences();
    } else {
      return getPassengerPreferences();
    }
  }
  
  /// Get the last view for the current user role
  Future<Map<String, dynamic>?> getLastViewForRole(UserRole role) async {
    if (role == UserRole.rider) {
      return getLastRiderView();
    } else {
      return getLastPassengerView();
    }
  }
  
  /// Save role-specific map position
  Future<void> saveMapPosition(UserRole role, LatLng position, double zoom) async {
    final Map<String, dynamic> mapState = {
      'latitude': position.latitude,
      'longitude': position.longitude,
      'zoom': zoom
    };
    
    final Map<String, dynamic> prefs = 
      role == UserRole.rider ? 
        await getRiderPreferences() : 
        await getPassengerPreferences();
        
    prefs['lastMapState'] = mapState;
    
    if (role == UserRole.rider) {
      await saveRiderPreferences(prefs);
    } else {
      await savePassengerPreferences(prefs);
    }
  }
  
  /// Get role-specific map position
  Future<Map<String, dynamic>?> getMapPosition(UserRole role) async {
    final Map<String, dynamic> prefs = 
      role == UserRole.rider ? 
        await getRiderPreferences() : 
        await getPassengerPreferences();
        
    return prefs['lastMapState'] as Map<String, dynamic>?;
  }
} 