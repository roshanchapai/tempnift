import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/location_service.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:location/location.dart' as loc;

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
  final loc.Location _location = loc.Location();
  final Completer<GoogleMapController> _mapController = Completer<GoogleMapController>();
  
  StreamSubscription<RideRequest?>? _rideStatusSubscription;
  StreamSubscription<loc.LocationData>? _locationSubscription;
  
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  
  String _rideStatus = 'accepted';
  String _statusMessage = 'Please pick up your passenger';
  bool _isRideCompleted = false;
  
  bool _isUpdatingStatus = false;
  LatLng? _currentLocation;
  
  @override
  void initState() {
    super.initState();
    _initializeMapMarkers();
    _startListeningToRideStatus();
    _startLocationUpdates();
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
    
    if (_rideStatus == 'accepted') {
      // Draw route from current location to pickup point
      final pickupLocation = LatLng(
        widget.rideRequest.fromLocation.latitude,
        widget.rideRequest.fromLocation.longitude,
      );
      
      _getRoutePolylines(_currentLocation!, pickupLocation);
    } else if (_rideStatus == 'in_progress') {
      // Draw route from current location to destination
      final destinationLocation = LatLng(
        widget.rideRequest.toLocation.latitude,
        widget.rideRequest.toLocation.longitude,
      );
      
      _getRoutePolylines(_currentLocation!, destinationLocation);
    }
  }
  
  void _handleRideStatusUpdate(RideRequest? updatedRequest) {
    if (!mounted || updatedRequest == null) return;
    
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
    
    // Update polylines based on new status
    _updateRoutePolylines();
    
    if (_isRideCompleted) {
      // Show completed dialog after a short delay
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _showRideCompletedDialog();
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
      await _rideService.updateRideStatus(
        requestId: widget.rideRequest.id,
        newStatus: 'completed',
      );
      
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
        _rideStatus = 'completed';
        _statusMessage = 'Ride completed successfully';
        _isRideCompleted = true;
      });
      
      // Show completion dialog
      _showRideCompletedDialog();
      
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
      
      if (!mounted) return;
      
      setState(() {
        _isUpdatingStatus = false;
        _rideStatus = 'cancelled';
        _statusMessage = 'Ride cancelled';
        _isRideCompleted = true;
      });
      
      // Show cancellation dialog
      _showRideCompletedDialog();
      
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
              ? 'You have successfully completed this ride. Thank you!'
              : 'This ride has been cancelled.',
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
} 