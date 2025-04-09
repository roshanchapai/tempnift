import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/auth_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart'; // Import constants which contains UserRole

/// Service class to handle drawer-related operations
class DrawerService {
  final BuildContext context;
  final AuthService _authService = AuthService();
  
  DrawerService(this.context);
  
  /// Handle profile menu tap action
  Future<void> handleProfileTap(UserModel? user) async {
    if (user == null) {
      // Not logged in, navigate to auth screen
      _navigateToAuth();
      return;
    }
    
    // TODO: Navigate to profile screen
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile screen coming soon!')),
      );
    }
  }
  
  /// Handle settings menu tap action
  void handleSettingsTap() {
    // TODO: Navigate to settings screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Settings screen coming soon!')),
    );
  }
  
  /// Handle ride history menu tap action
  void handleHistoryTap() {
    // TODO: Navigate to ride history screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Ride history screen coming soon!')),
    );
  }
  
  /// Handle help and support menu tap action
  void handleHelpTap() {
    // TODO: Navigate to help screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Help & Support screen coming soon!')),
    );
  }
  
  /// Handle about menu tap action
  void handleAboutTap() {
    // TODO: Navigate to about screen
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('About screen coming soon!')),
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
      final newRole = user.userRole == UserRole.passenger 
          ? UserRole.rider 
          : UserRole.passenger;
      
      await _authService.updateUserRole(
        uid: user.uid,
        newRole: newRole,
      );
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role switched to ${newRole.toString().split('.').last}'),
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