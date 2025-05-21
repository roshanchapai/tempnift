import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/utils/retry_helper.dart';
import 'package:flutter/foundation.dart';
import 'package:nift_final/services/cloudinary_service.dart';
import 'dart:io';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final CloudinaryService _cloudinaryService = CloudinaryService();
  
  // Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;
  
  // Check if user is logged in
  bool get isLoggedIn => _auth.currentUser != null;

  // Get the current user
  User? get currentUser => _auth.currentUser;

  // Send OTP to phone number
  Future<void> sendOTP({
    required String phoneNumber,
    required Function(String) onVerificationId,
    required Function(String) onCodeSent,
    required Function(FirebaseAuthException) onVerificationFailed,
  }) async {
    if (!phoneNumber.isValidPhone) {
      throw FirebaseAuthException(
        code: 'invalid-phone-number',
        message: 'Please enter a valid phone number',
      );
    }

    // Format phone number to include country code if needed
    String formattedPhone = phoneNumber;
    if (!phoneNumber.startsWith('+')) {
      // Assuming Nepal country code +977
      formattedPhone = '+977$phoneNumber';
    }
    
    debugPrint('Sending OTP to: $formattedPhone');
    
    await _auth.verifyPhoneNumber(
      phoneNumber: formattedPhone,
      verificationCompleted: (PhoneAuthCredential credential) async {
        debugPrint('Auto-verification completed');
        try {
          await _auth.signInWithCredential(credential);
          debugPrint('Auto sign-in successful');
        } catch (e) {
          debugPrint('Auto sign-in failed: $e');
        }
      },
      verificationFailed: (exception) {
        debugPrint('Verification failed: ${exception.code} - ${exception.message}');
        onVerificationFailed(exception);
      },
      codeSent: (String verificationId, int? resendToken) {
        debugPrint('Code sent successfully. VerificationId: $verificationId');
        onVerificationId(verificationId);
        onCodeSent('OTP sent to $formattedPhone');
      },
      codeAutoRetrievalTimeout: (String verificationId) {
        debugPrint('Code auto retrieval timed out');
      },
      timeout: const Duration(seconds: 60),
    );
  }

  // Verify OTP
  Future<UserCredential> verifyOTP(String verificationId, String otp) async {
    debugPrint('Verifying OTP: $otp with verificationId: $verificationId');
    
    return RetryHelper.retry(
      operation: () async {
        try {
          // Create a PhoneAuthCredential with the code
          PhoneAuthCredential credential = PhoneAuthProvider.credential(
            verificationId: verificationId,
            smsCode: otp,
          );

          // Sign in
          final userCredential = await _auth.signInWithCredential(credential);
          debugPrint('OTP verification successful: ${userCredential.user?.uid}');
          return userCredential;
        } catch (e) {
          debugPrint('OTP verification failed: $e');
          rethrow;
        }
      },
      maxAttempts: 3,
      shouldRetry: (e) => e is FirebaseAuthException && e.code == 'invalid-verification-code',
    );
  }

  // Check if user exists in Firestore
  Future<bool> checkUserExists(String uid) async {
    return RetryHelper.retry(
      operation: () async {
        final doc = await _firestore.collection('users').doc(uid).get();
        return doc.exists;
      },
    );
  }

  // Create new user in Firestore
  Future<void> createNewUser({
    required String uid,
    required String phoneNumber,
    required UserRole userRole,
  }) async {
    return RetryHelper.retry(
      operation: () async {
        final newUser = UserModel(
          uid: uid,
          phoneNumber: phoneNumber,
          userRole: userRole,
          createdAt: DateTime.now(),
        );
        
        await _firestore.collection('users').doc(uid).set(newUser.toMap());
      },
    );
  }

  // Update user details including profile image
  Future<void> updateUserDetails({
    required String uid,
    String? name,
    DateTime? dateOfBirth,
  }) async {
    final Map<String, dynamic> updateData = {};
    
    if (name != null) {
      updateData['name'] = name;
    }
    
    if (dateOfBirth != null) {
      updateData['dateOfBirth'] = Timestamp.fromDate(dateOfBirth);
    }
    
    if (updateData.isNotEmpty) {
      return RetryHelper.retry(
        operation: () async {
          await _firestore.collection('users').doc(uid).update(updateData);
        },
      );
    }
  }

  // Update user role
  Future<void> updateUserRole({
    required String uid,
    required UserRole newRole,
  }) async {
    return RetryHelper.retry(
      operation: () async {
        await _firestore.collection('users').doc(uid).update({
          'userRole': newRole.toString().split('.').last,
        });
      },
    );
  }

  // Update user rider status
  Future<void> updateUserRiderStatus({
    required String uid,
    required String newStatus,
  }) async {
    return RetryHelper.retry(
      operation: () async {
        await _firestore.collection('users').doc(uid).update({
          'riderStatus': newStatus,
        });
      },
    );
  }

  // Get user data
  Future<UserModel?> getUserData(String uid) async {
    return RetryHelper.retry(
      operation: () async {
        final doc = await _firestore.collection('users').doc(uid).get();
        if (doc.exists) {
          return UserModel.fromMap(doc.data() as Map<String, dynamic>);
        }
        return null;
      },
    );
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Check if user is admin
  Future<bool> isAdmin(String phoneNumber) async {
    try {
      final querySnapshot = await _firestore
          .collection('admins')
          .where('phoneNumber', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      
      return querySnapshot.docs.isNotEmpty;
    } catch (e) {
      debugPrint('Error checking admin status: $e');
      return false;
    }
  }

  // Sign in with credential
  Future<UserCredential> signInWithCredential(
    PhoneAuthCredential credential,
  ) async {
    return await _auth.signInWithCredential(credential);
  }

  // Check if user exists
  Future<bool> userExists(String uid) async {
    return RetryHelper.retry(
      operation: () async {
        final doc = await _firestore.collection('users').doc(uid).get();
        return doc.exists;
      },
    );
  }

  // Update user profile image
  Future<String?> updateProfileImage({
    required String uid,
    required File imageFile,
  }) async {
    try {
      // Upload image to Cloudinary
      final String? downloadUrl = await _cloudinaryService.uploadImage(
        imageFile: imageFile,
        folder: 'profile_images',
        publicId: 'profile_$uid',
      );
      
      if (downloadUrl != null) {
        // Update the user document with the image URL
        await RetryHelper.retry(
          operation: () async {
            await _firestore.collection('users').doc(uid).update({
              'profileImageUrl': downloadUrl,
            });
          },
        );
      }
      
      return downloadUrl;
    } catch (e) {
      debugPrint('Error updating profile image: $e');
      return null;
    }
  }

  // Get current user data
  Future<UserModel?> getCurrentUser() async {
    final user = _auth.currentUser;
    if (user == null) {
      return null;
    }
    
    return await getUserData(user.uid);
  }
}
