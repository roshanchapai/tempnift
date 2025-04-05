import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:nift_final/screens/home_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';

class UserDetailsScreen extends StatefulWidget {
  final String phoneNumber;
  final UserRole userRole;

  const UserDetailsScreen({
    Key? key,
    required this.phoneNumber,
    required this.userRole,
  }) : super(key: key);

  @override
  State<UserDetailsScreen> createState() => _UserDetailsScreenState();
}

class _UserDetailsScreenState extends State<UserDetailsScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _nameController = TextEditingController();
  
  // State variables
  bool _isLoading = false;
  String _errorMessage = '';
  DateTime? _selectedDate;
  
  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  // Open date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(2000),
      firstDate: DateTime(1950),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)), // Minimum 16 years old
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }
  
  // Save user details
  Future<void> _saveUserDetails() async {
    // Validate inputs
    if (_nameController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your name';
      });
      return;
    }
    
    if (_selectedDate == null) {
      setState(() {
        _errorMessage = 'Please select your date of birth';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      await _authService.updateUserDetails(
        uid: _authService.currentUserId!,
        name: _nameController.text.trim(),
        dateOfBirth: _selectedDate!,
      );
      
      // Get updated user data
      final userData = await _authService.getUserData(_authService.currentUserId!);
      
      if (userData != null && mounted) {
        // Navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomeScreen(user: userData)),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error saving user details: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Format selected date
    final dateFormat = DateFormat('dd MMM, yyyy');
    final formattedDate = _selectedDate != null 
        ? dateFormat.format(_selectedDate!) 
        : 'Select Date';
    
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        title: const Text('Complete Your Profile'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // Profile Icon
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.surfaceColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.userRole == UserRole.rider
                      ? Icons.directions_car
                      : Icons.person,
                  color: AppColors.primaryColor,
                  size: 60,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Profile Title
            Text(
              'Welcome to Nift!',
              style: AppTextStyles.headingStyle,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 8),
            
            // Profile Subtitle
            Text(
              'Please provide the following details to complete your profile',
              style: AppTextStyles.bodyStyle,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // User Role Info
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.accentColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: AppColors.primaryColor,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          'You can be both a passenger and a rider!',
                          style: AppTextStyles.subtitleStyle,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Switch between roles anytime from your profile',
                    style: AppTextStyles.captionStyle,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Name Input
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name',
                hintText: 'Enter your full name',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.words,
            ),
            
            const SizedBox(height: 24),
            
            // Date of Birth Selector
            GestureDetector(
              onTap: () => _selectDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(
                        fontSize: 16,
                        color: _selectedDate == null 
                            ? Colors.grey.shade600 
                            : AppColors.primaryTextColor,
                      ),
                    ),
                    const Icon(Icons.calendar_today),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Error Message (if any)
            if (_errorMessage.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(
                  _errorMessage,
                  style: const TextStyle(
                    color: Colors.red,
                    fontSize: 14,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            
            // Save Button
            ElevatedButton(
              onPressed: _isLoading ? null : _saveUserDetails,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                textStyle: AppTextStyles.buttonTextStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : const Text('Save & Continue'),
            ),
          ],
        ),
      ),
    );
  }
}
