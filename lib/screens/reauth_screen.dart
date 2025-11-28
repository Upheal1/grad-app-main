import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:lucide_icons/lucide_icons.dart';
import '../models/auth_model.dart';

class ReauthScreen extends StatefulWidget {
  final String email;

  const ReauthScreen({super.key, required this.email});

  @override
  State<ReauthScreen> createState() => _ReauthScreenState();
}

class _ReauthScreenState extends State<ReauthScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();

  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _handleReauth() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isLoading = true);

      final authModel = Provider.of<AuthModel>(context, listen: false);

      try {
        await authModel.reauthenticateUser(
          widget.email,
          _passwordController.text,
        );

        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Re-authentication successful!'),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to the main app
          Navigator.pop(context, true);
        }
      } on Exception catch (e) {
        setState(() => _isLoading = false);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Re-authentication failed: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
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
                        color: Colors.orange.withOpacity(0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                  ),
                  child: const Icon(
                    LucideIcons.shield,
                    size: 60,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 40),
                Text(
                  'Re-authentication Required',
                  style: GoogleFonts.inter(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your session has expired. Please re-enter your password to continue.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.7),
                  ),
                ),
                const SizedBox(height: 40),
                _buildReauthForm(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReauthForm() {
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
                  Text(
                    widget.email,
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
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
                  const SizedBox(height: 20),
                  _buildReauthButton(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReauthButton() {
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
        onPressed: _isLoading ? null : _handleReauth,
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
                'Re-authenticate',
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
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
