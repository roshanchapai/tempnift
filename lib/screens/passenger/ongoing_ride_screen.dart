import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/location_service.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';

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

class _PassengerOngoingRideScreenState extends State<PassengerOngoingRideScreen> {
  final RideService _rideService = RideService();
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  StreamSubscription<RideRequest?>? _rideStatusSubscription;
  StreamSubscription<LatLng?>? _riderLocationSubscription;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  String _rideStatus = 'accepted';
  String _statusMessage = 'Your rider is on the way';
  bool _isRideCompleted = false;
  
  LatLng? _riderLocation;
  
  @override
  void initState() {
    super.initState();
    _initializeMapMarkers();
    _startListeningToRideStatus();
    _startListeningToRiderLocation();
  }
  
  @override
  void dispose() {
    _rideStatusSubscription?.cancel();
    _riderLocationSubscription?.cancel();
    super.dispose();
  }
  
  void _initializeMapMarkers() {
    final fromLocation = LatLng(
      widget.rideRequest.fromLocation.latitude,
      widget.rideRequest.fromLocation.longitude,
    );
    
    final toLocation = LatLng(
      widget.rideRequest.toLocation.latitude,
      widget.rideRequest.toLocation.longitude,
    );
    
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
      
      // Initial polyline from pickup to destination
      _polylines = {
        Polyline(
          polylineId: const PolylineId('route'),
          points: [fromLocation, toLocation],
          color: AppColors.primaryColor,
          width: 5,
        ),
      };
    });
    
    // Try to get actual route polylines
    _getRoutePolyline(fromLocation, toLocation);
  }
  
  Future<void> _getRoutePolyline(LatLng origin, LatLng destination) async {
    try {
      // This depends on your implementation for getting route polylines
      // You can use the Google Directions API or another service
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
    }
  }
  
  void _startListeningToRideStatus() {
    _rideStatusSubscription = _rideService
        .getRideRequestStream(widget.rideRequest.id)
        .listen(_handleRideStatusUpdate, onError: _handleError);
  }
  
  void _startListeningToRiderLocation() {
    _riderLocationSubscription = _rideService
        .getRiderLocationStream(widget.rider.uid)
        .listen(_handleRiderLocationUpdate, onError: (e) {
          debugPrint('Error getting rider location: $e');
        });
  }
  
  void _handleRideStatusUpdate(RideRequest? updatedRequest) {
    if (!mounted || updatedRequest == null) return;
    
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
  }
  
  void _handleRiderLocationUpdate(LatLng? location) {
    if (!mounted || location == null) return;
    
    // Define original pickup and destination locations from the ride request
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
      
      // Update markers - ensure we keep the original pickup and destination markers
      _markers = {
        // Keep all markers except rider
        ..._markers.where((marker) => marker.markerId.value != 'rider'),
        
        // Add rider marker
        Marker(
          markerId: const MarkerId('rider'),
          position: location,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure),
          infoWindow: InfoWindow(title: '${widget.rider.name} (Your Rider)'),
        ),
        
        // Ensure pickup marker stays at the original location
        Marker(
          markerId: const MarkerId('pickup'),
          position: pickup,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen),
          infoWindow: const InfoWindow(title: 'Pickup Location'),
        ),
        
        // Ensure destination marker stays at the original location
        Marker(
          markerId: const MarkerId('destination'),
          position: destination,
          icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed),
          infoWindow: const InfoWindow(title: 'Destination'),
        ),
      };
      
      // Handle different ride statuses
      if (_rideStatus == 'in_progress') {
        // For rides in progress, show the original route with a rider indicator
        _updatePolylineWithRiderLocation(pickup, destination, location);
      }
      else if (_rideStatus == 'accepted') {
        // For accepted rides, show route from rider to pickup
        // but maintain the original pickup location
        _polylines = {
          // Show route from rider to pickup
          Polyline(
            polylineId: const PolylineId('rider_route'),
            points: [location, pickup],
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
        
        // Get the actual route from rider to pickup
        _getRoutePolyline(location, pickup);
      }
    });
    
    // Center map on rider's location
    _animateCameraToRider();
  }
  
  Future<void> _animateCameraToRider() async {
    if (_riderLocation == null || !_mapController.isCompleted) return;
    
    final controller = await _mapController.future;
    controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: _riderLocation!,
          zoom: 15,
        ),
      ),
    );
  }
  
  void _handleError(dynamic error) {
    debugPrint('Error in ride status stream: $error');
  }
  
  Future<void> _callRider() async {
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
  }
  
  void _showRideCompletedDialog() {
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
                },
                markers: _markers,
                polylines: _polylines,
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                zoomControlsEnabled: true,
                mapToolbarEnabled: false,
              ),
            ),
            
            // Rider info panel
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
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel ride: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }
  
  // New method to update polylines while maintaining the original route
  Future<void> _updatePolylineWithRiderLocation(LatLng pickup, LatLng destination, LatLng riderLocation) async {
    try {
      // Get the actual route from pickup to destination
      final points = await LocationService.getRoutePoints(pickup, destination);
      
      if (points != null && points.isNotEmpty && mounted) {
        // Find the nearest point on the route to the rider's current location
        final LatLng nearestPoint = _findNearestPointOnRoute(riderLocation, points);
        
        setState(() {
          _polylines = {
            // Main route from pickup to destination
            Polyline(
              polylineId: const PolylineId('route'),
              points: points,
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
  
  // Helper to find the nearest point on a route to the rider's location
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