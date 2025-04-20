import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:medi_connect/presentation/widgets/custom_text_field.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Add provider definition
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

class PatientProfilePage extends ConsumerStatefulWidget {
  const PatientProfilePage({super.key});

  @override
  ConsumerState<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends ConsumerState<PatientProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Personal Information
  final _dobController = TextEditingController();
  String _selectedGender = 'Male';
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  
  // Medical Information
  final _allergiesController = TextEditingController();
  final _medicationsController = TextEditingController();
  final _chronicConditionsController = TextEditingController();
  final _surgicalHistoryController = TextEditingController();
  final _familyHistoryController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingData = true;
  bool _isImageLoading = false;
  UserModel? _currentUser;
  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  
  // Profile image picker
  File? _profileImageFile;
  bool _isUploadingImage = false;
  
  @override
  void initState() {
    super.initState();
    _loadUserData();
  }
  
  Future<void> _loadUserData() async {
    setState(() {
      _isLoadingData = true;
    });
    
    try {
      final authService = AuthService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        _currentUser = await authService.getCurrentUserData();
        
        if (_currentUser != null && _currentUser!.medicalInfo != null) {
          final medicalInfo = _currentUser!.medicalInfo!;
          
          // Set values from user data
          _dobController.text = medicalInfo['dateOfBirth'] ?? '';
          _selectedGender = medicalInfo['gender'] ?? 'Male';
          _heightController.text = medicalInfo['height']?.toString() ?? '';
          _weightController.text = medicalInfo['weight']?.toString() ?? '';
          _phoneController.text = _currentUser!.phoneNumber ?? '';
          _addressController.text = medicalInfo['address'] ?? '';
          _allergiesController.text = medicalInfo['allergies'] ?? '';
          _medicationsController.text = medicalInfo['medications'] ?? '';
          _chronicConditionsController.text = medicalInfo['chronicConditions'] ?? '';
          _surgicalHistoryController.text = medicalInfo['surgicalHistory'] ?? '';
          _familyHistoryController.text = medicalInfo['familyHistory'] ?? '';
        } else if (_currentUser != null) {
          // Set just the phone number if we have it
          _phoneController.text = _currentUser!.phoneNumber ?? '';
        }
      }
    } catch (e) {
      debugPrint('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
    }
  }
  
  @override
  void dispose() {
    _dobController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _allergiesController.dispose();
    _medicationsController.dispose();
    _chronicConditionsController.dispose();
    _surgicalHistoryController.dispose();
    _familyHistoryController.dispose();
    super.dispose();
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1900),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF8A70D6),
              onPrimary: Colors.white,
              onSurface: Color(0xFF2D3748),
            ),
            dialogBackgroundColor: Colors.white,
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.day}/${picked.month}/${picked.year}";
      });
    }
  }
  
  void _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final authService = AuthService();
        final user = await authService.getCurrentUser();
        
        // Create medical info map
        final Map<String, dynamic> medicalInfo = {
          'dateOfBirth': _dobController.text,
          'gender': _selectedGender,
          'height': int.tryParse(_heightController.text),
          'weight': double.tryParse(_weightController.text),
          'address': _addressController.text,
          'allergies': _allergiesController.text,
          'medications': _medicationsController.text,
          'chronicConditions': _chronicConditionsController.text,
          'surgicalHistory': _surgicalHistoryController.text,
          'familyHistory': _familyHistoryController.text,
        };
        
        // If we don't have a current user, create a dummy one for demo purposes
        // HACK: This is just for demo purposes and would be replaced with proper auth in production
        if (user == null || _currentUser == null) {
          debugPrint('Creating demo user profile for testing');
          
          // Create a demo user
          final demoUser = UserModel(
            id: 'demo-user-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Demo Patient',
            email: 'demo@example.com',
            phoneNumber: _phoneController.text,
            role: UserRole.patient,
            medicalInfo: medicalInfo,
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now(),
          );
          
          // In a real app, we would save this to Firestore
          // For demo purposes, we'll just show success and navigate
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('Demo Profile created successfully!'),
                backgroundColor: const Color(0xFF5CD6A9),
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                margin: const EdgeInsets.all(10),
              ),
            );
            // Navigate to patient home dashboard
            Navigator.of(context).pushReplacementNamed(Routes.home);
          }
          return;
        }
        
        // Normal flow for when we have a current user
        // Update user model
        final updatedUser = _currentUser!.copyWith(
          phoneNumber: _phoneController.text,
          medicalInfo: medicalInfo,
          updatedAt: Timestamp.now(),
        );
        
        // Save to Firestore
        await authService.updateUserProfile(updatedUser);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Profile saved successfully!'),
              backgroundColor: const Color(0xFF5CD6A9),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
          // Navigate to patient home dashboard
          Navigator.of(context).pushReplacementNamed(Routes.home);
        }
      } catch (e) {
        debugPrint('Error saving profile: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving profile: ${e.toString()}'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(
            color: const Color(0xFF8A70D6),
          ),
        ),
      );
    }
    
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
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildProfileForm(),
                  const SizedBox(height: 40),
                ],
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
        Row(
          children: [
            IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white,
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
                  color: Color(0xFF2D3748),
                ),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                'Complete Your Profile',
                style: AppTypography.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF2D3748),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'Please provide your information to personalize your healthcare experience',
          style: AppTypography.bodyMedium.copyWith(
            color: const Color(0xFF718096),
          ),
        ),
        
        // Profile Avatar
        const SizedBox(height: 32),
        Center(
          child: Stack(
            children: [
              Container(
                height: 100,
                width: 100,
                decoration: BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF8A70D6).withOpacity(0.2),
                      blurRadius: 10,
                      spreadRadius: 0,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: _profileImageFile == null
                    ? const Icon(
                        Icons.person,
                        size: 60,
                        color: Color(0xFF8A70D6),
                      )
                    : ClipOval(
                        child: Image.file(
                          _profileImageFile!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                        ),
                      ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  height: 36,
                  width: 36,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF8A70D6), Color(0xFF5F82E2)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF8A70D6).withOpacity(0.3),
                        blurRadius: 5,
                        spreadRadius: 0,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 18,
                    ),
                    onPressed: () {
                      _showImageSourceOptions();
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Future<void> _showImageSourceOptions() async {
    final ImagePicker imagePicker = ImagePicker();
    
    await showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_rounded),
                  title: const Text('Gallery'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(ImageSource.gallery);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.camera_alt_rounded),
                  title: const Text('Camera'),
                  onTap: () async {
                    Navigator.pop(context);
                    await _pickImage(ImageSource.camera);
                  },
                ),
                if (_currentUser?.profileImageUrl != null) 
                  ListTile(
                    leading: const Icon(Icons.delete_outline_rounded, color: Colors.red),
                    title: const Text('Remove photo', style: TextStyle(color: Colors.red)),
                    onTap: () async {
                      Navigator.pop(context);
                      await _removeProfileImage();
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Future<void> _pickImage(ImageSource source) async {
    final ImagePicker imagePicker = ImagePicker();
    final XFile? pickedFile = await imagePicker.pickImage(
      source: source,
      imageQuality: 80,
    );
    
    if (pickedFile != null && mounted) {
      setState(() {
        _isImageLoading = true;
        _profileImageFile = File(pickedFile.path);
      });
      
      try {
        final String? uploadedUrl = await _uploadProfileImage(_profileImageFile!);
        if (uploadedUrl != null && mounted) {
          setState(() {
            _currentUser = _currentUser?.copyWith(profileImageUrl: uploadedUrl);
            _isImageLoading = false;
          });
          
          // Update user profile in Firebase
          await _uploadImageToFirebase(uploadedUrl);
          
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile picture updated successfully')),
            );
          }
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isImageLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to update profile picture: ${e.toString()}')),
          );
        }
      }
    }
  }
  
  Future<void> _uploadImageToFirebase(String imageUrl) async {
    try {
      if (_currentUser == null || _currentUser!.id.isEmpty) {
        throw Exception('User not authenticated');
      }
      
      final updatedUser = _currentUser!.copyWith(profileImageUrl: imageUrl);
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.updateUser(updatedUser);
    } catch (e) {
      debugPrint('Error updating user profile with image: $e');
      throw e;
    }
  }
  
  Future<String?> _uploadProfileImage(File imageFile) async {
    try {
      if (_currentUser == null || _currentUser!.id.isEmpty) {
        throw Exception('User not authenticated');
      }
      
      final String fileName = '${_currentUser!.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final Reference storageRef = FirebaseStorage.instance.ref().child('profile_images/$fileName');
      
      final UploadTask uploadTask = storageRef.putFile(imageFile);
      final TaskSnapshot taskSnapshot = await uploadTask;
      
      final String downloadUrl = await taskSnapshot.ref.getDownloadURL();
      return downloadUrl;
    } catch (e) {
      debugPrint('Error uploading profile image: $e');
      return null;
    }
  }
  
  Future<void> _removeProfileImage() async {
    if (!mounted) return;
    
    setState(() {
      _isImageLoading = true;
    });
    
    try {
      // Remove the profile image from Firebase Storage
      User? user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final storageRef = FirebaseStorage.instance.ref();
        final profileImageRef = storageRef.child('profile_images/${user.uid}.jpg');
        
        try {
          await profileImageRef.delete();
        } catch (e) {
          // If the file doesn't exist, just continue
        }
        
        // Update user data in Firestore
        final updatedUser = _currentUser!.copyWith(profileImageUrl: null);
        final firebaseService = ref.read(firebaseServiceProvider);
        await firebaseService.updateUser(updatedUser);
        
        setState(() {
          _currentUser = updatedUser;
          _profileImageFile = null;
          _isUploadingImage = false;
          _isImageLoading = false;
        });
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile picture removed successfully')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isImageLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error removing image: ${e.toString()}')),
        );
      }
    }
  }
  
  Widget _buildProfileForm() {
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
              // Personal Information Section
              Text(
                'Personal Information',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 20),
              
              // Date of Birth
              CustomTextField(
                controller: _dobController,
                label: 'Date of Birth',
                hint: 'DD/MM/YYYY',
                prefixIcon: Icons.calendar_today,
                readOnly: true,
                onTap: () => _selectDate(context),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your date of birth';
                  }
                  return null;
                },
              ),
              
              // Gender Dropdown
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFFE6E8F0),
                    width: 1.5,
                  ),
                ),
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: InputDecoration(
                    labelText: 'Gender',
                    labelStyle: AppTypography.bodyMedium.copyWith(
                      color: const Color(0xFF718096),
                    ),
                    prefixIcon: const Icon(
                      Icons.person_outline,
                      color: Color(0xFF9AA5B1),
                      size: 22,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                  ),
                  items: _genders.map((gender) {
                    return DropdownMenuItem(
                      value: gender,
                      child: Text(gender),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) {
                      setState(() {
                        _selectedGender = value;
                      });
                    }
                  },
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  icon: const Icon(
                    Icons.arrow_drop_down,
                    color: Color(0xFF9AA5B1),
                  ),
                ),
              ),
              
              // Height and Weight Row
              Row(
                children: [
                  Expanded(
                    child: CustomTextField(
                      controller: _heightController,
                      label: 'Height (cm)',
                      hint: '175',
                      prefixIcon: Icons.height,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (int.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: CustomTextField(
                      controller: _weightController,
                      label: 'Weight (kg)',
                      hint: '70',
                      prefixIcon: Icons.monitor_weight_outlined,
                      keyboardType: TextInputType.number,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Required';
                        }
                        if (double.tryParse(value) == null) {
                          return 'Invalid';
                        }
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              
              // Phone Number
              CustomTextField(
                controller: _phoneController,
                label: 'Phone Number',
                hint: '+1 (555) 123-4567',
                prefixIcon: Icons.phone,
                keyboardType: TextInputType.phone,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your phone number';
                  }
                  return null;
                },
              ),
              
              // Address
              CustomTextField(
                controller: _addressController,
                label: 'Address',
                hint: 'Enter your full address',
                prefixIcon: Icons.home,
                keyboardType: TextInputType.streetAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your address';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Medical Information Section
              Text(
                'Medical Information',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This information will help your doctor provide better care.',
                style: AppTypography.bodySmall.copyWith(
                  color: const Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 20),
              
              // Allergies
              CustomTextField(
                controller: _allergiesController,
                label: 'Allergies',
                hint: 'Enter any allergies you have',
                prefixIcon: Icons.warning_amber_rounded,
              ),
              
              // Current Medications
              CustomTextField(
                controller: _medicationsController,
                label: 'Current Medications',
                hint: 'Enter any medications you are taking',
                prefixIcon: Icons.medication,
              ),
              
              // Chronic Conditions
              CustomTextField(
                controller: _chronicConditionsController,
                label: 'Chronic Conditions',
                hint: 'Enter any chronic health conditions',
                prefixIcon: Icons.health_and_safety,
              ),
              
              // Surgical History
              CustomTextField(
                controller: _surgicalHistoryController,
                label: 'Surgical History',
                hint: 'Enter any past surgeries',
                prefixIcon: Icons.medical_services,
              ),
              
              // Family Medical History
              CustomTextField(
                controller: _familyHistoryController,
                label: 'Family Medical History',
                hint: 'Enter any relevant family medical history',
                prefixIcon: Icons.family_restroom,
              ),
              
              const SizedBox(height: 32),
              
              // Invitations and Connections Section
              Text(
                'Doctor Connections',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Manage your connections with healthcare providers.',
                style: AppTypography.bodySmall.copyWith(
                  color: const Color(0xFF718096),
                ),
              ),
              const SizedBox(height: 20),
              
              // View Invitations Button
              GestureDetector(
                onTap: () {
                  Navigator.of(context).pushNamed(Routes.viewInvitations);
                },
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0xFFE2E8F0),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.mail_outline,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Doctor Invitations',
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'View and respond to invitations from doctors',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right,
                        color: Color(0xFF9AA5B1),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Save Button
              _isLoading
                ? const Center(
                    child: CircularProgressIndicator(
                      color: Color(0xFF8A70D6),
                    ),
                  )
                : GradientButton(
                    text: 'Save Profile',
                    onPressed: _saveProfile,
                  ),
            ],
          ),
        ),
      ),
    );
  }
} 