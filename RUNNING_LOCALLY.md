# Running the Project Locally

This document provides step-by-step instructions to run the MindQuest Flutter project locally on Windows.

## Prerequisites

1. Flutter SDK (version 3.9.2 or higher)
2. Android Studio with Android SDK
3. Java Development Kit (JDK) 11 or higher
4. Git (optional, for version control)

## Steps to Run the Project Locally

### 1. Clone or Download the Project

If you haven't already, clone the repository or download the project files to your local machine.

### 2. Navigate to the Project Directory

Open Command Prompt or PowerShell and navigate to the project directory:

```cmd
cd "C:\path\to\grad-app-main"
```

### 3. Clean the Project (Optional but Recommended)

```cmd
flutter clean
```

### 4. Get Dependencies

```cmd
flutter pub get
```

### 5. Check for Issues

```cmd
flutter analyze
```

### 6. Run the App

To run on a connected device or emulator:

```cmd
flutter run
```

To run on a specific device:

```cmd
flutter run -d <device-id>
```

To see available devices:

```cmd
flutter devices
```

### 7. Build APK (Optional)

To build a debug APK:

```cmd
flutter build apk --debug
```

To build a release APK:

```cmd
flutter build apk --release
```

## Troubleshooting

### Common Issues

1. **Network Issues**: If you encounter network errors when building, check your internet connection and firewall settings.

2. **Android SDK Issues**: Make sure Android Studio is properly installed and the Android SDK path is correctly set in your environment variables.

3. **Flutter Version**: Ensure you're using a compatible Flutter version. This project was developed with Flutter 3.9.2.

4. **Java Version**: Ensure you have JDK 11 or higher installed.

### Android Emulator Setup

1. Open Android Studio
2. Go to Tools > AVD Manager
3. Create a new Virtual Device
4. Select a device definition and click Next
5. Select a system image (API level 21 or higher recommended) and click Next
6. Complete the AVD setup
7. Click the Play button to start the emulator

## Additional Notes

- The app requires internet connectivity for Firebase authentication
- For phone authentication, a physical device is recommended as emulators may not receive SMS
- Google Sign-In requires a properly configured Firebase project and SHA-1/SHA-256 certificates

## Useful Commands

```cmd
# Check Flutter installation
flutter doctor

# List available devices
flutter devices

# Get detailed analysis of the project
flutter analyze

# Run tests
flutter test

# Upgrade Flutter
flutter upgrade
```