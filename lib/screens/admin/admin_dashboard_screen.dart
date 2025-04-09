import 'package:flutter/material.dart';
import 'package:nift_final/screens/admin/rider_applications_screen.dart';
import 'package:nift_final/screens/admin/user_management_screen.dart';
import 'package:nift_final/screens/auth_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';

class AdminDashboardScreen extends StatelessWidget {
  const AdminDashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        elevation: 0,
        actions: [
          // Logout button
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: () => _confirmLogout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome header
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Admin Control Panel',
                style: AppTextStyles.headingStyle,
              ),
            ),
            
            // Dashboard cards grid
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                children: [
                  _buildDashboardCard(
                    context: context,
                    title: 'Rider Applications',
                    icon: Icons.app_registration,
                    color: AppColors.primaryColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const RiderApplicationsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    context: context,
                    title: 'Manage Users',
                    icon: Icons.people,
                    color: AppColors.accentColor,
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const UserManagementScreen(),
                        ),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    context: context,
                    title: 'Ride Requests',
                    icon: Icons.directions_car,
                    color: AppColors.secondaryColor,
                    onTap: () {
                      // TODO: Navigate to ride requests screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ride requests coming soon')),
                      );
                    },
                  ),
                  _buildDashboardCard(
                    context: context,
                    title: 'Analytics',
                    icon: Icons.analytics,
                    color: AppColors.infoColor,
                    onTap: () {
                      // TODO: Navigate to analytics screen
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Analytics coming soon')),
                      );
                    },
                  ),
                ],
              ),
            ),
            
            // Admin info footer
            Padding(
              padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
              child: Center(
                child: Text(
                  'NIFT Admin Console',
                  style: AppTextStyles.captionStyle.copyWith(
                    color: AppColors.secondaryTextColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Show logout confirmation dialog
  Future<void> _confirmLogout(BuildContext context) async {
    final authService = AuthService();
    
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout from the admin dashboard?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.errorColor,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    
    if (confirmed == true && context.mounted) {
      try {
        await authService.signOut();
        
        // Navigate to auth screen
        if (context.mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
            (route) => false, // Remove all previous routes
          );
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error logging out: $e'),
              backgroundColor: AppColors.errorColor,
            ),
          );
        }
      }
    }
  }

  Widget _buildDashboardCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: color,
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: AppTextStyles.subtitleStyle,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 