# Nift App Development To-Do List

## 1. Project Setup
- [ ] **Initialize Flutter Project**
  - Run `flutter create nift` to set up a new Flutter project.
- [ ] **Set Up Firebase**
  - Create a Firebase project in the [Firebase Console](https://console.firebase.google.com/).
  - Register Android and/or iOS apps in the Firebase project.
  - Download configuration files:
    - `google-services.json` for Android (place in `android/app/`).
    - `GoogleService-Info.plist` for iOS (place in `ios/Runner/`).
- [ ] **Add Dependencies**
  - Edit `pubspec.yaml` to include:
    ```yaml
    dependencies:
      flutter:
        sdk: flutter
      firebase_core: ^latest_version
      firebase_auth: ^latest_version
      cloud_firestore: ^latest_version
      firebase_storage: ^latest_version
      google_maps_flutter: ^latest_version
      google_places_flutter: ^latest_version
      image_picker: ^latest_version
      location: ^latest_version
    ```
  - Run `flutter pub get` to install them.
- [ ] **Initialize Firebase**
  - Update `main.dart`:
    ```dart
    import 'package:firebase_core/firebase_core.dart';

    void main() async {
      WidgetsFlutterBinding.ensureInitialized();
      await Firebase.initializeApp();
      runApp(MyApp());
    }
    ```
- [ ] **Configure Google Maps**
  - Get an API key from [Google Cloud Console](https://console.cloud.google.com/).
  - Add it to:
    - Android (`android/app/src/main/AndroidManifest.xml`):
      ```xml
      <meta-data
        android:name="com.google.android.geo.API_KEY"
        android:value="YOUR_API_KEY"/>
      ```
    - iOS (`ios/Runner/AppDelegate.swift`):
      ```swift
      GMSServices.provideAPIKey("YOUR_API_KEY")
      ```

---

## 2. Authentication Flow

### 2.1 Data Models
- [ ] **Set Up Firestore Collections**
  - `users`:
    - Fields: `phoneNumber` (String), `fullName` (String), `dateOfBirth` (Timestamp), `riderStatus` (String: `not_applied`, `pending`, `approved`, `rejected`), `currentMode` (String: `passenger`, `rider`).
  - `admins`:
    - Fields: `phoneNumber` (String, e.g., "9876543210"), `hashedKey` (String).
  - `riderApplications`:
    - Fields: `userId` (String), `selfPhotoUrl` (String), `idPhotoUrl` (String), `vehiclePhotoUrl` (String), `vehicleDetails` (Map), `status` (String: `pending`, `approved`, `rejected`).

### 2.2 Screens and Logic
- [ ] **Splash Screen**
  - Show app logo for 3 seconds.
  - Check `FirebaseAuth.instance.currentUser`:
    - If logged in:
      - Fetch user data from `users`.
      - Navigate to:
        - `currentMode: passenger` → Passenger Home.
        - `currentMode: rider` → Rider Home.
      - If admin (after key check), go to Admin Dashboard.
    - If not logged in, go to Login/Signup Screen.
- [ ] **Login/Signup Screen**
  - UI: Phone number field, "Next" button.
  - Validate phone (e.g., `+9779812345678`).
  - If matches admin number (e.g., "9876543210"), go to Admin Key Input Screen.
  - Otherwise, start Firebase phone auth and go to OTP Screen.
- [ ] **OTP Verification Screen**
  - UI: 6-digit OTP field, "Verify" button.
  - Verify OTP with Firebase Auth.
  - On success:
    - If `phoneNumber` in `users`: Login → Navigate by `currentMode`.
    - If not: Signup → Go to Signup Details Screen.
- [ ] **Signup Details Screen**
  - UI: Full name, date of birth fields, "Submit" button.
  - Validate inputs.
  - Save to `users` with `riderStatus: not_applied`, `currentMode: passenger`.
  - Go to Passenger Home.
- [ ] **Admin Key Input Screen**
  - UI: Key field, "Verify" button.
  - Fetch admin data from `admins`.
  - Hash input and compare with `hashedKey`.
  - If valid, go to Admin Dashboard; else, show error.

---

## 3. Home Screens

### 3.1 Passenger Home Screen
- [ ] **Map Display**
  - Use `google_maps_flutter` for a full-screen map.
  - Center on user's location (via `location` package).
- [ ] **Booking Panel**
  - Bottom UI: 
    - Toggle: "Bike Ride" or "Car Ride".
    - `From`: Autofilled with current location, editable.
    - `To`: Empty, with Google Places autocomplete.
    - `Offer Your Price`: Numeric input.
    - "Search Ride" button (saves to `rideRequests`).
- [ ] **Locate Me Button**
  - Right side, centers map on user location.
- [ ] **Hamburger Menu**
  - Top left corner.
- [ ] **Find Active Rides Button**
  - Top right, goes to Find Active Rides Screen.

### 3.2 Rider Home Screen
- [ ] **Ride Requests List**
  - Use `StreamBuilder` to show `rideRequests` (`status: pending`, matching rider's vehicle).
  - Show `from`, `to`, `offeredPrice`, "Accept" button.
  - On accept: Update `rideRequests` (`status: accepted`, `acceptedBy: riderId`).
- [ ] **Send Ride Request Button**
  - Top right, goes to Send Ride Offer Screen.

### 3.3 Admin Dashboard
- [ ] **Manage Users**
  - List `users` with `phoneNumber`, `fullName`, `riderStatus`.
- [ ] **Manage Rider Registrations**
  - List `riderApplications` (`status: pending`).
  - Show details/photos, with "Approve"/"Reject" buttons to update statuses.

---

## 4. Booking and Ride Offer Functionality

### 4.1 Data Models
- [ ] **Ride Requests (`rideRequests`)**
  - Fields: `passengerId`, `from`, `to`, `vehicleType`, `offeredPrice`, `status`, `acceptedBy`, `timestamp`.
- [ ] **Ride Offers (`rideOffers`)**
  - Fields: `riderId`, `from`, `to`, `fare`, `status`, `acceptedBy`, `timestamp`.

### 4.2 Ride Requests (Passenger)
- [ ] **Create Ride Request**
  - "Search Ride" saves to `rideRequests`.
- [ ] **Rider Acceptance**
  - Rider accepts, updating `rideRequests`.

### 4.3 Ride Offers (Rider)
- [ ] **Send Ride Offer Screen**
  - UI: `From`, `To`, `Fare`, "Submit" (saves to `rideOffers`).
- [ ] **Find Active Rides Screen**
  - List `rideOffers` (`status: pending`).
  - "Accept" updates `status: accepted`, `acceptedBy: passengerId`.

---

## 5. Role Switching and Rider Registration

### 5.1 Role Switching
- [ ] **Switch Role Button**
  - In hamburger menu.
  - If `riderStatus: approved`, toggle `currentMode` and navigate.
  - If `not_applied`/`rejected`, go to Rider Registration.
  - If `pending`, show "Under review".

### 5.2 Rider Registration Form
- [ ] **UI and Logic**
  - Fields: Self photo, ID photo, vehicle photo, personal/vehicle details.
  - Use `image_picker` to upload to Firebase Storage.
  - Save to `riderApplications` (`status: pending`).
  - Update `users` (`riderStatus: pending`).

### 5.3 Admin Approval
- [ ] **Approval Process**
  - Approve/reject in Admin Dashboard, updating `riderApplications` and `users`.

---

## 6. Hamburger Menu Features
- [ ] **Profile**
  - View/edit `fullName`, `dateOfBirth`.
- [ ] **Request History**
  - Show user's `rideRequests` and `rideOffers`.
- [ ] **Additional Screens**
  - Static: Safety Guidelines, Settings, Help & Support.
- [ ] **Switch Role**
  - Add role-switching logic.

---

## 7. Final Touches
- [ ] **Location Permissions**
  - Request and manage location access.
- [ ] **Error Handling**
  - Validate inputs and show errors/loading states.
- [ ] **Testing**
  - Test auth, ride booking, role switching, and admin features.

---
