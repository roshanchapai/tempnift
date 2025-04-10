import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/passenger/ongoing_ride_screen.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';

class ActiveRidesScreen extends StatefulWidget {
  final UserModel passenger;

  const ActiveRidesScreen({
    Key? key,
    required this.passenger,
  }) : super(key: key);

  @override
  State<ActiveRidesScreen> createState() => _ActiveRidesScreenState();
}

class _ActiveRidesScreenState extends State<ActiveRidesScreen> {
  final RideService _rideService = RideService();
  StreamSubscription<List<RideRequest>>? _activeRidesSubscription;
  List<RideRequest> _activeRides = [];
  bool _isLoading = true;
  Map<String, UserModel?> _riderDetails = {};

  @override
  void initState() {
    super.initState();
    _initActiveRidesStream();
  }

  @override
  void dispose() {
    _activeRidesSubscription?.cancel();
    super.dispose();
  }

  void _initActiveRidesStream() {
    _activeRidesSubscription = _rideService
        .getPassengerActiveRideRequests(widget.passenger.uid)
        .listen((rides) async {
      if (!mounted) return;

      setState(() {
        _activeRides = rides;
        _isLoading = false;
      });

      // Load rider details for each active ride
      for (final ride in rides) {
        if (ride.acceptedBy != null && !_riderDetails.containsKey(ride.acceptedBy)) {
          _loadRiderDetails(ride.acceptedBy!);
        }
      }
    }, onError: (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading active rides: $error'),
          backgroundColor: AppColors.errorColor,
        ),
      );
    });
  }

  Future<void> _loadRiderDetails(String riderId) async {
    try {
      final rider = await _rideService.getUserDetails(riderId);
      if (mounted) {
        setState(() {
          _riderDetails[riderId] = rider;
        });
      }
    } catch (e) {
      debugPrint('Error loading rider details: $e');
    }
  }

  Future<void> _viewOngoingRide(RideRequest ride) async {
    if (ride.acceptedBy == null) return;

    final rider = _riderDetails[ride.acceptedBy];
    if (rider == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Loading rider details, please try again in a moment'),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => PassengerOngoingRideScreen(
          rideRequest: ride,
          passenger: widget.passenger,
          rider: rider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Active Rides'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _activeRides.isEmpty
              ? _buildEmptyState()
              : _buildRidesList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.directions_car_outlined,
            size: 80,
            color: AppColors.primaryColor.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'No active rides',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Book a ride to get started',
            style: TextStyle(
              color: AppColors.secondaryTextColor,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to Map'),
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryColor,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRidesList() {
    return ListView.builder(
      itemCount: _activeRides.length,
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final ride = _activeRides[index];
        final minutesAgo = DateTime.now().difference(ride.timestamp).inMinutes;
        final riderName = ride.acceptedBy != null && _riderDetails.containsKey(ride.acceptedBy)
            ? _riderDetails[ride.acceptedBy]?.name ?? 'Loading...'
            : 'Waiting for rider...';

        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: InkWell(
            onTap: () {
              if (ride.acceptedBy != null) {
                _viewOngoingRide(ride);
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status header
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: AppColors.surfaceColor,
                        child: Icon(
                          ride.acceptedBy != null ? Icons.person : Icons.access_time,
                          color: AppColors.primaryColor,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              riderName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              '$minutesAgo minutes ago',
                              style: const TextStyle(
                                color: AppColors.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getRideStatusColor(ride.status),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          _getRideStatusLabel(ride.status),
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  
                  // From/To locations
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'From',
                              style: TextStyle(
                                color: AppColors.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              ride.fromAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.arrow_forward,
                        color: AppColors.secondaryTextColor,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'To',
                              style: TextStyle(
                                color: AppColors.secondaryTextColor,
                                fontSize: 12,
                              ),
                            ),
                            Text(
                              ride.toAddress,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Action button
                  if (ride.acceptedBy != null)
                    Align(
                      alignment: Alignment.centerRight,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.navigate_next),
                        label: const Text('View Ride'),
                        onPressed: () => _viewOngoingRide(ride),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryColor,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _getRideStatusLabel(String status) {
    switch (status) {
      case 'pending':
        return 'Waiting';
      case 'accepted':
        return 'Accepted';
      case 'in_progress':
        return 'In Progress';
      case 'completed':
        return 'Completed';
      case 'cancelled':
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  Color _getRideStatusColor(String status) {
    switch (status) {
      case 'pending':
        return AppColors.warningColor;
      case 'accepted':
        return AppColors.primaryColor;
      case 'in_progress':
        return AppColors.accentColor;
      case 'completed':
        return AppColors.successColor;
      case 'cancelled':
        return AppColors.errorColor;
      default:
        return AppColors.secondaryTextColor;
    }
  }
}
