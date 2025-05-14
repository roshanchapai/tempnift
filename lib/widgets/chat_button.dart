import 'package:flutter/material.dart';
import 'package:nift_final/models/ride_request_model.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/models/chat_message_model.dart';
import 'package:nift_final/screens/chat/ride_chat_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/services/chat_service.dart';
import 'package:nift_final/utils/constants.dart';

class ChatButton extends StatefulWidget {
  final RideRequest rideRequest;
  final UserModel currentUser;
  final UserModel otherUser;
  
  const ChatButton({
    Key? key,
    required this.rideRequest,
    required this.currentUser,
    required this.otherUser,
  }) : super(key: key);

  @override
  State<ChatButton> createState() => _ChatButtonState();
}

class _ChatButtonState extends State<ChatButton> {
  final ChatService _chatService = ChatService();
  int _unreadCount = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _setupUnreadCounter();
    
    // Debug the button visibility
    debugPrint('ChatButton initialized for ${widget.currentUser.userRole} - Ride status: ${widget.rideRequest.status}');
  }

  void _setupUnreadCounter() {
    // Always setup the counter regardless of ride status
    final currentUserSender = widget.currentUser.userRole == UserRole.passenger
        ? MessageSender.passenger
        : MessageSender.rider;
    
    // Listen to unread message count
    _chatService
        .getUnreadMessageCount(widget.rideRequest.id, currentUserSender)
        .listen((count) {
      if (mounted) {
        setState(() {
          _unreadCount = count;
          _isLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error getting unread count: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isRideActive = widget.rideRequest.status != 'completed' && widget.rideRequest.status != 'cancelled';
    
    // Always show chat button but with different appearance for inactive rides
    return _isLoading
        ? const SizedBox(width: 48, height: 48, child: Center(child: CircularProgressIndicator())) 
        : Stack(
            children: [
              FloatingActionButton(
                heroTag: 'chat_${widget.rideRequest.id}',
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => RideChatScreen(
                        rideRequest: widget.rideRequest,
                        currentUser: widget.currentUser,
                        otherUser: widget.otherUser,
                      ),
                    ),
                  );
                },
                backgroundColor: isRideActive 
                    ? AppColors.primaryColor  
                    : Colors.grey, // Grey for inactive rides
                tooltip: "Chat with ${widget.otherUser.name ?? (widget.currentUser.userRole == UserRole.passenger ? 'Rider' : 'Passenger')}",
                child: const Icon(Icons.chat),
              ),
              if (_unreadCount > 0)
                Positioned(
                  right: 0,
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Colors.red,
                      shape: BoxShape.circle,
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 18,
                      minHeight: 18,
                    ),
                    child: Text(
                      _unreadCount > 9 ? '9+' : '$_unreadCount',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
            ],
          );
  }
}

// Helper function to create a ChatButton with the current user automatically fetched
class ChatButtonFactory {
  static Widget createChatButton({
    required BuildContext context,
    required RideRequest rideRequest,
    required UserModel otherUser,
  }) {
    return FutureBuilder<UserModel?>(
      future: AuthService().getCurrentUser(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            width: 48, 
            height: 48, 
            child: Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }
        
        if (snapshot.hasError || snapshot.data == null) {
          return const SizedBox.shrink();
        }
        
        return ChatButton(
          rideRequest: rideRequest,
          currentUser: snapshot.data!,
          otherUser: otherUser,
        );
      },
    );
  }
} 