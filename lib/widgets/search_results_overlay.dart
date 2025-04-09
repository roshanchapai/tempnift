import 'package:flutter/material.dart';
import 'package:nift_final/models/place_models.dart';
import 'package:nift_final/utils/constants.dart';

class SearchResultsOverlay extends StatelessWidget {
  final bool isPickupSearching;
  final List<SearchResult> searchResults;
  final Function(SearchResult, bool) onLocationSelected;

  const SearchResultsOverlay({
    Key? key,
    required this.isPickupSearching,
    required this.searchResults,
    required this.onLocationSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.4,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardColor,
        borderRadius: BorderRadius.circular(AppColors.borderRadius),
        boxShadow: AppColors.cardShadow,
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Icon(
                  Icons.location_on,
                  color: isPickupSearching
                      ? AppColors.pickupMarkerColor
                      : AppColors.destinationMarkerColor,
                ),
                const SizedBox(width: 8),
                Text(
                  isPickupSearching
                      ? 'Search Pickup Location'
                      : 'Search Destination',
                  style: AppTextStyles.subtitleStyle,
                ),
              ],
            ),
          ),
          Divider(color: AppColors.surfaceColor),
          Expanded(
            child: searchResults.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.search,
                          size: 48,
                          color: AppColors.surfaceColor,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No results found',
                          style: AppTextStyles.bodyStyle.copyWith(
                            color: AppColors.surfaceColor,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: searchResults.length,
                    itemBuilder: (context, index) {
                      final result = searchResults[index];
                      return ListTile(
                        leading: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: (isPickupSearching
                                    ? AppColors.pickupMarkerColor
                                    : AppColors.destinationMarkerColor)
                                .withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.location_on,
                            color: isPickupSearching
                                ? AppColors.pickupMarkerColor
                                : AppColors.destinationMarkerColor,
                          ),
                        ),
                        title: Text(
                          result.formattedAddress,
                          style: AppTextStyles.bodyStyle,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: result.distance > 0
                            ? Text(
                                '${(result.distance / 1000).toStringAsFixed(1)} km away',
                                style: AppTextStyles.captionStyle,
                              )
                            : null,
                        onTap: () {
                          onLocationSelected(result, isPickupSearching);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
} 