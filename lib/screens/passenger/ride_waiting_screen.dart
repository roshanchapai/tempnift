import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/passenger/ongoing_ride_screen.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
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
  List<Animation<double>> _dotAnimations = [];
  String _statusMessage = 'Waiting for a rider to accept your request...';
  String? _acceptedRiderId;
  UserModel? _acceptedRider;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat();
    
    // Create staggered animations for each dot
    for (int i = 0; i < 6; i++) {
      final delay = i * 0.15;
      final begin = 0.0 + delay;
      final end = 1.0 + delay;
      
      _dotAnimations.add(
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(begin: 0, end: -10)
                .chain(CurveTween(curve: Interval(begin.clamp(0, 1), (begin + 0.5).clamp(0, 1), curve: Curves.easeOut))),
            weight: 50,
          ),
          TweenSequenceItem(
            tween: Tween<double>(begin: -10, end: 0)
                .chain(CurveTween(curve: Interval((begin + 0.5).clamp(0, 1), (end).clamp(0, 1), curve: Curves.easeIn))),
            weight: 50,
          ),
        ]).animate(_animationController),
      );
    }
    
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
                    // Simple bouncing dots animation
                    SizedBox(
                      width: double.infinity,
                      height: 120,
                      child: AnimatedBuilder(
                        animation: _animationController,
                        builder: (context, child) {
                          return Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(6, (index) {
                              return Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                                child: Transform.translate(
                                  offset: Offset(0, _dotAnimations[index].value),
                                  child: Container(
                                    width: 12,
                                    height: 12,
                                    decoration: BoxDecoration(
                                      color: AppColors.primaryColor,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                ),
                              );
                            }),
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