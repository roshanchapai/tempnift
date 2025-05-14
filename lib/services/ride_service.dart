import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/chat_service.dart';
import 'package:nift_final/services/notification_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:flutter/foundation.dart';

class RideService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  final ChatService _chatService = ChatService();
  
  // Create a new ride request
  Future<RideRequest> createRideRequest({
    required UserModel passenger,
    required String fromAddress,
    required String toAddress,
    required LatLng fromLocation,
    required LatLng toLocation,
    required double offeredPrice,
  }) async {
    try {
      // Create the request data
      final requestData = {
        'passengerId': passenger.uid,
        'passengerName': passenger.name ?? 'Unknown',
        'passengerPhone': passenger.phoneNumber,
        'fromAddress': fromAddress,
        'toAddress': toAddress,
        'fromLocation': GeoPoint(fromLocation.latitude, fromLocation.longitude),
        'toLocation': GeoPoint(toLocation.latitude, toLocation.longitude),
        'offeredPrice': offeredPrice,
        'timestamp': FieldValue.serverTimestamp(),
        'status': 'pending',
        'acceptedBy': null,
      };
      
      // Add to Firestore
      final docRef = await _firestore.collection('rideRequests').add(requestData);
      
      // Create a RideRequest object
      return RideRequest(
        id: docRef.id,
        passengerId: passenger.uid,
        passengerName: passenger.name ?? 'Unknown',
        passengerPhone: passenger.phoneNumber,
        fromAddress: fromAddress,
        toAddress: toAddress,
        fromLocation: GeoPoint(fromLocation.latitude, fromLocation.longitude),
        toLocation: GeoPoint(toLocation.latitude, toLocation.longitude),
        offeredPrice: offeredPrice,
        timestamp: DateTime.now(),
        status: 'pending',
        acceptedBy: null,
      );
    } catch (e) {
      throw Exception('Failed to create ride request: $e');
    }
  }
  
  // Get active ride requests for a passenger
  Stream<List<RideRequest>> getPassengerActiveRideRequests(String passengerId) {
    return _firestore
        .collection('rideRequests')
        .where('passengerId', isEqualTo: passengerId)
        .where('status', whereIn: ['pending', 'accepted'])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromMap(doc.data(), doc.id))
            .toList());
  }
  
  // Get ride request history for a passenger
  Future<List<RideRequest>> getPassengerRideHistory(String passengerId) async {
    try {
      final snapshot = await _firestore
          .collection('rideRequests')
          .where('passengerId', isEqualTo: passengerId)
          .where('status', whereIn: ['completed', 'cancelled'])
          .orderBy('timestamp', descending: true)
          .limit(20)
          .get();
      
      return snapshot.docs
          .map((doc) => RideRequest.fromMap(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw Exception('Failed to get ride history: $e');
    }
  }
  
  // Get available ride requests for riders
  Stream<List<RideRequest>> getAvailableRideRequests() {
    return _firestore
        .collection('rideRequests')
        .where('status', isEqualTo: 'pending')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromMap(doc.data(), doc.id))
            .toList());
  }
  
  // Accept a ride request (for riders)
  Future<void> acceptRideRequest({
    required String requestId,
    required String riderId,
    required String riderName,
    required String riderPhone,
  }) async {
    try {
      await _firestore.collection('rideRequests').doc(requestId).update({
        'status': 'accepted',
        'acceptedBy': riderId,
        'riderName': riderName,
        'riderPhone': riderPhone,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      // Get the ride request details to send notification
      final rideRequest = await getRideRequest(requestId);
      if (rideRequest != null) {
        // Get passenger details
        final passenger = await getUserDetails(rideRequest.passengerId);
        
        // Notify the passenger that their ride was accepted
        await _notificationService.showPassengerRideNotification(
          title: 'Ride Accepted!',
          body: 'Your ride has been accepted by $riderName',
          payload: 'ride_accepted:$requestId',
          passengerId: rideRequest.passengerId,
        );
        
        // Send a system message to the chat
        await _chatService.sendRideStatusUpdate(
          rideRequestId: requestId,
          ride: rideRequest,
          status: 'accepted',
        );
        
        // Also log to console
        debugPrint('Sent notification to passenger ${passenger.name} about ride acceptance');
      }
    } catch (e) {
      debugPrint('Error in acceptRideRequest: $e');
      throw Exception('Failed to accept ride request: $e');
    }
  }
  
  // Complete a ride
  Future<void> completeRide({
    required String requestId,
    double? finalPrice,
    double? estimatedDistance,
    Map<String, dynamic>? priceFactors,
  }) async {
    try {
      final data = <String, dynamic>{
        'status': 'completed',
        'completedAt': FieldValue.serverTimestamp(),
      };

      // Add price data if available
      if (finalPrice != null) {
        data['finalPrice'] = finalPrice;
      }
      
      if (estimatedDistance != null) {
        data['estimatedDistance'] = estimatedDistance;
      }
      
      if (priceFactors != null) {
        data['priceFactors'] = priceFactors;
      }

      await _firestore.collection('rideRequests').doc(requestId).update(data);
      
      // Get the ride request details to send notification
      final rideRequest = await getRideRequest(requestId);
      if (rideRequest != null && rideRequest.acceptedBy != null) {
        // Get passenger and rider details
        final passenger = await getUserDetails(rideRequest.passengerId);
        final rider = await getUserDetails(rideRequest.acceptedBy!);
        
        // Notify the passenger that their ride is completed
        await _notificationService.showPassengerRideNotification(
          title: 'Ride Completed',
          body: 'Your ride has been completed. Total fare: Rs.${finalPrice?.toInt() ?? rideRequest.offeredPrice.toInt()}',
          payload: 'ride_completed:$requestId',
          passengerId: rideRequest.passengerId,
        );
        
        // Notify the rider that the ride is completed
        await _notificationService.showRiderRideNotification(
          title: 'Ride Completed',
          body: 'Ride with ${passenger.name ?? 'passenger'} completed. Earned: Rs.${finalPrice?.toInt() ?? rideRequest.offeredPrice.toInt()}',
          payload: 'ride_completed:$requestId',
          riderId: rideRequest.acceptedBy,
        );
        
        // Send a system message to the chat
        await _chatService.sendRideStatusUpdate(
          rideRequestId: requestId,
          ride: rideRequest,
          status: 'completed',
        );
        
        // Also log to console
        debugPrint('Sent ride completion notifications to passenger and rider');
      }
    } catch (e) {
      debugPrint('Error in completeRide: $e');
      throw Exception('Failed to complete ride: $e');
    }
  }
  
  // Cancel a ride request
  Future<void> cancelRideRequest(String requestId) async {
    try {
      // Get the ride details first so we know who to notify
      final ride = await getRideRequest(requestId);
      if (ride == null) {
        throw Exception('Ride request not found');
      }
      
      // Update the status
      await _firestore.collection('rideRequests').doc(requestId).update({
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
      });
      
      if (ride.acceptedBy != null) {
        // This ride had been accepted, so notify the rider
        final rider = await getUserDetails(ride.acceptedBy!);
        final passenger = await getUserDetails(ride.passengerId);
        
        // Notify the rider that the ride was cancelled
        await _notificationService.showRiderRideNotification(
          title: 'Ride Cancelled',
          body: 'Ride with ${passenger.name ?? 'passenger'} has been cancelled.',
          payload: 'ride_cancelled:$requestId',
          riderId: ride.acceptedBy,
        );
        
        // Send a system message to the chat
        await _chatService.sendRideStatusUpdate(
          rideRequestId: requestId,
          ride: ride,
          status: 'cancelled',
        );
        
        debugPrint('Sent ride cancellation notification to rider');
      }
    } catch (e) {
      debugPrint('Error canceling ride request: $e');
      throw Exception('Failed to cancel ride request: $e');
    }
  }
  
  // Get a stream for a specific ride request
  Stream<RideRequest?> getRideRequestStream(String requestId) {
    return _firestore
        .collection('rideRequests')
        .doc(requestId)
        .snapshots()
        .map((snapshot) => 
            snapshot.exists 
                ? RideRequest.fromMap(snapshot.data()!, snapshot.id) 
                : null);
  }
  
  // Get rider details by rider ID
  Future<UserModel> getRiderDetails(String riderId) async {
    try {
      final doc = await _firestore.collection('users').doc(riderId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      throw Exception('Rider not found');
    } catch (e) {
      throw Exception('Failed to get rider details: $e');
    }
  }
  
  // Update rider's location
  Future<void> updateRiderLocation({
    required String riderId,
    required LatLng location,
  }) async {
    try {
      await _firestore.collection('riders_location').doc(riderId).set({
        'location': GeoPoint(location.latitude, location.longitude),
        'timestamp': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('Error updating rider location: $e');
    }
  }
  
  // Get rider's location stream
  Stream<LatLng?> getRiderLocationStream(String riderId) {
    return _firestore
        .collection('riders_location')
        .doc(riderId)
        .snapshots()
        .map((snapshot) {
          if (snapshot.exists && snapshot.data()?['location'] != null) {
            final location = snapshot.data()!['location'] as GeoPoint;
            return LatLng(location.latitude, location.longitude);
          }
          return null;
        });
  }
  
  // Update ride status
  Future<void> updateRideStatus({
    required String requestId,
    required String newStatus,
  }) async {
    try {
      await _firestore.collection('rideRequests').doc(requestId).update({
        'status': newStatus,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      });
      
      // Get the ride request to send status update
      final rideRequest = await getRideRequest(requestId);
      if (rideRequest != null) {
        // Send a system message to the chat
        await _chatService.sendRideStatusUpdate(
          rideRequestId: requestId,
          ride: rideRequest,
          status: newStatus,
        );
      }
    } catch (e) {
      throw Exception('Failed to update ride status: $e');
    }
  }
  
  // Get active rides for a rider
  Stream<List<RideRequest>> getRiderActiveRides(String riderId) {
    return _firestore
        .collection('rideRequests')
        .where('acceptedBy', isEqualTo: riderId)
        .where('status', whereIn: ['accepted', 'in_progress'])
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => RideRequest.fromMap(doc.data(), doc.id))
            .toList());
  }
  
  // Get user details by user ID
  Future<UserModel> getUserDetails(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        return UserModel.fromMap(doc.data() as Map<String, dynamic>);
      }
      throw Exception('User not found');
    } catch (e) {
      throw Exception('Failed to get user details: $e');
    }
  }

  Future<void> _fetchMissingRiderDetails(List<Map<String, dynamic>> rides) async {
    final FirebaseFirestore firestore = FirebaseFirestore.instance;
    final List<Future<void>> fetchTasks = [];
    
    for (final ride in rides) {
      // Mark whether this ride was ever accepted
      ride['wasAccepted'] = ride['acceptedBy'] != null;
      
      // Only process rides that have an acceptedBy but missing rider details
      if (ride['wasAccepted'] && 
          (ride['riderName'] == null || ride['riderPhone'] == null)) {
        
        final String riderId = ride['acceptedBy'];
        fetchTasks.add(
          firestore.collection('users').doc(riderId).get().then((userDoc) {
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>;
              // Update the ride with rider info
              ride['riderName'] = userData['name'] ?? 'Unknown Rider';
              ride['riderPhone'] = userData['phoneNumber'] ?? 'No Phone';
              
              // Also update the original document to fix it for future queries
              firestore.collection('rideRequests').doc(ride['id']).update({
                'riderName': ride['riderName'],
                'riderPhone': ride['riderPhone'],
              });
            } else {
              // User document doesn't exist anymore
              ride['riderName'] = 'Rider (Account Deleted)';
              ride['riderDeleted'] = true;
            }
          }).catchError((e) {
            debugPrint('Error fetching rider details: $e');
            ride['fetchError'] = true;
          })
        );
      }
    }
    
    // Wait for all fetch tasks to complete
    if (fetchTasks.isNotEmpty) {
      await Future.wait(fetchTasks);
    }
  }

  // Get a specific ride request by ID
  Future<RideRequest?> getRideRequest(String requestId) async {
    try {
      final doc = await _firestore
          .collection('rideRequests')
          .doc(requestId)
          .get();
      
      if (doc.exists) {
        return RideRequest.fromMap(doc.data()!, doc.id);
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting ride request: $e');
      return null;
    }
  }
} 