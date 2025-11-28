# Firebase Setup Guide

This document provides detailed instructions for setting up Firebase for the MindQuest mobile application.

## Prerequisites

1. A Google account
2. Flutter development environment set up
3. Android Studio with Android SDK
4. Java Development Kit (JDK) 11 or higher

## Step 1: Create a Firebase Project

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Click "Create a project" or "Add project" if you already have projects
3. Enter a project name (e.g., "MindQuest")
4. Accept the terms and conditions
5. Enable Google Analytics if desired (optional)
6. Click "Create project"

## Step 2: Register Your App with Firebase

### For Android

1. In the Firebase Console, click the Android icon or "Add app" > "Android"
2. Enter the package name: `com.example.flutter_project_ready`
3. Enter an app nickname (optional)
4. Enter the debug signing certificate SHA-1 (see Step 3 below)
5. Click "Register app"
6. Download the `google-services.json` file
7. Move the `google-services.json` file to the `android/app` directory in your project
8. Click "Next"
9. Add the Firebase SDK (already done in this project)
10. Click "Next"
11. Skip the test step and click "Continue to console"

### For iOS (Optional)

1. In the Firebase Console, click the iOS icon or "Add app" > "iOS"
2. Enter the bundle ID: `com.example.flutterProjectReady`
3. Enter an app nickname (optional)
4. Enter the App Store ID (optional)
5. Click "Register app"
6. Download the `GoogleService-Info.plist` file
7. Move the file to the `ios/Runner` directory in your project
8. Follow the additional setup steps in the Firebase Console

## Step 3: Generate SHA-1 and SHA-256 Certificates

### For Debug Keystore (Required for Development)

Open Command Prompt or Terminal and run:

```cmd
keytool -list -v -keystore "%USERPROFILE%\.android\debug.keystore" -alias androiddebugkey -storepass android -keypass android
```

If the debug keystore doesn't exist, Android Studio will create it automatically when you build your app.

### For Release Keystore (Required for Production)

If you have a release keystore, run:

```cmd
keytool -list -v -keystore /path/to/your/release/keystore.jks -alias your_key_alias -storepass your_store_password -keypass your_key_password
```

### Add SHA Certificates to Firebase

1. In the Firebase Console, go to Project Settings (gear icon)
2. Under "General" tab, scroll to "Your apps" section
3. Find your Android app and click the "Add fingerprint" button
4. Enter the SHA-1 and SHA-256 certificates
5. Click "Save"

## Step 4: Enable Authentication Providers

### Enable Email/Password Authentication

1. In the Firebase Console, go to "Authentication" > "Sign-in method"
2. Click "Email/Password"
3. Toggle "Enabled"
4. Click "Save"

### Enable Phone Authentication

1. In the Firebase Console, go to "Authentication" > "Sign-in method"
2. Click "Phone"
3. Toggle "Enabled"
4. Click "Save"

### Enable Google Sign-In

1. In the Firebase Console, go to "Authentication" > "Sign-in method"
2. Click "Google"
3. Toggle "Enabled"
4. Enter a support email
5. Click "Save"

### Enable Anonymous Authentication

1. In the Firebase Console, go to "Authentication" > "Sign-in method"
2. Click "Anonymous"
3. Toggle "Enabled"
4. Click "Save"

## Step 5: Configure Firestore Database

### Create Firestore Database

1. In the Firebase Console, go to "Firestore Database"
2. Click "Create database"
3. Choose "Start in test mode" (for development only)
4. Choose a location
5. Click "Enable"

### Set Up Security Rules

For development, you can use these basic rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow read/write access to all users
    match /{document=**} {
      allow read, write: if true;
    }
  }
}
```

For production, use more restrictive rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Allow users to read and write only their own data
    match /users/{userId} {
      allow read, update, delete: if request.auth != null && request.auth.uid == userId;
      allow create: if request.auth != null;
    }
  }
}
```

## Step 6: Configure Cloud Storage (Optional)

1. In the Firebase Console, go to "Storage"
2. Click "Get started"
3. Follow the setup wizard
4. Choose a location
5. Click "Done"

## Step 7: Test Phone Authentication

### Using Firebase Test Numbers

1. In the Firebase Console, go to "Authentication" > "Sign-in method"
2. Scroll to "Phone" provider
3. In the "Test phone numbers" section, add test phone numbers
4. Example:
   - Phone number: +15555555555
   - Verification code: 123456

## Step 8: Verify Configuration

### Check Firebase Options

Ensure the `lib/firebase_options.dart` file is correctly generated. If you need to regenerate it:

1. Install FlutterFire CLI:
   ```cmd
   dart pub global activate flutterfire_cli
   ```

2. Configure your app:
   ```cmd
   flutterfire configure
   ```

3. Select your Firebase project
4. Select the platforms you want to configure (Android, iOS, etc.)
5. The CLI will generate the `firebase_options.dart` file

## Step 9: 3-Day Session Expiration Logic

The app implements a custom 3-day session expiration mechanism:

### Implementation Details

1. On successful sign-in, the app stores in Firestore:
   ```
   users/{uid}:
     lastLogin: FieldValue.serverTimestamp()
     sessionExpiresAt: Timestamp(lastLogin + 3 days)
   ```

2. On app launch, the app checks:
   - If current time <= sessionExpiresAt → allow access
   - If expired → auto signOut() and redirect to password re-authentication screen

3. After successful re-authentication:
   - Update lastLogin and sessionExpiresAt with new timestamps

### Firestore Structure

The app expects the following Firestore structure:

```
users/
  {uid}/
    lastLogin: timestamp
    sessionExpiresAt: timestamp
    email: string
    displayName: string (optional)
    isAnonymous: boolean (optional)
```

## Cloudflare Security Integration (Backend-Level)

### DNS Configuration

1. Point your domain's nameservers to Cloudflare
2. Add DNS records in Cloudflare dashboard:
   - A record for your domain pointing to your server IP
   - CNAME records for subdomains if needed

### SSL/TLS Configuration

1. In Cloudflare dashboard, go to "SSL/TLS" > "Overview"
2. Set SSL/TLS encryption mode to "Full" or "Full (strict)"
3. Enable "Always Use HTTPS" if desired

### Web Application Firewall (WAF)

1. In Cloudflare dashboard, go to "Security" > "WAF"
2. Enable the WAF
3. Configure firewall rules as needed for your application

### Bot Protection

1. In Cloudflare dashboard, go to "Security" > "Bots"
2. Enable Bot Fight Mode or Super Bot Fight Mode
3. Configure additional bot protection rules if needed

### Rate Limiting

1. In Cloudflare dashboard, go to "Security" > "Rate Limiting"
2. Create rate limiting rules for sensitive endpoints
3. Example rule:
   - If more than 100 requests per minute to /api/auth
   - Then block the IP for 1 hour

### Cloudflare Turnstile Integration

To integrate Cloudflare Turnstile (human verification):

1. In Cloudflare dashboard, go to "Security" > "WAF" > "Turnstile"
2. Create a new Turnstile widget
3. Copy the site key and secret key
4. Integrate the Turnstile widget in your web forms:
   ```html
   <div class="cf-turnstile" data-sitekey="your_site_key"></div>
   ```
5. Verify the token on your backend with the secret key

## Troubleshooting

### Common Issues

1. **SHA Certificate Mismatch**: Ensure the SHA-1 and SHA-256 certificates in Firebase match those generated from your keystore.

2. **google-services.json Missing**: Make sure the `google-services.json` file is in the `android/app` directory.

3. **Authentication Not Working**: Check that all required authentication providers are enabled in Firebase Console.

4. **Phone Auth Not Working**: Verify SHA certificates and test with Firebase test numbers.

5. **Google Sign-In Issues**: Ensure the support email is set in Firebase Console and OAuth consent screen is configured.

### Debugging Tips

1. Check the Firebase Console for authentication logs
2. Use Flutter's debug output to trace authentication flow
3. Verify network connectivity
4. Check Android permissions in AndroidManifest.xml

## Additional Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [FlutterFire Documentation](https://firebase.flutter.dev/)
- [Cloudflare Documentation](https://developers.cloudflare.com/)