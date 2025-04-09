import 'package:flutter/material.dart';
import 'package:nift_final/models/drawer_state.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/auth_screen.dart';
import 'package:nift_final/screens/map_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/services/drawer_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/widgets/app_drawer.dart';

class HomeScreen extends StatefulWidget {
  final UserModel user;
  
  const HomeScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final AuthService _authService = AuthService();
  late UserModel _currentUser;
  bool _isLoading = false;
  late DrawerState _drawerState;
  late DrawerService _drawerService;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
    _drawerState = DrawerState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _drawerService = DrawerService(context);
  }

  // Sign out
  Future<void> _signOut(BuildContext context) async {
    await _authService.signOut();
    if (context.mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const AuthScreen()),
      );
    }
  }

  // Switch user role
  Future<void> _switchRole(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final newRole = _currentUser.userRole == UserRole.passenger 
          ? UserRole.rider 
          : UserRole.passenger;
      
      await _authService.updateUserRole(
        uid: _currentUser.uid,
        newRole: newRole,
      );
      
      setState(() {
        _currentUser = _currentUser.copyWith(userRole: newRole);
        _isLoading = false;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role switched to ${newRole.toString().split('.').last}'),
            backgroundColor: AppColors.successColor,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to switch role: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _drawerState.scaffoldKey,
      drawer: AppDrawer(
        currentUser: _currentUser,
        onProfileTap: () => _drawerService.handleProfileTap(_currentUser),
        onSettingsTap: () => _drawerService.handleSettingsTap(),
        onHistoryTap: () => _drawerService.handleHistoryTap(),
        onHelpTap: () => _drawerService.handleHelpTap(),
        onAboutTap: () => _drawerService.handleAboutTap(),
        onLogoutTap: () => _drawerService.handleLogoutTap(),
        onSwitchRoleTap: () => _drawerService.handleSwitchRoleTap(_currentUser),
      ),
      onDrawerChanged: _drawerState.handleDrawerCallback,
      body: MapScreenWithDrawer(
        drawerState: _drawerState,
        user: _currentUser,
      ),
    );
  }

  void _showProfileModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => Container(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // User Avatar
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _currentUser.userRole == UserRole.rider
                    ? Icons.directions_car
                    : Icons.person,
                color: AppColors.primaryColor,
                size: 40,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // User Name
            Text(
              _currentUser.name ?? "User",
              style: AppTextStyles.headingStyle,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // User Role
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.accentColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                _currentUser.userRole == UserRole.rider ? 'Rider' : 'Passenger',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: AppColors.primaryColor,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Phone Number
            Text(
              'Phone: ${_currentUser.phoneNumber}',
              style: AppTextStyles.bodyStyle,
            ),
            
            const SizedBox(height: 24),
            
            // Role Switch Button
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _switchRole(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: _isLoading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Icon(
                      _currentUser.userRole == UserRole.passenger
                          ? Icons.directions_car
                          : Icons.person,
                    ),
              label: Text(
                _isLoading
                    ? 'Switching...'
                    : 'Switch to ${_currentUser.userRole == UserRole.passenger ? 'Rider' : 'Passenger'}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A wrapper around MapScreen that adds drawer functionality
class MapScreenWithDrawer extends StatelessWidget {
  final DrawerState drawerState;
  final UserModel user;
  
  const MapScreenWithDrawer({
    Key? key,
    required this.drawerState,
    required this.user,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Original Map Screen
        const MapScreen(),
        
        // Custom Hamburger Menu Button
        Positioned(
          top: MediaQuery.of(context).padding.top + 10,
          left: 16,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.menu),
              onPressed: () {
                drawerState.openDrawer();
              },
            ),
          ),
        ),
      ],
    );
  }
}
