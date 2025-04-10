import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/auth_screen.dart';
import 'package:nift_final/screens/role_switch_screen.dart';
import 'package:nift_final/screens/profile_screen.dart';
import 'package:nift_final/screens/settings_screen.dart';
import 'package:nift_final/screens/ride_history_screen.dart';
import 'package:nift_final/screens/help_support_screen.dart';
import 'package:nift_final/screens/about_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart'; // Import constants which contains UserRole

/// Service class to handle drawer-related operations
class DrawerService {
  final BuildContext context;
  final AuthService _authService = AuthService();
  
  // Callback function to update the parent with the new user model after role switch
  Function(UserModel? updatedUser)? _roleSwitchCallback;
  
  DrawerService(this.context);
  
  // Set up the callback for role switching
  void setRoleSwitchCallback(Function(UserModel? updatedUser) callback) {
    _roleSwitchCallback = callback;
  }
  
  /// Handle profile menu tap action
  Future<void> handleProfileTap(UserModel? user) async {
    if (user == null) {
      // Not logged in, navigate to auth screen
      _navigateToAuth();
      return;
    }
    
    // Navigate to profile screen
    if (context.mounted) {
      final updatedUser = await Navigator.of(context).push<UserModel>(
        MaterialPageRoute(builder: (context) => ProfileScreen(user: user)),
      );
      
      // If we got an updated user back, call the callback
      if (updatedUser != null && _roleSwitchCallback != null) {
        _roleSwitchCallback!(updatedUser);
      }
    }
  }
  
  /// Handle settings menu tap action
  void handleSettingsTap() {
    // Navigate to settings screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const SettingsScreen()),
    );
  }
  
  /// Handle ride history menu tap action
  void handleHistoryTap(UserModel? user) {
    if (user == null) {
      // Not logged in, navigate to auth screen
      _navigateToAuth();
      return;
    }
    
    // Navigate to ride history screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => RideHistoryScreen(user: user)),
    );
  }
  
  /// Handle help and support menu tap action
  void handleHelpTap(UserModel? user) {
    // Navigate to help screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => HelpSupportScreen(user: user)),
    );
  }
  
  /// Handle about menu tap action
  void handleAboutTap() {
    // Navigate to about screen
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const AboutScreen()),
    );
  }
  
  /// Handle logout menu tap action
  Future<void> handleLogoutTap() async {
    try {
      final bool confirm = await _showLogoutConfirmationDialog();
      if (confirm && context.mounted) {
        await _authService.signOut();
        
        // Navigate to auth screen after logout
        if (context.mounted) {
          _navigateToAuth();
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging out: $e')),
        );
      }
    }
  }
  
  /// Handle role switching menu tap action
  Future<void> handleSwitchRoleTap(UserModel? user) async {
    if (user == null) {
      _navigateToAuth();
      return;
    }
    
    try {
      // Navigate to role switch screen
      final updatedUser = await Navigator.of(context).push<UserModel>(
        MaterialPageRoute(
          builder: (context) => RoleSwitchScreen(user: user),
        ),
      );
      
      // If we received an updated user model back, we can use it
      // otherwise, do nothing as the user likely cancelled
      if (updatedUser != null && context.mounted) {
        // Call the callback to update the parent component
        if (_roleSwitchCallback != null) {
          _roleSwitchCallback!(updatedUser);
        }
        
        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Switched to ${updatedUser.userRole == UserRole.rider ? 'Rider' : 'Passenger'} mode'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error switching role: $e')),
        );
      }
    }
  }
  
  /// Show confirmation dialog before logout
  Future<bool> _showLogoutConfirmationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout Confirmation'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    
    return result ?? false;
  }
  
  /// Navigate to auth screen
  void _navigateToAuth() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const AuthScreen()),
    );
  }
} 