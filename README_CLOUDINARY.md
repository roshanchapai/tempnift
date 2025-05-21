# Cloudinary Integration for NIFT

This document provides instructions for setting up Cloudinary image storage for the NIFT ride-sharing application.

## Why Cloudinary?

We've migrated from Firebase Storage to Cloudinary for image uploads because:

1. Cloudinary offers a generous free tier (10GB storage, 25GB bandwidth/month)
2. Better image optimization and transformation capabilities
3. No need for authentication tokens - works with upload presets

## Setup Instructions

### 1. Create a Cloudinary Account

1. Go to [Cloudinary.com](https://cloudinary.com/) and sign up for a free account
2. After signing up, you'll be taken to your dashboard

### 2. Get Your Credentials

From your Cloudinary dashboard:

1. Note your **Cloud Name** (shown prominently on the dashboard)
2. Create an unsigned upload preset:
   - Go to Settings > Upload
   - Scroll to "Upload presets"
   - Click "Add upload preset"
   - Set "Signing Mode" to "Unsigned"
   - Name your preset (e.g., "nift_preset")
   - Save the preset
   - Note the preset name

### 3. Configure the App

1. Open `lib/utils/config.dart`
2. Replace the placeholder values:

```dart
class AppConfig {
  // Cloudinary configuration
  static const String cloudinaryCloudName = "YOUR_CLOUD_NAME";
  static const String cloudinaryUploadPreset = "YOUR_UPLOAD_PRESET";
  
  // Other app configurations can be added here
}
```

Replace:
- `YOUR_CLOUD_NAME` with your actual Cloudinary cloud name
- `YOUR_UPLOAD_PRESET` with the unsigned upload preset you created

### 4. Test the Integration

1. Run the app
2. Try uploading a profile image or registering as a rider
3. Check your Cloudinary Media Library to verify images are being uploaded

## Implementation Details

The app uses the `cloudinary_public` package to handle uploads:

- `CloudinaryService` in `lib/services/cloudinary_service.dart` handles all uploads
- User profile images are stored in the `profile_images` folder
- Rider application images are stored in `rider_applications/[user_id]/[type]` folders

## Troubleshooting

If you encounter issues with uploads:

1. Verify your Cloudinary credentials are correct
2. Check that your upload preset is set to "Unsigned"
3. Verify network connectivity
4. Check the Flutter debug console for error messages

For any other issues, refer to the [Cloudinary documentation](https://cloudinary.com/documentation). 