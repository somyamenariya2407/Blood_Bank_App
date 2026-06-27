# Blood Bank App

A Flutter-based Blood Bank Management App for connecting blood donors, hospitals, and administrators. The app supports Firebase authentication, hospital blood inventory management, SOS blood requests, donation history, maps/location features, and notification support.

## Features

- User, hospital, and admin modules
- Firebase Authentication for login and registration
- Cloud Firestore for users, hospitals, SOS requests, donations, and activities
- Firebase Storage support for uploaded documents/files
- Blood inventory tracking for hospitals
- SOS emergency blood request flow
- Donor and hospital dashboards
- Donation and request history
- Location and map-based features
- Push notification support with Firebase Messaging / OneSignal
- Admin analytics and user/hospital management

## Tech Stack

- Flutter
- Dart
- Firebase Authentication
- Cloud Firestore
- Firebase Storage
- Firebase Messaging
- OneSignal
- Google Maps / Location services

## Project Structure

```text
lib/
  constants/      Shared constants
  models/         Data models
  screens/        App screens by role
  services/       Firebase, auth, notification, and app services
  utils/          Helper utilities
  widgets/        Reusable UI widgets
assets/
  images/         App images and logo
android/          Android platform project
ios/              iOS platform project
web/              Web platform project
```

## Getting Started

### Prerequisites

- Flutter SDK installed
- Dart SDK installed
- Android Studio or VS Code
- Firebase project configured

### Installation

1. Clone the repository:

```bash
git clone https://github.com/YOUR_USERNAME/Blood_Bank_App.git
```

2. Open the project:

```bash
cd Blood_Bank_App
```

3. Install dependencies:

```bash
flutter pub get
```

4. Add required Firebase configuration files:

```text
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
```

5. Run the app:

```bash
flutter run
```

## Important Security Notes

The following files are intentionally ignored and should not be committed:

```text
android/app/google-services.json
ios/Runner/GoogleService-Info.plist
lib/firebase_options.dart
lib/services/onesignal_service.dart
.env
*.jks
*.keystore
key.properties
```

Do not commit API keys, Firebase config files, keystore files, or OneSignal REST API keys to a public repository. Notification sending with a OneSignal REST API key should be handled from a secure backend or cloud function, not directly inside the Flutter client.

## Common Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

## Status

This project is under active development.
