import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageSender {
  passenger,
  rider,
  system
}

class ChatMessage {
  final String id;
  final String rideRequestId;
  final String senderId;
  final MessageSender sender;
  final String message;
  final DateTime timestamp;
  final bool isRead;

  ChatMessage({
    required this.id,
    required this.rideRequestId,
    required this.senderId,
    required this.sender,
    required this.message,
    required this.timestamp,
    this.isRead = false,
  });

  // Convert ChatMessage to a Map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'rideRequestId': rideRequestId,
      'senderId': senderId,
      'sender': sender.toString().split('.').last, // Convert enum to string
      'message': message,
      'timestamp': Timestamp.fromDate(timestamp),
      'isRead': isRead,
    };
  }

  // Create ChatMessage from Firestore document
  factory ChatMessage.fromMap(Map<String, dynamic> map, String id) {
    // Ensure we have a valid senderId, defaulting to 'system' if not present
    final String senderId = map['senderId'] as String? ?? 'system';
    
    return ChatMessage(
      id: id,
      rideRequestId: map['rideRequestId'] as String,
      senderId: senderId,
      sender: _parseSender(map['sender'] as String),
      message: map['message'] as String,
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isRead: map['isRead'] as bool? ?? false,
    );
  }

  // Helper method to parse sender type
  static MessageSender _parseSender(String sender) {
    switch (sender.toLowerCase()) {
      case 'passenger':
        return MessageSender.passenger;
      case 'rider':
        return MessageSender.rider;
      case 'system':
        return MessageSender.system;
      default:
        return MessageSender.system;
    }
  }

  // Create a copy with updated read status
  ChatMessage copyWithReadStatus(bool isRead) {
    return ChatMessage(
      id: id,
      rideRequestId: rideRequestId,
      senderId: senderId,
      sender: sender,
      message: message,
      timestamp: timestamp,
      isRead: isRead,
    );
  }
  
  // Verify if this message belongs to a specific user
  bool isSentByUser(String userId) {
    return senderId == userId;
  }
  
  // Utility method to check if message is from system
  bool get isSystemMessage => sender == MessageSender.system || senderId == 'system';
} 