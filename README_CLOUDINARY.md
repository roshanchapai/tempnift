# Switching from Firebase Storage to Cloudinary

This project has been updated to use Cloudinary instead of Firebase Storage for storing images. Cloudinary offers a free tier that should be suitable for development and small production apps.

## Why Cloudinary?

- Free tier with generous limits
- Better image optimization
- Built-in transformations for images (resizing, cropping, filters, etc.)
- Global CDN for faster delivery
- No need to manage storage rules

## Setup Instructions

1. Create a Cloudinary account at [cloudinary.com](https://cloudinary.com) (free tier is available)

2. Get your **Cloud Name** from the Cloudinary dashboard

3. Create an upload preset:
   - Go to Settings > Upload
   - Scroll down to "Upload presets" and click "Add upload preset"
   - Set "Signing Mode" to "Unsigned"
   - Choose any other settings you want (folder, transformations, etc.)
   - Save the preset
   - Note the preset name

4. Update the configuration in the app:
   - Open `lib/utils/config.dart`
   - Replace `your_cloud_name` with your actual cloud name
   - Replace `your_upload_preset` with your upload preset name

```dart
class AppConfig {
  // Cloudinary Configuration
  static const String cloudinaryCloudName = 'your_cloud_name';
  static const String cloudinaryUploadPreset = 'your_upload_preset';
}
```

5. Run the app - all image uploads should now go to Cloudinary instead of Firebase Storage

## Usage

The app now uses the `CloudinaryService` for all image uploads. If you need to add new image upload functionality, use this service instead of Firebase Storage.

Example:

```dart
final cloudinaryService = CloudinaryService();
final downloadUrl = await cloudinaryService.uploadImage(
  imageFile: imageFile,
  folder: 'custom_folder', // optional
  onProgress: (progress) {
    // Handle progress updates
    print('Upload progress: ${(progress * 100).toStringAsFixed(2)}%');
  },
);
```

## Important Notes

- This implementation uses the `cloudinary_public` package, which allows for client-side uploads without exposing your API key or secret
- The free tier of Cloudinary has limits, check their pricing page for details
- You may want to implement server-side validation and authorization for production apps 