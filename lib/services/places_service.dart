import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/models/place_models.dart';

class PlacesService {
  static Future<List<PlacePrediction>> searchPlaces(String input) async {
    // Add specific keywords to improve search results for educational institutions
    String searchQuery = input;
    if (input.toLowerCase().contains("college") || 
        input.toLowerCase().contains("university") ||
        input.toLowerCase().contains("school")) {
      // Already contains educational keywords, no need to modify
    } else if (input.contains(" ")) {
      // Check if it might be a college/university name without the word "college"
      // In this case, add "college" as a keyword to improve results
      searchQuery = "$input college";
    }
    
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$searchQuery'
        '&key=${AppConstants.googleApiKey}'
        '&components=country:np'
        '&types=establishment|school|university|point_of_interest'; // Filter to relevant place types
    
    debugPrint('Searching for places with query: $searchQuery');
    
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final predictions = data['predictions'] as List;
      
      // Convert to PlacePrediction objects
      final List<PlacePrediction> results = predictions.map((p) => PlacePrediction.fromJson(p)).toList();
      
      // Sort results by relevance - exact matches first, then partial matches
      results.sort((a, b) {
        final aLower = a.description.toLowerCase();
        final bLower = b.description.toLowerCase();
        final inputLower = input.toLowerCase();
        
        // Check for exact match at the beginning of the description
        final aStartsWith = aLower.startsWith(inputLower);
        final bStartsWith = bLower.startsWith(inputLower);
        
        if (aStartsWith && !bStartsWith) return -1;
        if (!aStartsWith && bStartsWith) return 1;
        
        // Then check for exact matches anywhere in the string
        final aContains = aLower.contains(inputLower);
        final bContains = bLower.contains(inputLower);
        
        if (aContains && !bContains) return -1;
        if (!aContains && bContains) return 1;
        
        // Then go by string length (shorter = more specific/relevant)
        return a.description.length.compareTo(b.description.length);
      });
      
      debugPrint('Found ${results.length} place predictions');
      return results;
    }
    
    debugPrint('Failed to search places, status code: ${response.statusCode}');
    return [];
  }

  static Future<PlaceDetail?> getPlaceDetails(String placeId) async {
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?placeid=$placeId&key=${AppConstants.googleApiKey}';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['result'] != null) {
        final location = data['result']['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        final formattedAddress = data['result']['formatted_address'] ?? '';
        final name = data['result']['name'] ?? '';
        
        // Use the place name if available, otherwise use formatted address
        final displayName = name.isNotEmpty ? 
            "$name, $formattedAddress" : formattedAddress;
        
        return PlaceDetail(
          latLng: LatLng(lat, lng),
          formattedAddress: displayName,
        );
      }
    }
    return null;
  }

  static Future<List<LatLng>?> getRouteFromGoogleDirections(LatLng origin, LatLng destination) async {
    final String apiKey = AppConstants.googleApiKey;
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$apiKey&mode=driving';
    final response = await http.get(Uri.parse(url));
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if ((data['routes'] as List).isNotEmpty) {
        final route = data['routes'][0];
        final String polyline = route['overview_polyline']['points'];
        return _decodePoly(polyline);
      }
    }
    return null;
  }

  static List<LatLng> _decodePoly(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;
    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lat += dlat;
      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0) ? ~(result >> 1) : (result >> 1);
      lng += dlng;
      poly.add(LatLng(lat / 1e5, lng / 1e5));
    }
    return poly;
  }
} 