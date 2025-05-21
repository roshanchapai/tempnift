import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:nift_final/utils/config.dart';

class CloudinaryService {
  // Use configuration from AppConfig
  final CloudinaryPublic _cloudinary = CloudinaryPublic(
    AppConfig.cloudinaryCloudName, 
    AppConfig.cloudinaryUploadPreset
  );
  
  // Upload a single image and return the URL
  Future<String?> uploadImage({
    required File imageFile,
    String? folder,
    Function(double)? onProgress,
  }) async {
    try {
      // Create a CloudinaryFile from the File
      final cloudinaryFile = CloudinaryFile.fromFile(
        imageFile.path,
        folder: folder,
        resourceType: CloudinaryResourceType.Image,
      );
      
      // Upload the file
      final CloudinaryResponse response = await _cloudinary.uploadFile(
        cloudinaryFile,
        onProgress: onProgress != null 
            ? (count, total) => onProgress(count / total) 
            : null,
      );
      
      debugPrint('Image uploaded successfully. URL: ${response.secureUrl}');
      return response.secureUrl;
    } on CloudinaryException catch (e) {
      debugPrint('Error uploading image: ${e.message}');
      return null;
    } catch (e) {
      debugPrint('Unexpected error uploading image: $e');
      return null;
    }
  }
  
  // Upload an image to a specific folder
  Future<String?> uploadProfileImage({
    required String uid,
    required File imageFile,
  }) async {
    return uploadImage(
      imageFile: imageFile,
      folder: 'profile_images',
    );
  }
  
  // Upload a rider application image (selfie, ID card, or vehicle)
  Future<String?> uploadRiderApplicationImage({
    required String uid,
    required File imageFile,
    required String imageType, // 'selfie', 'id_card', or 'vehicle'
    Function(double)? onProgress,
  }) async {
    return uploadImage(
      imageFile: imageFile,
      folder: 'rider_applications/$uid/$imageType',
      onProgress: onProgress,
    );
  }
} 