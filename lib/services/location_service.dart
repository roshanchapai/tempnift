import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:http/http.dart' as http;
import 'package:nift_final/utils/constants.dart';

class LocationService {
  static Future<LatLng?> getCurrentLocation() async {
    try {
      var permission = await Permission.location.status;
      if (!permission.isGranted) {
        permission = await Permission.location.request();
        if (!permission.isGranted) {
          return null;
        }
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 5),
      );

      return LatLng(position.latitude, position.longitude);
    } catch (e) {
      debugPrint('Error getting current location: $e');
      return null;
    }
  }

  static Future<String?> getAddressFromLatLng(LatLng location) async {
    try {
      final placemarks = await placemarkFromCoordinates(
        location.latitude,
        location.longitude,
      );
      if (placemarks.isNotEmpty) {
        final place = placemarks.first;
        return '${place.street}, ${place.locality}, ${place.country}';
      }
    } catch (e) {
      debugPrint('Error getting address: $e');
    }
    return null;
  }

  static Future<bool> requestLocationPermission(BuildContext context) async {
    try {
      var status = await Permission.location.status;
      status = await Permission.location.request();
      
      if (status.isDenied) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are required for this app to work properly.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return false;
      }

      if (status.isPermanentlyDenied) {
        if (context.mounted) {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Location Permission Required'),
                content: const Text(
                  'Location permissions are permanently denied. Please enable them in your device settings to use this app.',
                ),
                actions: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      openAppSettings();
                    },
                    child: const Text('Open Settings'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                ],
              );
            },
          );
        }
        return false;
      }

      if (status.isGranted) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location services are disabled. Please enable them.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return false;
        }

        var backgroundStatus = await Permission.locationAlways.status;
        if (backgroundStatus.isDenied) {
          backgroundStatus = await Permission.locationAlways.request();
        }
        return true;
      }
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error requesting location permission. Please try again.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
    return false;
  }

  static Future<List<LatLng>?> getRoutePoints(LatLng origin, LatLng destination) async {
    // This is a simple implementation - in a production app, you would use a proper Google Maps Directions API key
    // or replace this with another routing service like MapBox or OpenStreetMap
    try {
      // Using Google Maps Directions API
      final String apiKey = AppConstants.googleApiKey;
      final String url = 
          'https://maps.googleapis.com/maps/api/directions/json?'
          'origin=${origin.latitude},${origin.longitude}'
          '&destination=${destination.latitude},${destination.longitude}'
          '&key=$apiKey';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        if (data['status'] == 'OK') {
          // Decode the polyline points
          final points = _decodePolyline(data['routes'][0]['overview_polyline']['points']);
          return points;
        } else {
          // If the API returns an error, return a direct line between points
          return [origin, destination];
        }
      } else {
        // If the request fails, return a direct line between points
        return [origin, destination];
      }
    } catch (e) {
      debugPrint('Error getting route points: $e');
      // In case of error, return at least a direct line
      return [origin, destination];
    }
  }
  
  // Helper method to decode encoded polyline points from Google Maps Directions API
  static List<LatLng> _decodePolyline(String encoded) {
    List<LatLng> points = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    
    while (index < len) {
      int b, shift = 0, result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;
      
      shift = 0;
      result = 0;
      
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;
      
      points.add(LatLng(lat / 1E5, lng / 1E5));
    }
    
    return points;
  }
} 