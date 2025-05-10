import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/location_service.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/services/ride_session_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart' as loc;
import 'package:nift_final/services/rating_service.dart';
import 'package:nift_final/widgets/star_rating.dart';
import 'package:nift_final/widgets/chat_button.dart';

class RiderOngoingRideScreen extends StatefulWidget {
  final RideRequest rideRequest;
  final UserModel rider;
  final UserModel passenger;

  const RiderOngoingRideScreen({
    Key? key,
    required this.rideRequest,
    required this.rider,
    required this.passenger,
  }) : super(key: key);

  @override
  State<RiderOngoingRideScreen> createState() => _RiderOngoingRideScreenState();
}

class _RiderOngoingRideScreenState extends State<RiderOngoingRideScreen> {
  final RideService _rideService = RideService();
  final RideSessionService _rideSessionService = RideSessionService();
  final loc.Location _location = loc.Location();
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  StreamSubscription<RideRequest?>? _rideStatusSubscription;
  StreamSubscription<loc.LocationData>? _locationSubscription;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  String _rideStatus = 'accepted';
  String _statusMessage = 'Please pick up your passenger';
  bool _isRideCompleted = false;
  bool _isRatingDialogShown = false;
  
  bool _isUpdatingStatus = false;
  LatLng? _currentLocation;
  
  @override
  void initState() {
    super.initState();
    // Save the active ride session
    _saveRideSession();
    
    _initializeMapMarkers();
    _startListeningToRideStatus();
    _startLocationUpdates();
  }
  
  // Save the active ride session to SharedPreferences
  Future<void> _saveRideSession() async {
    await _rideSessionService.saveActiveRiderRide(
      rideRequest: widget.rideRequest,
      rider: widget.rider,
      passenger: widget.passenger,
    );
  }
  
  @override
  void dispose() {
    _rideStatusSubscription?.cancel();
    _locationSubscription?.cancel();
    super.dispose();
  }
  
  void _initializeMapMarkers() {
    final pickupLocation = LatLng(
      widget.rideRequest.fromLocation.latitude,
      widget.rideRequest.fromLocation.longitude,
    );
    
    final destinationLocation = LatLng(
      widget.rideRequest.toLocation.latitude,
      widget.rideRequest.toLocation.longitude,
    );
    
    setState(() {
      _markers = {
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickupLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
        Marker(
          markerId: const MarkerId('destination'),
          position: destinationLocation,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      };
      
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [pickupLocation, destinationLocation],
          color: AppColors.primaryColor,
          width: 5,
        ),
      };
    });
    
    // Try to get actual route polylines
    _getRoutePolylines(pickupLocation, destinationLocation);
  }
  
  Future<void> _getRoutePolylines(LatLng origin, LatLng destination) async {
    try {
      final points = await LocationService.getRoutePoints(origin, destination);
      
      if (points != null && points.isNotEmpty && mounted) {
        setState(() {
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
              color: AppColors.primaryColor,
              width: 5,
            ),
          };
        });
      }
    } catch (e) {
      debugPrint('Error getting route polylines: $e');
    }
  }
  
  void _startListeningToRideStatus() {
    _rideStatusSubscription = _rideService
        .getRideRequestStream(widget.rideRequest.id)
        .listen(_handleRideStatusUpdate, onError: _handleError);
  }
  
  void _startLocationUpdates() async {
    // Configure location service
    await _location.changeSettings(
      accuracy: loc.LocationAccuracy.high,
      interval: 10000, // Update every 10 seconds
    );
    
    // Request permission
    final hasPermission = await _location.requestPermission();
    if (hasPermission != loc.PermissionStatus.granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Location permission is required for this feature'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
      return;
    }
    
    // Enable location updates in background
    await _location.enableBackgroundMode(enable: true);
    
    // Start location updates
    _location.onLocationChanged.listen((locationData) {
      if (!mounted) return;
      
      final newLocation = LatLng(
        locationData.latitude!,
        locationData.longitude!,
      );
      
      setState(() {
        _currentLocation = newLocation;
        
        // Update current location marker
        _markers = {
          ..._markers.where((marker) => marker.markerId.value != 'current_location'),
          Marker(
            markerId: const MarkerId('current_location'),
            position: newLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: '${widget.rider.name} (You)'),
          ),
        };
      });
      
      // Update rider location in Firestore
      _updateRiderLocation(newLocation);
      
      // Update route polylines based on ride status
      _updateRoutePolylines();
    });
  }
  
  void _updateRiderLocation(LatLng location) {
    _rideService.updateRiderLocation(
      riderId: widget.rider.uid,
      location: location,
    );
  }
  
  void _updateRoutePolylines() {
    if (_currentLocation == null) return;
    
    // Always use the original pickup and destination from the ride request
    final pickupLocation = LatLng(
      widget.rideRequest.fromLocation.latitude,
      widget.rideRequest.fromLocation.longitude,
    );
    
    final destinationLocation = LatLng(
      widget.rideRequest.toLocation.latitude,
      widget.rideRequest.toLocation.longitude,
    );
    
    if (_rideStatus == 'accepted') {
      // Show route from current location to the original pickup point
      _getRoutePolylines(_currentLocation!, pickupLocation);
      
      // Also ensure the pickup marker is visible and at the original location
      setState(() {
        _markers = {
          ..._markers.where((marker) => 
              marker.markerId.value != 'pickup' && 
              marker.markerId.value != 'current_location'),
          Marker(
            markerId: const MarkerId('pickup'),
            position: pickupLocation,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
            infoWindow: const InfoWindow(title: 'Pickup Location'),
          ),
          Marker(
            markerId: const MarkerId('current_location'),
            position: _currentLocation!,
            icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
            infoWindow: InfoWindow(title: '${widget.rider.name} (You)'),
          ),
        };
      });
    } else if (_rideStatus == 'in_progress') {
      // For in_progress rides, maintain the original route from pickup to destination
      // and add a rider location indicator
      _getRouteAndCurrentLocationPolylines(pickupLocation, destinationLocation);
    }
  }
  
  // New method to handle both the fixed route and current location indicator
  Future<void> _getRouteAndCurrentLocationPolylines(LatLng pickup, LatLng destination) async {
    try {
      // Get the fixed route from pickup to destination
      final routePoints = await LocationService.getRoutePoints(pickup, destination);
      
      if (routePoints != null && routePoints.isNotEmpty && mounted) {
        // Create a simple line from current location to nearest point on route
        final LatLng currentLocation = _currentLocation!;
        
        setState(() {
          _polylines = {
            // Main route from pickup to destination
            Polyline(
              polylineId: const PolylineId('route'),
              points: routePoints,
              color: AppColors.primaryColor,
              width: 5,
            ),
            // Current location indicator
            Polyline(
              polylineId: const PolylineId('current_location'),
              points: [currentLocation, findNearestPointOnRoute(currentLocation, routePoints)],
              color: AppColors.accentColor,
              width: 3,
              patterns: [PatternItem.dash(10), PatternItem.gap(5)],
            ),
          };
        });
        
        // Update the rider marker
        setState(() {
          _markers = {
            // Keep existing markers except the rider marker
            ..._markers.where((marker) => marker.markerId.value != 'rider'),
            // Add rider marker at current location
            Marker(
              markerId: const MarkerId('rider'),
              position: currentLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
              infoWindow: const InfoWindow(title: 'Your Location'),
            ),
          };
        });
      }
    } catch (e) {
      debugPrint('Error getting route polylines: $e');
    }
  }
  
  // Helper method to find the nearest point on a route to the current location
  LatLng findNearestPointOnRoute(LatLng currentLocation, List<LatLng> routePoints) {
    LatLng nearestPoint = routePoints.first;
    double minDistance = double.infinity;
    
    for (final point in routePoints) {
      final distance = calculateDistance(currentLocation, point);
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = point;
      }
    }
    
    return nearestPoint;
  }
  
  // Simple distance calculation between two points
  double calculateDistance(LatLng point1, LatLng point2) {
    final double dx = point1.latitude - point2.latitude;
    final double dy = point1.longitude - point2.longitude;
    return dx * dx + dy * dy; // No need for square root for comparison
  }
  
  void _handleRideStatusUpdate(RideRequest? updatedRequest) {
    if (!mounted || updatedRequest == null) return;
    
    final bool wasCompleted = _isRideCompleted;
    final String previousStatus = _rideStatus;
    
    setState(() {
      _rideStatus = updatedRequest.status;
      
      if (updatedRequest.status == 'in_progress') {
        _statusMessage = 'Ride in progress. Drive safely!';
      } else if (updatedRequest.status == 'completed') {
        _statusMessage = 'Ride completed successfully';
        _isRideCompleted = true;
      } else if (updatedRequest.status == 'cancelled') {
        _statusMessage = 'This ride has been cancelled';
        _isRideCompleted = true;
      }
    });
    
    // If ride just became completed/cancelled, clear the session
    if (!wasCompleted && _isRideCompleted) {
      _rideSessionService.clearActiveRiderRide();
    }
    
    // Update polylines based on new status
    _updateRoutePolylines();
    
    if (_isRideCompleted) {
      // Show completed dialog after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted && !_isRatingDialogShown) {
          // Use default price for status updates
          _showRideCompletedDialog(widget.rideRequest.offeredPrice);
        }
      });
    }
  }
  
  void _handleError(dynamic error) {
    debugPrint('Error in ride status subscription: $error');
  }
  
  Future<void> _startRide() async {
    if (_isUpdatingStatus) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      await _rideService.updateRideStatus(
        requestId: widget.rideRequest.id,
        newStatus: 'in_progress',
      );
      
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
        _rideStatus = 'in_progress';
        _statusMessage = 'Ride in progress. Drive safely!';
      });
      
      // Update polylines
      _updateRoutePolylines();
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to start ride: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }
  
  Future<void> _completeRide() async {
    if (_isUpdatingStatus) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      // Calculate final price and factors
      final pickup = LatLng(
        widget.rideRequest.fromLocation.latitude,
        widget.rideRequest.fromLocation.longitude,
      );
      
      final destination = LatLng(
        widget.rideRequest.toLocation.latitude,
        widget.rideRequest.toLocation.longitude,
      );
      
      // Use the offered price as base and adjust based on actual conditions
      double finalPrice = widget.rideRequest.offeredPrice;
      double estimatedDistance = 0;
      
      // Try to get a more accurate final price
      try {
        // If we have our current location as the end point
        if (_currentLocation != null) {
          // Calculate actual route distance
          estimatedDistance = await _calculateActualDistance(pickup, _currentLocation!);
          
          // If the actual distance varies significantly from expected, adjust price
          final expectedDistance = _calculateHaversineDistance(pickup, destination);
          
          // If actual distance is more than 10% greater than expected
          if (estimatedDistance > expectedDistance * 1.1) {
            // Calculate pro-rated increase (maximum 20% increase)
            final ratio = math.min(estimatedDistance / expectedDistance, 1.2);
            finalPrice = finalPrice * ratio;
          }
        }
      } catch (e) {
        debugPrint('Error calculating final price: $e');
        // Fall back to original price
      }
      
      // Round to nearest 10
      finalPrice = (finalPrice / 10.0).round() * 10.0;
      
      // Price factors to save for analytics
      final priceFactors = {
        'initialPrice': widget.rideRequest.offeredPrice,
        'finalPrice': finalPrice,
        'estimatedDistance': estimatedDistance,
        'completionTime': DateTime.now().toIso8601String(),
      };
      
      // Complete the ride with the final price
      await _rideService.completeRide(
        requestId: widget.rideRequest.id,
        finalPrice: finalPrice,
        estimatedDistance: estimatedDistance,
        priceFactors: priceFactors,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
        _rideStatus = 'completed';
        _statusMessage = 'Ride completed successfully';
        _isRideCompleted = true;
      });
      
      // Show completion dialog and mark as shown
      _isRatingDialogShown = true;
      _showRideCompletedDialog(finalPrice);
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to complete ride: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }
  
  // Calculate distance using the Haversine formula
  double _calculateHaversineDistance(LatLng point1, LatLng point2) {
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
                     math.cos(lat1) * 
                     math.cos(lat2);
    final double c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    
    return earthRadius * c; // Distance in kilometers
  }
  
  // Helper functions for Haversine
  double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;
  double _haversine(double value) => (1 - math.cos(value)) / 2;
  
  // Calculate actual route distance based on route points
  Future<double> _calculateActualDistance(LatLng pickup, LatLng endpoint) async {
    try {
      final routePoints = await LocationService.getRoutePoints(pickup, endpoint);
      
      if (routePoints != null && routePoints.isNotEmpty) {
        double totalDistance = 0.0;
        
        for (int i = 0; i < routePoints.length - 1; i++) {
          totalDistance += _calculateHaversineDistance(routePoints[i], routePoints[i + 1]);
        }
        
        return totalDistance;
      }
      
      // Fallback to direct distance
      return _calculateHaversineDistance(pickup, endpoint);
    } catch (e) {
      debugPrint('Error calculating route distance: $e');
      return _calculateHaversineDistance(pickup, endpoint);
    }
  }
  
  void _showRideCompletedDialog(double finalPrice) {
    try {
      // Clear the active ride session
      _rideSessionService.clearActiveRiderRide();
      
      // Mark the dialog as shown
      _isRatingDialogShown = true;
      
      // Only show rating dialog for completed rides, not cancelled ones
      if (_rideStatus == 'completed') {
        _showRatingDialog();
        return;
      }
      
      // For cancelled rides, just show the standard completion dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(
            _rideStatus == 'completed' ? 'Ride Completed' : 'Ride Cancelled',
            style: TextStyle(
              color: _rideStatus == 'completed'
                  ? AppColors.successColor
                  : AppColors.errorColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _rideStatus == 'completed'
                    ? 'You have successfully completed the ride.'
                    : 'The ride has been cancelled.',
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Final Amount:'),
                  Text(
                    'Rs. ${finalPrice.toInt()}',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to previous screen
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      debugPrint('Error showing completion dialog: $e');
    }
  }
  
  void _showRatingDialog() {
    final RatingService _ratingService = RatingService();
    int selectedRating = 0;
    String comment = '';
    bool isSubmitting = false;
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text(
                'Rate Your Passenger',
                style: TextStyle(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'How was your experience with this passenger?',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Passenger info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.surfaceColor,
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.passenger.name ?? 'Passenger',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                'Trip Total: Rs. ${widget.rideRequest.offeredPrice.toInt()}',
                                style: AppTextStyles.captionStyle,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Star rating input
                    StarRatingInput(
                      onRatingChanged: (rating) {
                        setState(() {
                          selectedRating = rating;
                        });
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Comment field
                    TextField(
                      decoration: const InputDecoration(
                        hintText: 'Add a comment (optional)',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 2,
                      onChanged: (value) {
                        comment = value;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isSubmitting 
                      ? null 
                      : () {
                          // Skip rating
                          Navigator.of(context).pop();
                          Navigator.of(context).pop(); // Go back to previous screen
                        },
                  child: const Text('Skip'),
                ),
                ElevatedButton(
                  onPressed: isSubmitting || selectedRating == 0
                      ? null
                      : () async {
                          setState(() {
                            isSubmitting = true;
                          });
                          
                          try {
                            await _ratingService.rateUser(
                              userId: widget.passenger.uid,
                              raterId: widget.rider.uid,
                              rideId: widget.rideRequest.id,
                              rating: selectedRating,
                              comment: comment.isNotEmpty ? comment : null,
                            );
                            
                            if (!mounted) return;
                            
                            Navigator.of(context).pop();
                            
                            // Show thank you confirmation
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Thank you for your rating!'),
                                backgroundColor: AppColors.successColor,
                              ),
                            );
                            
                            Navigator.of(context).pop(); // Go back to previous screen
                          } catch (e) {
                            if (!mounted) return;
                            
                            setState(() {
                              isSubmitting = false;
                            });
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error submitting rating: $e'),
                                backgroundColor: AppColors.errorColor,
                              ),
                            );
                          }
                        },
                  child: const Text('Submit Rating'),
                ),
              ],
            );
          }
        );
      },
    );
  }
  
  Future<void> _cancelRide() async {
    if (_isUpdatingStatus) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      await _rideService.updateRideStatus(
        requestId: widget.rideRequest.id,
        newStatus: 'cancelled',
      );
      
      // Clear the active ride session
      await _rideSessionService.clearActiveRiderRide();
      
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
        _rideStatus = 'cancelled';
        _statusMessage = 'Ride cancelled';
        _isRideCompleted = true;
      });
      
      // Show cancellation dialog with original price
      _showRideCompletedDialog(widget.rideRequest.offeredPrice);
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel ride: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }
  
  Future<void> _callPassenger() async {
    final phoneNumber = 'tel:${widget.passenger.phoneNumber}';
    if (await canLaunch(phoneNumber)) {
      await launch(phoneNumber);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch phone dialer'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }
  
  Future<void> _navigateToLocation(bool isDestination) async {
    final lat = isDestination 
        ? widget.rideRequest.toLocation.latitude 
        : widget.rideRequest.fromLocation.latitude;
    final lng = isDestination 
        ? widget.rideRequest.toLocation.longitude 
        : widget.rideRequest.fromLocation.longitude;
    
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng&travelmode=driving';
    
    if (await canLaunch(url)) {
      await launch(url);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not launch maps application'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }
  
  void _showCancelConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Ride?'),
        content: const Text(
          'Are you sure you want to cancel this ride? This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _cancelRide();
            },
            child: const Text('Yes, Cancel'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button during active ride
        if (!_isRideCompleted && _rideStatus != 'cancelled') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('You cannot go back during an active ride.'),
            ),
          );
          return false;
        }
        return true;
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Ongoing Ride'),
          automaticallyImplyLeading: _isRideCompleted || _rideStatus == 'cancelled',
        ),
        body: Column(
          children: [
            // Status banner
            Container(
              padding: const EdgeInsets.all(16),
              color: _getStatusColor(),
              child: Row(
                children: [
                  Icon(
                    _getStatusIcon(),
                    color: Colors.white,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Map view
            Expanded(
              child: Stack(
                children: [
                  GoogleMap(
                    initialCameraPosition: CameraPosition(
                      target: LatLng(
                        widget.rideRequest.fromLocation.latitude,
                        widget.rideRequest.fromLocation.longitude,
                      ),
                      zoom: 14,
                    ),
                    onMapCreated: (controller) {
                      _mapController.complete(controller);
                    },
                    markers: _markers,
                    polylines: _polylines,
                    myLocationEnabled: true,
                    myLocationButtonEnabled: true,
                    zoomControlsEnabled: true,
                    mapToolbarEnabled: false,
                  ),
                  
                  // Navigation buttons
                  Positioned(
                    top: 16,
                    right: 16,
                    child: Column(
                      children: [
                        FloatingActionButton(
                          heroTag: 'navigate_pickup',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.pickupMarkerColor,
                          mini: true,
                          child: const Icon(Icons.directions),
                          onPressed: () => _navigateToLocation(false),
                          tooltip: 'Navigate to pickup',
                        ),
                        const SizedBox(height: 8),
                        FloatingActionButton(
                          heroTag: 'navigate_destination',
                          backgroundColor: Colors.white,
                          foregroundColor: AppColors.destinationMarkerColor,
                          mini: true,
                          child: const Icon(Icons.flag),
                          onPressed: () => _navigateToLocation(true),
                          tooltip: 'Navigate to destination',
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            // Passenger info panel
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Passenger info
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.surfaceColor,
                        radius: 30,
                        child: Icon(
                          Icons.person,
                          size: 30,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.passenger.name ?? 'Your Passenger',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Phone: ${widget.passenger.phoneNumber}',
                              style: TextStyle(
                                color: AppColors.secondaryTextColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.phone),
                        color: AppColors.primaryColor,
                        onPressed: _callPassenger,
                        tooltip: 'Call Passenger',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Ride details
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.attach_money,
                              size: 20,
                              color: AppColors.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Ride Price: Rs. ${widget.rideRequest.offeredPrice.toInt()}',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(
                              Icons.location_on,
                              size: 20,
                              color: AppColors.pickupMarkerColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Pickup: ${widget.rideRequest.fromAddress}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(
                              Icons.flag,
                              size: 20,
                              color: AppColors.destinationMarkerColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Destination: ${widget.rideRequest.toAddress}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action buttons
                  if (!_isRideCompleted && _rideStatus != 'cancelled')
                    Row(
                      children: [
                        // Cancel button
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: const Icon(Icons.cancel),
                            label: const Text('Cancel'),
                            onPressed: _isUpdatingStatus
                                ? null
                                : _showCancelConfirmationDialog,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.errorColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical:
                                12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Start/Complete ride button
                        Expanded(
                          child: ElevatedButton.icon(
                            icon: Icon(_rideStatus == 'accepted'
                                ? Icons.play_arrow
                                : Icons.check_circle),
                            label: Text(_rideStatus == 'accepted'
                                ? 'Start Ride'
                                : 'Complete'),
                            onPressed: _isUpdatingStatus
                                ? null
                                : (_rideStatus == 'accepted'
                                    ? _startRide
                                    : _completeRide),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _rideStatus == 'accepted'
                                  ? AppColors.primaryColor
                                  : AppColors.successColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
        floatingActionButton: ChatButton(
          rideRequest: widget.rideRequest,
          currentUser: widget.rider,
          otherUser: widget.passenger,
        ),
      ),
    );
  }
  
  Color _getStatusColor() {
    switch (_rideStatus) {
      case 'accepted':
        return AppColors.primaryColor;
      case 'in_progress':
        return AppColors.accentColor;
      case 'completed':
        return AppColors.successColor;
      case 'cancelled':
        return AppColors.errorColor;
      default:
        return AppColors.primaryColor;
    }
  }
  
  IconData _getStatusIcon() {
    switch (_rideStatus) {
      case 'accepted':
        return Icons.access_time;
      case 'in_progress':
        return Icons.directions_car;
      case 'completed':
        return Icons.check_circle;
      case 'cancelled':
        return Icons.cancel;
      default:
        return Icons.info;
    }
  }

  Future<void> _acceptRide() async {
    if (_isUpdatingStatus) return;
    
    setState(() {
      _isUpdatingStatus = true;
    });
    
    try {
      await _rideService.acceptRideRequest(
        requestId: widget.rideRequest.id,
        riderId: widget.rider.uid,
        riderName: widget.rider.name ?? 'Unknown',
        riderPhone: widget.rider.phoneNumber,
      );
      
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
        _rideStatus = 'accepted';
        _statusMessage = 'You have accepted the ride. Head to pickup point.';
      });
      
      // Update polylines after accepting
      _updateRoutePolylines();
      
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to accept ride: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }
} 