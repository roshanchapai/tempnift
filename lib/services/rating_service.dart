import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class RatingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Add a rating for a user
  Future<void> rateUser({
    required String userId,
    required String raterId,
    required String rideId,
    required int rating,
    String? comment,
  }) async {
    try {
      // First, create the rating document
      await _firestore.collection('ratings').add({
        'userId': userId, // The user being rated
        'raterId': raterId, // The user giving the rating
        'rideId': rideId, // The ride for which the rating is being given
        'rating': rating, // Rating value (1-5)
        'comment': comment, // Optional comment
        'timestamp': FieldValue.serverTimestamp(),
      });
      
      // Then update the user's aggregate rating data
      await _updateUserAggregateRating(userId, rating);
      
    } catch (e) {
      debugPrint('Error rating user: $e');
      throw Exception('Failed to rate user: $e');
    }
  }
  
  // Get ratings for a specific user
  Future<List<Map<String, dynamic>>> getUserRatings(String userId, {int limit = 10}) async {
    try {
      final snapshot = await _firestore
          .collection('ratings')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();
      
      return snapshot.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
        'timestamp': (doc.data()['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      }).toList();
    } catch (e) {
      debugPrint('Error getting user ratings: $e');
      return [];
    }
  }
  
  // Check if user has already rated a specific ride
  Future<bool> hasUserRatedRide({
    required String raterId,
    required String rideId,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('ratings')
          .where('raterId', isEqualTo: raterId)
          .where('rideId', isEqualTo: rideId)
          .limit(1)
          .get();
      
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if user rated ride: $e');
      return false;
    }
  }
  
  // Private method to update user's aggregate rating
  Future<void> _updateUserAggregateRating(String userId, int newRating) async {
    try {
      // Use a transaction to ensure consistency
      await _firestore.runTransaction((transaction) async {
        final userDocRef = _firestore.collection('users').doc(userId);
        final userDoc = await transaction.get(userDocRef);
        
        if (!userDoc.exists) {
          throw Exception('User not found');
        }
        
        // Get current rating data
        final int currentTotalRatings = userDoc.data()?['totalRatings'] as int? ?? 0;
        final int currentRatingCount = userDoc.data()?['ratingCount'] as int? ?? 0;
        
        // Calculate new rating data
        final int newTotalRatings = currentTotalRatings + newRating;
        final int newRatingCount = currentRatingCount + 1;
        final double newAverageRating = newRatingCount > 0 
            ? newTotalRatings / newRatingCount 
            : 0.0;
        
        // Update user document with new rating data
        transaction.update(userDocRef, {
          'totalRatings': newTotalRatings,
          'ratingCount': newRatingCount,
          'averageRating': newAverageRating,
        });
      });
    } catch (e) {
      debugPrint('Error updating user aggregate rating: $e');
      throw Exception('Failed to update user rating: $e');
    }
  }
} 