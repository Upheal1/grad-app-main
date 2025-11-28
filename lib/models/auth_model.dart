// lib/models/auth_model.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:argon2/argon2.dart';
import '../services/email_service.dart' as mail;
import '../config.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/auth_service.dart';

const String PASSWORD_PEPPER = 'D9f#7kLp2@wVx8qZrT1mY!uB4sE0jHcN';

class AuthModel extends ChangeNotifier {
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  final AuthService _authService = AuthService();

  bool _isAuthenticated = false;
  String? _userEmail;
  String? _userName;
  Map<String, UserAccount> _userAccounts = {};
  final Map<String, int> _failedAttempts = {};

  // Firebase user
  User? _firebaseUser;

  bool get isAuthenticated => _isAuthenticated;
  String? get userEmail => _userEmail;
  String? get userName => _userName;
  User? get firebaseUser => _firebaseUser;
  AuthService get authService => _authService;

  AuthModel() {
    _loadAuthState();
    _loadUserAccounts();
    // Listen to auth state changes
    _authService.authStateChanges.listen((User? user) {
      _firebaseUser = user;
      _isAuthenticated = user != null;
      if (user != null) {
        _userEmail = user.email;
        _userName = user.displayName ?? user.email;
      } else {
        _userEmail = null;
        _userName = null;
      }
      notifyListeners();
    });
  }

  // 🔹 توليد Salt عشوائي
  String _generateSalt([int length = 16]) {
    final rand = Random.secure();
    final values = List<int>.generate(length, (i) => rand.nextInt(256));
    return base64Url.encode(values);
  }

  // 🔹 تشفير كلمة المرور باستخدام Argon2 + Pepper
  Future<String> _hashPassword(String password, String salt) async {
    final saltBytes = utf8.encode(salt);
    final params = Argon2Parameters(
      Argon2Parameters.ARGON2_id,
      saltBytes,
      version: Argon2Parameters.ARGON2_VERSION_13,
      iterations: 2,
      memoryPowerOf2: 16,
      lanes: 1,
    );
    final generator = Argon2BytesGenerator();
    generator.init(params);
    final passwordBytes = utf8.encode(password + PASSWORD_PEPPER);
    final result = Uint8List(32);
    generator.generateBytes(passwordBytes, result, 0, result.length);
    return base64Url.encode(result);
  }

  // 🔹 تحميل حالة المستخدم
  Future<void> _loadAuthState() async {
    _isAuthenticated = await _getBool('isAuthenticated') ?? false;
    _userEmail = await _storage.read(key: 'userEmail');
    _userName = await _storage.read(key: 'userName');
    notifyListeners();
  }

  // 🔹 تحميل المستخدمين المخزنين
  Future<void> _loadUserAccounts() async {
    final accountsJson = await _storage.read(key: 'userAccounts');
    if (accountsJson != null) {
      final Map<String, dynamic> accountsMap = json.decode(accountsJson);
      _userAccounts = accountsMap.map(
        (key, value) => MapEntry(key, UserAccount.fromJson(value)),
      );
    }
  }

  // 🔹 حفظ الحالة
  Future<void> _saveAuthState() async {
    await _storage.write(
      key: 'isAuthenticated',
      value: _isAuthenticated.toString(),
    );
    if (_userEmail != null)
      await _storage.write(key: 'userEmail', value: _userEmail!);
    if (_userName != null)
      await _storage.write(key: 'userName', value: _userName!);
  }

  // 🔹 حفظ المستخدمين
  Future<void> _saveUserAccounts() async {
    final accountsMap = _userAccounts.map(
      (key, value) => MapEntry(key, value.toJson()),
    );
    await _storage.write(key: 'userAccounts', value: json.encode(accountsMap));
  }

  // 🔹 تقييم قوة كلمة المرور
  String evaluatePasswordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) score++;

    if (score <= 1) return "Weak";
    if (score == 2) return "Medium";
    return "Strong";
  }

  // 🔹 تسجيل مستخدم جديد
  Future<bool> signUp(String email, String password, String name) async {
    try {
      final UserCredential? userCredential = await _authService
          .createUserWithEmailAndPassword(email, password);

      if (userCredential != null) {
        _isAuthenticated = true;
        _userEmail = email;
        _userName = name;
        _firebaseUser = userCredential.user;
        await _saveAuthState();
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Sign up failed: ${e.message}');
      }
      return false;
    }
  }

  // 🔹 تسجيل الدخول
  Future<bool?> login(String email, String password) async {
    try {
      final UserCredential? userCredential = await _authService
          .signInWithEmailAndPassword(email, password);

      if (userCredential != null) {
        _isAuthenticated = true;
        _userEmail = email;
        _userName = userCredential.user?.displayName ?? email;
        _firebaseUser = userCredential.user;
        await _saveAuthState();
        notifyListeners();
        return true;
      }
      return false;
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Login failed: ${e.message}');
      }
      return false;
    }
  }

  // 🔹 تسجيل الخروج
  Future<void> logout() async {
    await _authService.signOut();
    _isAuthenticated = false;
    _userEmail = null;
    _userName = null;
    _firebaseUser = null;
    await _saveAuthState();
    notifyListeners();
  }

  // 🔹 طلب إعادة تعيين كلمة المرور
  Future<void> requestPasswordReset(String email) async {
    try {
      await _authService.sendPasswordResetEmail(email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Password reset failed: ${e.message}');
      }
    }
  }

  // 🔹 التحقق إذا مرت 3 أيام منذ آخر سيشن
  Future<bool> shouldAskPassword() async {
    if (_firebaseUser == null) return false;
    return await _authService.shouldReauthenticate(_firebaseUser!.uid);
  }

  // 🔹 إعادة مصادقة المستخدم
  Future<void> reauthenticateUser(String email, String password) async {
    try {
      await _authService.reauthenticateUser(email, password);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Reauthentication failed: ${e.message}');
      }
      rethrow;
    }
  }

  Future<bool?> _getBool(String key) async {
    final value = await _storage.read(key: key);
    if (value == null) return null;
    return value.toLowerCase() == 'true';
  }

  // 🔹 جلب بيانات المستخدم (للشاشة الأمنية)
  Future<Map<String, dynamic>?> getUserProfile(String email) async {
    // Return Firebase user data
    if (_firebaseUser != null) {
      return {
        'email': _firebaseUser!.email,
        'name': _firebaseUser!.displayName ?? _firebaseUser!.email,
        'lastLogin': 'Not available in this implementation',
        'is2FAEnabled': false,
        'isBiometricEnabled': false,
        'activities': ['Firebase authentication'],
      };
    }
    return null;
  }
}

// 🔹 نموذج المستخدم
class UserAccount {
  final String email;
  final String password;
  final String salt;
  final String name;
  List<String> activities;
  bool is2FAEnabled;
  bool isBiometricEnabled;
  String? lastLogin;
  String? lockUntil;

  UserAccount({
    required this.email,
    required this.password,
    required this.salt,
    required this.name,
    required this.activities,
    required this.is2FAEnabled,
    required this.isBiometricEnabled,
    this.lastLogin,
    this.lockUntil,
  });

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'salt': salt,
    'name': name,
    'activities': activities,
    'is2FAEnabled': is2FAEnabled,
    'isBiometricEnabled': isBiometricEnabled,
    'lastLogin': lastLogin,
    'lockUntil': lockUntil,
  };

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
    email: json['email'],
    password: json['password'],
    salt: json['salt'],
    name: json['name'],
    activities: List<String>.from(json['activities'] ?? []),
    is2FAEnabled: json['is2FAEnabled'] ?? true,
    isBiometricEnabled: json['isBiometricEnabled'] ?? false,
    lastLogin: json['lastLogin'],
    lockUntil: json['lockUntil'],
  );
}
