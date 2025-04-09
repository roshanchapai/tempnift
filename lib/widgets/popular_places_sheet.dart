import 'package:flutter/material.dart';
import 'package:nift_final/models/place_models.dart';
import 'package:nift_final/utils/constants.dart';

class PopularPlacesSheet extends StatelessWidget {
  final List<PopularPlace> places;
  final Function(PopularPlace) onPlaceSelected;

  const PopularPlacesSheet({
    Key? key,
    required this.places,
    required this.onPlaceSelected,
  }) : super(key: key);

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'transportation':
        return Icons.directions_bus;
      case 'tourist area':
        return Icons.place;
      case 'landmark':
        return Icons.location_city;
      case 'park':
        return Icons.park;
      case 'temple':
        return Icons.church;
      default:
        return Icons.place;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Popular Places',
                style: AppTextStyles.subtitleStyle,
              ),
              IconButton(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                return ListTile(
                  leading: Icon(
                    _getCategoryIcon(place.category),
                    color: AppColors.primaryColor,
                  ),
                  title: Text(place.name),
                  subtitle: Text(place.category),
                  onTap: () {
                    Navigator.pop(context);
                    onPlaceSelected(place);
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