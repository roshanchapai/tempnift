import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
// import 'package:firebase_storage/firebase_storage.dart'; // Remove Firebase Storage
import 'package:nift_final/models/user_model.dart';
import 'package:nift_final/services/auth_service.dart';
import 'package:nift_final/utils/constants.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nift_final/services/cloudinary_service.dart'; // Import CloudinaryService

class RiderRegistrationScreen extends StatefulWidget {
  final UserModel user;

  const RiderRegistrationScreen({Key? key, required this.user}) : super(key: key);

  @override
  State<RiderRegistrationScreen> createState() => _RiderRegistrationScreenState();
}

class _RiderRegistrationScreenState extends State<RiderRegistrationScreen> {
  final AuthService _authService = AuthService();
  final CloudinaryService _cloudinaryService = CloudinaryService(); // Add CloudinaryService
  final _formKey = GlobalKey<FormState>();
  
  // Form fields
  final _vehicleModelController = TextEditingController();
  final _vehicleNumberController = TextEditingController();
  final _vehicleColorController = TextEditingController();
  
  // Selected vehicle type
  String _selectedVehicleType = 'Bike'; // Default to Bike
  
  // Image files
  File? _selfieImage;
  File? _idCardImage;
  File? _vehicleImage;
  
  // Loading state
  bool _isLoading = false;
  String? _errorMessage;
  
  // Image picker
  final ImagePicker _picker = ImagePicker();
  
  @override
  void dispose() {
    _vehicleModelController.dispose();
    _vehicleNumberController.dispose();
    _vehicleColorController.dispose();
    super.dispose();
  }
  
  // Pick image from camera or gallery
  Future<File?> _pickImage(ImageSource source) async {
    try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 70,
      );
      
      if (pickedFile != null) {
        return File(pickedFile.path);
      }
      return null;
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to pick image: $e';
      });
      return null;
    }
  }
  
  // Show image source dialog
  Future<File?> _showImageSourceDialog(String title) async {
    final source = await showDialog<ImageSource>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                GestureDetector(
                  child: const Text('Take a picture'),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.camera);
                  },
                ),
                const Padding(padding: EdgeInsets.all(8.0)),
                GestureDetector(
                  child: const Text('Select from gallery'),
                  onTap: () {
                    Navigator.of(context).pop(ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    
    if (source != null) {
      return _pickImage(source);
    }
    return null;
  }
  
  // Upload image using Cloudinary instead of Firebase Storage
  Future<String?> _uploadImage(File image, String imageType) async {
    try {
      // Show upload progress in the UI
      final progressCallback = (double progress) {
        debugPrint('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
        // You could update a progress indicator here if needed
      };
      
      // Use CloudinaryService to upload the image
      final downloadUrl = await _cloudinaryService.uploadRiderApplicationImage(
        uid: widget.user.uid,
        imageFile: image,
        imageType: imageType,
        onProgress: progressCallback,
      );
      
      if (downloadUrl != null) {
        debugPrint('Image uploaded successfully. URL: $downloadUrl');
        return downloadUrl;
      } else {
        throw Exception('Upload failed');
      }
    } catch (e) {
      debugPrint('Error uploading image: $e');
      return null;
    }
  }
  
  // Submit rider application
  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    if (_selfieImage == null || _idCardImage == null || _vehicleImage == null) {
      setState(() {
        _errorMessage = 'Please upload all required images';
      });
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      // First save the application data without images
      final applicationData = {
        'userId': widget.user.uid,
        'userName': widget.user.name,
        'userPhone': widget.user.phoneNumber,
        'vehicleDetails': {
          'type': _selectedVehicleType,
          'model': _vehicleModelController.text.trim(),
          'number': _vehicleNumberController.text.trim(),
          'color': _vehicleColorController.text.trim(),
        },
        'status': 'pending',
        'submittedAt': FieldValue.serverTimestamp(),
        'selfPhotoUrl': null,
        'idPhotoUrl': null,
        'vehiclePhotoUrl': null,
      };
      
      // Save initial application to Firestore
      final applicationRef = FirebaseFirestore.instance
          .collection('riderApplications')
          .doc(widget.user.uid);
          
      await applicationRef.set(applicationData);
      
      // Now upload images one by one and update the document
      debugPrint('Uploading selfie image...');
      final selfieUrl = await _uploadImage(_selfieImage!, 'selfie');
      if (selfieUrl != null) {
        await applicationRef.update({'selfPhotoUrl': selfieUrl});
      }
      
      debugPrint('Uploading ID card image...');
      final idCardUrl = await _uploadImage(_idCardImage!, 'id_card');
      if (idCardUrl != null) {
        await applicationRef.update({'idPhotoUrl': idCardUrl});
      }
      
      debugPrint('Uploading vehicle image...');
      final vehicleUrl = await _uploadImage(_vehicleImage!, 'vehicle');
      if (vehicleUrl != null) {
        await applicationRef.update({'vehiclePhotoUrl': vehicleUrl});
      }
      
      // Check if all images uploaded successfully
      if (selfieUrl == null || idCardUrl == null || vehicleUrl == null) {
        // Update application status to indicate partial upload
        await applicationRef.update({
          'uploadStatus': 'partial',
          'uploadErrors': {
            'selfie': selfieUrl == null,
            'idCard': idCardUrl == null,
            'vehicle': vehicleUrl == null,
          }
        });
        
        throw Exception('Some images failed to upload. Please try again later.');
      }
      
      // All uploads successful, update user's rider status
      await _authService.updateUserRiderStatus(
        uid: widget.user.uid,
        newStatus: 'pending',
      );
      
      // Update local user model
      final updatedUser = widget.user.copyWith(riderStatus: 'pending');
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Application submitted successfully. It will be reviewed by our team.'),
            backgroundColor: AppColors.successColor,
          ),
        );
        
        // Return to previous screen with updated user model
        Navigator.of(context).pop(updatedUser);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to submit application: $e';
      });
      debugPrint('Error in application submission: $e');
    }
  }
  
  Widget _buildImageSelector(String title, String subtitle, File? image, Function(File?) onImageSelected) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.bodyBoldStyle,
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.captionStyle,
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onTap: () async {
              final imageFile = await _showImageSourceDialog('Select $title');
              if (imageFile != null) {
                onImageSelected(imageFile);
              }
            },
            child: Container(
              height: 150,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppColors.surfaceColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: image != null ? AppColors.primaryColor : Colors.grey.shade300,
                  width: 1,
                ),
              ),
              child: image != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        image,
                        fit: BoxFit.cover,
                      ),
                    )
                  : Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.camera_alt,
                          color: Colors.grey.shade400,
                          size: 40,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Tap to upload',
                          style: AppTextStyles.captionStyle,
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Registration'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                const Text(
                  'Become a Rider',
                  style: AppTextStyles.headingStyle,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Complete the form below to register as a rider. Your application will be reviewed by our team.',
                  style: AppTextStyles.captionStyle,
                ),
                const SizedBox(height: 24),
                
                // Photo uploads section
                const Text(
                  'Required Photos',
                  style: AppTextStyles.subtitleStyle,
                ),
                const SizedBox(height: 16),
                
                // Selfie image selector
                _buildImageSelector(
                  'Your Photo',
                  'A clear photo of your face',
                  _selfieImage,
                  (file) => setState(() => _selfieImage = file),
                ),
                
                // ID Card image selector
                _buildImageSelector(
                  'ID Card',
                  'Your government-issued ID card (front side)',
                  _idCardImage,
                  (file) => setState(() => _idCardImage = file),
                ),
                
                // Vehicle image selector
                _buildImageSelector(
                  'Vehicle Photo',
                  'A clear photo of your vehicle',
                  _vehicleImage,
                  (file) => setState(() => _vehicleImage = file),
                ),
                
                const SizedBox(height: 24),
                
                // Vehicle details section
                const Text(
                  'Vehicle Details',
                  style: AppTextStyles.subtitleStyle,
                ),
                const SizedBox(height: 16),
                
                // Vehicle type selection
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Type',
                    border: OutlineInputBorder(),
                  ),
                  value: _selectedVehicleType,
                  items: ['Bike', 'Car', 'Scooter']
                      .map((type) => DropdownMenuItem(
                            value: type,
                            child: Text(type),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedVehicleType = value;
                      });
                    }
                  },
                ),
                const SizedBox(height: 16),
                
                // Vehicle model
                TextFormField(
                  controller: _vehicleModelController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Model',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter vehicle model';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Vehicle number
                TextFormField(
                  controller: _vehicleNumberController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Number',
                    border: OutlineInputBorder(),
                    hintText: 'e.g., BA 1-2345',
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter vehicle number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                
                // Vehicle color
                TextFormField(
                  controller: _vehicleColorController,
                  decoration: const InputDecoration(
                    labelText: 'Vehicle Color',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter vehicle color';
                    }
                    return null;
                  },
                ),
                
                // Error message
                if (_errorMessage != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16.0),
                    child: Text(
                      _errorMessage!,
                      style: TextStyle(
                        color: AppColors.errorColor,
                        fontSize: 14,
                      ),
                    ),
                  ),
                
                const SizedBox(height: 32),
                
                // Submit button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitApplication,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
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
                        : const Text('Submit Application'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
} 