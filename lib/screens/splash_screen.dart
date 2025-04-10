import 'dart:async';
import 'package:flutter/material.dart';
import 'package:nift_final/screens/admin/admin_dashboard_screen.dart';
import 'package:nift_final/screens/auth_screen.dart';
import 'package:nift_final/screens/home_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/widgets/nift_logo.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  final AuthService _authService = AuthService();
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
    if (!mounted) return;
    
    try {
      if (_authService.isLoggedIn) {
        // User is logged in
        final userData = await _authService.getUserData(_authService.currentUserId!);
        
        if (!mounted) return;
        
        if (userData != null) {
          // Check if user is admin
          final isAdmin = await _authService.isAdmin(userData.phoneNumber);
          
          if (isAdmin) {
            // Navigate to admin dashboard
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AdminDashboardScreen()),
            );
            return;
          }
          
          if (userData.name != null) {
            // User has completed profile
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => HomeScreen(user: userData)),
            );
          } else {
            // User needs to complete profile
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => const AuthScreen()),
            );
          }
        } else {
          // User data not found, redirect to auth
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (context) => const AuthScreen()),
          );
        }
      } else {
        // User is not logged in
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const AuthScreen()),
        );
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
              
              const SizedBox(height: 8),
              
              // App Tagline
              Text(
                'Less Traffic, More Connection',
                style: TextStyle(
                  fontSize: 20,
                  color: AppColors.primaryTextColor,
                  letterSpacing: 1.2,
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Loading Indicator
              SizedBox(
                width: 40,
                height: 40,
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(AppColors.primaryColor),
                  strokeWidth: 3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
