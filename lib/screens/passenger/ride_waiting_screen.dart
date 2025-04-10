import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/passenger/ongoing_ride_screen.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:lottie/lottie.dart';
import 'package:nift_final/screens/map_screen.dart';
import 'package:nift_final/screens/home_screen.dart';
import 'package:nift_final/widgets/nift_logo.dart';

class RideWaitingScreen extends StatefulWidget {
  final RideRequest rideRequest;
  final UserModel passenger;

  const RideWaitingScreen({
    Key? key,
    required this.rideRequest,
    required this.passenger,
  }) : super(key: key);

  @override
  State<RideWaitingScreen> createState() => _RideWaitingScreenState();
}

class _RideWaitingScreenState extends State<RideWaitingScreen> with SingleTickerProviderStateMixin {
  final RideService _rideService = RideService();
  StreamSubscription<RideRequest?>? _rideStatusSubscription;
  bool _isLoading = false;
  late AnimationController _animationController;
  late Animation<Offset> _carAnimation;
  late Animation<double> _roadMarkingAnimation;
  late Animation<double> _scaleAnimation;
  late Animation<Color?> _skyColorAnimation;
  String _statusMessage = 'Waiting for a rider to accept your request...';
  String? _acceptedRiderId;
  UserModel? _acceptedRider;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: false);
    
    // Car movement animation
    _carAnimation = Tween<Offset>(
      begin: const Offset(-0.2, 0),
      end: const Offset(0.2, 0),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Road marking animation
    _roadMarkingAnimation = Tween<double>(
      begin: -300,
      end: MediaQuery.of(context).size.width,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));
    
    // Car bounce animation
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.0, end: 1.05)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.05, end: 1.0)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 50,
      ),
    ]).animate(_animationController);
    
    // Sky color animation for day-night cycle effect
    _skyColorAnimation = ColorTween(
      begin: AppColors.primaryColor.withOpacity(0.1),
      end: AppColors.primaryColor.withOpacity(0.3),
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    _startListeningToRideStatus();
  }
  
  @override
  void dispose() {
    _rideStatusSubscription?.cancel();
    _animationController.dispose();
    super.dispose();
  }
  
  void _startListeningToRideStatus() {
    _rideStatusSubscription = _rideService
        .getRideRequestStream(widget.rideRequest.id)
        .listen(_handleRideStatusUpdate, onError: _handleError);
  }
  
  void _handleRideStatusUpdate(RideRequest? updatedRequest) {
    if (!mounted) return;
    
    if (updatedRequest == null) {
      setState(() {
        _statusMessage = 'Ride request not found. It may have been cancelled.';
      });
      return;
    }
    
    if (updatedRequest.status == 'accepted' && updatedRequest.acceptedBy != null) {
      setState(() {
        _statusMessage = 'Ride accepted! Getting rider details...';
        _acceptedRiderId = updatedRequest.acceptedBy;
      });
      
      _loadRiderDetails(updatedRequest.acceptedBy!);
    } else if (updatedRequest.status == 'cancelled') {
      setState(() {
        _statusMessage = 'Ride has been cancelled.';
      });
      
      // Navigate back after a short delay
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }
  
  Future<void> _loadRiderDetails(String riderId) async {
    try {
      final riderData = await _rideService.getRiderDetails(riderId);
      
      if (!mounted) return;
      
      setState(() {
        _acceptedRider = riderData;
        _statusMessage = 'Your ride has been accepted by ${riderData.name}!';
      });
      
      // Navigate to ongoing ride screen
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => PassengerOngoingRideScreen(
                rideRequest: widget.rideRequest,
                passenger: widget.passenger,
                rider: _acceptedRider!,
              ),
            ),
          );
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _statusMessage = 'Error loading rider details. Please wait...';
        });
      }
    }
  }
  
  void _handleError(dynamic error) {
    if (!mounted) return;
    
    setState(() {
      _statusMessage = 'Error: $error';
    });
  }
  
  Future<void> _cancelRideRequest() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _statusMessage = 'Cancelling your ride request...';
    });
    
    try {
      await _rideService.cancelRideRequest(widget.rideRequest.id);
      
      if (!mounted) return;
      
      // Simply pop back to the original screen
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _statusMessage = 'Failed to cancel ride: $e';
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel ride: $e'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Prevent back button unless cancellation is confirmed
        final shouldCancel = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Cancel Ride Request?'),
            content: const Text('Are you sure you want to cancel your ride request?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('No'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Yes'),
              ),
            ],
          ),
        ) ?? false;
        
        if (shouldCancel) {
          await _cancelRideRequest();
          return true;  // Allow pop after cancellation
        }
        
        return false;  // Prevent pop if not cancelled
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Finding a Rider'),
          automaticallyImplyLeading: false,
        ),
        body: Column(
          children: [
            // Ride request details
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: AppColors.primaryColor.withOpacity(0.1),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Your Ride Request',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildLocationRow(
                    icon: Icons.location_on,
                    iconColor: AppColors.pickupMarkerColor,
                    label: 'From',
                    address: widget.rideRequest.fromAddress,
                  ),
                  _buildDivider(),
                  _buildLocationRow(
                    icon: Icons.flag,
                    iconColor: AppColors.destinationMarkerColor,
                    label: 'To',
                    address: widget.rideRequest.toAddress,
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      const Icon(Icons.attach_money, color: AppColors.primaryColor),
                      const SizedBox(width: 8),
                      Text(
                        'Offered Price: Rs. ${widget.rideRequest.offeredPrice.toInt()}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Advanced animated road with car
                    Container(
                      width: double.infinity,
                      height: 220,
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Stack(
                            alignment: Alignment.center,
                            children: [
                              // Sky background with animated color
                              Container(
                                width: double.infinity,
                                height: 220,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      _skyColorAnimation.value ?? AppColors.primaryColor.withOpacity(0.2),
                                      Colors.white,
                                    ],
                                  ),
                                ),
                              ),
                              
                              // Buildings or city skyline in background
                              Positioned(
                                bottom: 95,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                  children: List.generate(6, (index) {
                                    final height = 20.0 + (index % 3) * 15.0;
                                    return Container(
                                      margin: const EdgeInsets.symmetric(horizontal: 4),
                                      width: 40,
                                      height: height,
                                      decoration: BoxDecoration(
                                        color: Colors.blueGrey.withOpacity(0.7),
                                        borderRadius: const BorderRadius.only(
                                          topLeft: Radius.circular(4),
                                          topRight: Radius.circular(4),
                                        ),
                                      ),
                                      child: Row(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(2, (windowIndex) {
                                          return Container(
                                            margin: const EdgeInsets.all(2),
                                            width: 5,
                                            height: 5,
                                            color: Colors.yellow.withOpacity(0.7),
                                          );
                                        }),
                                      ),
                                    );
                                  }),
                                ),
                              ),
                              
                              // Road
                              Positioned(
                                bottom: 50,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 40,
                                  color: Colors.blueGrey.shade800,
                                ),
                              ),
                              
                              // Road markings (animated)
                              Positioned(
                                bottom: 68,
                                left: _roadMarkingAnimation.value - 600, // Starting offscreen
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  children: List.generate(10, (index) => 
                                    Container(
                                      margin: const EdgeInsets.only(right: 20),
                                      width: 40,
                                      height: 5,
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    )
                                  ),
                                ),
                              ),
                              
                              // Car with subtle bounce animation
                              Positioned(
                                bottom: 75,
                                child: SlideTransition(
                                  position: _carAnimation,
                                  child: ScaleTransition(
                                    scale: _scaleAnimation,
                                    child: SizedBox(
                                      width: 90,
                                      height: 35,
                                      child: Stack(
                                        children: [
                                          // Car body
                                          Container(
                                            width: 80,
                                            height: 25,
                                            decoration: BoxDecoration(
                                              color: AppColors.primaryColor,
                                              borderRadius: BorderRadius.circular(10),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 5,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                            ),
                                          ),
                                          
                                          // Car top/cabin
                                          Positioned(
                                            top: 0,
                                            left: 20,
                                            child: Container(
                                              width: 40,
                                              height: 15,
                                              decoration: BoxDecoration(
                                                color: AppColors.primaryColor.withOpacity(0.8),
                                                borderRadius: BorderRadius.circular(5),
                                              ),
                                            ),
                                          ),
                                          
                                          // Wheels
                                          Positioned(
                                            bottom: 0,
                                            left: 15,
                                            child: Container(
                                              width: 15,
                                              height: 15,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                          Positioned(
                                            bottom: 0,
                                            right: 15,
                                            child: Container(
                                              width: 15,
                                              height: 15,
                                              decoration: BoxDecoration(
                                                color: Colors.black,
                                                shape: BoxShape.circle,
                                                border: Border.all(color: Colors.white, width: 2),
                                              ),
                                            ),
                                          ),
                                          
                                          // Headlights
                                          Positioned(
                                            top: 10,
                                            right: 0,
                                            child: Container(
                                              width: 8,
                                              height: 8,
                                              decoration: BoxDecoration(
                                                color: Colors.yellow,
                                                borderRadius: BorderRadius.circular(2),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Status message
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 32),
                      child: Text(
                        _statusMessage,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 8),
                    
                    Text(
                      'Please wait while we find a rider for you',
                      style: TextStyle(
                        color: AppColors.secondaryTextColor,
                      ),
                    ),
                    
                    if (_acceptedRider != null) ...[
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.successColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircleAvatar(
                              backgroundColor: AppColors.successColor,
                              child: const Icon(Icons.person, color: Colors.white),
                            ),
                            const SizedBox(width: 16),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _acceptedRider!.name ?? 'Your Rider',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                Text(
                                  'Phone: ${_acceptedRider!.phoneNumber}',
                                  style: TextStyle(
                                    color: AppColors.secondaryTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            // Cancel button
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _cancelRideRequest,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.errorColor,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    child: _isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : const Text(
                            'Cancel Ride Request',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildLocationRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String address,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AppColors.surfaceColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppColors.secondaryTextColor,
                  fontSize: 12,
                ),
              ),
              Text(
                address,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: SizedBox(
        height: 20,
        child: VerticalDivider(
          color: AppColors.secondaryTextColor.withOpacity(0.3),
          thickness: 1,
          width: 1,
        ),
      ),
    );
  }
} 