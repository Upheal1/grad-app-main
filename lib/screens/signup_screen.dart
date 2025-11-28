import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/auth_model.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _otpController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;
  bool _requiresOtp = false;
  bool _isLocked = false;

  double _passwordStrength = 0.0;
  String _passwordStrengthLabel = '';
  Color _passwordStrengthColor = Colors.transparent;

  int _remainingAttempts = 5;
  DateTime? _lockEndTime;

  final _storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadLockStatus();
  }

  Future<void> _loadLockStatus() async {
    final lockEndString = await _storage.read(key: 'lock_end_time');
    if (lockEndString != null) {
      _lockEndTime = DateTime.tryParse(lockEndString);
      if (_lockEndTime != null && DateTime.now().isBefore(_lockEndTime!)) {
        setState(() => _isLocked = true);
        _startUnlockTimer();
      }
    }
  }

  void _startUnlockTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (_lockEndTime == null) return;
      if (DateTime.now().isAfter(_lockEndTime!)) {
        setState(() {
          _isLocked = false;
          _remainingAttempts = 5;
        });
        _storage.delete(key: 'lock_end_time');
      } else {
        setState(() {});
        _startUnlockTimer();
      }
    });
  }

  void _checkPasswordStrength(String password) {
    int score = 0;
    if (password.length >= 8) score++;
    if (RegExp(r'[A-Z]').hasMatch(password)) score++;
    if (RegExp(r'[0-9]').hasMatch(password)) score++;
    if (RegExp(r'[!@#\$&*~%^]').hasMatch(password)) score++;

    setState(() {
      _passwordStrength = (score / 4);
      if (score == 0) {
        _passwordStrengthLabel = '';
        _passwordStrengthColor = Colors.transparent;
      } else if (score == 1) {
        _passwordStrengthLabel = 'Weak';
        _passwordStrengthColor = Colors.red;
      } else if (score == 2) {
        _passwordStrengthLabel = 'Medium';
        _passwordStrengthColor = Colors.orange;
      } else if (score == 3) {
        _passwordStrengthLabel = 'Strong';
        _passwordStrengthColor = Colors.lightGreen;
      } else {
        _passwordStrengthLabel = 'Excellent';
        _passwordStrengthColor = Colors.greenAccent;
      }
    });
  }

  void _handleSignUp() async {
    if (_isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('⏳ Locked! Try again later')),
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authModel = Provider.of<AuthModel>(context, listen: false);

      try {
        final result = await authModel.signUp(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );

        setState(() => _isLoading = false);

        if (result == true) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Account created successfully!'),
                backgroundColor: Colors.green,
              ),
            );

            // Navigate back to login screen
            Navigator.pop(context);
          }
        } else {
          _remainingAttempts--;
          if (_remainingAttempts <= 0) {
            setState(() {
              _isLocked = true;
              _lockEndTime = DateTime.now().add(const Duration(minutes: 1));
            });
            await _storage.write(
              key: 'lock_end_time',
              value: _lockEndTime!.toIso8601String(),
            );
            _startUnlockTimer();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  '🚫 Too many failed attempts. Locked for 1 minute.',
                ),
                backgroundColor: Colors.red,
              ),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Account creation failed. Remaining: $_remainingAttempts',
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
            content: Text('Sign up failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final remainingLockTime = _lockEndTime != null
        ? _lockEndTime!.difference(DateTime.now()).inSeconds
        : 0;

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
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.userPlus,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Get Started Free',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Free Forever. No Credit Card Needed',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 40),
                Container(
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
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
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
                              _requiresOtp
                                  ? _buildGlassmorphismField(
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
                                  : Column(
                                      children: [
                                        _buildGlassmorphismField(
                                          controller: _emailController,
                                          label: 'Email Address',
                                          icon: LucideIcons.mail,
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          hintText: 'yourname@gmail.com',
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Enter your email';
                                            }
                                            if (!value.contains('@')) {
                                              return 'Enter valid email';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 20),
                                        _buildGlassmorphismField(
                                          controller: _nameController,
                                          label: 'Your Name',
                                          icon: LucideIcons.user,
                                          hintText: '@yourname',
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Enter your name';
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
                                          onChanged: _checkPasswordStrength,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Enter password';
                                            }
                                            if (value.length < 8) {
                                              return 'Min 8 characters';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 10),
                                        LinearProgressIndicator(
                                          value: _passwordStrength,
                                          minHeight: 8,
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                _passwordStrengthColor,
                                              ),
                                          backgroundColor: Colors.white
                                              .withOpacity(0.2),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          _passwordStrengthLabel,
                                          style: GoogleFonts.inter(
                                            color: _passwordStrengthColor,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 20),
                                        _buildGlassmorphismField(
                                          controller:
                                              _confirmPasswordController,
                                          label: 'Confirm Password',
                                          icon: LucideIcons.lock,
                                          isPassword: true,
                                          validator: (value) {
                                            if (value == null ||
                                                value.isEmpty) {
                                              return 'Confirm your password';
                                            }
                                            if (value !=
                                                _passwordController.text) {
                                              return 'Passwords do not match';
                                            }
                                            return null;
                                          },
                                        ),
                                        const SizedBox(height: 30),
                                      ],
                                    ),
                              Container(
                                width: double.infinity,
                                height: 50,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF7C3AED),
                                      Color(0xFFF97316),
                                    ],
                                  ),
                                ),
                                child: ElevatedButton(
                                  onPressed: _isLoading
                                      ? null
                                      : _isLocked
                                      ? null
                                      : _requiresOtp
                                      ? () {} // Will implement OTP verification if needed
                                      : _handleSignUp,
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
                                            valueColor: AlwaysStoppedAnimation(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : Text(
                                          _isLocked
                                              ? 'Locked (${remainingLockTime}s)'
                                              : _requiresOtp
                                              ? 'Verify OTP'
                                              : 'Sign Up',
                                          style: GoogleFonts.inter(
                                            color: Colors.white,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    String? hintText,
    String? Function(String?)? validator,
    Function(String)? onChanged,
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
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          hintText: hintText,
          labelStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.7),
            fontSize: 14,
          ),
          hintStyle: GoogleFonts.inter(
            color: Colors.white.withOpacity(0.5),
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
