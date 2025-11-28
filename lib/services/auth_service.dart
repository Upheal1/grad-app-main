import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter/foundation.dart';

class AuthService with ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // Email & Password Authentication
  Future<UserCredential?> signInWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Update last login and session expiration
      await _updateUserSession(result.user!.uid);

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to sign in with email and password: ${e.message}');
      }
      rethrow;
    }
  }

  Future<UserCredential?> createUserWithEmailAndPassword(
    String email,
    String password,
  ) async {
    try {
      final UserCredential result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'email': email,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update last login and session expiration
      await _updateUserSession(result.user!.uid);

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to create user with email and password: ${e.message}');
      }
      rethrow;
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to send password reset email: ${e.message}');
      }
      rethrow;
    }
  }

  // Phone Number Authentication
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required PhoneVerificationCompleted verificationCompleted,
    required PhoneVerificationFailed verificationFailed,
    required PhoneCodeSent codeSent,
    required PhoneCodeAutoRetrievalTimeout codeAutoRetrievalTimeout,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      verificationCompleted: verificationCompleted,
      verificationFailed: verificationFailed,
      codeSent: codeSent,
      codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
      timeout: const Duration(seconds: 60),
    );
  }

  Future<UserCredential?> signInWithPhoneNumber(
    String verificationId,
    String smsCode,
  ) async {
    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      // Update last login and session expiration
      await _updateUserSession(result.user!.uid);

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to sign in with phone number: ${e.message}');
      }
      rethrow;
    }
  }

  // Google Sign-In
  Future<UserCredential?> signInWithGoogle() async {
    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        // User canceled the sign-in
        return null;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential result = await _auth.signInWithCredential(
        credential,
      );

      // Create user document if it doesn't exist
      final DocumentSnapshot userDoc = await _firestore
          .collection('users')
          .doc(result.user!.uid)
          .get();
      if (!userDoc.exists) {
        await _firestore.collection('users').doc(result.user!.uid).set({
          'email': result.user!.email,
          'displayName': result.user!.displayName,
          'photoUrl': result.user!.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Update last login and session expiration
      await _updateUserSession(result.user!.uid);

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to sign in with Google: ${e.message}');
      }
      rethrow;
    }
  }

  // Anonymous Authentication
  Future<UserCredential?> signInAnonymously() async {
    try {
      final UserCredential result = await _auth.signInAnonymously();

      // Create user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).set({
        'isAnonymous': true,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update last login and session expiration
      await _updateUserSession(result.user!.uid);

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to sign in anonymously: ${e.message}');
      }
      rethrow;
    }
  }

  // Link anonymous account to email/password
  Future<UserCredential?> linkAnonymousAccountToEmail(
    String email,
    String password,
  ) async {
    try {
      final User? user = _auth.currentUser;
      if (user == null || !user.isAnonymous) {
        throw FirebaseAuthException(
          code: 'invalid-user',
          message: 'Current user is not anonymous',
        );
      }

      final AuthCredential credential = EmailAuthProvider.credential(
        email: email,
        password: password,
      );

      final UserCredential result = await user.linkWithCredential(credential);

      // Update user document in Firestore
      await _firestore.collection('users').doc(result.user!.uid).update({
        'email': email,
        'isAnonymous': false,
      });

      // Update last login and session expiration
      await _updateUserSession(result.user!.uid);

      return result;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to link anonymous account: ${e.message}');
      }
      rethrow;
    }
  }

  // Session Management
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

  Future<bool> shouldReauthenticate(String uid) async {
    try {
      final DocumentSnapshot doc = await _firestore
          .collection('users')
          .doc(uid)
          .get();
      if (!doc.exists) return false;

      final data = doc.data() as Map<String, dynamic>?;
      if (data == null) return false;

      final sessionExpiresAt = data['sessionExpiresAt'] as Timestamp?;
      if (sessionExpiresAt == null) return false;

      return Timestamp.now().compareTo(sessionExpiresAt) > 0;
    } catch (e) {
      if (kDebugMode) {
        print('Error checking session expiration: $e');
      }
      return false;
    }
  }

  Future<void> reauthenticateUser(String email, String password) async {
    final User? user = _auth.currentUser;
    if (user == null) return;

    final AuthCredential credential = EmailAuthProvider.credential(
      email: email,
      password: password,
    );

    await user.reauthenticateWithCredential(credential);
    await _updateUserSession(user.uid);
  }

  // Sign Out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
      await _googleSignIn.signOut();
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Failed to sign out: ${e.message}');
      }
      rethrow;
    }
  }
}
