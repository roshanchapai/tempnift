import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/notification_service.dart';
import 'package:nift_final/utils/constants.dart';

class NotificationSettingsScreen extends StatefulWidget {
  final UserModel user;

  const NotificationSettingsScreen({
    Key? key,
    required this.user,
  }) : super(key: key);

  @override
  State<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen> with SingleTickerProviderStateMixin {
  final NotificationService _notificationService = NotificationService();
  late TabController _tabController;
  bool _isLoading = true;
  
  // Passenger notification settings
  bool _passengerNotificationsEnabled = true;
  Map<String, bool> _passengerCategorySettings = {};
  
  // Rider notification settings
  bool _riderNotificationsEnabled = true;
  Map<String, bool> _riderCategorySettings = {};
  
  // Available roles for the user
  bool _userHasRiderRole = false;
  
  // Category labels for display
  final Map<String, String> _categoryLabels = {
    NotificationService.rideCategoryId: 'Ride Updates',
    NotificationService.messageCategoryId: 'Messages',
    NotificationService.promotionCategoryId: 'Promotions & Offers',
  };
  
  // Category descriptions
  final Map<String, String> _categoryDescriptions = {
    NotificationService.rideCategoryId: 'Updates about your ride status, driver location, etc.',
    NotificationService.messageCategoryId: 'Messages from drivers, support, and other users',
    NotificationService.promotionCategoryId: 'Special offers, discounts, and promotions',
  };
  
  // Category icons
  final Map<String, IconData> _categoryIcons = {
    NotificationService.rideCategoryId: Icons.local_taxi,
    NotificationService.messageCategoryId: Icons.message,
    NotificationService.promotionCategoryId: Icons.local_offer,
  };

  @override
  void initState() {
    super.initState();
    
    // Check if user has rider role (approved rider status)
    _userHasRiderRole = widget.user.riderStatus == 'approved';
    
    // Create tab controller with the appropriate number of tabs
    _tabController = TabController(
      length: _userHasRiderRole ? 2 : 1, 
      vsync: this
    );
    
    // Set initial tab based on current user role
    if (_userHasRiderRole) {
      _tabController.index = widget.user.userRole == UserRole.passenger ? 0 : 1;
    } else {
      _tabController.index = 0; // Only passenger tab available
    }
    
    // Load current notification settings
    _loadSettings();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  // Load notification settings for both roles
  Future<void> _loadSettings() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Load passenger settings
      final passengerSettings = await _notificationService.getNotificationSettings(UserRole.passenger);
      setState(() {
        _passengerNotificationsEnabled = passengerSettings['enabled'] as bool? ?? true;
        _passengerCategorySettings = Map<String, bool>.from(
          passengerSettings['categories'] as Map<dynamic, dynamic>? ?? {}
        );
      });
      
      // Only load rider settings if user has rider role
      if (_userHasRiderRole) {
        final riderSettings = await _notificationService.getNotificationSettings(UserRole.rider);
        setState(() {
          _riderNotificationsEnabled = riderSettings['enabled'] as bool? ?? true;
          _riderCategorySettings = Map<String, bool>.from(
            riderSettings['categories'] as Map<dynamic, dynamic>? ?? {}
          );
        });
      }
      
      // Ensure all categories have a value
      _ensureCategoriesExist();
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
      // Show error to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading notification settings: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Ensure all category settings exist
  void _ensureCategoriesExist() {
    for (final category in [
      NotificationService.rideCategoryId,
      NotificationService.messageCategoryId,
      NotificationService.promotionCategoryId,
    ]) {
      if (!_passengerCategorySettings.containsKey(category)) {
        _passengerCategorySettings[category] = true;
      }
      if (_userHasRiderRole && !_riderCategorySettings.containsKey(category)) {
        _riderCategorySettings[category] = true;
      }
    }
  }
  
  // Save passenger notification settings
  Future<void> _savePassengerSettings() async {
    try {
      await _notificationService.updateNotificationSettings(
        userRole: UserRole.passenger,
        enabled: _passengerNotificationsEnabled,
        categorySettings: _passengerCategorySettings,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Passenger notification settings saved')),
        );
      }
    } catch (e) {
      debugPrint('Error saving passenger notification settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }
  
  // Save rider notification settings
  Future<void> _saveRiderSettings() async {
    try {
      await _notificationService.updateNotificationSettings(
        userRole: UserRole.rider,
        enabled: _riderNotificationsEnabled,
        categorySettings: _riderCategorySettings,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rider notification settings saved')),
        );
      }
    } catch (e) {
      debugPrint('Error saving rider notification settings: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving settings: $e')),
        );
      }
    }
  }
  
  // Toggle a category setting for passenger
  void _togglePassengerCategory(String category, bool value) {
    setState(() {
      _passengerCategorySettings[category] = value;
    });
  }
  
  // Toggle a category setting for rider
  void _toggleRiderCategory(String category, bool value) {
    setState(() {
      _riderCategorySettings[category] = value;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Settings'),
        bottom: _userHasRiderRole ? TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Passenger Mode'),
            Tab(text: 'Rider Mode'),
          ],
          labelColor: AppColors.primaryColor,
          unselectedLabelColor: AppColors.secondaryTextColor,
          indicatorColor: AppColors.primaryColor,
        ) : null,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _userHasRiderRole 
            ? TabBarView(
                controller: _tabController,
                children: [
                  // Passenger notification settings
                  _buildNotificationSettings(
                    enabled: _passengerNotificationsEnabled,
                    onEnabledChanged: (value) {
                      setState(() {
                        _passengerNotificationsEnabled = value;
                      });
                    },
                    categorySettings: _passengerCategorySettings,
                    onCategoryChanged: _togglePassengerCategory,
                    onSave: _savePassengerSettings,
                    role: UserRole.passenger,
                  ),
                  
                  // Rider notification settings
                  _buildNotificationSettings(
                    enabled: _riderNotificationsEnabled,
                    onEnabledChanged: (value) {
                      setState(() {
                        _riderNotificationsEnabled = value;
                      });
                    },
                    categorySettings: _riderCategorySettings,
                    onCategoryChanged: _toggleRiderCategory,
                    onSave: _saveRiderSettings,
                    role: UserRole.rider,
                  ),
                ],
              )
            : _buildNotificationSettings( // Only passenger settings for non-riders
                enabled: _passengerNotificationsEnabled,
                onEnabledChanged: (value) {
                  setState(() {
                    _passengerNotificationsEnabled = value;
                  });
                },
                categorySettings: _passengerCategorySettings,
                onCategoryChanged: _togglePassengerCategory,
                onSave: _savePassengerSettings,
                role: UserRole.passenger,
              ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: () {
            // Save the currently visible tab's settings
            if (!_userHasRiderRole || _tabController.index == 0) {
              _savePassengerSettings();
            } else {
              _saveRiderSettings();
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Save Settings'),
        ),
      ),
    );
  }
  
  // Build notification settings section
  Widget _buildNotificationSettings({
    required bool enabled,
    required ValueChanged<bool> onEnabledChanged,
    required Map<String, bool> categorySettings,
    required void Function(String, bool) onCategoryChanged,
    required VoidCallback onSave,
    required UserRole role,
  }) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: [
        // Master toggle
        Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: SwitchListTile(
            title: Text(
              'Enable ${role == UserRole.passenger ? "Passenger" : "Rider"} Notifications',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            subtitle: Text(
              'Control all notifications for ${role == UserRole.passenger ? "passenger" : "rider"} mode',
            ),
            value: enabled,
            onChanged: onEnabledChanged,
            secondary: Icon(
              Icons.notifications,
              color: enabled ? AppColors.primaryColor : AppColors.secondaryTextColor,
              size: 28,
            ),
            activeColor: AppColors.primaryColor,
          ),
        ),
        
        // Only show category settings if notifications are enabled
        if (enabled) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Text(
              'Notification Categories',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          
          // Category switches - showing only the relevant categories for each role
          ...categorySettings.keys.map((category) {
            // Skip payment notifications since we don't have payment integration
            if (category == 'payment_notifications') {
              return const SizedBox.shrink();
            }
            
            // For rider role, ensure ride category is always shown first
            if (role == UserRole.rider && 
                category == NotificationService.rideCategoryId) {
              return _buildCategorySwitch(
                category: category,
                enabled: categorySettings[category] ?? true,
                onChanged: (value) => onCategoryChanged(category, value),
                description: 'Updates about ride requests and passenger information',
              );
            }
            
            // For passenger role, customize ride category description
            if (role == UserRole.passenger && 
                category == NotificationService.rideCategoryId) {
              return _buildCategorySwitch(
                category: category,
                enabled: categorySettings[category] ?? true,
                onChanged: (value) => onCategoryChanged(category, value),
                description: 'Updates about your ride status and driver location',
              );
            }
            
            return _buildCategorySwitch(
              category: category,
              enabled: categorySettings[category] ?? true,
              onChanged: (value) => onCategoryChanged(category, value),
            );
          }).where((widget) => widget != const SizedBox.shrink()).toList(),
          
          // Test notification button
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showTestNotification(role),
            icon: const Icon(Icons.send),
            label: const Text('Send Test Notification'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
        ],
      ],
    );
  }
  
  // Build a category toggle switch
  Widget _buildCategorySwitch({
    required String category,
    required bool enabled,
    required ValueChanged<bool> onChanged,
    String? description,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: SwitchListTile(
        title: Text(_categoryLabels[category] ?? category),
        subtitle: Text(description ?? _categoryDescriptions[category] ?? ''),
        value: enabled,
        onChanged: onChanged,
        secondary: Icon(
          _categoryIcons[category] ?? Icons.circle_notifications,
          color: enabled ? AppColors.primaryColor : AppColors.secondaryTextColor,
        ),
        activeColor: AppColors.primaryColor,
      ),
    );
  }
  
  // Show a test notification for the selected role
  void _showTestNotification(UserRole role) async {
    final title = role == UserRole.passenger 
        ? 'Test Passenger Notification' 
        : 'Test Rider Notification';
        
    final body = 'This is a test notification for ${role == UserRole.passenger ? "passenger" : "rider"} mode';
    
    try {
      await _notificationService.showNotification(
        userRole: role,
        title: title,
        body: body,
        category: NotificationService.rideCategoryId,
        payload: 'test_notification',
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test notification sent to ${role.toString().split('.').last} channel')),
        );
      }
    } catch (e) {
      debugPrint('Error sending test notification: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error sending test notification: $e')),
        );
      }
    }
  }
} 