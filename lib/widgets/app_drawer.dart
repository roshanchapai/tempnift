import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
    final bool isRider = isLoggedIn && currentUser!.userRole == UserRole.rider;

    return Drawer(
      child: Column(
        children: [
          // Enhanced Header with user info
          Container(
            padding: const EdgeInsets.only(top: 50, bottom: 20),
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: AppColors.primaryGradient,
              ),
            ),
            child: Column(
              children: [
                // Profile Image
                Hero(
                  tag: 'profile-picture',
                  child: GestureDetector(
                    onTap: isRider ? null : onProfileTap,
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: AppColors.lightTextColor,
                          width: 3,
                        ),
                      ),
                      child: ClipOval(
                        child: isLoggedIn && currentUser!.profileImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: currentUser!.profileImageUrl!,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => CircularProgressIndicator(),
                              errorWidget: (context, url, error) => Icon(
                                Icons.person,
                                color: AppColors.primaryColor,
                                size: 60,
                              ),
                            )
                          : Container(
                              color: AppColors.lightTextColor,
                              child: Icon(
                                Icons.person,
                                color: AppColors.primaryColor,
                                size: 60,
                              ),
                            ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // User Name
                Text(
                  userName,
                  style: AppTextStyles.bodyBoldStyle.copyWith(
                    color: AppColors.lightTextColor,
                    fontSize: 20,
                  ),
                ),
                
                const SizedBox(height: 4),
                
                // User Phone
                Text(
                  userPhone,
                  style: AppTextStyles.captionStyle.copyWith(
                    color: AppColors.lightTextColor.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
                
                const SizedBox(height: 8),
                
                // User Role Badge
                if (userRole.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4),
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.lightTextColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(16),
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
          ),
          
          // Menu Items with enhanced appearance
          const SizedBox(height: 8),
          
          _buildMenuItem(
            context: context,
            icon: Icons.person_outline,
            title: 'My Profile',
            onTap: () {
              Navigator.pop(context); // Close drawer
              onProfileTap();
            },
          ),
          
          _buildMenuItem(
            context: context,
            icon: Icons.history,
            title: 'Ride History',
            onTap: () {
              Navigator.pop(context); // Close drawer
              onHistoryTap();
            },
          ),
          
          if (isLoggedIn)
            _buildMenuItem(
              context: context,
              icon: Icons.swap_horiz,
              title: 'Switch to ${currentUser!.userRole == UserRole.rider ? 'Passenger' : 'Rider'} Mode',
              onTap: () {
                Navigator.pop(context); // Close drawer
                onSwitchRoleTap();
              },
            ),
          
          _buildMenuItem(
            context: context,
            icon: Icons.settings_outlined,
            title: 'Settings',
            onTap: () {
              Navigator.pop(context); // Close drawer
              onSettingsTap();
            },
          ),
          
          _buildMenuItem(
            context: context,
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              Navigator.pop(context); // Close drawer
              onHelpTap();
            },
          ),
          
          _buildMenuItem(
            context: context,
            icon: Icons.info_outline,
            title: 'About',
            onTap: () {
              Navigator.pop(context); // Close drawer
              onAboutTap();
            },
          ),
          
          const Divider(height: 16),
          
          _buildMenuItem(
            context: context,
            icon: Icons.logout,
            title: 'Logout',
            textColor: AppColors.errorColor,
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
  
  // Helper method to build menu items with consistent styling
  Widget _buildMenuItem({
    required BuildContext context,
    required IconData icon,
    required String title,
    required Function() onTap,
    Color? iconColor,
    Color? textColor,
  }) {
    return ListTile(
      leading: Icon(
        icon, 
        color: iconColor ?? Theme.of(context).iconTheme.color,
        size: 24,
      ),
      title: Text(
        title,
        style: AppTextStyles.bodyStyle.copyWith(
          color: textColor ?? AppColors.primaryTextColor,
        ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      dense: true,
      visualDensity: VisualDensity.adaptivePlatformDensity,
    );
  }
} 