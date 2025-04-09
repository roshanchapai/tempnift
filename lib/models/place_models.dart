import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';

class PlacePrediction {
  final String placeId;
  final String description;

  PlacePrediction({required this.placeId, required this.description});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      placeId: json['place_id'],
      description: json['description'],
    );
  }
}

class PlaceDetail {
  final LatLng latLng;
  final String formattedAddress;

  PlaceDetail({
    required this.latLng,
    required this.formattedAddress,
  });
}

class SearchResult {
  final Placemark place;
  final LatLng location;
  final String formattedAddress;
  final double distance;

  SearchResult({
    required this.place,
    required this.location,
    required this.formattedAddress,
    required this.distance,
  });
}

class PopularPlace {
  final String name;
  final LatLng location;
  final String category;

  PopularPlace({
    required this.name,
    required this.location,
    required this.category,
  });
} 