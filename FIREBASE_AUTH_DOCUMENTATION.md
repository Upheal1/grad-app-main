# Firebase Authentication Implementation Documentation

## Overview

This document provides detailed information about the Firebase authentication implementation in the MindQuest mobile application. The implementation includes multiple authentication methods with a custom 3-day session expiration requirement.

## Firebase Setup

### Prerequisites

1. Firebase project created in the Firebase Console
2. FlutterFire CLI installed (`npm install -g flutterfire_cli`)
3. SHA-1 and SHA-256 certificates for Android app (required for phone authentication)

### Firebase Configuration Steps

1. **Install FlutterFire CLI**:
   ```bash
   npm install -g flutterfire_cli
   ```

2. **Configure Firebase in your Flutter project**:
   ```bash
   flutterfire configure
   ```
   This command generates the `firebase_options.dart` file with platform-specific configuration.

3. **Add Firebase dependencies to `pubspec.yaml`**:
   ```yaml
   dependencies:
     firebase_core: ^3.15.2
     firebase_auth: ^5.7.0
     cloud_firestore: ^5.6.12
     google_sign_in: ^6.2.1
   ```

4. **Initialize Firebase in your app**:
   ```dart
   import 'package:firebase_core/firebase_core.dart';
   import 'firebase_options.dart';

   void main() async {
     WidgetsFlutterBinding.ensureInitialized();
     await Firebase.initializeApp(
       options: DefaultFirebaseOptions.currentPlatform,
     );
     runApp(const MyApp());
   }
   ```

## Authentication Methods

### 1. Email & Password Authentication

#### Implementation Details

- Uses Firebase Authentication's built-in email/password provider
- Implements proper form validation and error handling
- Supports user registration and login
- Includes password reset functionality

#### Key Methods

```dart
// Sign up
final UserCredential result = await _auth.createUserWithEmailAndPassword(
  email: email,
  password: password,
);

// Sign in
final UserCredential result = await _auth.signInWithEmailAndPassword(
  email: email,
  password: password,
);

// Password reset
await _auth.sendPasswordResetEmail(email: email);
```

### 2. Phone Number Authentication (SMS OTP)

#### Implementation Details

- Uses Firebase Authentication's phone provider
- Handles SMS sending, auto-retrieval, and resend logic
- Requires SHA-1 and SHA-256 configuration for Android

#### Setup Requirements

1. **Generate SHA-1 and SHA-256 certificates**:
   ```bash
   cd android
   ./gradlew signingReport
   ```

2. **Add fingerprints to Firebase Console**:
   - Go to Project Settings in Firebase Console
   - Under "General" tab, add the SHA-1 and SHA-256 fingerprints

#### Key Methods

```dart
// Verify phone number
await _auth.verifyPhoneNumber(
  phoneNumber: phoneNumber,
  verificationCompleted: verificationCompleted,
  verificationFailed: verificationFailed,
  codeSent: codeSent,
  codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
);

// Sign in with phone number
final AuthCredential credential = PhoneAuthProvider.credential(
  verificationId: verificationId,
  smsCode: smsCode,
);
final UserCredential result = await _auth.signInWithCredential(credential);
```

### 3. Google Sign-In Integration

#### Implementation Details

- Uses the `google_sign_in` package
- Links Google accounts to Firebase Auth
- Properly handles authentication states

#### Setup Requirements

1. **Configure Google Sign-In in Firebase Console**:
   - Enable Google as a sign-in provider
   - Add support email

2. **Add Google Services dependencies** in `android/app/build.gradle`:
   ```gradle
   implementation 'com.google.android.gms:play-services-auth:21.2.0'
   ```

#### Key Methods

```dart
// Sign in with Google
final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
final GoogleSignInAuthentication googleAuth = await googleUser!.authentication;
final OAuthCredential credential = GoogleAuthProvider.credential(
  accessToken: googleAuth.accessToken,
  idToken: googleAuth.idToken,
);
final UserCredential result = await _auth.signInWithCredential(credential);
```

### 4. Anonymous Authentication

#### Implementation Details

- Enables guest access to the application
- Allows upgrading guest accounts to permanent accounts without losing data

#### Key Methods

```dart
// Sign in anonymously
final UserCredential result = await _auth.signInAnonymously();

// Link anonymous account to email/password
final AuthCredential credential = EmailAuthProvider.credential(
  email: email,
  password: password,
);
final UserCredential result = await user.linkWithCredential(credential);
```

## Custom Session Expiration (3-Day Limit)

### Implementation Details

The application enforces a strict 3-day authentication session limit:

1. On successful sign-in:
   - Sets `lastLogin` using server timestamp
   - Calculates `sessionExpiresAt = lastLogin + 3 days`

2. On every app launch:
   - Reads `sessionExpiresAt`
   - If current time > `sessionExpiresAt`:
     - Automatically performs `FirebaseAuth.signOut()`
     - Redirects user to password re-authentication screen

3. Post-Verification:
   - After user re-enters password:
     - Uses `reauthenticateWithCredential`
     - Updates `lastLogin` and recalculates `sessionExpiresAt`

### Firestore Structure

```javascript
users/{uid}:
   lastLogin: timestamp
   sessionExpiresAt: timestamp
```

### Key Methods

```dart
// Update user session
Future<void> _updateUserSession(String uid) async {
  final Timestamp now = Timestamp.now();
  final Timestamp sessionExpiresAt = Timestamp.fromDate(
    DateTime.now().add(const Duration(days: 3)),
  );

  await _firestore.collection('users').doc(uid).set({
    'lastLogin': now,
    'sessionExpiresAt': sessionExpiresAt,
  }, SetOptions(merge: true));
}

// Check if re-authentication is needed
Future<bool> shouldReauthenticate(String uid) async {
  final DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
  if (!doc.exists) return false;

  final sessionExpiresAt = doc['sessionExpiresAt'] as Timestamp?;
  if (sessionExpiresAt == null) return false;

  return Timestamp.now().compareTo(sessionExpiresAt) > 0;
}
```

## Cloudflare Security Integration

### Implementation Details

Cloudflare is configured at the backend/DNS level to enhance security:

1. Route all API traffic through Cloudflare
2. Enable SSL/TLS Full mode
3. Configure Web Application Firewall (WAF)
4. Enable bot protection
5. Set up rate limiting for sensitive endpoints
6. Integrate Cloudflare Turnstile as a human verification method (instead of CAPTCHA)

### Setup Process

1. Point your domain's DNS to Cloudflare nameservers
2. Enable SSL/TLS encryption in Cloudflare dashboard
3. Configure Firewall rules and WAF settings
4. Set up Rate Limiting rules for sensitive endpoints
5. Integrate Cloudflare Turnstile in your web forms

## Testing Authentication Flows

### Test Cases

1. **Email/Password Authentication**:
   - Valid registration
   - Invalid registration (duplicate email, weak password)
   - Valid login
   - Invalid login (wrong credentials)
   - Password reset flow

2. **Phone Authentication**:
   - Valid phone number verification
   - Invalid phone number
   - SMS code verification
   - Resend SMS code

3. **Google Sign-In**:
   - Successful Google sign-in
   - Cancelled Google sign-in
   - Account linking

4. **Anonymous Authentication**:
   - Anonymous sign-in
   - Upgrade anonymous account

5. **Session Expiration**:
   - Session expiration after 3 days
   - Re-authentication flow
   - Session extension after re-authentication

## Security Considerations

1. All passwords are securely hashed by Firebase Authentication
2. Sensitive data is stored in Firestore with appropriate security rules
3. Phone authentication requires proper SHA certificate configuration
4. Google Sign-In uses OAuth 2.0 for secure authentication
5. Session expiration ensures periodic re-authentication

## Troubleshooting

### Common Issues

1. **Phone Authentication Not Working**:
   - Verify SHA-1 and SHA-256 fingerprints are added to Firebase Console
   - Check that the phone number format is correct (+1234567890)

2. **Google Sign-In Issues**:
   - Ensure Google Services dependencies are added to build.gradle
   - Verify Google Sign-In is enabled in Firebase Console

3. **Session Expiration Not Working**:
   - Check Firestore rules allow reading/writing to user documents
   - Verify device time is correct

## Conclusion

This implementation provides a robust, secure authentication system with multiple sign-in options and a custom session expiration mechanism. All authentication methods are fully integrated with Firebase Authentication and tested for reliability.