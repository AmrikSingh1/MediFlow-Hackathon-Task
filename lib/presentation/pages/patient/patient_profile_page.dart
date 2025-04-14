import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
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
  final List<String> _genders = ['Male', 'Female', 'Other', 'Prefer not to say'];
  
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
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
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
      
      // TODO: Save profile data to Firestore
      // Simulating network request
      await Future.delayed(const Duration(seconds: 2));
      
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(Routes.home);
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Complete Your Profile'),
        elevation: 0,
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Profile Avatar
                  Center(
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: AppColors.surfaceMedium,
                          child: Icon(
                            Icons.person,
                            size: 80,
                            color: AppColors.primary,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            height: 40,
                            width: 40,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: Colors.white,
                                width: 2,
                              ),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.camera_alt,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () {
                                // TODO: Implement image picker
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Personal Information Section
                  Text(
                    'Personal Information',
                    style: AppTypography.headlineSmall,
                  ),
                  const SizedBox(height: 16),
                  
                  // Date of Birth
                  TextFormField(
                    controller: _dobController,
                    readOnly: true,
                    onTap: () => _selectDate(context),
                    decoration: const InputDecoration(
                      labelText: 'Date of Birth',
                      hintText: 'DD/MM/YYYY',
                      prefixIcon: Icon(Icons.calendar_today),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your date of birth';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Gender Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedGender,
                    decoration: const InputDecoration(
                      labelText: 'Gender',
                      prefixIcon: Icon(Icons.person_outline),
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
                  ),
                  const SizedBox(height: 16),
                  
                  // Height and Weight Row
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Height (cm)',
                            hintText: '175',
                            prefixIcon: Icon(Icons.height),
                          ),
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
                        child: TextFormField(
                          controller: _weightController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Weight (kg)',
                            hintText: '70',
                            prefixIcon: Icon(Icons.monitor_weight_outlined),
                          ),
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
                  const SizedBox(height: 16),
                  
                  // Phone Number
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone Number',
                      hintText: '+1 (555) 123-4567',
                      prefixIcon: Icon(Icons.phone),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your phone number';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 16),
                  
                  // Address
                  TextFormField(
                    controller: _addressController,
                    keyboardType: TextInputType.streetAddress,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Address',
                      hintText: 'Enter your full address',
                      prefixIcon: Icon(Icons.home),
                      alignLabelWithHint: true,
                    ),
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
                    style: AppTypography.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This information will help your doctor provide better care.',
                    style: AppTypography.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  
                  // Allergies
                  TextFormField(
                    controller: _allergiesController,
                    decoration: const InputDecoration(
                      labelText: 'Allergies',
                      hintText: 'Enter any allergies you have',
                      prefixIcon: Icon(Icons.warning_amber_rounded),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Current Medications
                  TextFormField(
                    controller: _medicationsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Current Medications',
                      hintText: 'Enter any medications you are taking',
                      prefixIcon: Icon(Icons.medication),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Chronic Conditions
                  TextFormField(
                    controller: _chronicConditionsController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Chronic Conditions',
                      hintText: 'Enter any chronic health conditions',
                      prefixIcon: Icon(Icons.health_and_safety),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Surgical History
                  TextFormField(
                    controller: _surgicalHistoryController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Surgical History',
                      hintText: 'Enter any past surgeries',
                      prefixIcon: Icon(Icons.medical_services),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Family Medical History
                  TextFormField(
                    controller: _familyHistoryController,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Family Medical History',
                      hintText: 'Enter any relevant family medical history',
                      prefixIcon: Icon(Icons.family_restroom),
                      alignLabelWithHint: true,
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  // Save Button
                  _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : GradientButton(
                        text: 'Save Profile',
                        onPressed: _saveProfile,
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