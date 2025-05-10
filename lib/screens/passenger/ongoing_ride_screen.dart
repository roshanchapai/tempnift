import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/location_service.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';
import 'package:nift_final/services/rating_service.dart';
import 'package:nift_final/widgets/star_rating.dart';

class PassengerOngoingRideScreen extends StatefulWidget {
  final RideRequest rideRequest;
  final UserModel passenger;
  final UserModel rider;

  const PassengerOngoingRideScreen({
    Key? key,
    required this.rideRequest,
    required this.passenger,
    required this.rider,
  }) : super(key: key);

  @override
  State<PassengerOngoingRideScreen> createState() => _PassengerOngoingRideScreenState();
}

class _PassengerOngoingRideScreenState extends State<PassengerOngoingRideScreen> with WidgetsBindingObserver {
  final RideService _rideService = RideService();
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  StreamSubscription<RideRequest?>? _rideStatusSubscription;
  StreamSubscription<LatLng?>? _riderLocationSubscription;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  String _rideStatus = 'accepted';
  String _statusMessage = 'Your rider is on the way';
  bool _isRideCompleted = false;
  bool _isMapLoaded = false;
  
  LatLng? _riderLocation;
  
  // Throttle location updates
  DateTime _lastLocationUpdate = DateTime.now();
  static const _locationUpdateThreshold = Duration(seconds: 3);
  bool _isProcessingRouteUpdate = false;
  GoogleMapController? _mapControllerInstance;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Defer map initialization slightly
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _initializeMapMarkers();
        _startListeningToRideStatus();
        _startListeningToRiderLocation();
      }
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Handle app background/foreground transitions
    if (state == AppLifecycleState.resumed) {
      _resumeMap();
    } else if (state == AppLifecycleState.paused) {
      _pauseMap();
    }
  }
  
  Future<void> _resumeMap() async {
    if (_mapControllerInstance != null) {
      try {
        await _mapControllerInstance!.setMapStyle(null);
      } catch (e) {
        debugPrint('Error resuming map: $e');
      }
    }
  }
  
  Future<void> _pauseMap() async {
    if (_mapControllerInstance != null) {
      try {
        // Release resources by applying empty style
        const emptyStyle = '[]';
        await _mapControllerInstance!.setMapStyle(emptyStyle);
      } catch (e) {
        debugPrint('Error pausing map: $e');
      }
    }
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _rideStatusSubscription?.cancel();
    _riderLocationSubscription?.cancel();
    
    // Dispose map controller
    if (_mapControllerInstance != null) {
      _pauseMap();
    }
    
    super.dispose();
  }
  
  void _initializeMapMarkers() {
    try {
      final fromLocation = LatLng(
        widget.rideRequest.fromLocation.latitude,
        widget.rideRequest.fromLocation.longitude,
      );
      
      final toLocation = LatLng(
        widget.rideRequest.toLocation.latitude,
        widget.rideRequest.toLocation.longitude,
      );
      
      if (mounted) {
        setState(() {
          _markers = {
            Marker(
              markerId: const MarkerId('pickup'),
              position: fromLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
              infoWindow: const InfoWindow(title: 'Pickup Location'),
            ),
            Marker(
              markerId: const MarkerId('destination'),
              position: toLocation,
              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
              infoWindow: const InfoWindow(title: 'Destination'),
            ),
          };
          
          // Initial polyline from pickup to destination (simplified, direct line)
          _polylines = {
            Polyline(
              polylineId: const PolylineId('route'),
              points: [fromLocation, toLocation],
              color: AppColors.primaryColor,
              width: 5,
            ),
          };
        });
      }
      
      // Fetch route polyline on a slight delay to avoid UI blocking
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          _getRoutePolyline(fromLocation, toLocation);
        }
      });
    } catch (e) {
      debugPrint('Error initializing map markers: $e');
    }
  }
  
  Future<void> _getRoutePolyline(LatLng origin, LatLng destination) async {
    if (_isProcessingRouteUpdate) return;
    
    _isProcessingRouteUpdate = true;
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
      debugPrint('Error getting route: $e');
    } finally {
      _isProcessingRouteUpdate = false;
    }
  }
  
  void _startListeningToRideStatus() {
    try {
      _rideStatusSubscription = _rideService
          .getRideRequestStream(widget.rideRequest.id)
          .listen(_handleRideStatusUpdate, onError: _handleError);
    } catch (e) {
      debugPrint('Error starting ride status stream: $e');
    }
  }
  
  void _startListeningToRiderLocation() {
    try {
      _riderLocationSubscription = _rideService
          .getRiderLocationStream(widget.rider.uid)
          .listen(_handleRiderLocationUpdate, onError: (e) {
            debugPrint('Error getting rider location: $e');
          });
    } catch (e) {
      debugPrint('Error starting rider location stream: $e');
    }
  }
  
  void _handleRideStatusUpdate(RideRequest? updatedRequest) {
    if (!mounted || updatedRequest == null) return;
    
    try {
      setState(() {
        _rideStatus = updatedRequest.status;
        
        if (updatedRequest.status == 'in_progress') {
          _statusMessage = 'Your ride is in progress';
        } else if (updatedRequest.status == 'completed') {
          _statusMessage = 'Your ride has been completed';
          _isRideCompleted = true;
        } else if (updatedRequest.status == 'cancelled') {
          _statusMessage = 'Your ride has been cancelled';
          _isRideCompleted = true;
        }
      });
      
      if (_isRideCompleted) {
        // Show completed dialog after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            _showRideCompletedDialog();
          }
        });
      }
    } catch (e) {
      debugPrint('Error handling ride status update: $e');
    }
  }
  
  void _handleRiderLocationUpdate(LatLng? location) {
    if (!mounted || location == null) return;
    
    // Throttle location updates to reduce UI workload
    final now = DateTime.now();
    if (now.difference(_lastLocationUpdate) < _locationUpdateThreshold && _riderLocation != null) {
      return;
    }
    _lastLocationUpdate = now;
    
    try {
      // Define original pickup and destination locations
      final pickup = LatLng(
        widget.rideRequest.fromLocation.latitude,
        widget.rideRequest.fromLocation.longitude,
      );
      
      final destination = LatLng(
        widget.rideRequest.toLocation.latitude,
        widget.rideRequest.toLocation.longitude,
      );
      
      setState(() {
        _riderLocation = location;
        
        // Update only the rider marker to reduce setState work
        _updateRiderMarker(location, pickup, destination);
      });
      
      // Handle route updates outside of setState to minimize UI blocking
      _updateRouteBasedOnStatus(pickup, destination, location);
      
      // Only animate camera at certain intervals to avoid excessive map movements
      if (_isMapLoaded) {
        _animateCameraToRider();
      }
    } catch (e) {
      debugPrint('Error updating rider location: $e');
    }
  }
  
  void _updateRiderMarker(LatLng location, LatLng pickup, LatLng destination) {
    // More efficient marker update - only change the rider marker
    final riderMarker = Marker(
      markerId: const MarkerId('rider'),
      position: location,
      icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
      infoWindow: InfoWindow(title: '${widget.rider.name} (Your Rider)'),
    );
    
    // Remove existing rider marker if present
    _markers.removeWhere((marker) => marker.markerId.value == 'rider');
    _markers.add(riderMarker);
    
    // Ensure pickup and destination markers are present
    if (!_markers.any((marker) => marker.markerId.value == 'pickup')) {
      _markers.add(Marker(
        markerId: const MarkerId('pickup'),
        position: pickup,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
        infoWindow: const InfoWindow(title: 'Pickup Location'),
      ));
    }
    
    if (!_markers.any((marker) => marker.markerId.value == 'destination')) {
      _markers.add(Marker(
        markerId: const MarkerId('destination'),
        position: destination,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
        infoWindow: const InfoWindow(title: 'Destination'),
      ));
    }
  }
  
  Future<void> _updateRouteBasedOnStatus(LatLng pickup, LatLng destination, LatLng riderLocation) async {
    // Skip if we're already processing a route update to prevent overload
    if (_isProcessingRouteUpdate) return;
    
    _isProcessingRouteUpdate = true;
    try {
      if (_rideStatus == 'in_progress') {
        // For rides in progress, use a simplified approach to reduce computation
        if (mounted) {
          setState(() {
            _polylines = {
              // Main route from pickup to destination
              Polyline(
                polylineId: const PolylineId('route'),
                points: [pickup, destination],
                color: AppColors.primaryColor,
                width: 5,
              ),
              // Line from rider to pickup (simplified)
              Polyline(
                polylineId: const PolylineId('rider_indicator'),
                points: [riderLocation, pickup],
                color: AppColors.accentColor,
                width: 3,
                patterns: [PatternItem.dash(10), PatternItem.gap(5)],
              ),
            };
          });
        }
        
        // Get actual route details less frequently (every few updates)
        if (DateTime.now().second % 10 == 0) {
          _updatePolylineWithRiderLocation(pickup, destination, riderLocation);
        }
      }
      else if (_rideStatus == 'accepted') {
        // Simple direct lines for accepted state
        if (mounted) {
          setState(() {
            _polylines = {
              // Show route from rider to pickup
              Polyline(
                polylineId: const PolylineId('rider_route'),
                points: [riderLocation, pickup],
                color: AppColors.accentColor,
                width: 5,
              ),
              // Show the future route from pickup to destination
              Polyline(
                polylineId: const PolylineId('destination_route'),
                points: [pickup, destination],
                color: AppColors.primaryColor,
                width: 5,
                patterns: [PatternItem.dash(10), PatternItem.gap(5)],
              ),
            };
          });
        }
        
        // Less frequent route updates to reduce API calls
        if (DateTime.now().second % 15 == 0) {
          _getRoutePolyline(riderLocation, pickup);
        }
      }
    } catch (e) {
      debugPrint('Error updating route: $e');
    } finally {
      _isProcessingRouteUpdate = false;
    }
  }
  
  Future<void> _animateCameraToRider() async {
    if (_riderLocation == null || !_mapController.isCompleted) return;
    
    try {
      final controller = await _mapController.future;
      controller.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: _riderLocation!,
            zoom: 15,
          ),
        ),
      );
    } catch (e) {
      debugPrint('Error animating camera: $e');
    }
  }
  
  void _handleError(dynamic error) {
    debugPrint('Error in ride status stream: $error');
    
    // Attempt to restart streams if they fail
    if (_rideStatusSubscription == null || _riderLocationSubscription == null) {
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          if (_rideStatusSubscription == null) _startListeningToRideStatus();
          if (_riderLocationSubscription == null) _startListeningToRiderLocation();
        }
      });
    }
  }
  
  Future<void> _callRider() async {
    try {
      final phoneNumber = 'tel:${widget.rider.phoneNumber}';
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
    } catch (e) {
      debugPrint('Error calling rider: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to call rider: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }
  
  void _showRideCompletedDialog() {
    try {
      // Only show rating dialog for completed rides, not cancelled ones
      if (_rideStatus == 'completed') {
        _showRatingDialog();
        return;
      }
      
      // For cancelled rides, show the standard completion dialog
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
            ),
          ),
          content: Text(
            _rideStatus == 'completed'
                ? 'Your ride has been completed successfully. Thank you for using our service!'
                : 'Your ride has been cancelled. We apologize for any inconvenience.',
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
                'Rate Your Rider',
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
                      'How was your experience with this rider?',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    
                    // Rider info
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.surfaceColor,
                          child: const Icon(
                            Icons.directions_car,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                widget.rider.name ?? 'Rider',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (widget.rideRequest.finalPrice != null)
                                Text(
                                  'Trip Total: Rs. ${widget.rideRequest.finalPrice!.toInt()}',
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
                              userId: widget.rider.uid,
                              raterId: widget.passenger.uid,
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

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button after ride is in progress
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
                  Text(
                    _statusMessage,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            
            // Map view
            Expanded(
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(
                    widget.rideRequest.fromLocation.latitude,
                    widget.rideRequest.fromLocation.longitude,
                  ),
                  zoom: 14,
                ),
                onMapCreated: (controller) {
                  _mapController.complete(controller);
                  _mapControllerInstance = controller;
                  _isMapLoaded = true;
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
                compassEnabled: true,
                // Reduce map features to improve performance
                buildingsEnabled: false,
                indoorViewEnabled: false,
                trafficEnabled: false,
                mapType: MapType.normal,
                liteModeEnabled: false, // Consider setting to true for even better performance
              ),
            ),
            
            // Rider info panel - Use RepaintBoundary to improve performance
            RepaintBoundary(
              child: Container(
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
                    // Rider info
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
                                widget.rider.name ?? 'Your Rider',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Phone: ${widget.rider.phoneNumber}',
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
                          onPressed: _callRider,
                          tooltip: 'Call Rider',
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
                                  'From: ${widget.rideRequest.fromAddress}',
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
                                  'To: ${widget.rideRequest.toAddress}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Cancel button (only show if ride is not completed or already cancelled)
                    if (!_isRideCompleted && _rideStatus != 'cancelled') ...[
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _showCancelConfirmationDialog(),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.errorColor,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text(
                            'Cancel Ride',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
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
  
  void _showCancelConfirmationDialog() {
    try {
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
    } catch (e) {
      debugPrint('Error showing cancel dialog: $e');
    }
  }
  
  Future<void> _cancelRide() async {
    try {
      await _rideService.cancelRideRequest(widget.rideRequest.id);
      
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ride cancelled successfully'),
          backgroundColor: AppColors.successColor,
        ),
      );
    } catch (e) {
      debugPrint('Error cancelling ride: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel ride: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }
  
  // Optimized method to update polylines - less frequent and more efficient
  Future<void> _updatePolylineWithRiderLocation(LatLng pickup, LatLng destination, LatLng riderLocation) async {
    try {
      // Get route points but with a simpler implementation to avoid excessive API calls
      List<LatLng>? points;
      
      // Check if we already have polyline points to reuse
      final existingPolyline = _polylines.firstWhere(
        (polyline) => polyline.polylineId.value == 'route',
        orElse: () => Polyline(polylineId: const PolylineId('route'), points: []),
      );
      
      if (existingPolyline.points.length > 2) {
        // Reuse existing points
        points = existingPolyline.points;
      } else {
        // Only fetch new points if we don't have good ones already
        points = await LocationService.getRoutePoints(pickup, destination);
      }
      
      if (points != null && points.isNotEmpty && mounted) {
        // Find the nearest point on the route with an optimized algorithm for fewer calculations
        final LatLng nearestPoint = _findNearestPointOnRouteSampled(riderLocation, points);
        
        setState(() {
          _polylines = {
            // Main route from pickup to destination
            Polyline(
              polylineId: const PolylineId('route'),
              points: points!,
              color: AppColors.primaryColor,
              width: 5,
            ),
            // Line from rider to the nearest point on route
            Polyline(
              polylineId: const PolylineId('rider_indicator'),
              points: [riderLocation, nearestPoint],
              color: AppColors.accentColor,
              width: 3,
              patterns: [PatternItem.dash(10), PatternItem.gap(5)],
            ),
          };
        });
      }
    } catch (e) {
      debugPrint('Error updating polyline: $e');
    }
  }
  
  // More efficient nearest point calculation that samples points
  LatLng _findNearestPointOnRouteSampled(LatLng point, List<LatLng> routePoints) {
    // Skip points to reduce computation (check every 3rd point)
    LatLng nearestPoint = routePoints.first;
    double minDistance = double.infinity;
    
    for (int i = 0; i < routePoints.length; i += 3) {
      if (i >= routePoints.length) break;
      
      final routePoint = routePoints[i];
      final double dx = point.latitude - routePoint.latitude;
      final double dy = point.longitude - routePoint.longitude;
      final double distance = dx * dx + dy * dy; // Squared distance is fine for comparison
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = routePoint;
      }
    }
    
    return nearestPoint;
  }
  
  // Original helper retained for compatibility but not used
  LatLng _findNearestPointOnRoute(LatLng point, List<LatLng> routePoints) {
    LatLng nearestPoint = routePoints.first;
    double minDistance = double.infinity;
    
    for (final routePoint in routePoints) {
      final double dx = point.latitude - routePoint.latitude;
      final double dy = point.longitude - routePoint.longitude;
      final double distance = dx * dx + dy * dy;
      
      if (distance < minDistance) {
        minDistance = distance;
        nearestPoint = routePoint;
      }
    }
    
    return nearestPoint;
  }
} 