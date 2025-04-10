import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nift_final/screens/admin/admin_dashboard_screen.dart';
import 'package:nift_final/screens/home_screen.dart';
import 'package:nift_final/screens/user_details_screen.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';

class AuthScreen extends StatefulWidget {
  const AuthScreen({Key? key}) : super(key: key);

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final AuthService _authService = AuthService();
  final TextEditingController _phoneController = TextEditingController();
  final List<TextEditingController> _otpControllers = List.generate(6, (index) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (index) => FocusNode());
  final FocusNode _phoneFocusNode = FocusNode();
  
  // State variables
  bool _isLoading = false;
  bool _otpSent = false;
  String _verificationId = '';
  String _errorMessage = '';
  int _resendTimer = 0;
  Timer? _timer;
  
  @override
  void initState() {
    super.initState();
    // Auto-focus the phone number field when the screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _phoneFocusNode.requestFocus();
    });
  }
  
  @override
  void dispose() {
    _phoneController.dispose();
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var node in _otpFocusNodes) {
      node.dispose();
    }
    _phoneFocusNode.dispose();
    _timer?.cancel();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer = 30; // 30 seconds cooldown
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_resendTimer > 0) {
          _resendTimer--;
        } else {
          timer.cancel();
        }
      });
    });
  }
  
  // Send OTP
  Future<void> _sendOTP() async {
    // Validate phone number
    if (_phoneController.text.isEmpty) {
      setState(() {
        _errorMessage = 'Please enter your phone number';
      });
      _phoneFocusNode.requestFocus();
      return;
    }
    
    if (!_phoneController.text.isValidPhone) {
      setState(() {
        _errorMessage = 'Please enter a valid 10-digit phone number';
      });
      _phoneFocusNode.requestFocus();
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      await _authService.sendOTP(
        phoneNumber: _phoneController.text,
        onVerificationId: (verificationId) {
          setState(() {
            _verificationId = verificationId;
            _otpSent = true;
            _isLoading = false;
          });
          _startResendTimer();
          // Auto-focus the first OTP field
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _otpFocusNodes[0].requestFocus();
          });
        },
        onCodeSent: (message) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
        },
        onVerificationFailed: (exception) {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Verification failed: ${exception.message}';
          });
          _phoneFocusNode.requestFocus();
        },
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error sending OTP: $e';
      });
      _phoneFocusNode.requestFocus();
    }
  }
  
  // Verify OTP and navigate to appropriate screen
  Future<void> _verifyOTP() async {
    // Combine OTP digits
    final String otpCode = _otpControllers.map((c) => c.text).join();
    if (otpCode.length != 6) {
      setState(() {
        _errorMessage = 'Please enter all 6 digits';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });
    
    try {
      debugPrint('Verifying OTP...');
      // Verify OTP with Firebase
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode: otpCode,
      );
      
      final userCredential = await _authService.signInWithCredential(credential);
      final uid = userCredential.user?.uid;
      
      if (uid == null) {
        throw Exception('Failed to sign in with credential');
      }
      
      // Check if this is an admin phone number
      final bool isAdmin = await _authService.isAdmin(_phoneController.text);
      
      if (isAdmin) {
        debugPrint('Admin user detected, navigating to admin dashboard');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen()
            ),
          );
        }
        return;
      }
      
      debugPrint('Authentication successful, checking if user exists...');
      
      // Check if user exists in database
      final userExists = await _authService.userExists(uid);
      debugPrint('User exists: $userExists');
      
      if (userExists) {
        // Existing user - Login flow
        debugPrint('Existing user, fetching user data');
        final userData = await _authService.getUserData(uid);
        debugPrint('User data fetched: ${userData?.name != null ? 'Complete' : 'Incomplete'}');
        
        if (userData != null && userData.name != null) {
          // User has completed profile - go to home screen
          debugPrint('User has complete profile, navigating to home screen');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (context) => HomeScreen(user: userData)),
            );
          }
        } else {
          // User needs to complete profile
          debugPrint('User needs to complete profile, navigating to user details screen');
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (context) => UserDetailsScreen(
                  phoneNumber: _phoneController.text,
                  userRole: UserRole.passenger,
                ),
              ),
            );
          }
        }
      } else {
        // New user - Signup flow
        debugPrint('New user, creating user record');
        await _authService.createNewUser(
          uid: uid,
          phoneNumber: _phoneController.text,
          userRole: UserRole.passenger, // All new users start as passengers
        );
        
        // Navigate to user details screen
        debugPrint('Navigating to user details screen');
        if (mounted) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (context) => UserDetailsScreen(
                phoneNumber: _phoneController.text,
                userRole: UserRole.passenger,
              ),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error verifying OTP: $e');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error verifying OTP: $e';
        // Clear OTP fields on error
        for (var controller in _otpControllers) {
          controller.clear();
        }
      });
      _otpFocusNodes[0].requestFocus();
    }
  }

  void _onOtpDigitChanged(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      _otpFocusNodes[index - 1].requestFocus();
    }
    
    // Auto-verify when all digits are entered
    if (index == 5 && value.isNotEmpty) {
      final otp = _otpControllers.map((c) => c.text).join();
      if (otp.length == 6) {
        _verifyOTP();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.primaryColor,
        title: const Text('Nift - Nepal Lift'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 20),
            
            // App Logo with animation
            Center(
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryColor.withOpacity(0.3),
                      blurRadius: 15,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.directions_car,
                  color: Colors.white,
                  size: 50,
                ),
              ),
            ),
            
            const SizedBox(height: 32),
            
            // Authentication Title with gradient
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: AppColors.primaryGradient,
              ).createShader(bounds),
              child: Text(
                _otpSent ? 'Verify OTP' : 'Login / Sign Up',
                style: AppTextStyles.headingStyle.copyWith(
                  color: Colors.white,
                  fontSize: 28,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 8),
            
            // Authentication Subtitle
            Text(
              _otpSent 
                ? 'Enter the 6-digit code sent to your phone'
                : 'Enter your phone number to continue',
              style: AppTextStyles.bodyStyle,
              textAlign: TextAlign.center,
            ),
            
            const SizedBox(height: 32),
            
            // Phone Number Input (visible if OTP not sent)
            if (!_otpSent) ...[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _phoneController,
                  focusNode: _phoneFocusNode,
                  keyboardType: TextInputType.number,
                  autofocus: true,
                  style: AppTextStyles.inputStyle.copyWith(
                    letterSpacing: 2,
                    fontSize: 20,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  decoration: InputDecoration(
                    labelText: 'Phone Number',
                    hintText: '98XXXXXXXX',
                    hintStyle: AppTextStyles.hintStyle,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    prefixIcon: Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(right: 8),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          bottomLeft: Radius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.phone_android,
                            color: AppColors.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '+977',
                            style: TextStyle(
                              color: AppColors.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                  ),
                  onSubmitted: (_) => _sendOTP(),
                ),
              ),
            ],
            
            // OTP Input (visible after OTP sent)
            if (_otpSent) ...[
              Column(
                children: [
                  // OTP Title
                  Text(
                    'Enter Verification Code',
                    style: AppTextStyles.subtitleStyle,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  
                  // OTP Input Fields
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(
                      6,
                      (index) => SizedBox(
                        width: 45,
                        height: 55,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 5),
                              ),
                            ],
                            border: Border.all(
                              color: _otpFocusNodes[index].hasFocus 
                                  ? AppColors.primaryColor 
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: TextField(
                            controller: _otpControllers[index],
                            focusNode: _otpFocusNodes[index],
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: AppTextStyles.inputStyle.copyWith(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                            ),
                            maxLength: 1,
                            decoration: InputDecoration(
                              counterText: '',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: EdgeInsets.zero,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              LengthLimitingTextInputFormatter(1),
                            ],
                            onChanged: (value) {
                              if (value.isNotEmpty) {
                                _onOtpDigitChanged(index, value);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Resend OTP option with timer
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Didn't receive the code?",
                        style: AppTextStyles.captionStyle,
                      ),
                      TextButton(
                        onPressed: _resendTimer > 0 ? null : _sendOTP,
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: Text(
                          _resendTimer > 0
                              ? 'Resend in ${_resendTimer}s'
                              : 'Resend',
                          style: TextStyle(
                            color: _resendTimer > 0
                                ? AppColors.primaryColor.withOpacity(0.5)
                                : AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
            
            const SizedBox(height: 24),
            
            // Error Message (if any)
            if (_errorMessage.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: AppColors.errorColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.errorColor.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: AppColors.errorColor,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: AppColors.errorColor,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            
            const SizedBox(height: 24),
            
            // Action Button (Send OTP or Verify OTP)
            ElevatedButton(
              onPressed: _isLoading ? null : (_otpSent ? _verifyOTP : _sendOTP),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryColor,
                foregroundColor: AppColors.lightTextColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                textStyle: AppTextStyles.buttonTextStyle,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _otpSent ? Icons.check_circle : Icons.send,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(_otpSent ? 'Verify' : 'Send OTP'),
                      ],
                    ),
            ),
            
            // Back Button (visible after OTP sent)
            if (_otpSent)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _otpSent = false;
                      for (var controller in _otpControllers) {
                        controller.clear();
                      }
                      _timer?.cancel();
                      _resendTimer = 0;
                      _phoneFocusNode.requestFocus();
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Change Phone Number'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primaryColor,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}