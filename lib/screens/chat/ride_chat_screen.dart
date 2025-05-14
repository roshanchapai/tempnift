import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nift_final/models/chat_message_model.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/chat_service.dart';
import 'package:nift_final/utils/constants.dart';

class RideChatScreen extends StatefulWidget {
  final RideRequest rideRequest;
  final UserModel currentUser;
  final UserModel otherUser;

  const RideChatScreen({
    Key? key,
    required this.rideRequest,
    required this.currentUser,
    required this.otherUser,
  }) : super(key: key);

  @override
  State<RideChatScreen> createState() => _RideChatScreenState();
}

class _RideChatScreenState extends State<RideChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  
  late MessageSender _currentUserSender;
  bool _isRideActive = false;

  @override
  void initState() {
    super.initState();
    
    // Validate user role first to ensure correct typing
    if (widget.currentUser.userRole != UserRole.passenger && widget.currentUser.userRole != UserRole.rider) {
      debugPrint('WARNING: Invalid user role detected: ${widget.currentUser.userRole}. Defaulting to passenger.');
    }
    
    // Determine sender type based on user role with validation
    _currentUserSender = widget.currentUser.userRole == UserRole.passenger
        ? MessageSender.passenger
        : MessageSender.rider;
    
    // Log debug info to help diagnose issues
    debugPrint('Chat initialized - Current user: ${widget.currentUser.uid} (${widget.currentUser.name ?? 'Unknown'})');
    debugPrint('Current user role: ${widget.currentUser.userRole.toString()}');
    debugPrint('Message sender type: ${_currentUserSender.toString()}');
    debugPrint('Other user: ${widget.otherUser.uid} (${widget.otherUser.name ?? 'Unknown'})');
    debugPrint('Other user role: ${widget.otherUser.userRole.toString()}');
    
    // Check if ride is active (not completed or cancelled)
    _isRideActive = widget.rideRequest.status != 'completed' && 
                    widget.rideRequest.status != 'cancelled';
    
    // Mark all messages as read when opening the chat
    _chatService.markAllMessagesAsRead(
      widget.rideRequest.id,
      _currentUserSender,
    );
    
    // Scroll to bottom when messages load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scrollToBottom();
    });
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _sendMessage() async {
    final message = _messageController.text.trim();
    if (message.isEmpty) return;

    try {
      // Clear the input field
      _messageController.clear();

      // Verify sender and recipient match roles
      if ((widget.currentUser.userRole == UserRole.passenger && _currentUserSender != MessageSender.passenger) ||
          (widget.currentUser.userRole == UserRole.rider && _currentUserSender != MessageSender.rider)) {
        debugPrint('ERROR: Sender type does not match user role. Correcting before sending.');
        _currentUserSender = widget.currentUser.userRole == UserRole.passenger
            ? MessageSender.passenger
            : MessageSender.rider;
      }

      // Log the details of the message being sent
      debugPrint('Sending message as ${_currentUserSender.toString()} (${widget.currentUser.uid}) to ${widget.otherUser.uid}');

      // Send the message
      await _chatService.sendMessage(
        rideRequestId: widget.rideRequest.id,
        senderId: widget.currentUser.uid,
        sender: _currentUserSender,
        message: message,
        recipient: widget.otherUser,
      );

      // Scroll to bottom after sending
      _scrollToBottom();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send message: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUser.name ?? 'Chat'),
            Text(
              _isRideActive ? 'Active Ride' : 'Completed Ride',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.normal,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              _showRideDetails(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Ride status banner
          if (!_isRideActive)
            Container(
              color: AppColors.warningColor.withOpacity(0.2),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.warningColor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This chat is no longer active because the ride has been ${widget.rideRequest.status}.',
                      style: const TextStyle(color: AppColors.warningColor),
                    ),
                  ),
                ],
              ),
            ),
          
          // Messages list
          Expanded(
            child: StreamBuilder<List<ChatMessage>>(
              stream: _chatService.getMessagesForRide(widget.rideRequest.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                
                if (snapshot.hasError) {
                  return Center(
                    child: Text('Error loading messages: ${snapshot.error}'),
                  );
                }
                
                final messages = snapshot.data ?? [];
                
                if (messages.isEmpty) {
                  return const Center(
                    child: Text('No messages yet. Start the conversation!'),
                  );
                }
                
                // Mark messages as read
                for (final message in messages) {
                  if (!message.isRead && 
                      message.senderId != widget.currentUser.uid && 
                      message.sender != MessageSender.system) {
                    _chatService.markMessageAsRead(message);
                  }
                }
                
                // Scroll to bottom when new messages arrive
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToBottom();
                });
                
                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    return _buildMessageItem(messages[index]);
                  },
                );
              },
            ),
          ),
          
          // Message input
          if (_isRideActive) // Only show if ride is active
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    spreadRadius: 1,
                    blurRadius: 3,
                    offset: const Offset(0, -1),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: InputDecoration(
                        hintText: 'Type a message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: Colors.grey[100],
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                      ),
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton(
                    onPressed: _sendMessage,
                    mini: true,
                    backgroundColor: AppColors.primaryColor,
                    child: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMessageItem(ChatMessage message) {
    // Determine if this message is from the current user by comparing sender ID AND user ID
    final isCurrentUser = message.senderId == widget.currentUser.uid;
    final isSystem = message.sender == MessageSender.system;
    
    // Format the timestamp
    final timeString = DateFormat('h:mm a').format(message.timestamp);
    
    if (isSystem) {
      // System message
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey[300],
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                message.message,
                style: const TextStyle(
                  color: Colors.black54,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // Determine the avatar letter for the message sender
    // Make this more robust by checking both sender type and actual user identity
    String avatarLetter;
    if (message.senderId == widget.currentUser.uid) {
      avatarLetter = widget.currentUser.userRole == UserRole.passenger ? 'P' : 'R';
    } else if (message.senderId == widget.otherUser.uid) {
      avatarLetter = widget.otherUser.userRole == UserRole.passenger ? 'P' : 'R';
    } else if (message.senderId == widget.rideRequest.passengerId) {
      avatarLetter = 'P'; // Must be passenger
    } else if (widget.rideRequest.acceptedBy != null && message.senderId == widget.rideRequest.acceptedBy) {
      avatarLetter = 'R'; // Must be rider
    } else {
      // Fallback for legacy messages without proper user ID
      avatarLetter = message.sender == MessageSender.passenger ? 'P' : 'R';
    }
    
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isCurrentUser
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isCurrentUser) // Show avatar for other user
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.secondaryColor,
              child: Text(
                avatarLetter,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          
          const SizedBox(width: 8),
          
          Flexible(
            child: Container(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: isCurrentUser
                    ? AppColors.primaryColor
                    : Colors.grey[200],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message.message,
                    style: TextStyle(
                      color: isCurrentUser ? Colors.white : Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timeString,
                        style: TextStyle(
                          fontSize: 10,
                          color: isCurrentUser
                              ? Colors.white.withOpacity(0.8)
                              : Colors.black54,
                        ),
                      ),
                      if (isCurrentUser) ...[
                        const SizedBox(width: 4),
                        Icon(
                          message.isRead ? Icons.done_all : Icons.done,
                          size: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          if (isCurrentUser) // Show avatar for current user
            const SizedBox(width: 8),
          if (isCurrentUser)
            CircleAvatar(
              radius: 16,
              backgroundColor: AppColors.primaryColor.withOpacity(0.7),
              child: Text(
                avatarLetter,
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
    );
  }

  void _showRideDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Ride Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow('From:', widget.rideRequest.fromAddress),
            const SizedBox(height: 8),
            _buildDetailRow('To:', widget.rideRequest.toAddress),
            const SizedBox(height: 8),
            _buildDetailRow('Status:', widget.rideRequest.status.toUpperCase()),
            const SizedBox(height: 8),
            _buildDetailRow(
              'Price:',
              'Rs. ${widget.rideRequest.offeredPrice.toStringAsFixed(2)}',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(child: Text(value)),
      ],
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
} 