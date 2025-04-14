import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

// Provider for the auth service
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;
  String _errorMessage = '';

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        final authService = ref.read(authServiceProvider);
        await authService.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

        // Check if user needs to complete their profile
        final isProfileComplete = await authService.isUserProfileComplete();
        
        if (mounted) {
          if (!isProfileComplete) {
            // Navigate to profile completion page
            Navigator.of(context).pushReplacementNamed(Routes.completeProfile);
          } else {
            // Navigate to home page on successful login
            Navigator.of(context).pushReplacementNamed(Routes.home);
          }
        }
      } catch (e) {
        setState(() {
          _errorMessage = _getReadableErrorMessage(e.toString());
        });
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _loginWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      final authService = ref.read(authServiceProvider);
      
      debugPrint("Starting Google Sign-In process...");
      final userCredential = await authService.signInWithGoogle();
      
      // Check if we have a valid user
      final user = userCredential.user;
      if (user == null) {
        debugPrint("Sign-in failed: No user returned");
        setState(() {
          _errorMessage = 'Failed to sign in with Google. Please try again.';
          _isLoading = false;
        });
        return;
      }
      
      debugPrint("Successfully signed in with Google: ${user.uid}");
      debugPrint("User email: ${user.email}");
      debugPrint("User display name: ${user.displayName}");
      
      // Make sure user data is in Firestore
      final userData = await authService.getCurrentUserData();
      debugPrint("User data from Firestore: ${userData?.name ?? 'Not found'}");
      
      // Check if user needs to complete their profile
      final isProfileComplete = await authService.isUserProfileComplete();
      
      if (mounted) {
        if (!isProfileComplete) {
          // Navigate to profile completion page
          Navigator.of(context).pushReplacementNamed(Routes.completeProfile);
        } else {
          // Navigate to home page on successful login
          Navigator.of(context).pushReplacementNamed(Routes.home);
        }
      }
    } catch (e) {
      debugPrint("Google Sign-In error: $e");
      setState(() {
        _errorMessage = _getReadableErrorMessage(e.toString());
      });
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  String _getReadableErrorMessage(String errorMessage) {
    if (errorMessage.contains('user-not-found')) {
      return 'No user found with this email address';
    } else if (errorMessage.contains('wrong-password')) {
      return 'Incorrect password';
    } else if (errorMessage.contains('invalid-email')) {
      return 'Invalid email format';
    } else if (errorMessage.contains('user-disabled')) {
      return 'This account has been disabled';
    } else if (errorMessage.contains('network-request-failed')) {
      return 'Network error. Please check your connection';
    } else if (errorMessage.contains('ERROR_ABORTED_BY_USER')) {
      return 'Sign-in aborted';
    } else {
      return 'Authentication failed. Please try again';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 40),
                  // Header
                  Center(
                    child: Column(
                      children: [
                        Icon(
                          Icons.medical_services_rounded,
                          size: 64,
                          color: AppColors.primary,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'MediConnect',
                          style: AppTypography.displaySmall,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account',
                          style: AppTypography.bodyLarge.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 48),
                  
                  // Email Field
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: Icon(Icons.email_outlined),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Password Field
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_isPasswordVisible,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Remember Me & Forgot Password
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Checkbox(
                            value: _rememberMe,
                            activeColor: AppColors.primary,
                            onChanged: (value) {
                              setState(() {
                                _rememberMe = value ?? false;
                              });
                            },
                          ),
                          Text(
                            'Remember me',
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () {
                          // TODO: Implement forgot password functionality
                        },
                        child: Text(
                          'Forgot Password?',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  
                  // Error message
                  if (_errorMessage.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _errorMessage,
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  
                  if (_errorMessage.isNotEmpty)
                    const SizedBox(height: 16),
                  
                  // Login Button
                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GradientButton(
                          text: 'Sign In',
                          onPressed: _login,
                        ),
                  const SizedBox(height: 24),
                  
                  // OR Divider
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(thickness: 1),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Text(
                          'OR',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(thickness: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Google Sign In
                  OutlinedButton.icon(
                    onPressed: _isLoading ? null : _loginWithGoogle,
                    icon: Icon(
                      Icons.g_translate_rounded,
                      color: Colors.red,
                      size: 24,
                    ),
                    label: const Text('Sign in with Google'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: BorderSide(color: AppColors.primary.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Sign Up Link
                  Center(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Don\'t have an account?',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.of(context).pushNamed(Routes.register);
                          },
                          child: Text(
                            'Sign Up',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
} 