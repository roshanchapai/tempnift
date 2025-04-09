import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';

class AppDrawer extends StatelessWidget {
  final UserModel? currentUser;
  final Function() onProfileTap;
  final Function() onSettingsTap;
  final Function() onHistoryTap;
  final Function() onHelpTap;
  final Function() onAboutTap;
  final Function() onLogoutTap;
  final Function() onSwitchRoleTap;

  const AppDrawer({
    Key? key,
    this.currentUser,
    required this.onProfileTap,
    required this.onSettingsTap,
    required this.onHistoryTap,
    required this.onHelpTap,
    required this.onAboutTap,
    required this.onLogoutTap,
    required this.onSwitchRoleTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final bool isLoggedIn = currentUser != null;
    final String userName = isLoggedIn ? (currentUser!.name ?? 'User') : 'Guest';
    final String userPhone = isLoggedIn ? (currentUser!.phoneNumber) : '';
    final String userRole = isLoggedIn 
        ? (currentUser!.userRole == UserRole.rider ? 'Rider' : 'Passenger') 
        : '';

    return Drawer(
      child: Column(
        children: [
          // Header with user info
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              color: AppColors.primaryColor,
            ),
            accountName: Text(
              userName,
              style: AppTextStyles.bodyBoldStyle.copyWith(
                color: AppColors.lightTextColor,
              ),
            ),
            accountEmail: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  userPhone,
                  style: AppTextStyles.captionStyle.copyWith(
                    color: AppColors.lightTextColor,
                  ),
                ),
                if (userRole.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.lightTextColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      userRole,
                      style: AppTextStyles.captionStyle.copyWith(
                        color: AppColors.lightTextColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.lightTextColor,
              child: Icon(
                Icons.person,
                color: AppColors.primaryColor,
                size: 36,
              ),
            ),
          ),
          
          // Menu Items
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('My Profile'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              onProfileTap();
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Ride History'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              onHistoryTap();
            },
          ),
          
          if (isLoggedIn)
            ListTile(
              leading: const Icon(Icons.swap_horiz),
              title: Text('Switch to ${currentUser!.userRole == UserRole.rider ? 'Passenger' : 'Rider'} Mode'),
              onTap: () {
                Navigator.pop(context); // Close drawer
                onSwitchRoleTap();
              },
            ),
          
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('Settings'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              onSettingsTap();
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Help & Support'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              onHelpTap();
            },
          ),
          
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('About'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              onAboutTap();
            },
          ),
          
          const Divider(),
          
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: () {
              Navigator.pop(context); // Close drawer
              onLogoutTap();
            },
          ),
          
          // Bottom version info
          const Spacer(),
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Version 1.0.0',
              style: AppTextStyles.captionStyle,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
} 