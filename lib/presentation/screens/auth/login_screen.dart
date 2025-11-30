import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../providers/auth_providers.dart';

/// Login screen with email/password authentication
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(authServiceProvider).signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
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
              content: Text('Welcome back, ${result.user?.displayName ?? 'Adventurer'}!'),
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
          // Use pushReplacement to avoid back navigation to login
          context.go('/');
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Login failed';
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
                    // Logo/Title
                    _buildHeader(),
                    const SizedBox(height: 48),
                    
                    // Login Form
                    _buildLoginForm(),
                    const SizedBox(height: 24),
                    
                    // Register Link
                    _buildRegisterLink(),
                    const SizedBox(height: 16),
                    
                    // Skip Login (Guest Mode)
                    _buildGuestButton(),
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
        // Dragon Icon
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.dragonGold,
                AppColors.dragonBlood,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.dragonGold.withValues(alpha: 0.4),
                blurRadius: 30,
                spreadRadius: 5,
              ),
            ],
          ),
          child: const Icon(
            Icons.castle,
            size: 50,
            color: Colors.white,
          ),
        ).animate().scale(duration: 600.ms, curve: Curves.elasticOut),
        
        const SizedBox(height: 24),
        
        // Title
        Text(
          'Welcome Back',
          style: GoogleFonts.cinzel(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: AppColors.dragonGold,
          ),
        ).animate().fadeIn(delay: 200.ms).slideY(begin: -0.3, end: 0),
        
        const SizedBox(height: 8),
        
        Text(
          'Your adventure awaits',
          style: GoogleFonts.spectral(
            fontSize: 16,
            color: AppColors.parchmentDark,
            fontStyle: FontStyle.italic,
          ),
        ).animate().fadeIn(delay: 400.ms),
      ],
    );
  }

  Widget _buildLoginForm() {
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
            
            // Email Field
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: AppColors.parchment),
              decoration: InputDecoration(
                labelText: 'Email',
                labelStyle: TextStyle(color: AppColors.parchmentDark),
                prefixIcon: const Icon(Icons.email, color: AppColors.dragonGold),
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
            
            const SizedBox(height: 16),
            
            // Password Field
            TextFormField(
              controller: _passwordController,
              obscureText: _obscurePassword,
              style: const TextStyle(color: AppColors.parchment),
              decoration: InputDecoration(
                labelText: 'Password',
                labelStyle: TextStyle(color: AppColors.parchmentDark),
                prefixIcon: const Icon(Icons.lock, color: AppColors.dragonGold),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility : Icons.visibility_off,
                    color: AppColors.parchmentDark,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
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
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter your password';
                }
                return null;
              },
            ),
            
            const SizedBox(height: 24),
            
            // Login Button
            SizedBox(
              height: 54,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleLogin,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.dragonGold,
                  foregroundColor: AppColors.bgDark,
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
                          valueColor: AlwaysStoppedAnimation(AppColors.bgDark),
                        ),
                      )
                    : Text(
                        'ENTER THE REALM',
                        style: GoogleFonts.cinzel(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: 600.ms).slideY(begin: 0.2, end: 0);
  }

  Widget _buildRegisterLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New adventurer? ',
          style: TextStyle(color: AppColors.parchmentDark),
        ),
        TextButton(
          onPressed: () => context.push('/register'),
          child: Text(
            'Create Account',
            style: GoogleFonts.cinzel(
              color: AppColors.dragonGold,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms);
  }

  Widget _buildGuestButton() {
    return TextButton.icon(
      onPressed: _isLoading ? null : _handleGuestLogin,
      icon: const Icon(Icons.play_arrow, color: AppColors.parchmentDark),
      label: Text(
        'Continue as Guest',
        style: TextStyle(color: AppColors.parchmentDark),
      ),
    ).animate().fadeIn(delay: 1000.ms);
  }

  Future<void> _handleGuestLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final result = await ref.read(authServiceProvider).continueAsGuest();

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      if (result.success) {
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome, Adventurer! Your progress will be saved.'),
            backgroundColor: AppColors.success,
            duration: Duration(seconds: 2),
          ),
        );
        
        // Force refresh auth state
        ref.invalidate(authStateProvider);
        ref.invalidate(userSavesProvider);
        
        await Future.delayed(const Duration(milliseconds: 500));
        
        if (mounted) {
          context.go('/');
        }
      } else {
        setState(() {
          _errorMessage = result.error ?? 'Failed to continue as guest';
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
}

