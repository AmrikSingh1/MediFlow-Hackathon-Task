import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/presentation/pages/auth/register_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:medi_connect/presentation/widgets/custom_text_field.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// Provider for the auth service
final authServiceProvider = Provider<AuthService?>((ref) {
  try {
    return AuthService();
  } catch (e) {
    print("Error creating AuthService: $e");
    return null;
  }
});

// Provider for the firebase service
final firebaseServiceProvider = Provider<FirebaseService?>((ref) {
  try {
    return FirebaseService();
  } catch (e) {
    print("Error creating FirebaseService: $e");
    return null;
  }
});

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _rememberMe = false;
  bool _isLoading = false;
  String _errorMessage = '';
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;
  AuthService? _authService;
  bool _isFirebaseAvailable = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _slideAnimation = Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
    );
    _animationController.forward();
    
    // Try to get the AuthService, but don't crash if it's not available
    try {
      _authService = ref.read(authServiceProvider);
      _isFirebaseAvailable = _authService != null;
    } catch (e) {
      print("Failed to initialize AuthService: $e");
      _isFirebaseAvailable = false;
    }
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  void _login() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = '';
      });

      try {
        if (!_isFirebaseAvailable) {
          throw Exception("Firebase is not available. Please check your internet connection and try again.");
        }
        
        await _authService!.signInWithEmailAndPassword(
          _emailController.text.trim(),
          _passwordController.text,
        );

        // Check if user needs to complete their profile
        final isProfileComplete = await _authService!.isUserProfileComplete();
        
        if (mounted) {
          if (!isProfileComplete) {
            final userModel = await _authService!.getCurrentUserData();
            if (userModel?.role == UserRole.patient) {
              Navigator.of(context).pushReplacementNamed(Routes.patientProfile);
            } else {
              Navigator.of(context).pushReplacementNamed(Routes.doctorProfile);
            }
          } else {
            final userModel = await _authService!.getCurrentUserData();
            if (userModel?.role == UserRole.patient) {
              Navigator.of(context).pushReplacementNamed(Routes.home);
            } else {
              Navigator.of(context).pushReplacementNamed(Routes.doctorDashboard);
            }
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

  Future<void> _loginWithApple() async {
    if (!_isFirebaseAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Firebase is not available. Please check your internet connection and try again."),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      debugPrint("Attempting Apple sign-in from login page");
      
      // Check if running on a simulator (this is a simplistic check, we're detecting based on error handling)
      final bool isSimulator = defaultTargetPlatform == TargetPlatform.iOS && 
                               !await SignInWithApple.isAvailable();
                              
      if (isSimulator) {
        // On simulator, we can't perform actual Apple Sign In, so show a message
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Apple Sign In doesn't work on simulator. Please use email sign in or test on a real device."),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
        setState(() {
          _isLoading = false;
          _errorMessage = 'Apple Sign In is not available on simulator';
        });
        return;
      }
      
      final userCredential = await _authService!.signInWithApple();
      
      if (userCredential.user != null) {
        final user = userCredential.user!;
        final isNewUser = user.metadata.creationTime?.isAtSameMomentAs(user.metadata.lastSignInTime!) ?? false;
        
        // Get the user data from Firestore
        final userModel = await ref.read(firebaseServiceProvider)!.getUserById(user.uid);
        
        if (isNewUser || userModel == null) {
          // If it's a new user, show user type selection dialog
          final selectedRole = await _showUserTypeSelectionDialog();
          if (selectedRole != null) {
            // Create new user in Firestore with selected role
            final newUser = UserModel(
              id: user.uid,
              name: user.displayName ?? '',
              email: user.email ?? '',
              role: selectedRole,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            );
            await ref.read(firebaseServiceProvider)!.createUser(newUser);
            
            // Navigate to profile completion page based on role
            if (!mounted) return;
            if (selectedRole == UserRole.patient) {
              Navigator.pushReplacementNamed(context, Routes.patientProfile);
            } else {
              Navigator.pushReplacementNamed(context, Routes.doctorProfile);
            }
          } else {
            // User cancelled role selection, sign out
            await _authService!.signOut();
          }
        } else {
          // Existing user, check if profile is complete
          final bool isProfileComplete = userModel.role == UserRole.patient 
              ? (userModel.medicalInfo != null && userModel.medicalInfo!.isNotEmpty)
              : (userModel.doctorInfo != null && userModel.doctorInfo!.isNotEmpty);
          
          if (isProfileComplete) {
            // Navigate to dashboard based on role
            if (!mounted) return;
            if (userModel.role == UserRole.patient) {
              Navigator.pushReplacementNamed(context, Routes.home);
            } else {
              Navigator.pushReplacementNamed(context, Routes.doctorDashboard);
            }
          } else {
            // Profile not complete, redirect to profile completion page based on role
            if (!mounted) return;
            if (userModel.role == UserRole.patient) {
              Navigator.pushReplacementNamed(context, Routes.patientProfile);
            } else {
              Navigator.pushReplacementNamed(context, Routes.doctorProfile);
            }
          }
        }
      }
    } catch (e) {
      if (!mounted) return;
      
      // Provide more detailed error message
      String errorMessage;
      if (e is SignInWithAppleAuthorizationException) {
        switch (e.code) {
          case AuthorizationErrorCode.canceled:
            errorMessage = 'Sign-in was cancelled';
            break;
          case AuthorizationErrorCode.failed:
            errorMessage = 'Sign-in failed. Please try again.';
            break;
          case AuthorizationErrorCode.invalidResponse:
            errorMessage = 'Invalid response received. Please try again.';
            break;
          case AuthorizationErrorCode.notHandled:
            errorMessage = 'Sign-in not handled. Please try again.';
            break;
          case AuthorizationErrorCode.unknown:
            errorMessage = 'Apple Sign-In is not available. Please try email sign-in instead.';
            break;
          default:
            errorMessage = 'Error signing in: ${e.message}';
        }
      } else if (e is FirebaseAuthException) {
        switch (e.code) {
          case 'ERROR_ABORTED_BY_USER':
            errorMessage = 'Sign-in was cancelled';
            break;
          case 'ERROR_MISSING_APPLE_AUTH_TOKEN':
            errorMessage = 'Apple Sign-In failed. Please try again.';
            break;
          case 'ERROR_FIREBASE_AUTH_FAILED':
            errorMessage = 'Authentication failed. Please try again.';
            break;
          case 'account-exists-with-different-credential':
            errorMessage = 'An account already exists with the same email. Try signing in with a different method.';
            break;
          case 'network-request-failed':
            errorMessage = 'Network error. Please check your internet connection.';
            break;
          default:
            errorMessage = 'Error signing in: ${e.message ?? e.code}';
        }
        debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
      } else {
        errorMessage = 'Error signing in: ${e.toString()}';
        debugPrint('Error during Apple Sign-In: $e');
      }
      
      setState(() {
        _errorMessage = errorMessage;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          duration: const Duration(seconds: 4),
          action: SnackBarAction(
            label: 'Dismiss',
            textColor: Colors.white,
            onPressed: () {},
          ),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<UserRole?> _showUserTypeSelectionDialog() async {
    return await showDialog<UserRole>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        title: Text(
          'Select User Type',
          style: AppTypography.headlineSmall.copyWith(
            color: const Color(0xFF2D3748),
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        content: SizedBox(
          width: double.maxFinite,
          height: 220,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Please select your role to continue:',
                style: AppTypography.bodyMedium.copyWith(
                  color: const Color(0xFF718096),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildRoleCard(
                    context: context,
                    title: 'Patient',
                    description: 'Book appointments, chat with doctors',
                    icon: Icons.person,
                    role: UserRole.patient,
                  ),
                  _buildRoleCard(
                    context: context,
                    title: 'Doctor',
                    description: 'Manage patients, appointments',
                    icon: Icons.medical_services,
                    role: UserRole.doctor,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard({
    required BuildContext context,
    required String title,
    required String description,
    required IconData icon,
    required UserRole role,
  }) {
    return InkWell(
      onTap: () => Navigator.of(context).pop(role),
      child: Container(
        width: 120,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.15),
              spreadRadius: 1,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
          border: Border.all(
            color: const Color(0xFFE2E8F0),
            width: 1.5,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              height: 48,
              width: 48,
              decoration: BoxDecoration(
                color: const Color(0xFF8A70D6).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 28,
                color: const Color(0xFF8A70D6),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 4),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8.0),
              child: Text(
                description,
                style: AppTypography.bodySmall.copyWith(
                  color: const Color(0xFF718096),
                  fontSize: 10,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF0F4FF), // Very light lavender blue
              Color(0xFFF9F1FF), // Very light purple
            ],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: SlideTransition(
              position: _slideAnimation,
              child: Center(
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo and App Name
                        _buildLogoAndHeader(),
                        
                        const SizedBox(height: 40),
                        
                        // Login Form Card
                        _buildLoginCard(),
                        
                        const SizedBox(height: 32),
                        
                        // Sign Up Link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: AppTypography.bodyMedium.copyWith(
                                color: const Color(0xFF718096),
                              ),
                            ),
                            GestureDetector(
                              onTap: () {
                                try {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (context) => const RegisterPage(),
                                    ),
                                  );
                                } catch (e) {
                                  debugPrint("Navigation error: $e");
                                }
                              },
                              child: Text(
                                'Sign Up',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: const Color(0xFF8A70D6),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLogoAndHeader() {
    return Column(
      children: [
        // App Logo
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8A70D6).withOpacity(0.2),
                blurRadius: 20,
                spreadRadius: 0,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: const Icon(
            Icons.favorite,
            size: 54,
            color: Color(0xFF8A70D6),
          ),
        ),
        const SizedBox(height: 24),
        
        // App Name
        Text(
          'MediConnect',
          style: AppTypography.displaySmall.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        
        // Tagline
        Text(
          'Your health, connected',
          style: AppTypography.bodyLarge.copyWith(
            color: const Color(0xFF718096),
            letterSpacing: 0.5,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Form Title
              Text(
                'Sign In',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              
              Text(
                'Welcome back! Please enter your details',
                style: AppTypography.bodyMedium.copyWith(
                  color: const Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 24),
              
              // Email Field
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                prefixIcon: Icons.email_outlined,
                keyboardType: TextInputType.emailAddress,
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
              
              const SizedBox(height: 16),
              
              // Password Field
              CustomTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Enter your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: !_isPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF9AA5B1),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isPasswordVisible = !_isPasswordVisible;
                    });
                  },
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
                  // Remember Me
                  Row(
                    children: [
                      SizedBox(
                        height: 20,
                        width: 20,
                        child: Checkbox(
                          value: _rememberMe,
                          activeColor: const Color(0xFF8A70D6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                          side: const BorderSide(
                            color: Color(0xFFCBD5E0),
                            width: 1.5,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _rememberMe = value ?? false;
                            });
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Remember me',
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFF718096),
                        ),
                      ),
                    ],
                  ),
                  
                  // Forgot Password
                  GestureDetector(
                    onTap: () {
                      _showForgotPasswordDialog();
                    },
                    child: Text(
                      'Forgot Password?',
                      style: AppTypography.bodySmall.copyWith(
                        color: const Color(0xFF8A70D6),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Error Message
              if (_errorMessage.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.error.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.error_outline,
                        color: AppColors.error,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _formatErrorMessage(_errorMessage),
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Sign In Button
              if (_isLoading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(
                      color: Color(0xFF8A70D6),
                    ),
                  ),
                )
              else
                GradientButton(
                  text: 'Sign In',
                  onPressed: _login,
                ),
              
              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Divider(
                        thickness: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0),
                      child: Text(
                        'OR',
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFF9AA5B1),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        thickness: 1,
                        color: const Color(0xFFE2E8F0),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Apple Sign In Button
              if (!_isLoading)
                _buildAppleSignInButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppleSignInButton() {
    return InkWell(
      onTap: _loginWithApple,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.black,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 5,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.apple,
                color: Colors.white,
                size: 24,
              ),
              const SizedBox(width: 12),
              Text(
                'Sign in with Apple',
                style: AppTypography.buttonMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Show forgot password dialog
  void _showForgotPasswordDialog() {
    final TextEditingController emailController = TextEditingController();
    bool isLoading = false;
    String errorMessage = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: Text(
              'Reset Password',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter your email address to receive a password reset link.',
                  style: AppTypography.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: emailController,
                  decoration: InputDecoration(
                    labelText: 'Email',
                    hintText: 'Enter your email',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  onChanged: (_) => setState(() => errorMessage = ''),
                ),
                if (errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    errorMessage,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Cancel',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              isLoading
                ? Container(
                    width: 24,
                    height: 24,
                    padding: const EdgeInsets.all(4),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: () async {
                      if (emailController.text.trim().isEmpty) {
                        setState(() {
                          errorMessage = 'Please enter your email';
                        });
                        return;
                      }
                      
                      setState(() {
                        isLoading = true;
                        errorMessage = '';
                      });
                      
                      try {
                        await _authService!.resetPassword(emailController.text.trim());
                        
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Password reset email sent. Please check your inbox.'),
                              backgroundColor: AppColors.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setState(() {
                          isLoading = false;
                          errorMessage = e.toString().contains('no user record')
                              ? 'No account found with this email'
                              : 'Failed to send reset email. Please try again.';
                        });
                      }
                    },
                    child: Text(
                      'Send Link',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
            ],
          );
        },
      ),
    );
  }

  // Helper method to format error messages
  String _formatErrorMessage(String errorMessage) {
    // Clean up Firebase and Apple authentication error messages for display
    if (errorMessage.contains('firebase_auth')) {
      return 'Authentication failed. Please try again.';
    }
    
    if (errorMessage.contains('SignInWithAppleAuthorizationException')) {
      if (errorMessage.contains('AuthorizationErrorCode.unknown')) {
        return 'Apple Sign In is not available. Please use email sign-in instead.';
      }
      return 'Apple Sign In failed. Please try again.';
    }

    // Return original error if no specific formatting is needed
    return errorMessage;
  }
} 