import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/auth_model.dart';
import 'signup_screen.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _otpController = TextEditingController();
  final _phoneController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _requiresOtp = false;
  bool _showPhoneAuth = false;
  String? _otpEmail;
  String? _verificationId;

  // 🔐 ميزات جديدة
  int _loginAttempts = 0;
  final int _maxAttempts = 5;
  bool _isLocked = false;
  final int _lockDuration = 600; // بالثواني
  Timer? _lockTimer;
  int _remainingLockTime = 0;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _otpController.dispose();
    _phoneController.dispose();
    _lockTimer?.cancel();
    super.dispose();
  }

  // ⏱ قفل الحساب مؤقتًا بعد محاولات خاطئة
  void _startLockTimer() {
    setState(() {
      _isLocked = true;
      _remainingLockTime = _lockDuration;
    });

    _lockTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remainingLockTime--;
        if (_remainingLockTime <= 0) {
          _isLocked = false;
          _loginAttempts = 0;
          timer.cancel();
        }
      });
    });
  }

  void _handleEmailLogin() async {
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account temporarily locked. Try again in $_remainingLockTime seconds.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);
      final authModel = Provider.of<AuthModel>(context, listen: false);

      try {
        final result = await authModel.login(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );

        setState(() => _isLoading = false);

        if (result == true) {
          // Successful login
          _loginAttempts = 0;

          // Check if re-authentication is needed
          bool needPassword = await authModel.shouldAskPassword();
          if (needPassword) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please re-enter your password.'),
                  backgroundColor: Colors.orange,
                ),
              );
            }
            // Could redirect to re-authentication screen here
            return;
          }

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Login successful!'),
                backgroundColor: Colors.green,
              ),
            );
          }
        } else {
          // Failed login attempt
          _loginAttempts++;
          if (_loginAttempts >= _maxAttempts) {
            _startLockTimer();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Too many failed attempts. Account locked for $_lockDuration seconds.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            int remaining = _maxAttempts - _loginAttempts;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Invalid credentials. $remaining attempts remaining before lock.',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } catch (e) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handlePhoneAuth() async {
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account temporarily locked. Try again in $_remainingLockTime seconds.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authModel = Provider.of<AuthModel>(context, listen: false);

    try {
      await authModel.authService.verifyPhoneNumber(
        phoneNumber: _phoneController.text.trim(),
        verificationCompleted: (PhoneAuthCredential credential) async {
          // Auto-retrieval of SMS code
          try {
            await FirebaseAuth.instance.signInWithCredential(credential);
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Phone verification successful!'),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            setState(() => _isLoading = false);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Phone verification failed: $e'),
                  backgroundColor: Colors.red,
                ),
              );
            }
          }
        },
        verificationFailed: (FirebaseAuthException e) {
          setState(() => _isLoading = false);
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Phone verification failed: ${e.message}'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        codeSent: (String verificationId, int? resendToken) {
          setState(() {
            _isLoading = false;
            _verificationId = verificationId;
            _requiresOtp = true;
          });
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('SMS code sent. Please enter the code below.'),
                backgroundColor: Colors.blue,
              ),
            );
          }
        },
        codeAutoRetrievalTimeout: (String verificationId) {
          _verificationId = verificationId;
        },
      );
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Phone authentication error: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _verifyPhoneOtp() async {
    if (_otpController.text.isEmpty || _verificationId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter the verification code'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final AuthCredential credential = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otpController.text.trim(),
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      setState(() {
        _isLoading = false;
        _requiresOtp = false;
        _verificationId = null;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Phone verification successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid verification code: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleGoogleSignIn() async {
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account temporarily locked. Try again in $_remainingLockTime seconds.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authModel = Provider.of<AuthModel>(context, listen: false);

    try {
      final result = await authModel.authService.signInWithGoogle();

      setState(() => _isLoading = false);

      if (result == null) {
        // User canceled the sign-in
        return;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google sign-in successful!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Google sign-in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _handleAnonymousSignIn() async {
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Account temporarily locked. Try again in $_remainingLockTime seconds.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authModel = Provider.of<AuthModel>(context, listen: false);

    try {
      final result = await authModel.authService.signInAnonymously();

      setState(() => _isLoading = false);

      if (result != null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Anonymous sign-in successful!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anonymous sign-in failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF1a1a2e), Color(0xFF16213e), Color(0xFF0f3460)],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              children: [
                const SizedBox(height: 40),
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(60),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purple.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.user,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Welcome Back!',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _isLocked
                      ? 'Account locked. Try again in $_remainingLockTime s'
                      : 'Welcome back, we missed you!',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: _isLocked
                        ? Colors.redAccent
                        : Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 40),
                _buildLoginForm(),
                const SizedBox(height: 20),
                _buildAuthOptions(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_requiresOtp)
                    _buildGlassmorphismField(
                      controller: _otpController,
                      label: 'Enter OTP',
                      icon: LucideIcons.key,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter the OTP';
                        }
                        if (value.length != 6) {
                          return 'OTP must be 6 digits';
                        }
                        return null;
                      },
                    )
                  else if (_showPhoneAuth)
                    _buildGlassmorphismField(
                      controller: _phoneController,
                      label: 'Phone Number',
                      icon: LucideIcons.phone,
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your phone number';
                        }
                        return null;
                      },
                    )
                  else
                    Column(
                      children: [
                        _buildGlassmorphismField(
                          controller: _emailController,
                          label: 'Email',
                          icon: LucideIcons.user,
                          keyboardType: TextInputType.emailAddress,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        _buildGlassmorphismField(
                          controller: _passwordController,
                          label: 'Password',
                          icon: LucideIcons.lock,
                          isPassword: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your password';
                            }
                            if (value.length < 6) {
                              return 'Password must be at least 6 characters';
                            }
                            return null;
                          },
                        ),
                      ],
                    ),
                  const SizedBox(height: 20),
                  _buildLoginButton(),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    child: Text(
                      "Don't have an account? Sign up",
                      style: GoogleFonts.inter(
                        color: Colors.white.withOpacity(0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 50,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [Color(0xFF7C3AED), Color(0xFFF97316)],
        ),
        boxShadow: [
          BoxShadow(color: Colors.purple.withOpacity(0.3), blurRadius: 15),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading
            ? null
            : _requiresOtp
            ? (_showPhoneAuth
                  ? _verifyPhoneOtp
                  : () {}) // Will implement email OTP verification if needed
            : (_showPhoneAuth ? _handlePhoneAuth : _handleEmailLogin),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                _requiresOtp
                    ? 'Verify OTP'
                    : _showPhoneAuth
                    ? 'Send Code'
                    : 'Sign in',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
      ),
    );
  }

  Widget _buildAuthOptions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Text(
                'OR',
                style: GoogleFonts.inter(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.3))),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 15,
          runSpacing: 15,
          children: [
            _buildAuthOptionButton(
              icon: LucideIcons.phone,
              label: 'Phone',
              onTap: () {
                setState(() {
                  _showPhoneAuth = !_showPhoneAuth;
                  _requiresOtp = false;
                  _verificationId = null;
                });
              },
            ),
            _buildAuthOptionButton(
              icon: LucideIcons.mail,
              label: 'Google',
              onTap: _handleGoogleSignIn,
            ),
            _buildAuthOptionButton(
              icon: LucideIcons.user,
              label: 'Guest',
              onTap: _handleAnonymousSignIn,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAuthOptionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: _isLoading ? null : onTap,
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white.withOpacity(0.1),
              Colors.white.withOpacity(0.05),
            ],
          ),
          border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Colors.white, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlassmorphismField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool isPassword = false,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.white.withOpacity(0.1),
            Colors.white.withOpacity(0.05),
          ],
        ),
        border: Border.all(color: Colors.white.withOpacity(0.2), width: 1),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: isPassword ? !_isPasswordVisible : false,
        style: GoogleFonts.inter(color: Colors.white, fontSize: 16),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
          prefixIcon: Icon(
            icon,
            color: Colors.white.withOpacity(0.7),
            size: 20,
          ),
          suffixIcon: isPassword
              ? IconButton(
                  icon: Icon(
                    _isPasswordVisible ? LucideIcons.eyeOff : LucideIcons.eye,
                    color: Colors.white.withOpacity(0.7),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() => _isPasswordVisible = !_isPasswordVisible);
                  },
                )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(
              color: Colors.purple.withOpacity(0.5),
              width: 2,
            ),
          ),
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 16,
          ),
        ),
        validator: validator,
      ),
    );
  }
}
