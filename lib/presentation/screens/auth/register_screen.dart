import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';

/// Register screen for new users
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _displayNameController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _handleRegister() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(authServiceProvider).register(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _displayNameController.text.trim().isEmpty 
            ? null 
            : _displayNameController.text.trim(),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome, ${result.user?.displayName ?? 'Adventurer'}! Your account is ready.'),
              backgroundColor: AppColors.success,
              duration: const Duration(seconds: 1),
            ),
          );
        }
        
        // Force refresh auth state
        ref.invalidate(authStateProvider);
        ref.invalidate(userSavesProvider);
        
        // Small delay for snackbar visibility
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          context.go('/');
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Registration failed';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connection error: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkBackgroundGradient,
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Header
                    _buildHeader(),
                    const SizedBox(height: 32),
                    
                    // Register Form
                    _buildRegisterForm(),
                    const SizedBox(height: 24),
                    
                    // Login Link
                    _buildLoginLink(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        // Icon
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.mysticPurple,
                AppColors.dragonBlood,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.mysticPurple.withValues(alpha: 0.4),
                blurRadius: 25,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Icon(
            Icons.person_add,
            size: 40,
            color: Colors.white,
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        
        const SizedBox(height: 20),
        
        // Title
        Text(
          'Join the Adventure',
          style: GoogleFonts.cinzel(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: AppColors.dragonGold,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3, end: 0),
        
        const SizedBox(height: 8),
        
        Text(
          'Create your hero\'s legacy',
          style: GoogleFonts.spectral(
            fontSize: 14,
            color: AppColors.parchmentDark,
            fontStyle: FontStyle.italic,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.bgMedium.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Error Message
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.error.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.error.withValues(alpha: 0.5)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: AppColors.error, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    ),
                  ],
                ),
              ).animate().shake(),
            
            // Display Name Field (Optional)
            _buildTextField(
              controller: _displayNameController,
              label: 'Hero Name (Optional)',
              icon: Icons.badge,
              hint: 'What shall we call you?',
            ),
            
            const SizedBox(height: 16),
            
            // Email Field
            _buildTextField(
              controller: _emailController,
              label: 'Email',
              icon: Icons.email,
              keyboardType: TextInputType.emailAddress,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your email';
                }
                if (!value.contains('@') || !value.contains('.')) {
                  return 'Please enter a valid email';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Password Field
            _buildTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock,
              isPassword: true,
              obscureText: _obscurePassword,
              onToggleObscure: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a password';
                }
                if (value.length < 6) {
                  return 'Password must be at least 6 characters';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 16),
            
            // Confirm Password Field
            _buildTextField(
              controller: _confirmPasswordController,
              label: 'Confirm Password',
              icon: Icons.lock_outline,
              isPassword: true,
              obscureText: _obscureConfirmPassword,
              onToggleObscure: () {
                setState(() {
                  _obscureConfirmPassword = !_obscureConfirmPassword;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please confirm your password';
                }
                if (value != _passwordController.text) {
                  return 'Passwords do not match';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Register Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleRegister,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.mysticPurple,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 5,
                ),
                child: _isLoading
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation(Colors.white),
                        ),
                      )
                    : Text(
                        'BEGIN YOUR JOURNEY',
                        style: GoogleFonts.cinzel(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hint,
    TextInputType? keyboardType,
    bool isPassword = false,
    bool obscureText = false,
    VoidCallback? onToggleObscure,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: AppColors.parchment),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AppColors.parchmentDark),
        hintStyle: TextStyle(color: AppColors.parchmentDark.withValues(alpha: 0.5)),
        prefixIcon: Icon(icon, color: AppColors.dragonGold),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  obscureText ? Icons.visibility : Icons.visibility_off,
                  color: AppColors.parchmentDark,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.bgDark.withValues(alpha: 0.5),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: AppColors.borderColor.withValues(alpha: 0.3)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.dragonGold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      validator: validator,
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'Already have an account? ',
          style: TextStyle(color: AppColors.parchmentDark),
        ),
        TextButton(
          onPressed: () => context.pop(),
          child: Text(
            'Sign In',
            style: GoogleFonts.cinzel(
              color: AppColors.dragonGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms);
  }
}

