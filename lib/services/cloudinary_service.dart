import 'dart:io';
import 'package:cloudinary_public/cloudinary_public.dart';
import 'package:flutter/foundation.dart';
import 'package:nift_final/utils/config.dart';

class CloudinaryService {
  late final CloudinaryPublic _cloudinary;
  
  CloudinaryService() {
    _cloudinary = CloudinaryPublic(
      AppConfig.cloudinaryCloudName, 
      AppConfig.cloudinaryUploadPreset,
    );
  }

  /// Uploads an image file to Cloudinary
  /// 
  /// [imageFile]: The File object of the image to upload
  /// [folder]: Optional folder path within Cloudinary to store the image
  /// [publicId]: Optional custom public ID for the image
  /// 
  /// Returns the URL of the uploaded image if successful, null otherwise
  Future<String?> uploadImage({
    required File imageFile,
    String? folder,
    String? publicId,
  }) async {
    try {
      debugPrint('Uploading image to Cloudinary...');
      
      // Create CloudinaryResponse with optional parameters
      final response = await _cloudinary.uploadFile(
        CloudinaryFile.fromFile(
          imageFile.path,
          folder: folder,
          publicId: publicId,
          resourceType: CloudinaryResourceType.image,
        ),
      );
      
      debugPrint('Image uploaded successfully. URL: ${response.secureUrl}');
      return response.secureUrl;
    } catch (e) {
      debugPrint('Error uploading image to Cloudinary: $e');
      return null;
    }
  }
} 