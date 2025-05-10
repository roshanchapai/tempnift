import 'package:flutter/material.dart';
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/services/rating_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:nift_final/widgets/star_rating.dart';
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

  Future<void> _selectDate(BuildContext context) async {
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Profile image and rating
                    Center(
                      child: Column(
                        children: [
                          // Profile image with edit option
                          Stack(
                            alignment: Alignment.bottomRight,
                            children: [
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: AppColors.surfaceColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primaryColor.withOpacity(0.1),
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
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.primaryColor,
                                  shape: BoxShape.circle,
                                ),
                                child: IconButton(
                                  icon: const Icon(
                                    Icons.edit,
                                    color: Colors.white,
                                    size: 16,
                                  ),
                                  constraints: const BoxConstraints(
                                    maxHeight: 32,
                                    maxWidth: 32,
                                  ),
                                  padding: EdgeInsets.zero,
                                  onPressed: _pickImage,
                                ),
                              ),
                            ],
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // User's name
                          Text(
                            widget.user.name ?? 'User',
                            style: AppTextStyles.headingStyle,
                          ),
                          
                          const SizedBox(height: 8),
                          
                          // User role badge
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              isRider ? 'Rider' : 'Passenger',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primaryColor,
                              ),
                            ),
                          ),
                          
                          const SizedBox(height: 16),
                          
                          // User rating
                          if (widget.user.ratingCount > 0) ...[
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                StarRating(
                                  rating: widget.user.averageRating,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  widget.user.averageRating.toStringAsFixed(1),
                                  style: AppTextStyles.subtitleStyle.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            Text(
                              '${widget.user.ratingCount} ${widget.user.ratingCount == 1 ? 'rating' : 'ratings'}',
                              style: AppTextStyles.captionStyle,
                            ),
                          ] else ...[
                            Text(
                              'No ratings yet',
                              style: AppTextStyles.captionStyle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    // Personal details section
                    Text(
                      'Personal Details',
                      style: AppTextStyles.subtitleStyle,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Name field
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Full Name',
                        prefixIcon: Icon(Icons.person),
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your name';
                        }
                        return null;
                      },
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Phone number (non-editable)
                    TextFormField(
                      initialValue: widget.user.phoneNumber,
                      decoration: const InputDecoration(
                        labelText: 'Phone Number',
                        prefixIcon: Icon(Icons.phone),
                      ),
                      readOnly: true,
                      enabled: false,
                    ),
                    
                    const SizedBox(height: 16),
                    
                    // Date of birth field
                    GestureDetector(
                      onTap: () => _selectDate(context),
                      child: AbsorbPointer(
                        child: TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Date of Birth',
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          controller: TextEditingController(
                            text: _selectedDate != null
                                ? DateFormat('MMM d, yyyy').format(_selectedDate!)
                                : '',
                          ),
                        ),
                      ),
                    ),
                    
                    // Display ratings section
                    const SizedBox(height: 32),
                    const Divider(),
                    const SizedBox(height: 16),
                    
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Reviews',
                          style: AppTextStyles.subtitleStyle,
                        ),
                        if (widget.user.ratingCount > 0)
                          TextButton(
                            onPressed: () {
                              // View all reviews
                              _showAllReviews();
                            },
                            child: const Text('View All'),
                          ),
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Display recent ratings
                    _buildRecentRatings(),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildRecentRatings() {
    final RatingService _ratingService = RatingService();
    
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _ratingService.getUserRatings(widget.user.uid, limit: 3),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'Error loading ratings: ${snapshot.error}',
              style: TextStyle(color: AppColors.errorColor),
            ),
          );
        }
        
        final ratings = snapshot.data ?? [];
        
        if (ratings.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'No reviews yet',
                style: AppTextStyles.captionStyle,
              ),
            ),
          );
        }
        
        return Column(
          children: ratings.map((rating) {
            final ratingValue = rating['rating'] as int? ?? 0;
            final comment = rating['comment'] as String? ?? '';
            final timestamp = rating['timestamp'] as DateTime? ?? DateTime.now();
            
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: AppColors.surfaceColor,
                  width: 1,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        StarRating(
                          rating: ratingValue.toDouble(),
                          size: 20,
                        ),
                        Text(
                          DateFormat('MMM d, yyyy').format(timestamp),
                          style: AppTextStyles.captionStyle,
                        ),
                      ],
                    ),
                    if (comment.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        comment,
                        style: AppTextStyles.bodyStyle,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
  
  void _showAllReviews() {
    final RatingService _ratingService = RatingService();
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header with average rating
                  Center(
                    child: Column(
                      children: [
                        Container(
                          width: 40,
                          height: 5,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2.5),
                          ),
                        ),
                        Text(
                          'All Reviews',
                          style: AppTextStyles.subtitleStyle,
                        ),
                        const SizedBox(height: 8),
                        if (widget.user.ratingCount > 0) ...[
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              StarRating(
                                rating: widget.user.averageRating,
                                size: 32,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                widget.user.averageRating.toStringAsFixed(1),
                                style: AppTextStyles.headingStyle,
                              ),
                            ],
                          ),
                          Text(
                            '${widget.user.ratingCount} ${widget.user.ratingCount == 1 ? 'rating' : 'ratings'}',
                            style: AppTextStyles.captionStyle,
                          ),
                        ] else ...[
                          Text(
                            'No ratings yet',
                            style: AppTextStyles.captionStyle,
                          ),
                        ],
                      ],
                    ),
                  ),
                  
                  const Divider(height: 32),
                  
                  // Rating list
                  Expanded(
                    child: FutureBuilder<List<Map<String, dynamic>>>(
                      future: _ratingService.getUserRatings(widget.user.uid, limit: 50),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }
                        
                        if (snapshot.hasError) {
                          return Center(
                            child: Text(
                              'Error loading ratings: ${snapshot.error}',
                              style: TextStyle(color: AppColors.errorColor),
                            ),
                          );
                        }
                        
                        final ratings = snapshot.data ?? [];
                        
                        if (ratings.isEmpty) {
                          return const Center(
                            child: Text('No reviews yet'),
                          );
                        }
                        
                        return ListView.builder(
                          controller: scrollController,
                          itemCount: ratings.length,
                          itemBuilder: (context, index) {
                            final rating = ratings[index];
                            final ratingValue = rating['rating'] as int? ?? 0;
                            final comment = rating['comment'] as String? ?? '';
                            final timestamp = rating['timestamp'] as DateTime? ?? DateTime.now();
                            
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(
                                  color: AppColors.surfaceColor,
                                  width: 1,
                                ),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        StarRating(
                                          rating: ratingValue.toDouble(),
                                          size: 20,
                                        ),
                                        Text(
                                          DateFormat('MMM d, yyyy').format(timestamp),
                                          style: AppTextStyles.captionStyle,
                                        ),
                                      ],
                                    ),
                                    if (comment.isNotEmpty) ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        comment,
                                        style: AppTextStyles.bodyStyle,
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
} 