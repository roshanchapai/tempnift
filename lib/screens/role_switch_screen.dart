import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/screens/rider_registration_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/services/role_preference_service.dart';
import 'package:nift_final/utils/constants.dart';

class RoleSwitchScreen extends StatefulWidget {
  final UserModel user;

  const RoleSwitchScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<RoleSwitchScreen> createState() => _RoleSwitchScreenState();
}

class _RoleSwitchScreenState extends State<RoleSwitchScreen> {
  final AuthService _authService = AuthService();
  final RolePreferenceService _rolePreferenceService = RolePreferenceService();
  late UserModel _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _currentUser = widget.user;
  }

  // Save current role state before switching
  Future<void> _saveCurrentRoleState() async {
    final currentRole = _currentUser.userRole;
    final currentView = ModalRoute.of(context)?.settings.name ?? 'home_screen';
    
    try {
      if (currentRole == UserRole.passenger) {
        await _rolePreferenceService.saveLastPassengerView(currentView);
      } else {
        await _rolePreferenceService.saveLastRiderView(currentView);
      }
    } catch (e) {
      debugPrint('Error saving role state: $e');
    }
  }

  // Switch user role
  Future<void> _switchRole() async {
    if (_isLoading) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Save current role state before switching
      await _saveCurrentRoleState();
      
      final newRole = _currentUser.userRole == UserRole.passenger
          ? UserRole.rider
          : UserRole.passenger;

      // If switching to rider, check the rider status first
      if (newRole == UserRole.rider) {
        // TODO: Check rider status from Firestore
        // For now, let's assume rider status is stored in the user model
        // We'll need to enhance this later
        
        // If not applied or rejected, navigate to rider registration
        if (_currentUser.riderStatus == 'not_applied' || 
            _currentUser.riderStatus == 'rejected') {
          setState(() {
            _isLoading = false;
          });
          
          if (context.mounted) {
            final updatedUser = await Navigator.of(context).push<UserModel>(
              MaterialPageRoute(
                builder: (context) => RiderRegistrationScreen(user: _currentUser),
              ),
            );
            
            // If we got an updated user back from registration, return it
            if (updatedUser != null && context.mounted) {
              Navigator.of(context).pop(updatedUser);
            }
          }
          return;
        }
        
        // If pending, show message and don't switch
        if (_currentUser.riderStatus == 'pending') {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Your rider application is still under review.';
          });
          return;
        }
        
        // If not approved, show message and don't switch
        if (_currentUser.riderStatus != 'approved') {
          setState(() {
            _isLoading = false;
            _errorMessage = 'You need to be approved as a rider first.';
          });
          return;
        }
      }

      // Proceed with role switch
      await _authService.updateUserRole(
        uid: _currentUser.uid,
        newRole: newRole,
      );

      // Update local user model
      final updatedUser = _currentUser.copyWith(userRole: newRole);
      
      setState(() {
        _currentUser = updatedUser;
        _isLoading = false;
      });

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Role switched to ${newRole.toString().split('.').last}'),
            backgroundColor: AppColors.successColor,
          ),
        );
        
        // Close the screen and return the updated user model
        Navigator.of(context).pop(updatedUser);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to switch role: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isPassenger = _currentUser.userRole == UserRole.passenger;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Switch Role'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Current Mode Icon
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPassenger ? Icons.person : Icons.directions_car,
                  color: AppColors.primaryColor,
                  size: 64,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Current Mode Text
              Text(
                'You are currently in',
                style: AppTextStyles.subtitleStyle.copyWith(
                  color: AppColors.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 8),
              
              // Current Mode Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Text(
                  isPassenger ? 'PASSENGER MODE' : 'RIDER MODE',
                  style: AppTextStyles.bodyBoldStyle.copyWith(
                    color: AppColors.lightTextColor,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              // Switch Mode Section
              Text(
                'Switch to',
                style: AppTextStyles.subtitleStyle.copyWith(
                  color: AppColors.secondaryTextColor,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              // Target Mode Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isPassenger ? Icons.directions_car : Icons.person,
                  color: AppColors.accentColor,
                  size: 48,
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Target Mode Text
              Text(
                isPassenger ? 'RIDER MODE' : 'PASSENGER MODE',
                style: AppTextStyles.bodyBoldStyle.copyWith(
                  color: AppColors.accentColor,
                  letterSpacing: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              
              const SizedBox(height: 16),
              
              if (!isPassenger || _currentUser.riderStatus == 'approved')
                Text(
                  isPassenger 
                      ? 'Start offering rides to passengers'
                      : 'Start booking rides as a passenger',
                  style: AppTextStyles.captionStyle,
                  textAlign: TextAlign.center,
                ),
                
              if (isPassenger && _currentUser.riderStatus != 'approved')
                Text(
                  _currentUser.riderStatus == 'not_applied'
                      ? 'You need to register as a rider first'
                      : _currentUser.riderStatus == 'pending'
                          ? 'Your rider application is under review'
                          : 'Your rider application was rejected',
                  style: AppTextStyles.captionStyle.copyWith(
                    color: _currentUser.riderStatus == 'rejected' 
                        ? AppColors.errorColor 
                        : AppColors.secondaryTextColor,
                  ),
                  textAlign: TextAlign.center,
                ),
              
              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Text(
                    _errorMessage!,
                    style: AppTextStyles.captionStyle.copyWith(
                      color: AppColors.errorColor,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              
              const SizedBox(height: 32),
              
              // Switch Role Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _switchRole,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryColor,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : Text(
                          isPassenger 
                              ? (_currentUser.riderStatus == 'not_applied' || _currentUser.riderStatus == 'rejected')
                                  ? 'Register as Rider'
                                  : _currentUser.riderStatus == 'pending'
                                      ? 'View Application Status'
                                      : 'Switch to Rider Mode'
                              : 'Switch to Passenger Mode',
                          style: AppTextStyles.buttonTextStyle,
                        ),
                ),
              ),
              
              const SizedBox(height: 16),
              
              // Cancel Button
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(
                  'Cancel',
                  style: TextStyle(
                    color: AppColors.secondaryTextColor,
                    fontSize: 16,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 