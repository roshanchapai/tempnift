import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';

class ProfileScreen extends StatefulWidget {
  final UserModel user;

  const ProfileScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _authService = AuthService();
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  File? _imageFile;
  bool _isLoading = false;
  bool _hasChanges = false;
  UserModel? _updatedUser;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.user.name ?? '';
    _selectedDate = widget.user.dateOfBirth;
    
    // Add listener to track changes
    _nameController.addListener(_onFormChanged);
  }

  @override
  void dispose() {
    _nameController.removeListener(_onFormChanged);
    _nameController.dispose();
    super.dispose();
  }

  void _onFormChanged() {
    final nameChanged = _nameController.text != (widget.user.name ?? '');
    final dateChanged = _selectedDate != widget.user.dateOfBirth;
    
    if (mounted) {
      setState(() {
        _hasChanges = nameChanged || dateChanged || _imageFile != null;
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? pickedFile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _imageFile = File(pickedFile.path);
          _hasChanges = true;
        });
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error selecting image: $e')),
      );
    }
  }

  Future<void> _selectDate() async {
    final initialDate = _selectedDate ?? DateTime.now().subtract(const Duration(days: 365 * 18));
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(1930),
      lastDate: DateTime.now().subtract(const Duration(days: 365 * 16)), // 16 years ago
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primaryColor,
              onPrimary: AppColors.lightTextColor,
              onSurface: AppColors.primaryTextColor,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _hasChanges = true;
      });
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate() || !_hasChanges) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      String? imageUrl;
      
      // Upload image if selected
      if (_imageFile != null) {
        imageUrl = await _authService.updateProfileImage(
          uid: widget.user.uid,
          imageFile: _imageFile!,
        );
        
        if (imageUrl == null) {
          throw Exception('Failed to upload profile image');
        }
      }
      
      // Update user details in Firestore
      await _authService.updateUserDetails(
        uid: widget.user.uid,
        name: _nameController.text.trim(),
        dateOfBirth: _selectedDate,
      );
      
      // Get updated user data
      final updatedUser = await _authService.getUserData(widget.user.uid);
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _updatedUser = updatedUser;
          _hasChanges = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profile updated successfully'),
            backgroundColor: AppColors.successColor,
          ),
        );
        
        // Return updated user to previous screen
        Navigator.pop(context, _updatedUser);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating profile: $e'),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isRider = widget.user.userRole == UserRole.rider;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          if (_hasChanges)
            TextButton(
              onPressed: _isLoading ? null : _saveProfile,
              child: Text(
                'Save',
                style: AppTextStyles.buttonTextStyle.copyWith(
                  color: AppColors.lightTextColor,
                ),
              ),
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 16),
                    
                    // Profile Image
                    Hero(
                      tag: 'profile-picture',
                      child: GestureDetector(
                        onTap: isRider ? null : _pickImage,
                        child: Stack(
                          alignment: Alignment.bottomRight,
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.primaryColor,
                                  width: 3,
                                ),
                              ),
                              child: ClipOval(
                                child: _imageFile != null
                                    ? Image.file(
                                        _imageFile!,
                                        fit: BoxFit.cover,
                                      )
                                    : widget.user.profileImageUrl != null
                                        ? CachedNetworkImage(
                                            imageUrl: widget.user.profileImageUrl!,
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => const Center(
                                              child: CircularProgressIndicator(),
                                            ),
                                            errorWidget: (context, url, error) => Icon(
                                              Icons.person,
                                              color: AppColors.primaryColor,
                                              size: 60,
                                            ),
                                          )
                                        : Container(
                                            color: AppColors.surfaceColor,
                                            child: Icon(
                                              Icons.person,
                                              color: AppColors.primaryColor,
                                              size: 60,
                                            ),
                                          ),
                              ),
                            ),
                            if (!isRider)
                              Container(
                                padding: const EdgeInsets.all(4),
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: AppColors.lightTextColor,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.camera_alt,
                                  color: AppColors.lightTextColor,
                                  size: 20,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // User role badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        widget.user.userRole == UserRole.rider ? 'Rider' : 'Passenger',
                        style: AppTextStyles.captionStyle.copyWith(
                          color: AppColors.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      readOnly: isRider, // Riders cannot edit name
                      decoration: InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: const Icon(Icons.person_outline),
                        enabled: !isRider,
                      ),
                      validator: (value) {
                        if (!isRider && (value == null || value.trim().isEmpty)) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Phone number (read-only)
                    TextFormField(
                      initialValue: widget.user.phoneNumber,
                      readOnly: true,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone_outlined),
                        enabled: false,
                      ),
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Date of birth
                    GestureDetector(
                      onTap: isRider ? null : _selectDate,
                      child: AbsorbPointer(
                        child: TextFormField(
                          readOnly: true,
                          initialValue: _selectedDate != null
                              ? DateFormat('dd MMMM, yyyy').format(_selectedDate!)
                              : '',
                          decoration: InputDecoration(
                            labelText: 'Date of Birth',
                            prefixIcon: const Icon(Icons.calendar_today_outlined),
                            suffixIcon: isRider
                                ? null
                                : const Icon(Icons.arrow_drop_down),
                            enabled: !isRider,
                          ),
                        ),
                      ),
                    ),
                    
                    const SizedBox(height: 24),
                    
                    if (isRider)
                      Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Text(
                          'As a Rider, you cannot modify your profile information. Please contact support if you need to make changes.',
                          style: AppTextStyles.captionStyle,
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
} 