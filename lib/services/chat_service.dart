import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nift_final/models/chat_message_model.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/notification_service.dart';
import 'package:nift_final/utils/constants.dart';

class ChatService {
  static final ChatService _instance = ChatService._internal();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final NotificationService _notificationService = NotificationService();
  
  factory ChatService() {
    return _instance;
  }
  
  ChatService._internal();
  
  // Collection references
  CollectionReference get _messagesCollection => _firestore.collection('chat_messages');
  
  // Send a message
  Future<ChatMessage> sendMessage({
    required String rideRequestId,
    required String senderId,
    required MessageSender sender,
    required String message,
    required UserModel recipient,
  }) async {
    try {
      // Double-check sender type against actual user role to catch any errors
      // This fixes the issue where a rider might appear to be sending messages as a passenger
      MessageSender correctedSender;
      UserRole recipientRole;
      
      // Get the ride request to verify roles
      final rideRequest = await getRideRequest(rideRequestId);
      if (rideRequest == null) {
        throw Exception("Cannot send message: Ride request not found");
      }
      
      // Verify if the sender is actually the passenger or rider based on the ride request
      bool isSenderPassenger = senderId == rideRequest.passengerId;
      bool isSenderRider = rideRequest.acceptedBy != null && senderId == rideRequest.acceptedBy;
      
      // Set the correct sender type based on actual role in the ride
      if (isSenderPassenger) {
        correctedSender = MessageSender.passenger;
        recipientRole = UserRole.rider;
        
        // Log the correction if there was a mismatch
        if (sender != MessageSender.passenger) {
          debugPrint('Correcting sender type from ${sender.toString()} to passenger');
        }
      } else if (isSenderRider) {
        correctedSender = MessageSender.rider;
        recipientRole = UserRole.passenger;
        
        // Log the correction if there was a mismatch
        if (sender != MessageSender.rider) {
          debugPrint('Correcting sender type from ${sender.toString()} to rider');
        }
      } else {
        // If neither passenger nor rider, this is an error
        throw Exception('Sender ID does not match either passenger or rider in this ride');
      }
      
      // Ensure recipient is the correct user
      String recipientId;
      if (correctedSender == MessageSender.passenger) {
        // If sender is passenger, recipient should be the rider
        recipientId = rideRequest.acceptedBy!;
      } else {
        // If sender is rider, recipient should be the passenger
        recipientId = rideRequest.passengerId;
      }
      
      // Log detailed message information for debugging
      debugPrint('=== SENDING MESSAGE ===');
      debugPrint('Ride: $rideRequestId');
      debugPrint('Sender ID: $senderId as ${correctedSender.toString()}');
      debugPrint('Recipient ID: $recipientId as ${recipientRole.toString()}');
      debugPrint('Message: $message');
      
      // Create message data with validated fields
      final messageData = {
        'rideRequestId': rideRequestId,
        'senderId': senderId,
        'sender': correctedSender.toString().split('.').last,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      
      // Add to Firestore
      final docRef = await _messagesCollection.add(messageData);
      
      // Send notification to the correct recipient
      final senderRoleAsString = correctedSender == MessageSender.passenger ? 'Passenger' : 'Rider';
      
      // Get the actual recipient user
      UserModel actualRecipient;
      try {
        final FirebaseFirestore _firestore = FirebaseFirestore.instance;
        final docSnapshot = await _firestore.collection('users').doc(recipientId).get();
        
        if (docSnapshot.exists) {
          actualRecipient = UserModel.fromMap(docSnapshot.data()!);
        } else {
          throw Exception('Recipient user not found');
        }
      } catch (e) {
        debugPrint('Error fetching recipient user: $e');
        // Fallback to the passed recipient if we can't fetch the actual one
        actualRecipient = recipient;
      }
      
      // Send notification
      await _notificationService.showMessageNotification(
        userRole: recipientRole,
        title: 'New Message from $senderRoleAsString',
        body: message,
        payload: 'chat:$rideRequestId',
        userId: recipientId, // Use the verified recipient ID
      );
      
      // Create and return ChatMessage object
      return ChatMessage(
        id: docRef.id,
        rideRequestId: rideRequestId,
        senderId: senderId,
        sender: correctedSender, // Use corrected sender type
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }
  
  // Helper method to get a ride request by ID
  Future<RideRequest?> getRideRequest(String rideRequestId) async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('rideRequests')
          .doc(rideRequestId)
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
  
  // Get messages for a ride
  Stream<List<ChatMessage>> getMessagesForRide(String rideRequestId) {
    return _messagesCollection
        .where('rideRequestId', isEqualTo: rideRequestId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => ChatMessage.fromMap(doc.data() as Map<String, dynamic>, doc.id))
            .toList());
  }
  
  // Mark message as read
  Future<void> markMessageAsRead(ChatMessage message) async {
    try {
      await _messagesCollection.doc(message.id).update({'isRead': true});
    } catch (e) {
      debugPrint('Error marking message as read: $e');
    }
  }
  
  // Mark all messages in a ride as read for a specific user
  Future<void> markAllMessagesAsRead(String rideRequestId, MessageSender recipient) async {
    try {
      // Get all unread messages from the other party
      final QuerySnapshot unreadMessages = await _messagesCollection
          .where('rideRequestId', isEqualTo: rideRequestId)
          .where('isRead', isEqualTo: false)
          .where('sender', isNotEqualTo: recipient.toString().split('.').last)
          .get();
      
      // Batch update
      final batch = _firestore.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error marking all messages as read: $e');
    }
  }
  
  // Get unread message count for a ride
  Stream<int> getUnreadMessageCount(String rideRequestId, MessageSender recipient) {
    return _messagesCollection
        .where('rideRequestId', isEqualTo: rideRequestId)
        .where('isRead', isEqualTo: false)
        .where('sender', isNotEqualTo: recipient.toString().split('.').last)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }
  
  // Check if a chat exists for this ride
  Future<bool> doesChatExist(String rideRequestId) async {
    try {
      final messages = await _messagesCollection
          .where('rideRequestId', isEqualTo: rideRequestId)
          .limit(1)
          .get();
      
      return messages.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking if chat exists: $e');
      return false;
    }
  }
  
  // Send system message
  Future<void> sendSystemMessage({
    required String rideRequestId,
    required String message,
  }) async {
    try {
      final messageData = {
        'rideRequestId': rideRequestId,
        'senderId': 'system',
        'sender': 'system',
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      
      await _messagesCollection.add(messageData);
    } catch (e) {
      debugPrint('Error sending system message: $e');
    }
  }
  
  // Delete all messages for a ride
  // Note: This won't actually be used when rides are completed/cancelled
  // We'll just prevent UI access to these messages instead
  Future<void> deleteAllMessagesForRide(String rideRequestId) async {
    try {
      final QuerySnapshot messages = await _messagesCollection
          .where('rideRequestId', isEqualTo: rideRequestId)
          .get();
      
      final batch = _firestore.batch();
      for (final doc in messages.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Error deleting messages: $e');
    }
  }
  
  // Send a ride status update as a system message
  Future<void> sendRideStatusUpdate({
    required String rideRequestId,
    required RideRequest ride,
    required String status,
  }) async {
    String message;
    
    switch (status) {
      case 'accepted':
        message = 'Ride accepted by ${ride.riderName}. They are on their way!';
        break;
      case 'arrived':
        message = 'Rider has arrived at your pickup location.';
        break;
      case 'started':
        message = 'Your ride has started.';
        break;
      case 'completed':
        message = 'Your ride has been completed. Thank you for using our service!';
        break;
      case 'cancelled':
        message = 'This ride has been cancelled.';
        break;
      default:
        message = 'Ride status updated to: $status';
    }
    
    await sendSystemMessage(
      rideRequestId: rideRequestId,
      message: message,
    );
  }
} 