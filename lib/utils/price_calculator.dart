import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:nift_final/services/location_service.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class PriceCalculator {
  // Base constants
  static const double _basePrice = 100.0;
  static const double _perKmRate = 50.0;
  static const double _minimumPrice = 100.0;
  
  // Public getters for constants
  static double get basePrice => _basePrice;
  static double get perKmRate => _perKmRate;
  static double get minimumPrice => _minimumPrice;
  
  // Time multipliers
  static const double _peakHourMultiplier = 1.25;
  static const double _nightTimeMultiplier = 1.15;
  static const double _weekendMultiplier = 1.1;
  
  // Demand-based pricing
  static const double _highDemandMultiplier = 1.3;
  
  // Calculate the suggested price based on pickup and destination
  static Future<double> calculateSuggestedPrice(
    LatLng pickup, 
    LatLng destination, 
    {bool considerTimeFactors = true, bool considerDemand = true}
  ) async {
    try {
      // Calculate accurate distance using the Haversine formula
      double distanceInKm = calculateHaversineDistance(pickup, destination);
      
      // Optionally get more accurate route distance if available
      try {
        final routePoints = await LocationService.getRoutePoints(pickup, destination);
        if (routePoints != null && routePoints.length > 1) {
          distanceInKm = calculateRouteDistance(routePoints);
        }
      } catch (e) {
        debugPrint('Error getting route distance: $e');
        // Continue with the direct distance calculation
      }
      
      // Base price calculation: base + distance factor
      double price = _basePrice + (distanceInKm * _perKmRate);
      
      // Apply time-based factors if enabled
      if (considerTimeFactors) {
        price *= _getTimeMultiplier();
      }
      
      // Apply demand-based pricing if enabled
      if (considerDemand) {
        price *= _getDemandMultiplier();
      }
      
      // Ensure minimum price
      price = price < _minimumPrice ? _minimumPrice : price;
      
      // Round to nearest 10
      price = (price / 10.0).round() * 10.0;
      
      return price;
    } catch (e) {
      debugPrint('Error calculating price: $e');
      return _basePrice; // Return base price as fallback
    }
  }
  
  // Calculate distance using the Haversine formula (more accurate than Euclidean for geographic coordinates)
  static double calculateHaversineDistance(LatLng point1, LatLng point2) {
    const int earthRadius = 6371; // Earth's radius in kilometers
    
    // Convert latitude and longitude from degrees to radians
    final double lat1 = _degreesToRadians(point1.latitude);
    final double lon1 = _degreesToRadians(point1.longitude);
    final double lat2 = _degreesToRadians(point2.latitude);
    final double lon2 = _degreesToRadians(point2.longitude);
    
    // Haversine formula
    final double dLat = lat2 - lat1;
    final double dLon = lon2 - lon1;
    final double a = _haversine(dLat) + 
                     _haversine(dLon) * 
                     _cosine(lat1) * 
                     _cosine(lat2);
    final double c = 2 * _arctangent2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c; // Distance in kilometers
  }
  
  // Calculate distance along a route (more accurate than direct distance)
  static double calculateRouteDistance(List<LatLng> points) {
    double totalDistance = 0.0;
    
    for (int i = 0; i < points.length - 1; i++) {
      totalDistance += calculateHaversineDistance(points[i], points[i + 1]);
    }
    
    return totalDistance;
  }
  
  // Math helpers
  static double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
  static double _haversine(double value) => (1 - _cosine(value)) / 2;
  static double _cosine(double value) => math.cos(value);
  static double _arctangent2(double y, double x) => math.atan2(y, x);
  
  // Time-based pricing factors
  static double _getTimeMultiplier() {
    final now = DateTime.now();
    double multiplier = 1.0;
    
    // Peak hours: 7-9 AM and 5-7 PM on weekdays
    if (_isWeekday(now) && (_isPeakMorningHour(now) || _isPeakEveningHour(now))) {
      multiplier *= _peakHourMultiplier;
    }
    
    // Night time: 10 PM to 5 AM
    if (_isNightTime(now)) {
      multiplier *= _nightTimeMultiplier;
    }
    
    // Weekend
    if (_isWeekend(now)) {
      multiplier *= _weekendMultiplier;
    }
    
    return multiplier;
  }
  
  // Demand-based pricing (could be connected to backend in a real app)
  static double _getDemandMultiplier() {
    // Simplified demand calculation - in a real app this would be based on:
    // - Number of active riders vs. passengers in an area
    // - Historical demand patterns
    // - Special events, weather conditions, etc.
    
    // For this demo, we'll simulate random demand with a slight increase
    final random = DateTime.now().millisecondsSinceEpoch % 10;
    if (random > 7) { // 20% chance of high demand
      return _highDemandMultiplier;
    }
    
    return 1.0;
  }
  
  // Time helpers
  static bool _isWeekday(DateTime date) => 
      date.weekday >= DateTime.monday && date.weekday <= DateTime.friday;
  
  static bool _isWeekend(DateTime date) => 
      date.weekday == DateTime.saturday || date.weekday == DateTime.sunday;
  
  static bool _isPeakMorningHour(DateTime date) => 
      date.hour >= 7 && date.hour < 9;
  
  static bool _isPeakEveningHour(DateTime date) => 
      date.hour >= 17 && date.hour < 19;
  
  static bool _isNightTime(DateTime date) => 
      date.hour >= 22 || date.hour < 5;
} 