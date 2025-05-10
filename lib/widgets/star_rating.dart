import 'package:flutter/material.dart';
import 'package:nift_final/utils/constants.dart';

class StarRating extends StatelessWidget {
  final double rating;
  final double size;
  final Color? color;
  final bool readOnly;
  final ValueChanged<int>? onRatingChanged;
  final int starCount;
  
  const StarRating({
    Key? key,
    required this.rating,
    this.size = 24.0,
    this.color,
    this.readOnly = true,
    this.onRatingChanged,
    this.starCount = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(starCount, (index) {
        // Full, half, or empty star logic
        final position = index + 1;
        final difference = rating - position;
        
        Widget star;
        
        // Choose the appropriate star icon based on the rating
        if (difference >= 0) {
          // Full star
          star = Icon(
            Icons.star,
            size: size,
            color: color ?? AppColors.warningColor,
          );
        } else if (difference > -1 && difference < 0) {
          // Half star
          star = Icon(
            Icons.star_half,
            size: size,
            color: color ?? AppColors.warningColor,
          );
        } else {
          // Empty star
          star = Icon(
            Icons.star_border,
            size: size,
            color: color ?? AppColors.warningColor,
          );
        }
        
        if (readOnly) {
          return star;
        } else {
          return GestureDetector(
            onTap: () {
              if (onRatingChanged != null) {
                onRatingChanged!(position);
              }
            },
            child: star,
          );
        }
      }),
    );
  }
}

class StarRatingInput extends StatefulWidget {
  final int initialRating;
  final double size;
  final Color? color;
  final ValueChanged<int> onRatingChanged;
  final int starCount;
  
  const StarRatingInput({
    Key? key,
    this.initialRating = 0,
    this.size = 40.0,
    this.color,
    required this.onRatingChanged,
    this.starCount = 5,
  }) : super(key: key);

  @override
  State<StarRatingInput> createState() => _StarRatingInputState();
}

class _StarRatingInputState extends State<StarRatingInput> {
  late int _currentRating;
  
  @override
  void initState() {
    super.initState();
    _currentRating = widget.initialRating;
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        StarRating(
          rating: _currentRating.toDouble(),
          size: widget.size,
          color: widget.color ?? AppColors.warningColor,
          readOnly: false,
          onRatingChanged: (rating) {
            setState(() {
              _currentRating = rating;
            });
            widget.onRatingChanged(rating);
          },
          starCount: widget.starCount,
        ),
        const SizedBox(height: 8),
        // Label to indicate current rating
        Text(
          _currentRating > 0 
              ? _getRatingText(_currentRating) 
              : 'Tap a star to rate',
          style: AppTextStyles.captionStyle.copyWith(
            fontWeight: _currentRating > 0 ? FontWeight.bold : FontWeight.normal,
            color: _currentRating > 0 
                ? _getRatingColor(_currentRating) 
                : AppColors.secondaryTextColor,
          ),
        ),
      ],
    );
  }
  
  String _getRatingText(int rating) {
    switch (rating) {
      case 1:
        return 'Poor';
      case 2:
        return 'Fair';
      case 3:
        return 'Good';
      case 4:
        return 'Very Good';
      case 5:
        return 'Excellent';
      default:
        return '';
    }
  }
  
  Color _getRatingColor(int rating) {
    if (rating >= 4) {
      return AppColors.successColor;
    } else if (rating >= 3) {
      return AppColors.primaryColor;
    } else if (rating >= 2) {
      return AppColors.accentColor;
    } else {
      return AppColors.errorColor;
    }
  }
} 