import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/role_preference_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final RolePreferenceService _rolePreferenceService = RolePreferenceService();
  
  // Notification channels
  static const String passengerChannelId = 'passenger_notifications';
  static const String riderChannelId = 'rider_notifications';
  
  // Notification categories
  static const String rideCategoryId = 'ride_notifications';
  static const String messageCategoryId = 'message_notifications';
  static const String promotionCategoryId = 'promotion_notifications';
  
  factory NotificationService() {
    return _instance;
  }
  
  NotificationService._internal();
  
  /// Initialize notification service
  Future<void> initialize() async {
    // Initialize for Android
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    
    // Initialize for iOS
    // Note: The onDidReceiveLocalNotification callback is for iOS versions < 10
    // and is deprecated in the latest version
    final DarwinInitializationSettings initializationSettingsIOS = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    
    // Initialize notification settings
    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );
    
    await _flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        _handleNotificationTap(response.payload);
      },
    );
    
    // Set up notification channels
    await _setupNotificationChannels();
  }
  
  /// Request notification permissions
  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final result = await _flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
      return result ?? false;
    } else if (Platform.isAndroid) {
      final AndroidFlutterLocalNotificationsPlugin? androidPlugin =
          _flutterLocalNotificationsPlugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>();
      
      if (androidPlugin != null) {
        // Android permission is handled differently in newer versions of flutter_local_notifications
        // Just return true as permission is handled via Android manifest
        return true;
      }
    }
    
    return false;
  }
  
  /// Set up notification channels
  Future<void> _setupNotificationChannels() async {
    if (Platform.isAndroid) {
      // Passenger channel
      AndroidNotificationChannel passengerChannel = const AndroidNotificationChannel(
        passengerChannelId,
        'Passenger Notifications',
        description: 'Notifications for passenger activities',
        importance: Importance.high,
      );
      
      // Rider channel
      AndroidNotificationChannel riderChannel = const AndroidNotificationChannel(
        riderChannelId,
        'Rider Notifications',
        description: 'Notifications for rider activities',
        importance: Importance.high,
      );
      
      // Create channels
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(passengerChannel);
          
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(riderChannel);
    }
  }
  
  // Handle notification tap
  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    
    try {
      debugPrint('Notification tapped with payload: $payload');
      // Here we can navigate to specific screens based on the payload
      // For now just print the payload
    } catch (e) {
      debugPrint('Error handling notification tap: $e');
    }
  }
  
  /// Show notification based on user role and category
  Future<void> showNotification({
    required UserRole userRole,
    required String title,
    required String body,
    required String category,
    String? payload,
    int? notificationId,
    String? recipientUserId,
  }) async {
    try {
      // Log detailed information about the notification
      debugPrint('🔔 SHOWING NOTIFICATION');
      debugPrint('  Role: ${userRole.toString()}');
      debugPrint('  Recipient ID: ${recipientUserId ?? 'Not specified'}');
      debugPrint('  Title: $title');
      debugPrint('  Body: $body');
      debugPrint('  Category: $category');
      
      // Validate the recipient user ID if provided
      if (recipientUserId != null) {
        try {
          final FirebaseFirestore _firestore = FirebaseFirestore.instance;
          final docSnapshot = await _firestore.collection('users').doc(recipientUserId).get();
          
          if (!docSnapshot.exists) {
            debugPrint('⚠️ Warning: Recipient user not found in database: $recipientUserId');
          } else {
            final userData = docSnapshot.data();
            if (userData != null) {
              final userRoleFromDB = _parseUserRole(userData['userRole'] as String?);
              if (userRoleFromDB != userRole) {
                debugPrint('⚠️ Warning: Recipient role mismatch. Specified: $userRole, Database: $userRoleFromDB');
                // Use the correct role from the database
                // userRole = userRoleFromDB;
              }
            }
          }
        } catch (e) {
          debugPrint('Error validating user: $e');
        }
      } else {
        debugPrint('⚠️ Warning: No recipient ID provided. Notification might not reach intended user.');
      }
      
      // Check if notifications are enabled for this role and category
      final bool isEnabled = await _isNotificationEnabled(userRole, category);
      if (!isEnabled) {
        debugPrint('🔕 Notification disabled for role: $userRole, category: $category');
        return;
      }
      
      // Use the appropriate channel ID based on user role
      final channelId = userRole == UserRole.passenger 
          ? passengerChannelId 
          : riderChannelId;
      
      // Generate a consistent notification ID from the recipient ID if provided
      int actualNotificationId;
      if (notificationId != null) {
        actualNotificationId = notificationId;
      } else if (recipientUserId != null) {
        // Generate a consistent ID based on recipient + timestamp for grouping related notifications
        actualNotificationId = (recipientUserId.hashCode + DateTime.now().millisecondsSinceEpoch.remainder(10000)).remainder(100000);
      } else {
        actualNotificationId = _generateUniqueId();
      }
      
      // Notification details for Android
      final AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        channelId,
        userRole == UserRole.passenger ? 'Passenger Notifications' : 'Rider Notifications',
        channelDescription: userRole == UserRole.passenger 
            ? 'Notifications for passenger activities'
            : 'Notifications for rider activities',
        importance: Importance.max,
        priority: Priority.high,
        enableLights: true,
        color: userRole == UserRole.passenger 
            ? const Color.fromARGB(255, 255, 150, 0) // Passenger color (orange)
            : const Color.fromARGB(255, 0, 150, 255), // Rider color (blue)
        // Make sure notification is shown on top of other apps
        fullScreenIntent: category == rideCategoryId,
      );
      
      // Notification details for iOS
      const DarwinNotificationDetails iosDetails = DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      );
      
      // Combined notification details
      final NotificationDetails notificationDetails = NotificationDetails(
        android: androidDetails,
        iOS: iosDetails,
      );
      
      // Show notification
      await _flutterLocalNotificationsPlugin.show(
        actualNotificationId,
        title,
        body,
        notificationDetails,
        payload: payload,
      );
      
      debugPrint('✅ Notification sent to ${userRole.toString()} user${recipientUserId != null ? ' with ID: $recipientUserId' : ''}');
    } catch (e) {
      debugPrint('❌ Error showing notification: $e');
    }
  }
  
  /// Show ride notification for passenger
  Future<void> showPassengerRideNotification({
    required String title,
    required String body,
    String? payload,
    int? notificationId,
    String? passengerId,
  }) async {
    return showNotification(
      userRole: UserRole.passenger,
      title: title,
      body: body,
      category: rideCategoryId,
      payload: payload,
      notificationId: notificationId,
      recipientUserId: passengerId,
    );
  }
  
  /// Show ride notification for rider
  Future<void> showRiderRideNotification({
    required String title,
    required String body,
    String? payload,
    int? notificationId,
    String? riderId,
  }) async {
    return showNotification(
      userRole: UserRole.rider,
      title: title,
      body: body,
      category: rideCategoryId,
      payload: payload,
      notificationId: notificationId,
      recipientUserId: riderId,
    );
  }
  
  /// Show message notification based on user role - specialized for chat messages
  Future<void> showMessageNotification({
    required UserRole userRole,
    required String title,
    required String body,
    String? payload,
    int? notificationId,
    String? userId,
  }) async {
    // Validate that we have a user ID for the notification
    if (userId == null || userId.isEmpty) {
      debugPrint('⚠️ Cannot send message notification: No user ID provided');
      return;
    }
    
    // First verify the user exists and has the correct role
    try {
      final FirebaseFirestore _firestore = FirebaseFirestore.instance;
      final docSnapshot = await _firestore.collection('users').doc(userId).get();
      
      if (!docSnapshot.exists) {
        debugPrint('⚠️ Cannot send message notification: User not found');
        return;
      }
      
      // Get the actual user role from the database
      final userData = docSnapshot.data();
      if (userData != null) {
        final actualUserRole = _parseUserRole(userData['userRole'] as String?);
        
        // If the specified role doesn't match the actual role, use the actual role
        if (actualUserRole != userRole) {
          debugPrint('⚠️ Correcting recipient role from $userRole to $actualUserRole');
          userRole = actualUserRole;
        }
      }
    } catch (e) {
      debugPrint('Error verifying message recipient: $e');
      // Continue with the provided role if verification fails
    }
    
    return showNotification(
      userRole: userRole,
      title: title,
      body: body,
      category: messageCategoryId,
      payload: payload,
      notificationId: notificationId,
      recipientUserId: userId,
    );
  }
  
  /// Show promotion notification based on user role
  Future<void> showPromotionNotification({
    required UserRole userRole,
    required String title,
    required String body,
    String? payload,
    int? notificationId,
  }) async {
    return showNotification(
      userRole: userRole,
      title: title,
      body: body,
      category: promotionCategoryId,
      payload: payload,
      notificationId: notificationId,
    );
  }
  
  /// Check if notifications are enabled for this role and category
  Future<bool> _isNotificationEnabled(UserRole userRole, String category) async {
    try {
      // Get preferences for the role
      final prefs = await _rolePreferenceService.getPreferencesForRole(userRole);
      
      // If notifications aren't configured yet, default to enabled
      if (!prefs.containsKey('notifications')) {
        return true;
      }
      
      // Get notification preferences
      final notificationPrefs = prefs['notifications'] as Map<String, dynamic>?;
      if (notificationPrefs == null) {
        return true;
      }
      
      // Check if notifications are enabled globally
      final bool globalEnabled = notificationPrefs['enabled'] as bool? ?? true;
      if (!globalEnabled) {
        return false;
      }
      
      // Check if this category is enabled
      final categories = notificationPrefs['categories'] as Map<String, dynamic>?;
      if (categories == null) {
        return true;
      }
      
      return categories[category] as bool? ?? true;
    } catch (e) {
      debugPrint('Error checking notification preferences: $e');
      return true; // Default to enabled on error
    }
  }
  
  /// Update notification settings for a role
  Future<void> updateNotificationSettings({
    required UserRole userRole,
    required bool enabled,
    required Map<String, bool> categorySettings,
  }) async {
    try {
      // Get current preferences
      final prefs = await _rolePreferenceService.getPreferencesForRole(userRole);
      
      // Create or update notification settings
      final notificationSettings = {
        'enabled': enabled,
        'categories': categorySettings,
      };
      
      // Update preferences
      prefs['notifications'] = notificationSettings;
      
      // Save updated preferences
      if (userRole == UserRole.passenger) {
        await _rolePreferenceService.savePassengerPreferences(prefs);
      } else {
        await _rolePreferenceService.saveRiderPreferences(prefs);
      }
      
      debugPrint('Updated notification settings for ${userRole.toString()}');
    } catch (e) {
      debugPrint('Error updating notification settings: $e');
    }
  }
  
  /// Get notification settings for a role
  Future<Map<String, dynamic>> getNotificationSettings(UserRole userRole) async {
    try {
      // Get preferences for the role
      final prefs = await _rolePreferenceService.getPreferencesForRole(userRole);
      
      // Get notification preferences or create default
      final notificationPrefs = prefs['notifications'] as Map<String, dynamic>? ?? {
        'enabled': true,
        'categories': {
          rideCategoryId: true,
          messageCategoryId: true,
          promotionCategoryId: true,
        },
      };
      
      return notificationPrefs;
    } catch (e) {
      debugPrint('Error getting notification settings: $e');
      
      // Return default settings on error
      return {
        'enabled': true,
        'categories': {
          rideCategoryId: true,
          messageCategoryId: true,
          promotionCategoryId: true,
        },
      };
    }
  }
  
  // Generate a unique ID for notifications
  int _generateUniqueId() {
    return DateTime.now().millisecondsSinceEpoch.remainder(100000);
  }
  
  /// Helper method to parse user role - same as in UserModel
  static UserRole _parseUserRole(String? role) {
    switch (role?.toLowerCase()) {
      case 'rider':
        return UserRole.rider;
      case 'passenger':
        return UserRole.passenger;
      default:
        return UserRole.passenger; // Default role
    }
  }
} 