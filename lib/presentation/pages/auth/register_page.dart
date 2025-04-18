import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/presentation/pages/auth/login_page.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:medi_connect/presentation/widgets/custom_text_field.dart';
import 'package:medi_connect/presentation/widgets/selection_card.dart';

enum UserType { patient, doctor }

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isConfirmPasswordVisible = false;
  bool _agreeToTerms = false;
  bool _isLoading = false;
  UserType _selectedUserType = UserType.patient;
  String? _selectedSpecialty;
  
  // List of available specialties
  final List<String> _specialties = [
    'General Physician',
    'Cardiologist',
    'Dermatologist',
    'Endocrinologist',
    'Family Medicine',
    'Gastroenterologist',
    'Neurologist',
    'Obstetrics & Gynecology',
    'Oncology',
    'Ophthalmology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Pulmonology',
    'Rheumatology',
    'Urology',
  ];
  
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

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
    
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _animationController.forward();
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _animationController.stop();
    _animationController.dispose();
    super.dispose();
  }

  void _register() async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!_agreeToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Please agree to the Terms of Service and Privacy Policy'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ),
        );
        return;
      }
      
      // Check if doctor has selected a specialty
      if (_selectedUserType == UserType.doctor && (_selectedSpecialty == null || _selectedSpecialty!.isEmpty)) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Please select your medical specialty'),
                ),
              ],
            ),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.all(10),
          ),
        );
        return;
      }
      
      setState(() {
        _isLoading = true;
      });

      try {
        // Get the auth service
        final authService = AuthService();
        
        // Register with Firebase
        final userCredential = await authService.registerWithEmailAndPassword(
          _emailController.text,
          _passwordController.text,
          _nameController.text,
          _selectedUserType == UserType.patient ? UserRole.patient : UserRole.doctor,
          specialty: _selectedUserType == UserType.doctor ? _selectedSpecialty : null,
        );
        
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Show success message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Account created successfully!'),
              backgroundColor: const Color(0xFF5CD6A9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
          
          // Navigate based on user type
          if (_selectedUserType == UserType.patient) {
            Navigator.of(context).pushReplacementNamed(Routes.patientProfile);
          } else {
            Navigator.of(context).pushReplacementNamed(Routes.doctorProfile);
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          
          // Show error message
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Registration failed: ${e.toString()}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: const Text('Create Account'),
        centerTitle: true,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 18,
            ),
          ),
          onPressed: () {
            try {
              Navigator.of(context).pop();
            } catch (e) {
              debugPrint("Navigation error on back: $e");
              // Navigate directly to login
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ),
              );
            }
          },
        ),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: const Color(0xFF2D3748),
      ),
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
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
                  child: Column(
                    children: [
                      _buildHeader(),
                      const SizedBox(height: 24),
                      _buildRegisterCard(),
                      const SizedBox(height: 32),
                      
                      // Login Link
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Already have an account? ",
                            style: AppTypography.bodyMedium.copyWith(
                              color: const Color(0xFF718096),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              Navigator.of(context).pushReplacement(
                                MaterialPageRoute(
                                  builder: (context) => const LoginPage(),
                                ),
                              );
                            },
                            child: Text(
                              'Sign In',
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
    );
  }
  
  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Join MediConnect',
          style: AppTypography.headlineMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: const Color(0xFF2D3748),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Create an account to access personalized healthcare services',
          style: AppTypography.bodyMedium.copyWith(
            color: const Color(0xFF718096),
          ),
        ),
      ],
    );
  }
  
  Widget _buildRegisterCard() {
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
              // Account Type Selection Title
              Text(
                'Select Account Type',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              
              // User Type Selection Cards
              Row(
                children: [
                  Expanded(
                    child: SelectionCard(
                      title: 'Patient',
                      description: 'I need medical assistance',
                      icon: Icons.person_rounded,
                      isSelected: _selectedUserType == UserType.patient,
                      onTap: () {
                        setState(() {
                          _selectedUserType = UserType.patient;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: SelectionCard(
                      title: 'Doctor',
                      description: 'I provide medical services',
                      icon: Icons.medical_services_rounded,
                      isSelected: _selectedUserType == UserType.doctor,
                      onTap: () {
                        setState(() {
                          _selectedUserType = UserType.doctor;
                          // Set default specialty if none selected
                          if (_selectedSpecialty == null || _selectedSpecialty!.isEmpty) {
                            _selectedSpecialty = _specialties[0];
                          }
                        });
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Doctor Specialty selection (only if doctor is selected)
              if (_selectedUserType == UserType.doctor) ...[
                Text(
                  'Medical Specialty',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2D3748),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                      width: 1.5,
                    ),
                  ),
                  child: DropdownButtonFormField<String>(
                    value: _selectedSpecialty ?? _specialties.first,
                    decoration: InputDecoration(
                      hintText: 'Select your medical specialty',
                      prefixIcon: const Icon(
                        Icons.medical_services_outlined,
                        color: Color(0xFF9AA5B1),
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                    style: AppTypography.bodyMedium,
                    icon: const Icon(
                      Icons.arrow_drop_down_rounded,
                      color: Color(0xFF9AA5B1),
                    ),
                    isExpanded: true,
                    dropdownColor: Colors.white,
                    items: _specialties.map((String specialty) {
                      return DropdownMenuItem<String>(
                        value: specialty,
                        child: Text(
                          specialty,
                          style: AppTypography.bodyMedium,
                        ),
                      );
                    }).toList(),
                    onChanged: (String? value) {
                      setState(() {
                        _selectedSpecialty = value;
                      });
                    },
                    validator: (value) {
                      if (_selectedUserType == UserType.doctor && (value == null || value.isEmpty)) {
                        return 'Please select your medical specialty';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
              
              // Personal Information Title
              Text(
                'Personal Information',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 16),
              
              // Full Name Field
              CustomTextField(
                controller: _nameController,
                label: 'Full Name',
                hint: 'Enter your full name',
                prefixIcon: Icons.person_outline_rounded,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your name';
                  }
                  return null;
                },
              ),
              
              // Email Field
              CustomTextField(
                controller: _emailController,
                label: 'Email',
                hint: 'Enter your email',
                prefixIcon: Icons.mail_outline_rounded,
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your email';
                  }
                  // Basic email validation
                  if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                    return 'Please enter a valid email';
                  }
                  return null;
                },
              ),
              
              // Password Field
              CustomTextField(
                controller: _passwordController,
                label: 'Password',
                hint: 'Create a password',
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
                    return 'Please enter a password';
                  }
                  if (value.length < 8) {
                    return 'Password must be at least 8 characters';
                  }
                  // Check for complexity
                  if (!RegExp(r'^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])').hasMatch(value)) {
                    return 'Password must contain uppercase, lowercase, and number';
                  }
                  return null;
                },
              ),
              
              // Confirm Password Field
              CustomTextField(
                controller: _confirmPasswordController,
                label: 'Confirm Password',
                hint: 'Confirm your password',
                prefixIcon: Icons.lock_outline_rounded,
                obscureText: !_isConfirmPasswordVisible,
                suffixIcon: IconButton(
                  icon: Icon(
                    _isConfirmPasswordVisible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: const Color(0xFF9AA5B1),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _isConfirmPasswordVisible = !_isConfirmPasswordVisible;
                    });
                  },
                ),
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
              
              const SizedBox(height: 20),
              
              // Terms of Service Checkbox
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    height: 20,
                    width: 20,
                    child: Checkbox(
                      value: _agreeToTerms,
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
                          _agreeToTerms = value ?? false;
                        });
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text.rich(
                      TextSpan(
                        style: AppTypography.bodySmall.copyWith(
                          color: const Color(0xFF718096),
                        ),
                        children: [
                          const TextSpan(
                            text: 'I agree to the ',
                          ),
                          TextSpan(
                            text: 'Terms of Service',
                            style: TextStyle(
                              color: const Color(0xFF8A70D6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const TextSpan(
                            text: ' and ',
                          ),
                          TextSpan(
                            text: 'Privacy Policy',
                            style: TextStyle(
                              color: const Color(0xFF8A70D6),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Register Button
              _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8A70D6),
                    ),
                  )
                : GradientButton(
                    text: 'Create Account',
                    onPressed: _register,
                  ),
            ],
          ),
        ),
      ),
    );
  }
} 