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
import 'package:medi_connect/presentation/pages/patient/find_doctor_page.dart';

class DoctorProfilePage extends ConsumerStatefulWidget {
  const DoctorProfilePage({super.key});

  @override
  ConsumerState<DoctorProfilePage> createState() => _DoctorProfilePageState();
}

class _DoctorProfilePageState extends ConsumerState<DoctorProfilePage> {
  final _formKey = GlobalKey<FormState>();
  
  // Profile Image Variables
  File? _profileImage;
  bool _isProfileImageChanged = false;
  String? _selectedProfileImageUrl;
  
  // Professional Information
  final _specialtyController = TextEditingController();
  final _hospitalAffiliationController = TextEditingController();
  final _licenseNumberController = TextEditingController();
  final _yearsExperienceController = TextEditingController();
  final _educationController = TextEditingController();
  
  // Personal Information
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _bioController = TextEditingController();
  
  bool _isLoading = false;
  bool _isLoadingData = true;
  UserModel? _currentUser;
  final List<String> _specialties = [
    'Cardiologist',
    'Dermatologist',
    'Endocrinologist',
    'Gastroenterologist',
    'Neurologist',
    'Obstetrician',
    'Oncologist',
    'Ophthalmologist',
    'Orthopedist',
    'Pediatrician',
    'Psychiatrist',
    'Pulmonologist',
    'Rheumatologist',
    'Urologist',
    'General Practitioner',
    'Other'
  ];
  String _selectedSpecialty = 'General Practitioner';
  String _selectedCity = kAppCities.first;
  
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
        
        if (_currentUser != null && _currentUser!.doctorInfo != null) {
          final doctorInfo = _currentUser!.doctorInfo!;
          
          // Set values from user data
          _selectedSpecialty = doctorInfo['specialty'] ?? 'General Practitioner';
          _hospitalAffiliationController.text = doctorInfo['hospitalAffiliation'] ?? '';
          _licenseNumberController.text = doctorInfo['licenseNumber'] ?? '';
          _yearsExperienceController.text = doctorInfo['yearsExperience']?.toString() ?? '';
          _educationController.text = doctorInfo['education'] ?? '';
          _phoneController.text = _currentUser!.phoneNumber ?? '';
          _addressController.text = doctorInfo['address'] ?? '';
          _bioController.text = doctorInfo['bio'] ?? '';
          _selectedCity = doctorInfo['city'] ?? kAppCities.first;
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
    _specialtyController.dispose();
    _hospitalAffiliationController.dispose();
    _licenseNumberController.dispose();
    _yearsExperienceController.dispose();
    _educationController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _bioController.dispose();
    super.dispose();
  }
  
  void _saveProfile() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
      });
      
      try {
        final authService = AuthService();
        final user = await authService.getCurrentUser();
        
        // Create doctor info map
        final Map<String, dynamic> doctorInfo = {
          'specialty': _selectedSpecialty,
          'hospitalAffiliation': _hospitalAffiliationController.text,
          'licenseNumber': _licenseNumberController.text,
          'yearsExperience': int.tryParse(_yearsExperienceController.text),
          'education': _educationController.text,
          'address': _addressController.text,
          'bio': _bioController.text,
          'city': _selectedCity,
        };
        
        // If we don't have a current user, create a dummy one for demo purposes
        // HACK: This is just for demo purposes and would be replaced with proper auth in production
        if (user == null || _currentUser == null) {
          debugPrint('Creating demo doctor profile for testing');
          
          // Create a demo user
          final demoUser = UserModel(
            id: 'demo-doctor-${DateTime.now().millisecondsSinceEpoch}',
            name: 'Dr. Demo',
            email: 'doctor@example.com',
            phoneNumber: _phoneController.text,
            role: UserRole.doctor,
            doctorInfo: doctorInfo,
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
            // Navigate to doctor dashboard instead of home
            Navigator.of(context).pushReplacementNamed(Routes.doctorDashboard);
          }
          return;
        }
        
        // Normal flow for when we have a current user
        // Update user model
        final updatedUser = _currentUser!.copyWith(
          phoneNumber: _phoneController.text,
          doctorInfo: doctorInfo,
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
          // Navigate to doctor dashboard instead of home
          Navigator.of(context).pushReplacementNamed(Routes.doctorDashboard);
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
                'Complete Your Doctor Profile',
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
          'Please provide your professional information to help patients find you',
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
                child: const Icon(
                  Icons.person,
                  size: 60,
                  color: Color(0xFF8A70D6),
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
                      _showImageSourceDialog();
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
  
  void _showImageSourceDialog() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Profile Photo',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
                color: const Color(0xFF2D3748),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildImageSourceOption(
                  icon: Icons.photo_library,
                  label: 'Gallery',
                  onTap: () {
                    // Implement gallery picker
                    _pickImageFromGallery();
                    Navigator.pop(context);
                  },
                ),
                _buildImageSourceOption(
                  icon: Icons.camera_alt,
                  label: 'Camera',
                  onTap: () {
                    // Implement camera picker
                    _pickImageFromCamera();
                    Navigator.pop(context);
                  },
                ),
                _buildImageSourceOption(
                  icon: Icons.delete,
                  label: 'Remove',
                  color: Colors.red.shade300,
                  onTap: () {
                    // Implement photo removal
                    _removeProfilePhoto();
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
  
  Widget _buildImageSourceOption({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: (color ?? const Color(0xFF8A70D6)).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color ?? const Color(0xFF8A70D6),
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: const Color(0xFF2D3748),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
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
              // Professional Information Section
              Text(
                'Professional Information',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 20),
              
              // Specialty Field - Replace Dropdown with Custom Solution
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Specialty',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _showSpecialtySelectionDialog();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedSpecialty,
                              style: const TextStyle(
                                color: Color(0xFF2D3748),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF8A70D6)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // City Field - Replace Dropdown with Custom Solution
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Practice Location',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                      color: const Color(0xFF4A5568),
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () {
                      _showCitySelectionDialog();
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFFF7FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              _selectedCity,
                              style: const TextStyle(
                                color: Color(0xFF2D3748),
                                fontSize: 16,
                              ),
                            ),
                          ),
                          const Icon(Icons.arrow_drop_down, color: Color(0xFF8A70D6)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Hospital Affiliation
              CustomTextField(
                controller: _hospitalAffiliationController,
                label: 'Hospital/Clinic Affiliation',
                hint: 'e.g. Metro General Hospital',
                prefixIcon: Icons.local_hospital,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your hospital or clinic affiliation';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // License Number
              CustomTextField(
                controller: _licenseNumberController,
                label: 'License Number',
                hint: 'e.g. MD12345678',
                prefixIcon: Icons.badge,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your medical license number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Years of Experience
              CustomTextField(
                controller: _yearsExperienceController,
                label: 'Years of Experience',
                hint: 'e.g. 10',
                prefixIcon: Icons.work_history,
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (int.tryParse(value) == null) {
                    return 'Please enter a valid number';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Education
              CustomTextField(
                controller: _educationController,
                label: 'Education',
                hint: 'e.g. MD, Harvard Medical School',
                prefixIcon: Icons.school,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your education details';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Personal Information Section
              Text(
                'Contact Information',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 20),
              
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
              
              const SizedBox(height: 16),
              
              // Address
              CustomTextField(
                controller: _addressController,
                label: 'Office Address',
                hint: 'Enter your office address',
                prefixIcon: Icons.location_on,
                keyboardType: TextInputType.streetAddress,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your office address';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 16),
              
              // Bio
              CustomTextField(
                controller: _bioController,
                label: 'Professional Bio',
                hint: 'Tell patients about yourself and your practice...',
                prefixIcon: Icons.description,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter your professional bio';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // Additional Actions Section
              Text(
                'Additional Actions',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF2D3748),
                ),
              ),
              const SizedBox(height: 20),
              
              // Invite Patients Button
              _buildActionButton(
                context: context,
                title: 'Invite Patients',
                subtitle: 'Invite patients to connect with you for appointments',
                icon: Icons.person_add_outlined,
                onTap: () {
                  Navigator.of(context).pushNamed(Routes.invitePatient);
                },
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

  // Add these new methods to implement the image functionality:
  
  Future<void> _pickImageFromGallery() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );
      
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
          _isProfileImageChanged = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile photo selected from gallery'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error picking image from gallery: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error selecting image: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  Future<void> _pickImageFromCamera() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
        preferredCameraDevice: CameraDevice.front,
      );
      
      if (photo != null) {
        setState(() {
          _profileImage = File(photo.path);
          _isProfileImageChanged = true;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Profile photo captured from camera'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Error taking photo: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error capturing photo: $e'),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
  
  void _removeProfilePhoto() {
    setState(() {
      _profileImage = null;
      _isProfileImageChanged = true;
      _selectedProfileImageUrl = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile photo removed'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Add these methods to show selection dialogs
  void _showSpecialtySelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Specialty',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: _specialties.length,
                    itemBuilder: (context, index) {
                      final specialty = _specialties[index];
                      return ListTile(
                        title: Text(specialty),
                        onTap: () {
                          setState(() {
                            _selectedSpecialty = specialty;
                          });
                          Navigator.pop(context);
                        },
                        selected: _selectedSpecialty == specialty,
                        selectedTileColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCitySelectionDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Practice Location',
                  style: AppTypography.titleLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  width: double.maxFinite,
                  child: ListView.builder(
                    itemCount: kAppCities.length,
                    itemBuilder: (context, index) {
                      final city = kAppCities[index];
                      return ListTile(
                        title: Text(city),
                        onTap: () {
                          setState(() {
                            _selectedCity = city;
                          });
                          Navigator.pop(context);
                        },
                        selected: _selectedCity == city,
                        selectedTileColor: AppColors.primary.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildActionButton({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              height: 60,
              width: 60,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
                size: 30,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: AppTypography.bodyMedium.copyWith(
                color: const Color(0xFF2D3748),
                fontWeight: FontWeight.w500,
              ),
            ),
            Text(
              subtitle,
              style: AppTypography.bodySmall.copyWith(
                color: const Color(0xFF718096),
              ),
            ),
          ],
        ),
      ),
    );
  }
} 