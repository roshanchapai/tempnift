import 'package:flutter/material.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/rider/ongoing_ride_screen.dart';
import 'package:nift_final/services/ride_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/widgets/star_rating.dart';

class AvailableRidesScreen extends StatefulWidget {
  // ... (existing code)
  @override
  _AvailableRidesScreenState createState() => _AvailableRidesScreenState();
}

class _AvailableRidesScreenState extends State<AvailableRidesScreen> {
  // ... (existing code)

  @override
  Widget build(BuildContext context) {
    // ... (existing code)
  }

  Widget _buildRideCard(RideRequest ride) {
    final isLoading = _loadingRequestIds.contains(ride.id);
    final userService = RideService();
    
    return FutureBuilder<UserModel>(
      future: userService.getUserDetails(ride.passengerId),
      builder: (context, snapshot) {
        final passenger = snapshot.data;
        
        return Card(
          margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: AppColors.primaryColor.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Passenger info and price row
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Passenger info
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceColor,
                              shape: BoxShape.circle,
                            ),
                            child: passenger?.profileImageUrl != null
                                ? ClipOval(
                                    child: Image.network(
                                      passenger!.profileImageUrl!,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.person,
                                        color: AppColors.primaryColor,
                                        size: 24,
                                      ),
                                    ),
                                  )
                                : const Icon(
                                    Icons.person,
                                    color: AppColors.primaryColor,
                                    size: 24,
                                  ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ride.passengerName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              if (passenger != null && passenger.ratingCount > 0) ...[
                                Row(
                                  children: [
                                    StarRating(
                                      rating: passenger.averageRating,
                                      size: 14,
                                    ),
                                    const SizedBox(width:
                                        4),
                                    Text(
                                      passenger.averageRating.toStringAsFixed(1),
                                      style: AppTextStyles.captionStyle,
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    
                    // Price
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            'Offered',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.primaryColor,
                            ),
                          ),
                          Text(
                            'Rs. ${ride.offeredPrice.toInt()}',
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Location information
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      color: AppColors.pickupMarkerColor,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ride.fromAddress,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
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
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        ride.toAddress,
                        style: const TextStyle(
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Accept button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : () => _acceptRideRequest(ride.id),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 24,
                            height: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : const Text('Accept Request'),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    );
  }

  // ... (rest of the existing code)
} 