import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/models/place_models.dart';

class PlacesService {
  /// Searches places using the Google Place Autocomplete API.
  ///
  /// - [input]: The user’s search query.
  /// - [sessionToken]: A unique token to group queries in the same user session.
  ///
  /// This method does not alter the input query so that it behaves exactly 
  /// like the Google Maps search feature.
  static Future<List<PlacePrediction>> searchPlaces(
      String input, {required String sessionToken}) async {
    // Encode the query to handle spaces and special characters.
    final String encodedInput = Uri.encodeComponent(input);
    final String url =
        'https://maps.googleapis.com/maps/api/place/autocomplete/json?input=$encodedInput'
        '&key=${AppConstants.googleApiKey}'
        '&components=country:np'
        '&sessiontoken=$sessionToken';

    debugPrint('Searching for places with query: $input');
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final predictions = data['predictions'] as List;

      // Convert JSON predictions to PlacePrediction objects.
      final List<PlacePrediction> results =
          predictions.map((p) => PlacePrediction.fromJson(p)).toList();

      debugPrint('Found ${results.length} place predictions');
      return results;
    }

    debugPrint('Failed to search places, status code: ${response.statusCode}');
    return [];
  }

  /// Gets detailed information about a place.
  ///
  /// - [placeId]: The unique identifier of the place.
  /// 
  /// Fetches details (including location and formatted address) using the
  /// Google Place Details API.
  static Future<PlaceDetail?> getPlaceDetails(String placeId) async {
    // Encode the placeId in case it contains any special characters.
    final String encodedPlaceId = Uri.encodeComponent(placeId);
    final String url =
        'https://maps.googleapis.com/maps/api/place/details/json?placeid=$encodedPlaceId&key=${AppConstants.googleApiKey}';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['result'] != null) {
        final location = data['result']['geometry']['location'];
        final lat = location['lat'];
        final lng = location['lng'];
        final formattedAddress = data['result']['formatted_address'] ?? '';
        final name = data['result']['name'] ?? '';

        // Use the place name, if available; otherwise, fall back to the address.
        final displayName =
            name.isNotEmpty ? "$name, $formattedAddress" : formattedAddress;

        return PlaceDetail(
          latLng: LatLng(lat, lng),
          formattedAddress: displayName,
        );
      }
    }
    return null;
  }

  /// Retrieves the driving route between two points using the Google Directions API.
  static Future<List<LatLng>?> getRouteFromGoogleDirections(
      LatLng origin, LatLng destination) async {
    final String apiKey = AppConstants.googleApiKey;
    final String url =
        'https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}'
        '&destination=${destination.latitude},${destination.longitude}'
        '&key=$apiKey&mode=driving';
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

  /// Decodes an encoded polyline string into a list of [LatLng] coordinates.
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