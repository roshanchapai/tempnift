# Nift - Ride-Hailing Application

<img src="assets/logo/nift_logo.png" alt="Nift Logo" width="150"/>

## Project Overview

Nift is a versatile ride-hailing application built with Flutter and Firebase, designed to provide a unique two-way ride service experience. Unlike traditional ride-hailing platforms, Nift allows users to seamlessly switch between passenger and rider roles, creating a flexible community-driven transport ecosystem.

### Key Features

- **Dual Role System**: Users can switch between being a passenger or a rider (after verification)
- **Phone Number Authentication**: Secure login via OTP verification
- **Ride Request System**: Traditional passenger-initiated ride requests
- **Ride Offer System**: Unique rider-initiated ride offers (carpooling)
- **Location Services**: Google Maps integration for accurate navigation
- **Admin Dashboard**: For user management and rider verification
- **Customizable Pricing**: Passengers can offer their own price for rides

## Technology Stack

### Frontend
- **Flutter (Dart)**: Cross-platform UI toolkit

### Backend
- **Firebase**:
  - **Firebase Authentication**: Phone number authentication with OTP verification
  - **Cloud Firestore**: NoSQL database for user data and ride information
  - **Firebase Storage**: For storing rider verification documents

### APIs
- **Google Maps API**: For maps display and location services
- **Google Places API**: For location search with autocomplete

### Core Dependencies
- `firebase_auth`: Phone authentication
- `cloud_firestore`: Database operations
- `firebase_storage`: Document storage
- `google_maps_flutter`: Maps integration
- `google_places_flutter`: Location search
- `image_picker`: Document upload functionality
- `location`: Location permission handling

## Installation

### Prerequisites
- Flutter SDK (Latest stable version)
- Dart SDK
- Android Studio / VS Code
- Firebase account
- Google Maps API key

### Setup Instructions

1. **Clone the repository**
   ```
   git clone <repository-url>
   cd nift_final
   ```

2. **Install dependencies**
   ```
   flutter pub get
   ```

3. **Firebase Configuration**
   - Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/)
   - Add Android and iOS apps to your Firebase project
   - Download configuration files:
     - `google-services.json` for Android (place in `android/app/`)
     - `GoogleService-Info.plist` for iOS (place in `ios/Runner/`)

4. **Google Maps Configuration**
   - Get an API key from [Google Cloud Console](https://console.cloud.google.com/)
   - Enable Google Maps SDK for Android/iOS and Places API
   - Add the key to:
     - `android/app/src/main/AndroidManifest.xml` for Android
     - `ios/Runner/AppDelegate.swift` for iOS

5. **Run the application**
   ```
   flutter run
   ```

## Project Structure

### Authentication Flow
- Splash Screen → Phone Login → OTP Verification → (New Users) Signup Details or (Existing Users) Home Screen
- Admin authentication via special phone number and secure key

### User Roles
- **Passenger**: Default role for all users
- **Rider**: Available after admin verification of documents and details
- **Admin**: Special role for managing user verification and app oversight

### Core Functionalities
1. **Passenger Mode**:
   - Request rides with custom pricing
   - View and accept ride offers from riders
   - Track ride history

2. **Rider Mode**:
   - View and accept ride requests from passengers
   - Post ride offers with set pricing
   - Manage ride schedule

3. **Admin Dashboard**:
   - Verify rider applications
   - Manage user accounts
   - View system statistics

### Data Models
- **Users**: Core user information and role status
- **Ride Requests**: Passenger-initiated ride details
- **Ride Offers**: Rider-initiated carpooling offers
- **Rider Applications**: Verification documents and status

## Usage

### Passenger Flow
1. Log in with phone number
2. Set pickup and drop-off locations
3. Offer a price for the ride
4. Wait for a rider to accept or browse available ride offers

### Rider Flow
1. Complete rider verification process
2. Switch to rider mode
3. Browse ride requests or post ride offers
4. Accept requests matching your route

### Rider Verification Process
1. Submit personal information
2. Upload required documents (ID, vehicle registration, etc.)
3. Wait for admin approval
4. Once approved, gain ability to switch to rider mode

## Future Enhancements
- Real-time ride tracking
- In-app notifications
- Payment integration
- Rating and review system
- Enhanced safety features

## Contributors
- [Your Team Members' Names]

## License
[Your License Information]
