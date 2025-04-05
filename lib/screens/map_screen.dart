import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nift_final/screens/auth_screen.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({Key? key}) : super(key: key);

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
  bool _isSearching = false;
  bool _isPickupSearching = false;
  bool _isDestinationSearching = false;
  List<_SearchResult> _searchResults = [];
  bool _isBookingPanelExpanded = false;
  bool _isDraggingPin = false;
  bool _isDraggingPickup = false;
  bool _isDraggingDestination = false;
  List<_PopularPlace> _popularPlaces = [];
  StreamSubscription<Position>? _locationSubscription;
  String _currentAddress = '';
  Timer? _addressUpdateTimer;

  // Default location (Kathmandu Valley, Nepal)
  static const CameraPosition _defaultLocation = CameraPosition(
    target: LatLng(27.7172, 85.3240), // Kathmandu Valley coordinates
    zoom: 12.0, // Slightly zoomed out to show the valley
  );

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadPopularPlaces();
    _startLocationUpdates();
  }

  void _loadPopularPlaces() {
    // In a real app, this would come from an API or database
    _popularPlaces = [
      _PopularPlace(
        name: 'Tribhuvan International Airport',
        location: const LatLng(27.6961, 85.3592),
        category: 'Transportation',
      ),
      _PopularPlace(
        name: 'Thamel',
        location: const LatLng(27.7167, 85.3136),
        category: 'Tourist Area',
      ),
      _PopularPlace(
        name: 'Durbar Square',
        location: const LatLng(27.7044, 85.3073),
        category: 'Landmark',
      ),
      _PopularPlace(
        name: 'Garden of Dreams',
        location: const LatLng(27.7125, 85.3172),
        category: 'Park',
      ),
      _PopularPlace(
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

  Future<void> _requestLocationPermission() async {
    try {
      // Request location permission using permission_handler
      var status = await Permission.location.status;
      
      // Always request permission regardless of current status
      status = await Permission.location.request();
      
      if (status.isDenied) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Location permissions are required for this app to work properly.'),
              duration: Duration(seconds: 5),
            ),
          );
        }
        return;
      }

      if (status.isPermanentlyDenied) {
        if (mounted) {
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
        return;
      }

      // If location permission is granted, check location services
      if (status.isGranted) {
        bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
        if (!serviceEnabled) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location services are disabled. Please enable them.'),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // Request background location permission
        var backgroundStatus = await Permission.locationAlways.status;
        if (backgroundStatus.isDenied) {
          backgroundStatus = await Permission.locationAlways.request();
        }

        // Get current location
        _getCurrentLocation();
      }
    } catch (e) {
      debugPrint('Error requesting location permission: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error requesting location permission. Please try again.'),
            duration: Duration(seconds: 5),
          ),
        );
      }
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      final newLocation = LatLng(position.latitude, position.longitude);
      
      setState(() {
        _currentLocation = newLocation;
        _pickupLocation = newLocation;
        _markers = {
          Marker(
            markerId: const MarkerId('current_location'),
            position: newLocation,
            infoWindow: const InfoWindow(title: 'Current Location'),
          ),
        };
        _isLoading = false;
      });

      // Get address for current location
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          setState(() {
            _pickupController.text = '${place.street}, ${place.locality}, ${place.country}';
          });
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      // Animate camera to new location
      if (_mapController != null) {
        try {
          await _mapController!.animateCamera(
            CameraUpdate.newCameraPosition(
              CameraPosition(
                target: newLocation,
                zoom: 15.0,
              ),
            ),
          );
        } catch (e) {
          debugPrint('Error animating camera: $e');
        }
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          // If location fails, show Kathmandu Valley
          _currentLocation = _defaultLocation.target;
          _pickupLocation = _currentLocation;
          _markers = {
            Marker(
              markerId: const MarkerId('current_location'),
              position: _currentLocation!,
              infoWindow: const InfoWindow(title: 'Kathmandu Valley'),
            ),
          };
        });
        
        // Animate to default location
        if (_mapController != null) {
          try {
            await _mapController!.animateCamera(
              CameraUpdate.newCameraPosition(_defaultLocation),
            );
          } catch (e) {
            debugPrint('Error animating to default location: $e');
          }
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Using default location: Kathmandu Valley'),
          ),
        );
      }
    }
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
      // First try with specific location search
      List<Location> locations = [];
      try {
        locations = await locationFromAddress(
          query,
          localeIdentifier: 'en_US'  // Ensure consistent language
        );
      } catch (e) {
        debugPrint('Initial location search failed: $e');
        // If specific search fails, try with a more general search
        try {
          locations = await locationFromAddress(
            '$query, Nepal',  // Add country context
            localeIdentifier: 'en_US'
          );
        } catch (e) {
          debugPrint('Fallback location search failed: $e');
        }
      }
      
      if (locations.isNotEmpty) {
        List<_SearchResult> results = [];
        
        // Process each location
        for (var location in locations) {
          try {
            // Get detailed place information
            final placemarks = await placemarkFromCoordinates(
              location.latitude,
              location.longitude,
              localeIdentifier: 'en_US'  // Ensure consistent language
            );
            
            if (placemarks.isNotEmpty) {
              final place = placemarks.first;
              
              // Only add if we have meaningful address components
              if (_hasValidAddressComponents(place)) {
                results.add(_SearchResult(
                  place: place,
                  location: LatLng(location.latitude, location.longitude),
                  formattedAddress: _formatDetailedAddress(place),
                  distance: _calculateDistance(
                    _currentLocation?.latitude ?? 0,
                    _currentLocation?.longitude ?? 0,
                    location.latitude,
                    location.longitude,
                  ),
                ));
              }
            }
          } catch (e) {
            debugPrint('Error getting place details: $e');
          }
        }
        
        // Sort results by relevance and distance
        results.sort((a, b) {
          // First prioritize results with more complete addresses
          final aScore = _getAddressCompleteness(a.place);
          final bScore = _getAddressCompleteness(b.place);
          
          if (aScore != bScore) {
            return bScore.compareTo(aScore);
          }
          
          // Then sort by distance if current location is available
          if (_currentLocation != null) {
            return a.distance.compareTo(b.distance);
          }
          
          return 0;
        });
        
        // Remove duplicates and limit results
        final uniqueResults = _removeDuplicateResults(results);
        
        setState(() {
          _searchResults = uniqueResults.take(5).toList();  // Limit to top 5 results
        });
        
        // If there's only one result and it's a direct search (not from dropdown),
        // automatically select it and animate to that location
        if (uniqueResults.length == 1 && !_isPickupSearching && !_isDestinationSearching) {
          final result = uniqueResults.first;
          
          // First update the UI state
          if (isPickup) {
            setState(() {
              _pickupLocation = result.location;
              _pickupController.text = result.formattedAddress;
              _markers.removeWhere((m) => m.markerId.value == 'pickup');
              _markers.add(
                Marker(
                  markerId: const MarkerId('pickup'),
                  position: result.location,
                  infoWindow: InfoWindow(title: 'Pickup Location', snippet: result.formattedAddress),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
                  draggable: true,
                  onDragEnd: (newPosition) {
                    _updateLocationFromDrag(newPosition, true);
                  },
                ),
              );
            });
          } else {
            setState(() {
              _destinationLocation = result.location;
              _destinationController.text = result.formattedAddress;
              _markers.removeWhere((m) => m.markerId.value == 'destination');
              _markers.add(
                Marker(
                  markerId: const MarkerId('destination'),
                  position: result.location,
                  infoWindow: InfoWindow(title: 'Destination', snippet: result.formattedAddress),
                  icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
                  draggable: true,
                  onDragEnd: (newPosition) {
                    _updateLocationFromDrag(newPosition, false);
                  },
                ),
              );
              _isBookingPanelExpanded = true;
            });
          }
          
          // Clear search results
          setState(() {
            _searchResults = [];
            _isPickupSearching = false;
            _isDestinationSearching = false;
          });
          
          // Ensure camera animates to the location with a good zoom level
          if (_mapController != null) {
            try {
              // First zoom out slightly to get a better view
              await _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: result.location,
                    zoom: 14.0, // Slightly zoomed out for context
                    tilt: 45.0, // Add some tilt for a better 3D view
                  ),
                ),
              );
              
              // Then zoom in to the location
              await Future.delayed(const Duration(milliseconds: 500));
              await _mapController!.animateCamera(
                CameraUpdate.newCameraPosition(
                  CameraPosition(
                    target: result.location,
                    zoom: 16.0, // Closer zoom for detail
                    tilt: 45.0, // Keep the tilt for 3D view
                  ),
                ),
              );
            } catch (e) {
              debugPrint('Error animating camera to location: $e');
            }
          }
          
          // Draw route if both locations are set
          if (_pickupLocation != null && _destinationLocation != null) {
            _drawRoute();
          }
        }
      } else {
        // Show a helpful message when no results are found
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('No locations found for "$query". Try adding more details.'),
              duration: const Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error in location search: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error searching location. Please check your internet connection and try again.'),
            duration: Duration(seconds: 3),
          ),
        );
      }
    }
  }

  bool _hasValidAddressComponents(Placemark place) {
    return (place.name?.isNotEmpty == true) ||
           (place.street?.isNotEmpty == true) ||
           (place.locality?.isNotEmpty == true) ||
           (place.subLocality?.isNotEmpty == true) ||
           (place.administrativeArea?.isNotEmpty == true);
  }

  String _formatDetailedAddress(Placemark place) {
    List<String> addressParts = [];
    
    // Add specific location name if available
    if (place.name?.isNotEmpty == true && place.name != place.street) {
      addressParts.add(place.name!);
    }

    // Add street address
    if (place.street?.isNotEmpty == true) {
      addressParts.add(place.street!);
    }

    // Add sublocality (neighborhood/area)
    if (place.subLocality?.isNotEmpty == true) {
      addressParts.add(place.subLocality!);
    }

    // Add locality (city)
    if (place.locality?.isNotEmpty == true) {
      addressParts.add(place.locality!);
    }

    // Add administrative area (state/province)
    if (place.administrativeArea?.isNotEmpty == true) {
      addressParts.add(place.administrativeArea!);
    }

    // Add country
    if (place.country?.isNotEmpty == true) {
      addressParts.add(place.country!);
    }

    return addressParts.join(', ');
  }

  int _getAddressCompleteness(Placemark place) {
    int score = 0;
    if (place.name?.isNotEmpty == true) score++;
    if (place.street?.isNotEmpty == true) score++;
    if (place.subLocality?.isNotEmpty == true) score++;
    if (place.locality?.isNotEmpty == true) score++;
    if (place.administrativeArea?.isNotEmpty == true) score++;
    if (place.country?.isNotEmpty == true) score++;
    return score;
  }

  List<_SearchResult> _removeDuplicateResults(List<_SearchResult> results) {
    return results.fold<List<_SearchResult>>(
      [],
      (list, result) {
        // Check for duplicates using multiple criteria
        bool isDuplicate = list.any((existing) =>
            (existing.location.latitude - result.location.latitude).abs() < 0.0001 &&
            (existing.location.longitude - result.location.longitude).abs() < 0.0001 ||
            existing.formattedAddress.toLowerCase() == result.formattedAddress.toLowerCase()
        );
        
        if (!isDuplicate) {
          list.add(result);
        }
        return list;
      },
    );
  }

  void _selectLocation(_SearchResult result, bool isPickup) async {
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

    // Animate to the selected location
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLng(
          isPickup ? _pickupLocation! : _destinationLocation!,
        ),
      );
    }
  }

  void _selectPopularPlace(_PopularPlace place) async {
    // First update the UI state
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

    // Then animate the camera
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

    // Draw route if pickup location is set
    if (_pickupLocation != null) {
      _drawRoute();
    }
  }

  void _updateLocationFromDrag(LatLng newPosition, bool isPickup) async {
    // Update markers and locations
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

    // Animate camera to the new position
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

    // Get address for the new position
    try {
      final placemarks = await placemarkFromCoordinates(
        newPosition.latitude,
        newPosition.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final place = placemarks.first;
        setState(() {
          if (isPickup) {
            _pickupController.text = '${place.street}, ${place.locality}, ${place.country}';
          } else {
            _destinationController.text = '${place.street}, ${place.locality}, ${place.country}';
          }
        });
      }
    } catch (e) {
      debugPrint('Error getting address after drag: $e');
    }

    // Draw route if both locations are set
    if (_pickupLocation != null && _destinationLocation != null) {
      _drawRoute();
    }
  }

  void _drawRoute() {
    // In a real app, you would use a directions API to get the actual route
    // For now, we'll just draw a straight line
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

  void _onMapTapped(LatLng location) {
    // If we're not in search mode, allow setting destination by tapping
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

      // Get address for the tapped location
      placemarkFromCoordinates(location.latitude, location.longitude)
          .then((placemarks) {
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          setState(() {
            _destinationController.text = '${place.street}, ${place.locality}, ${place.country}';
          });
        }
      });

      // Draw route if both locations are set
      if (_pickupLocation != null) {
        _drawRoute();
      }
    }
  }

  void _showPopularPlaces() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Popular Places',
                    style: AppTextStyles.subtitleStyle,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: ListView.builder(
                  itemCount: _popularPlaces.length,
                  itemBuilder: (context, index) {
                    final place = _popularPlaces[index];
                    return ListTile(
                      leading: Icon(
                        _getCategoryIcon(place.category),
                        color: AppColors.primaryColor,
                      ),
                      title: Text(place.name),
                      subtitle: Text(place.category),
                      onTap: () {
                        Navigator.pop(context);
                        _selectPopularPlace(place);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'transportation':
        return Icons.directions_bus;
      case 'tourist area':
        return Icons.place;
      case 'landmark':
        return Icons.location_city;
      case 'park':
        return Icons.park;
      case 'temple':
        return Icons.church;
      default:
        return Icons.place;
    }
  }

  void _showHamburgerMenu() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(16),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Menu',
                    style: AppTextStyles.subtitleStyle,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profile'),
                subtitle: const Text('View your profile details'),
                onTap: () {
                  Navigator.pop(context);
                  _showProfileDetails();
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: const Text('Ride History'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to ride history screen
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment),
                title: const Text('Payment Methods'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to payment methods screen
                },
              ),
              ListTile(
                leading: const Icon(Icons.help),
                title: const Text('Help & Support'),
                onTap: () {
                  Navigator.pop(context);
                  // TODO: Navigate to help & support screen
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings),
                title: const Text('Settings'),
                onTap: () {
                  Navigator.pop(context);
                  _showSettingsMenu();
                },
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: const Text('Switch to Rider'),
                subtitle: const Text('Become a driver and earn money'),
                onTap: () {
                  Navigator.pop(context);
                  _showRiderRegistrationForm();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showProfileDetails() {
    // Show loading indicator while fetching user data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
    
    // Get the current user's UID
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) {
      // Close the loading dialog
      Navigator.pop(context);
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Fetch user data from Firestore
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get()
        .then((DocumentSnapshot documentSnapshot) {
          // Close the loading dialog
          Navigator.pop(context);
          
          if (documentSnapshot.exists) {
            // Extract user data from the document
            final data = documentSnapshot.data() as Map<String, dynamic>;
            final String userName = data['name'] ?? 'Unknown';
            final String userPhone = data['phoneNumber'] ?? 'Unknown';
            final String userRole = data['userRole'] ?? 'Unknown';
            final String userProfileImage = data['profileImage'] ?? ''; // URL to profile image in Firestore
            
            // Show profile dialog with the fetched data
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Profile Details'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Center(
                          child: userProfileImage.isNotEmpty
                              ? CircleAvatar(
                                  radius: 50,
                                  backgroundImage: NetworkImage(userProfileImage),
                                )
                              : CircleAvatar(
                                  radius: 50,
                                  backgroundColor: AppColors.primaryColor,
                                  child: Text(
                                    userName.substring(0, 1).toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 40,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                        ),
                        const SizedBox(height: 20),
                        _buildProfileItem(Icons.person, 'Name', userName),
                        const SizedBox(height: 10),
                        _buildProfileItem(Icons.phone, 'Phone', userPhone),
                        const SizedBox(height: 10),
                        _buildProfileItem(Icons.verified_user, 'Role', userRole),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            );
          } else {
            // Show error message if user document doesn't exist
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User data not found. Please try again later.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        })
        .catchError((error) {
          // Close the loading dialog
          Navigator.pop(context);
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching user data: $error'),
              backgroundColor: Colors.red,
            ),
          );
        });
  }

  Widget _buildProfileItem(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppColors.primaryColor),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Colors.grey,
              ),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showSettingsMenu() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Settings'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Notifications'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to notifications settings
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: const Text('Language'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to language settings
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.security),
                  title: const Text('Privacy & Security'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to privacy settings
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Help & Support'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to help & support
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('About'),
                  onTap: () {
                    Navigator.pop(context);
                    // TODO: Navigate to about screen
                  },
                ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Logout', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    Navigator.pop(context);
                    _showLogoutConfirmation();
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Logout'),
          content: const Text('Are you sure you want to logout?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context); // Close the confirmation dialog
                
                // Show loading indicator
                showDialog(
                  context: context,
                  barrierDismissible: false,
                  builder: (BuildContext context) {
                    return const Center(
                      child: CircularProgressIndicator(),
                    );
                  },
                );
                
                try {
                  // Sign out from Firebase Auth
                  await FirebaseAuth.instance.signOut();
                  
                  if (!mounted) return;
                  
                  // Close the loading dialog
                  Navigator.pop(context);
                  
                  // Show success message
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Logged out successfully'),
                      backgroundColor: Colors.green,
                    ),
                  );
                  
                  // Navigate to auth screen and remove all previous routes
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (context) => const AuthScreen()),
                    (route) => false, // This will remove all previous routes
                  );
                } catch (error) {
                  if (!mounted) return;
                  
                  // Close the loading dialog
                  Navigator.pop(context);
                  
                  // Show error message
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error logging out: $error'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );
  }

  void _showRiderRegistrationForm() {
    // Get the current user's UID
    final String? currentUserId = FirebaseAuth.instance.currentUser?.uid;
    
    if (currentUserId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('User not logged in. Please log in again.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }
    
    // Show loading indicator while fetching user data
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return const Center(
          child: CircularProgressIndicator(),
        );
      },
    );
    
    // Fetch user data from Firestore
    FirebaseFirestore.instance
        .collection('users')
        .doc(currentUserId)
        .get()
        .then((DocumentSnapshot documentSnapshot) {
          // Close the loading dialog
          Navigator.pop(context);
          
          if (documentSnapshot.exists) {
            // Extract user data from the document
            final data = documentSnapshot.data() as Map<String, dynamic>;
            final String userName = data['name'] ?? 'Unknown';
            final String userPhone = data['phoneNumber'] ?? 'Unknown';
            
            // Create controllers with the fetched data
            final TextEditingController nameController = TextEditingController(text: userName);
            final TextEditingController phoneController = TextEditingController(text: userPhone);
            final TextEditingController licenseController = TextEditingController();
            final TextEditingController vehicleController = TextEditingController();
            final TextEditingController vehicleNumberController = TextEditingController();
            
            // Show the registration form
            showDialog(
              context: context,
              builder: (BuildContext context) {
                return AlertDialog(
                  title: const Text('Rider Registration'),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Fill out the form below to become a rider. Your application will be reviewed within 24-48 hours.',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            border: OutlineInputBorder(),
                          ),
                          // Name is editable
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: phoneController,
                          decoration: const InputDecoration(
                            labelText: 'Phone Number',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.phone,
                          enabled: false, // Phone number is immutable
                          style: TextStyle(color: Colors.grey[700]), // Style to indicate it's disabled
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: licenseController,
                          decoration: const InputDecoration(
                            labelText: 'Driver\'s License Number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: vehicleController,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Model',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: vehicleNumberController,
                          decoration: const InputDecoration(
                            labelText: 'Vehicle Registration Number',
                            border: OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'You will need to upload your license and vehicle documents after submitting this form.',
                          style: TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      child: const Text('Cancel'),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        // Validate form
                        if (nameController.text.isEmpty ||
                            phoneController.text.isEmpty ||
                            licenseController.text.isEmpty ||
                            vehicleController.text.isEmpty ||
                            vehicleNumberController.text.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please fill all fields'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        
                        // Show loading indicator
                        showDialog(
                          context: context,
                          barrierDismissible: false,
                          builder: (BuildContext context) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          },
                        );
                        
                        // Submit rider registration to Firestore
                        FirebaseFirestore.instance
                            .collection('rider_registrations')
                            .add({
                              'userId': currentUserId,
                              'name': nameController.text,
                              'phoneNumber': phoneController.text,
                              'licenseNumber': licenseController.text,
                              'vehicleModel': vehicleController.text,
                              'vehicleRegistrationNumber': vehicleNumberController.text,
                              'status': 'pending',
                              'createdAt': FieldValue.serverTimestamp(),
                            })
                            .then((_) {
                              // Close the loading dialog
                              Navigator.pop(context);
                              // Close the registration form
                              Navigator.pop(context);
                              
                              // Show success message
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Registration submitted successfully! We will review your application and contact you soon.'),
                                  backgroundColor: Colors.green,
                                  duration: Duration(seconds: 5),
                                ),
                              );
                            })
                            .catchError((error) {
                              // Close the loading dialog
                              Navigator.pop(context);
                              
                              // Show error message
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error submitting registration: $error'),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            });
                      },
                      child: const Text('Submit'),
                    ),
                  ],
                );
              },
            );
          } else {
            // Show error message if user document doesn't exist
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('User data not found. Please try again later.'),
                backgroundColor: Colors.red,
              ),
            );
          }
        })
        .catchError((error) {
          // Close the loading dialog
          Navigator.pop(context);
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error fetching user data: $error'),
              backgroundColor: Colors.red,
            ),
          );
        });
  }

  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    return Geolocator.distanceBetween(lat1, lon1, lat2, lon2);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: null, // Explicitly set appBar to null to ensure it's removed
      extendBodyBehindAppBar: true, // This ensures content extends behind where the app bar would be
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : GoogleMap(
                  mapType: MapType.normal,
                  initialCameraPosition: _defaultLocation,
                  onMapCreated: (GoogleMapController controller) {
                    if (!_controller.isCompleted) {
                      _controller.complete(controller);
                      _mapController = controller;
                    }
                  },
                  markers: _markers,
                  polylines: _polylines,
                  myLocationEnabled: false, // Disable current location blue dot
                  myLocationButtonEnabled: false, // Remove the default location button
                  zoomControlsEnabled: true,
                  compassEnabled: true,
                  onTap: _onMapTapped,
                ),
          
          // Hamburger Menu Button
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            left: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(AppColors.borderRadius),
                boxShadow: AppColors.cardShadow,
              ),
              child: IconButton(
                icon: const Icon(Icons.menu),
                onPressed: _showHamburgerMenu,
              ),
            ),
          ),
          
          // Use Current Location Button with address tooltip
          Positioned(
            top: MediaQuery.of(context).padding.top + 10,
            right: 16,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: BorderRadius.circular(AppColors.borderRadius),
                boxShadow: AppColors.cardShadow,
              ),
              child: Tooltip(
                message: _currentAddress.isNotEmpty 
                    ? 'Current Location:\n$_currentAddress' 
                    : 'Getting current location...',
                preferBelow: false,
                showDuration: const Duration(seconds: 2),
                decoration: BoxDecoration(
                  color: Colors.black87,
                  borderRadius: BorderRadius.circular(8),
                ),
                padding: const EdgeInsets.all(8),
                textStyle: const TextStyle(color: Colors.white, fontSize: 12),
                child: IconButton(
                  icon: const Icon(Icons.my_location),
                  onPressed: () => _useCurrentLocationAsPickup(),
                  tooltip: 'Use current location as pickup',
                ),
              ),
            ),
          ),
          
          // Booking Panel
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle bar
                  Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  
                  // Pickup Location
                  Row(
                    children: [
                      Icon(Icons.location_on, color: AppColors.pickupMarkerColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _pickupController,
                          style: AppTextStyles.inputStyle,
                          decoration: InputDecoration(
                            hintText: 'Pickup Location',
                            hintStyle: AppTextStyles.hintStyle,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onTap: () {
                            setState(() {
                              _isPickupSearching = true;
                              _isDestinationSearching = false;
                            });
                          },
                          onChanged: (value) {
                            _searchLocation(value, true);
                          },
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              _searchLocation(value, true);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.my_location),
                        onPressed: () => _useCurrentLocationAsPickup(),
                        tooltip: 'Use current location',
                        color: AppColors.primaryColor,
                      ),
                    ],
                  ),
                  Divider(color: AppColors.surfaceColor),
                  
                  // Destination Location
                  Row(
                    children: [
                      Icon(Icons.location_on, color: AppColors.destinationMarkerColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: _destinationController,
                          style: AppTextStyles.inputStyle,
                          decoration: InputDecoration(
                            hintText: 'Destination',
                            hintStyle: AppTextStyles.hintStyle,
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(vertical: 8),
                          ),
                          onTap: () {
                            setState(() {
                              _isPickupSearching = false;
                              _isDestinationSearching = true;
                            });
                          },
                          onChanged: (value) {
                            _searchLocation(value, false);
                          },
                          onSubmitted: (value) {
                            if (value.isNotEmpty) {
                              _searchLocation(value, false);
                            }
                          },
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.map),
                        onPressed: () {
                          setState(() {
                            _isPickupSearching = false;
                            _isDestinationSearching = false;
                          });
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Tap on the map to set destination'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        tooltip: 'Set on map',
                        color: AppColors.primaryColor,
                      ),
                      IconButton(
                        icon: const Icon(Icons.place),
                        onPressed: _showPopularPlaces,
                        tooltip: 'Popular places',
                        color: AppColors.primaryColor,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Book Now Button
                  ElevatedButton(
                    onPressed: _destinationLocation == null ? null : () {
                      // TODO: Implement ride booking logic
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Booking ride...')),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: AppColors.lightTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      minimumSize: const Size(double.infinity, 0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.buttonRadius),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Book Now',
                      style: AppTextStyles.buttonTextStyle,
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Search Results
          if (_isPickupSearching || _isDestinationSearching)
            Positioned(
              top: MediaQuery.of(context).padding.top + 70,
              left: 16,
              right: 16,
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.4,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardColor,
                  borderRadius: BorderRadius.circular(AppColors.borderRadius),
                  boxShadow: AppColors.cardShadow,
                ),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        children: [
                          Icon(
                            _isPickupSearching ? Icons.location_on : Icons.location_on,
                            color: _isPickupSearching ? AppColors.pickupMarkerColor : AppColors.destinationMarkerColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _isPickupSearching ? 'Search Pickup Location' : 'Search Destination',
                            style: AppTextStyles.subtitleStyle,
                          ),
                        ],
                      ),
                    ),
                    Divider(color: AppColors.surfaceColor),
                    Expanded(
                      child: _searchResults.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.search,
                                    size: 48,
                                    color: AppColors.surfaceColor,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No results found',
                                    style: AppTextStyles.bodyStyle.copyWith(
                                      color: AppColors.surfaceColor,
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: _searchResults.length,
                              itemBuilder: (context, index) {
                                final result = _searchResults[index];
                                return ListTile(
                                  leading: Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: (_isPickupSearching ? AppColors.pickupMarkerColor : AppColors.destinationMarkerColor)
                                          .withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      _isPickupSearching ? Icons.location_on : Icons.location_on,
                                      color: _isPickupSearching ? AppColors.pickupMarkerColor : AppColors.destinationMarkerColor,
                                    ),
                                  ),
                                  title: Text(
                                    result.formattedAddress,
                                    style: AppTextStyles.bodyStyle,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  subtitle: result.distance > 0
                                      ? Text(
                                          '${(result.distance / 1000).toStringAsFixed(1)} km away',
                                          style: AppTextStyles.captionStyle,
                                        )
                                      : null,
                                  onTap: () {
                                    _selectLocation(result, _isPickupSearching);
                                  },
                                );
                              },
                            ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Modified method to use current location as pickup
  Future<void> _useCurrentLocationAsPickup() async {
    try {
      setState(() {
        _isLoading = true;
      });
      
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      if (!mounted) return;

      final newLocation = LatLng(position.latitude, position.longitude);
      
      // Update pickup location and marker
      setState(() {
        _pickupLocation = newLocation;
        _updateMarkers();
        _isLoading = false;
      });

      // Get address for pickup location
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          setState(() {
            _pickupController.text = '${place.street}, ${place.locality}, ${place.country}';
          });
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }

      // Animate camera to new location
      if (_mapController != null) {
        await _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newLocation,
              zoom: 15.0,
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('Error getting current location: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not get current location. Please try again.'),
          ),
        );
      }
    }
  }

  // Helper method to update markers
  void _updateMarkers() {
    _markers = {};
    
    // Add pickup marker if exists
    if (_pickupLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('pickup'),
          position: _pickupLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
      );
    }
    
    // Add destination marker if exists
    if (_destinationLocation != null) {
      _markers.add(
        Marker(
          markerId: const MarkerId('destination'),
          position: _destinationLocation!,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      );
    }
  }

  // Add this new method to start location updates
  void _startLocationUpdates() async {
    // Request location permission if not already granted
    var permission = await Permission.location.status;
    if (!permission.isGranted) {
      permission = await Permission.location.request();
      if (!permission.isGranted) return;
    }

    // Start listening to location changes
    _locationSubscription = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // Update every 10 meters
      ),
    ).listen((Position position) async {
      if (!mounted) return;

      final newLocation = LatLng(position.latitude, position.longitude);
      _currentLocation = newLocation;

      // Update current address
      try {
        final placemarks = await placemarkFromCoordinates(
          position.latitude,
          position.longitude,
        );
        if (placemarks.isNotEmpty && mounted) {
          final place = placemarks.first;
          setState(() {
            _currentAddress = '${place.street}, ${place.locality}, ${place.country}';
          });
        }
      } catch (e) {
        debugPrint('Error getting address: $e');
      }
    });

    // Set up periodic address updates (every 30 seconds)
    _addressUpdateTimer = Timer.periodic(const Duration(seconds: 30), (timer) async {
      if (_currentLocation != null) {
        try {
          final placemarks = await placemarkFromCoordinates(
            _currentLocation!.latitude,
            _currentLocation!.longitude,
          );
          if (placemarks.isNotEmpty && mounted) {
            final place = placemarks.first;
            setState(() {
              _currentAddress = '${place.street}, ${place.locality}, ${place.country}';
            });
          }
        } catch (e) {
          debugPrint('Error updating address: $e');
        }
      }
    });
  }
}

class _SearchResult {
  final Placemark place;
  final LatLng location;
  final String formattedAddress;
  final double distance;

  _SearchResult({
    required this.place,
    required this.location,
    required this.formattedAddress,
    required this.distance,
  });
}

class _PopularPlace {
  final String name;
  final LatLng location;
  final String category;

  _PopularPlace({
    required this.name,
    required this.location,
    required this.category,
  });
} 