import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/passenger/ongoing_ride_screen.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/widgets/star_rating.dart';

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

        return _buildRideCard(ride, _riderDetails[ride.acceptedBy]);
      },
    );
  }

  Widget _buildRideCard(RideRequest ride, UserModel? rider) {
    // Format timestamp
    final timestamp = ride.timestamp;
    final now = DateTime.now();
    final difference = now.difference(timestamp);
    
    final String timeAgo = difference.inMinutes < 60
        ? '${difference.inMinutes} min ago'
        : difference.inHours < 24
            ? '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago'
            : '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    
    final bool isAccepted = ride.status == 'accepted';
    final bool isInProgress = ride.status == 'in_progress';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isInProgress
              ? AppColors.accentColor.withOpacity(0.2)
              : AppColors.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: rider != null ? () => _viewOngoingRide(ride) : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and time row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Status
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isInProgress
                          ? AppColors.accentColor.withOpacity(0.1)
                          : AppColors.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      isInProgress ? 'In Progress' : (isAccepted ? 'Accepted' : 'Waiting'),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isInProgress
                            ? AppColors.accentColor
                            : AppColors.primaryColor,
                      ),
                    ),
                  ),
                  
                  // Time ago
                  Text(
                    timeAgo,
                    style: AppTextStyles.captionStyle,
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Locations
              Row(
                children: [
                  const Icon(
                    Icons.location_on,
                    color: AppColors.pickupMarkerColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.fromAddress,
                      style: AppTextStyles.bodyStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.flag,
                    color: AppColors.destinationMarkerColor,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      ride.toAddress,
                      style: AppTextStyles.bodyStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              if (isAccepted || isInProgress) ...[
                // Divider
                const Divider(height: 1),
                const SizedBox(height: 16),
                
                // Rider info
                Row(
                  children: [
                    // Rider avatar
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      child: rider?.profileImageUrl != null
                          ? ClipOval(
                              child: Image.network(
                                rider!.profileImageUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (_, __, ___) => const Icon(
                                  Icons.directions_car,
                                  color: AppColors.primaryColor,
                                  size: 20,
                                ),
                              ),
                            )
                          : const Icon(
                              Icons.directions_car,
                              color: AppColors.primaryColor,
                              size: 20,
                            ),
                    ),
                    const SizedBox(width: 12),
                    
                    // Rider name and rating
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            rider?.name ?? ride.riderName ?? 'Loading...',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (rider != null && rider.ratingCount > 0)
                            Row(
                              children: [
                                StarRating(
                                  rating: rider.averageRating,
                                  size: 14,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  rider.averageRating.toStringAsFixed(1),
                                  style: AppTextStyles.captionStyle,
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Rs. ${ride.offeredPrice.toInt()}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.primaryColor,
                          ),
                        ),
                        Text(
                          isInProgress ? 'In transit' : 'Arriving',
                          style: AppTextStyles.captionStyle,
                        ),
                      ],
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // View details button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: rider != null ? () => _viewOngoingRide(ride) : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isInProgress
                          ? AppColors.accentColor
                          : AppColors.primaryColor,
                      foregroundColor: AppColors.lightTextColor,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('View Ride Details'),
                  ),
                ),
              ] else ...[
                // Price info for waiting rides
                Row(
                  children: [
                    // Price tag
                    const Icon(
                      Icons.attach_money,
                      size: 16,
                      color: AppColors.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Rs. ${ride.offeredPrice.toInt()}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    
                    const Spacer(),
                    
                    // Waiting status
                    const Text(
                      'Waiting for a rider',
                      style: TextStyle(
                        color: AppColors.secondaryTextColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
