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
      // Create message data
      final messageData = {
        'rideRequestId': rideRequestId,
        'senderId': senderId,
        'sender': sender.toString().split('.').last,
        'message': message,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      };
      
      // Add to Firestore
      final docRef = await _messagesCollection.add(messageData);
      
      // Send notification to recipient
      final senderRoleAsString = sender == MessageSender.passenger ? 'Passenger' : 'Rider';
      final recipientRole = sender == MessageSender.passenger ? UserRole.rider : UserRole.passenger;
      
      await _notificationService.showMessageNotification(
        userRole: recipientRole,
        title: 'New Message from $senderRoleAsString',
        body: message,
        payload: 'chat:$rideRequestId',
      );
      
      // Create and return ChatMessage object
      return ChatMessage(
        id: docRef.id,
        rideRequestId: rideRequestId,
        senderId: senderId,
        sender: sender,
        message: message,
        timestamp: DateTime.now(),
        isRead: false,
      );
    } catch (e) {
      debugPrint('Error sending message: $e');
      throw Exception('Failed to send message: $e');
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