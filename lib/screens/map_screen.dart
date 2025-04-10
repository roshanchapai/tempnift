import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/screens/auth_screen.dart';
import 'package:nift_final/models/place_models.dart';
import 'package:nift_final/services/location_service.dart';
import 'package:nift_final/services/places_service.dart';
import 'package:nift_final/widgets/popular_places_sheet.dart';
import 'package:nift_final/widgets/booking_panel.dart';
import 'package:nift_final/widgets/search_results_overlay.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/ride_request_screen.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/screens/passenger/ride_waiting_screen.dart';
import 'package:nift_final/screens/passenger/active_rides_screen.dart';
import 'package:nift_final/widgets/nift_logo.dart';

class MapScreen extends StatefulWidget {
  final UserModel? user;
  
  const MapScreen({Key? key, this.user}) : super(key: key);

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final Completer<GoogleMapController> _controller = Completer<GoogleMapController>();
  GoogleMapController? _mapController;
  final TextEditingController _pickupController = TextEditingController();
  final TextEditingController _destinationController = TextEditingController();
  
  LatLng? _currentLocation;
  LatLng? _pickupLocation;
  LatLng? _destinationLocation;
  bool _isLoading = true;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  bool _isPickupSearching = false;
  bool _isDestinationSearching = false;
  List<SearchResult> _searchResults = [];
  bool _isBookingPanelExpanded = false;
  List<PopularPlace> _popularPlaces = [];
  StreamSubscription<Position>? _locationSubscription;
  String _currentAddress = '';
  Timer? _addressUpdateTimer;
  LatLng? _savedCurrentLocation;
  
  // Generate a unique session token for place search requests
  final String _sessionToken = Random().nextInt(1000000).toString();

  // Default location (Kathmandu Valley, Nepal)
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(27.7172, 85.3240),
    zoom: 12.0,
    tilt: 0.0,
  );

  @override
  void initState() {
    super.initState();
    _initializeMap();
  }

  Future<void> _initializeMap() async {
    await LocationService.requestLocationPermission(context);
    _loadPopularPlaces();
    await _getCurrentLocation();
  }

  void _loadPopularPlaces() {
    _popularPlaces = [
      PopularPlace(
        name: 'Tribhuvan International Airport',
        location: const LatLng(27.6961, 85.3592),
        category: 'Transportation',
      ),
      PopularPlace(
        name: 'Thamel',
        location: const LatLng(27.7167, 85.3136),
        category: 'Tourist Area',
      ),
      PopularPlace(
        name: 'Durbar Square',
        location: const LatLng(27.7044, 85.3073),
        category: 'Landmark',
      ),
      PopularPlace(
        name: 'Garden of Dreams',
        location: const LatLng(27.7125, 85.3172),
        category: 'Park',
      ),
      PopularPlace(
        name: 'Swayambhunath Stupa',
        location: const LatLng(27.7148, 85.2903),
        category: 'Temple',
      ),
    ];
  }

  @override
  void dispose() {
    _locationSubscription?.cancel();
    _addressUpdateTimer?.cancel();
    _pickupController.dispose();
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });

      final location = await LocationService.getCurrentLocation();
      if (location != null) {
        _savedCurrentLocation = location;
        if (!mounted) return;
        
        setState(() {
          _currentLocation = location;
          _pickupLocation = location;
          _markers = {
            Marker(
              markerId: const MarkerId('current_location'),
              position: location,
              infoWindow: const InfoWindow(title: 'Current Location'),
            ),
          };
          _isLoading = false;
        });

        final address = await LocationService.getAddressFromLatLng(location);
        if (address != null && mounted) {
          setState(() {
            _pickupController.text = address;
            _currentAddress = address;
          });
        }

        if (_mapController != null && mounted) {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: location,
                zoom: 16.0,
                tilt: 0.0,
              ),
            ),
          );
        }
      } else {
        _useDefaultLocation();
      }
    } catch (e) {
      _useDefaultLocation();
    }
  }

  void _useDefaultLocation() {
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _currentLocation = _defaultLocation.target;
      _pickupLocation = _currentLocation;
      _savedCurrentLocation = _currentLocation;
      _markers = {
        Marker(
          markerId: const MarkerId('current_location'),
          position: _currentLocation!,
          infoWindow: const InfoWindow(title: 'Kathmandu Valley'),
        ),
      };
    });

    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(_defaultLocation),
      );
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Using default location: Kathmandu Valley'),
      ),
    );
  }

  Future<void> _searchLocation(String query, bool isPickup) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isPickupSearching = false;
        _isDestinationSearching = false;
      });
      return;
    }

    setState(() {
      _isPickupSearching = isPickup;
      _isDestinationSearching = !isPickup;
      _searchResults = [];
    });

    try {
      // Pass the session token to the searchPlaces method
      final predictions = await PlacesService.searchPlaces(
        query,
        sessionToken: _sessionToken,
      );
      
      List<SearchResult> results = [];

      for (var prediction in predictions) {
        final details = await PlacesService.getPlaceDetails(prediction.placeId);
        if (details != null) {
          results.add(SearchResult(
            place: Placemark(
              name: '',
              street: '',
              locality: '',
              subLocality: '',
              administrativeArea: '',
              country: '',
            ),
            location: details.latLng,
            formattedAddress: details.formattedAddress,
            distance: _currentLocation != null
              ? _calculateDistance(
                  _currentLocation!.latitude,
                  _currentLocation!.longitude,
                  details.latLng.latitude,
                  details.latLng.longitude,
                )
                : 0.0,
          ));
        }
      }

      results.sort((a, b) => a.distance.compareTo(b.distance));
      setState(() {
        _searchResults = results.take(5).toList();
      });
    } catch (e) {
      debugPrint('Error in _searchLocation: $e');
    }
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    // Simple Euclidean distance for sorting purposes
    return ((lat2 - lat1) * (lat2 - lat1) + (lon2 - lon1) * (lon2 - lon1)).abs();
  }

  void _selectLocation(SearchResult result, bool isPickup) async {
    if (!mounted) return;
    
    setState(() {
      if (isPickup) {
        _pickupLocation = result.location;
        _pickupController.text = result.formattedAddress;
      } else {
        _destinationLocation = result.location;
        _destinationController.text = result.formattedAddress;
      }
      _isPickupSearching = false;
      _isDestinationSearching = false;
      _searchResults.clear();
      _updateMarkers();
    });

    if (_mapController != null && mounted) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          isPickup ? _pickupLocation! : _destinationLocation!,
        ),
      );
    }

    if (_pickupLocation != null && _destinationLocation != null && mounted) {
      _drawRoute();
    }
  }

  void _selectPopularPlace(PopularPlace place) async {
    setState(() {
      _destinationLocation = place.location;
      _destinationController.text = place.name;
      _markers.removeWhere((m) => m.markerId.value == 'destination');
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: place.location,
          infoWindow: InfoWindow(title: place.name),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          draggable: true,
          onDragEnd: (newPosition) {
            _updateLocationFromDrag(newPosition, false);
          },
        ),
      );
      _isBookingPanelExpanded = true;
    });

    if (_mapController != null) {
      try {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: place.location,
              zoom: 15.0,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error animating camera to destination: $e');
      }
    }

    if (_pickupLocation != null) {
      _drawRoute();
    }
  }

  void _updateLocationFromDrag(LatLng newPosition, bool isPickup) async {
    if (!mounted) return;
    
    setState(() {
      if (isPickup) {
        _pickupLocation = newPosition;
        _markers.removeWhere((m) => m.markerId.value == 'pickup');
        _markers.add(
          Marker(
            markerId: const MarkerId('pickup'),
            position: newPosition,
            infoWindow: const InfoWindow(title: 'Pickup Location'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            draggable: true,
            onDragEnd: (newPosition) {
              _updateLocationFromDrag(newPosition, true);
            },
          ),
        );
      } else {
        _destinationLocation = newPosition;
        _markers.removeWhere((m) => m.markerId.value == 'destination');
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: newPosition,
            infoWindow: const InfoWindow(title: 'Destination'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            draggable: true,
            onDragEnd: (newPosition) {
              _updateLocationFromDrag(newPosition, false);
            },
          ),
        );
      }
    });

    if (!mounted) return;

    if (_mapController != null) {
      try {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPosition,
              zoom: 15.0,
            ),
          ),
        );
      } catch (e) {
        debugPrint('Error animating camera after drag: $e');
      }
    }

    final address = await LocationService.getAddressFromLatLng(newPosition);
    if (address != null && mounted) {
      setState(() {
        if (isPickup) {
          _pickupController.text = address;
        } else {
          _destinationController.text = address;
        }
      });
    }

    if (!mounted) return;
    
    if (_pickupLocation != null && _destinationLocation != null) {
      _drawRoute();
    }
  }

  void _drawRoute() async {
    if (_pickupLocation == null || _destinationLocation == null || !mounted) return;

    try {
      final routePoints = await PlacesService.getRouteFromGoogleDirections(
        _pickupLocation!,
        _destinationLocation!,
      );

      if (routePoints != null && routePoints.isNotEmpty && mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: AppColors.primaryColor,
              width: 5,
            ),
          };
        });
      }
    } catch (e) {
      debugPrint('Error drawing route: $e');
      if (mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: [_pickupLocation!, _destinationLocation!],
              color: AppColors.primaryColor,
              width: 5,
            ),
          };
        });
      }
    }
  }

  void _updateMarkers() {
    _markers = {};
    if (_pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          infoWindow: const InfoWindow(title: 'Pickup Location'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          draggable: true,
          onDragEnd: (newPosition) {
            _updateLocationFromDrag(newPosition, true);
          },
        ),
      );
    }
    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          infoWindow: const InfoWindow(title: 'Destination'),
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          draggable: true,
          onDragEnd: (newPosition) {
            _updateLocationFromDrag(newPosition, false);
          },
        ),
      );
    }
  }

  void _showPopularPlaces() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => PopularPlacesSheet(
        places: _popularPlaces,
        onPlaceSelected: _selectPopularPlace,
      ),
    );
  }
  
  // Handle the Book Now button click
  void _handleBookNow() {
    if (_pickupLocation == null || _destinationLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select pickup and destination locations'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }
    
    // Check if user is logged in and is a passenger
    if (widget.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to request a ride'),
          backgroundColor: AppColors.errorColor,
        ),
      );
      return;
    }
    
    Navigator.of(context).push<RideRequest>(
      MaterialPageRoute(
        builder: (context) => RideRequestScreen(
          passenger: widget.user!,
          pickupAddress: _pickupController.text,
          destinationAddress: _destinationController.text,
          pickupLocation: _pickupLocation!,
          destinationLocation: _destinationLocation!,
        ),
      ),
    ).then((request) {
      if (request != null && mounted) {
        // Navigate to ride waiting screen using push (not pushReplacement)
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => RideWaitingScreen(
              rideRequest: request,
              passenger: widget.user!,
            ),
          ),
        );
        
        // Reset the map inputs (will apply when user returns)
        setState(() {
          _destinationController.clear();
          _destinationLocation = null;
          _markers.removeWhere((m) => m.markerId.value == 'destination');
          _polylines.clear();
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          GoogleMap(
            mapType: MapType.normal,
            initialCameraPosition: _defaultLocation,
            onMapCreated: (GoogleMapController controller) {
              _controller.complete(controller);
              _mapController = controller;
            },
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: true,
            compassEnabled: false,
            onTap: _onMapTapped,
          ),
          if (_isLoading)
            const Center(
              child: CircularProgressIndicator(),
            ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: TextButton.icon(
                icon: const NiftLogo(size: 24.0),
                label: const Text('Active Rides'),
                onPressed: () {
                  if (widget.user == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please log in to view your active rides'),
                        backgroundColor: AppColors.errorColor,
                      ),
                    );
                    return;
                  }
                  
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ActiveRidesScreen(
                        passenger: widget.user!,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: BookingPanel(
              pickupController: _pickupController,
              destinationController: _destinationController,
              pickupLocation: _pickupLocation,
              destinationLocation: _destinationLocation,
              isPickupSearching: _isPickupSearching,
              isDestinationSearching: _isDestinationSearching,
              searchResults: _searchResults,
              onSearch: _searchLocation,
              onLocationSelected: _selectLocation,
              onGetCurrentLocation: () async {
                final location = await LocationService.getCurrentLocation();
                if (location != null && mounted) {
                  setState(() {
                    _pickupLocation = location;
                    _updateMarkers();
                  });
                  
                  final address = await LocationService.getAddressFromLatLng(location);
                  if (address != null && mounted) {
                    setState(() {
                      _pickupController.text = address;
                    });
                  }
                  
                  if (_mapController != null && mounted) {
                    _mapController!.animateCamera(
                      CameraUpdate.newCameraPosition(
                        CameraPosition(
                          target: location,
                          zoom: 16.0,
                          tilt: 0.0,
                        ),
                      ),
                    );
                  }
                  
                  if (_destinationLocation != null && mounted) {
                    _drawRoute();
                  }
                }
              },
              onShowPopularPlaces: _showPopularPlaces,
              onBookNow: _handleBookNow,
            ),
          ),
          if (_isPickupSearching || _isDestinationSearching)
            Positioned(
              left: 16,
              right: 16,
              top: 100,
              child: SearchResultsOverlay(
                isPickupSearching: _isPickupSearching,
                searchResults: _searchResults,
                onLocationSelected: (result, isPickup) {
                  _selectLocation(result, isPickup);
                },
              ),
            ),
        ],
      ),
    );
  }

  void _onMapTapped(LatLng location) {
    if (!mounted) return;
    
    if (!_isPickupSearching && !_isDestinationSearching) {
      setState(() {
        _destinationLocation = location;
        _markers.removeWhere((m) => m.markerId.value == 'destination');
        _markers.add(
          Marker(
            markerId: const MarkerId('destination'),
            position: location,
            infoWindow: const InfoWindow(title: 'Destination'),
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
            draggable: true,
            onDragEnd: (newPosition) {
              _updateLocationFromDrag(newPosition, false);
            },
          ),
        );
        _isBookingPanelExpanded = true;
      });

      LocationService.getAddressFromLatLng(location).then((address) {
        if (address != null && mounted) {
          setState(() {
            _destinationController.text = address;
          });
        }
      });

      if (mounted && _pickupLocation != null) {
        _drawRoute();
      }
    }
  }
}

// --- New supporting classes for Google Places ---

class PlacePrediction {
  final String description;
  final String placeId;

  PlacePrediction({required this.description, required this.placeId});

  factory PlacePrediction.fromJson(Map<String, dynamic> json) {
    return PlacePrediction(
      description: json['description'] ?? '',
      placeId: json['place_id'] ?? '',
    );
  }
}

class PlaceDetail {
  final LatLng latLng;
  final String formattedAddress;

  PlaceDetail({required this.latLng, required this.formattedAddress});
}