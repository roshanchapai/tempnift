import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nift_final/models/place_models.dart';
import 'package:nift_final/utils/constants.dart';

class BookingPanel extends StatelessWidget {
  final TextEditingController pickupController;
  final TextEditingController destinationController;
  final LatLng? pickupLocation;
  final LatLng? destinationLocation;
  final bool isPickupSearching;
  final bool isDestinationSearching;
  final List<SearchResult> searchResults;
  final Function(String, bool) onSearch;
  final Function(SearchResult, bool) onLocationSelected;
  final Function() onGetCurrentLocation;
  final Function() onShowPopularPlaces;
  final Function() onBookNow;

  const BookingPanel({
    Key? key,
    required this.pickupController,
    required this.destinationController,
    required this.pickupLocation,
    required this.destinationLocation,
    required this.isPickupSearching,
    required this.isDestinationSearching,
    required this.searchResults,
    required this.onSearch,
    required this.onLocationSelected,
    required this.onGetCurrentLocation,
    required this.onShowPopularPlaces,
    required this.onBookNow,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: AppColors.surfaceColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          _buildLocationRow(
            controller: pickupController,
            isPickup: true,
            iconColor: AppColors.pickupMarkerColor,
            hintText: 'Pickup Location',
            onGetCurrentLocation: onGetCurrentLocation,
          ),
          Divider(color: AppColors.surfaceColor),
          _buildLocationRow(
            controller: destinationController,
            isPickup: false,
            iconColor: AppColors.destinationMarkerColor,
            hintText: 'Destination',
            onShowPopularPlaces: onShowPopularPlaces,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: destinationLocation == null ? null : onBookNow,
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
    );
  }

  Widget _buildLocationRow({
    required TextEditingController controller,
    required bool isPickup,
    required Color iconColor,
    required String hintText,
    VoidCallback? onGetCurrentLocation,
    VoidCallback? onShowPopularPlaces,
  }) {
    return Row(
      children: [
        Icon(Icons.location_on, color: iconColor),
        const SizedBox(width: 8),
        Expanded(
          child: TextField(
            controller: controller,
            style: AppTextStyles.inputStyle,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: AppTextStyles.hintStyle,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              suffixIcon: isPickup && onGetCurrentLocation != null
                  ? IconButton(
                      icon: Icon(Icons.my_location, color: iconColor),
                      onPressed: onGetCurrentLocation,
                    )
                  : null,
            ),
            onTap: () {
              onSearch('', isPickup);
            },
            onChanged: (value) {
              onSearch(value, isPickup);
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                onSearch(value, isPickup);
              }
            },
          ),
        ),
        if (!isPickup) ...[
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              // Show map tap instruction
            },
            tooltip: 'Set on map',
            color: AppColors.primaryColor,
          ),
          IconButton(
            icon: const Icon(Icons.place),
            onPressed: onShowPopularPlaces,
            tooltip: 'Popular places',
            color: AppColors.primaryColor,
          ),
        ],
      ],
    );
  }
} 