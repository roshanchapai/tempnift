import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/admin/admin_dashboard_screen.dart';
import 'package:nift_final/screens/auth_screen.dart';
import 'package:nift_final/screens/home_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/services/ride_session_service.dart';
import 'package:nift_final/services/role_preference_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/widgets/nift_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
  final RideSessionService _rideSessionService = RideSessionService();
  final RolePreferenceService _rolePreferenceService = RolePreferenceService();
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  @override
  void initState() {
    super.initState();
    
    // Setup fade animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeIn,
      ),
    );
    
    // Start animation
    _animationController.forward();
    
    // Check authentication status after splash duration
    Timer(AppConstants.defaultSplashDuration, () {
      _checkAuthStatus();
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Check if user is logged in
  Future<void> _checkAuthStatus() async {
    try {
      final user = await _authService.getCurrentUser();
      
      if (user == null) {
        // Not logged in, navigate to auth screen
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
        return;
      }
      
      // Check if the user is an admin
      final isAdmin = await _authService.isAdmin(user.phoneNumber);
      
      if (mounted) {
        if (isAdmin) {
          // Admin user, navigate to admin dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
          );
        } else {
          // Check for active rides first (highest priority)
          await _rideSessionService.checkAndNavigateToActiveRide(context, user);
          
          // If no active ride found, check for role-specific preferences
          if (mounted) {
            // Load preferences for the user's current role
            final rolePrefs = await _rolePreferenceService.getPreferencesForRole(user.userRole);
            final lastView = await _rolePreferenceService.getLastViewForRole(user.userRole);
            
            debugPrint('Loaded role preferences for ${user.userRole}: ${rolePrefs.toString()}');
            if (lastView != null) {
              debugPrint('Last view for ${user.userRole}: ${lastView['viewName']}');
              // Could implement navigation to last view here if needed
            }
            
            // Navigate to home screen
            if (mounted) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (context) => HomeScreen(user: user)),
              );
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error checking auth status: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
        // Navigate to auth screen on error
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // App Logo
              Container(
                width: 240,
                height: 240,
                decoration: BoxDecoration(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.transparent,
                      blurRadius: 20,
                      offset: const Offset(0, 15),
                    ),
                  ],
                ),
                child: const NiftLogo(size: 48.0),
              ),
              
              const SizedBox(height: 24),
              
              // App Name
              Text(
                'Nepal Lift',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                  shadows: [
                    Shadow(
                      color: AppColors.primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Loading indicator
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(
                  AppColors.primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
