import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/models/appointment_slot_model.dart';
import 'package:medi_connect/core/models/doctor_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

// Provider for available doctors
final availableDoctorsProvider = FutureProvider.autoDispose<List<DoctorModel>>((ref) async {
  final firebaseService = ref.read(firebaseServiceProvider);
  return await firebaseService.getDoctorsFromCollection();
});

// Provider for available doctors by specialty
final specialtyDoctorsProvider = FutureProvider.family<List<DoctorModel>, String>((ref, specialty) async {
  final firebaseService = ref.read(firebaseServiceProvider);
  if (specialty.isEmpty) {
    return await firebaseService.getDoctorsFromCollection();
  }
  return await firebaseService.getDoctorsFromCollection(specialty: specialty);
});

// Provider for available slots for a specific doctor on a specific date
final availableSlotsProvider = FutureProvider.family<List<AppointmentSlotModel>, Map<String, dynamic>>((ref, params) async {
  final firebaseService = ref.read(firebaseServiceProvider);
  final doctorId = params['doctorId'] as String;
  final date = params['date'] as DateTime;
  return await firebaseService.getAvailableSlotsForDoctor(doctorId, date);
});

class BookAppointmentPage extends ConsumerStatefulWidget {
  const BookAppointmentPage({super.key});

  @override
  ConsumerState<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends ConsumerState<BookAppointmentPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedDoctorId;
  String _selectedSpecialty = '';
  AppointmentType _appointmentType = AppointmentType.inPerson;
  String _reasonForVisit = '';
  String _additionalNotes = '';
  String? _selectedSlotId;
  
  bool _isLoading = false;
  bool _isFetchingDoctors = false;
  
  // List to store available slots
  List<AppointmentSlotModel> _availableSlots = [];
  
  // Future to store the async operation for loading slots
  Future<List<AppointmentSlotModel>>? _slotsAsync;

  // Cache for doctors by specialty to make loading instant
  Map<String, List<DoctorModel>> _doctorsBySpecialty = {};
  List<DoctorModel> _currentDoctors = [];

  // List of specialties
  final List<String> _specialties = [
    'General Physician',
    'Cardiologist',
    'Dermatologist',
    'Neurologist',
    'Pediatrician',
    'Psychiatrist',
    'Orthopedic',
    'Gynecologist',
    'Ophthalmologist',
    'ENT Specialist',
    'Dentist',
  ];
  
  @override
  void initState() {
    super.initState();
    // Initialize _slotsAsync as needed
    _updateSlotsAsync();
    // Pre-fetch all doctors and categorize by specialty
    _prefetchAllDoctors();
  }

  // Pre-fetch all doctors and categorize them by specialty for instant loading
  void _prefetchAllDoctors() async {
    setState(() {
      _isFetchingDoctors = true;
    });

    try {
      // Fetch all doctors once
      final firebaseService = FirebaseService();
      final allDoctors = await firebaseService.getDoctorsFromCollection();
      
      // Organize doctors by specialty
      final Map<String, List<DoctorModel>> doctorMap = {};
      
      // Initialize with empty lists for all specialties
      for (final specialty in _specialties) {
        doctorMap[specialty] = [];
      }
      
      // Categorize doctors by specialty
      for (final doctor in allDoctors) {
        final specialty = doctor.specialty;
        if (doctorMap.containsKey(specialty)) {
          doctorMap[specialty]!.add(doctor);
        } else {
          // For specialties not in our predefined list
          doctorMap[specialty] = [doctor];
        }
      }
      
      if (mounted) {
        setState(() {
          _doctorsBySpecialty = doctorMap;
          _isFetchingDoctors = false;
        });
      }
    } catch (e) {
      debugPrint("Error pre-fetching doctors: $e");
      if (mounted) {
        setState(() {
          _isFetchingDoctors = false;
        });
      }
    }
  }

  // Helper method to update slots async when doctor or date changes
  void _updateSlotsAsync() {
    if (_selectedDoctorId != null) {
      final params = {
        'doctorId': _selectedDoctorId!,
        'date': _selectedDate,
      };
      
      setState(() {
        _isLoading = true;
      });
      
      // Immediately get the slots to minimize perceived loading time
      FirebaseService().getAvailableSlotsForDoctor(_selectedDoctorId!, _selectedDate)
        .then((slots) {
          if (mounted) {
            setState(() {
              _availableSlots = slots;
              _isLoading = false;
            });
          }
        }).catchError((error) {
          if (mounted) {
            setState(() {
              _availableSlots = _createDefaultTimeSlots();
              _isLoading = false;
            });
          }
          debugPrint("Error pre-loading slots: $error");
        });
      
      // Still use the provider for consistency
      _slotsAsync = ref.read(availableSlotsProvider(params).future);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Book Appointment"),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 12),
                  
                  // Heading
                  Text(
                    'Schedule Your Appointment',
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Fill in the details to book your appointment',
                    style: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  
            // Specialty Selection
                  Text(
              'Select Specialty',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.surfaceLight,
              ),
              constraints: const BoxConstraints(minHeight: 60),
              child: DropdownButtonFormField<String>(
                value: _selectedSpecialty.isEmpty ? null : _selectedSpecialty,
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  hintText: 'Select a specialty',
                  filled: true,
                  fillColor: Colors.transparent,
                  isDense: true,
                ),
                menuMaxHeight: 350,
                items: _specialties.map((specialty) {
                  return DropdownMenuItem<String>(
                    value: specialty,
                    child: Text(specialty),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _selectedSpecialty = value ?? '';
                    
                    // Reset doctor selection when specialty changes
                    _selectedDoctorId = null;
                    
                    // Update current doctors from cached doctors by specialty
                    if (_selectedSpecialty.isNotEmpty && _doctorsBySpecialty.containsKey(_selectedSpecialty)) {
                      _currentDoctors = _doctorsBySpecialty[_selectedSpecialty] ?? [];
                    } else {
                      _currentDoctors = [];
                    }
                  });
                },
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please select a specialty';
                  }
                  return null;
                },
                dropdownColor: AppColors.surfaceLight,
                isExpanded: true,
              ),
            ),
            const SizedBox(height: 24),
            
            // Doctor Selection - only shown after specialty is selected
            if (_selectedSpecialty.isNotEmpty) ...[
              Text(
                'Select Doctor',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              
              // Use the pre-fetched doctors instead of loading them each time
              Builder(
                builder: (context) {
                  // Show loading indicator only when fetching all doctors initially
                  if (_isFetchingDoctors) {
                    return const Center(
                      child: Padding(
                        padding: EdgeInsets.all(16.0),
                        child: CircularProgressIndicator(),
                      ),
                    );
                  }
                  
                  final doctors = _doctorsBySpecialty[_selectedSpecialty] ?? [];
                  
                  if (doctors.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16.0),
                        child: Text(
                          'No doctors available for $_selectedSpecialty',
                          style: AppTypography.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    );
                  }
                  
                  return LayoutBuilder(
                    builder: (context, constraints) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: AppColors.surfaceLight,
                        ),
                        constraints: const BoxConstraints(minHeight: 50, maxHeight: 60),
                        child: DropdownButtonFormField<String>(
                          value: _selectedDoctorId,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide.none,
                            ),
                            contentPadding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: constraints.maxWidth < 350 ? 4 : 8,
                            ),
                            hintText: 'Select a doctor',
                            filled: true,
                            fillColor: Colors.transparent,
                            isDense: true,
                          ),
                          menuMaxHeight: MediaQuery.of(context).size.height * 0.4,
                          itemHeight: constraints.maxWidth < 350 ? 50 : 60,
                          items: doctors.map((doctor) {
                            return DropdownMenuItem<String>(
                              value: doctor.id,
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  maxHeight: constraints.maxWidth < 350 ? 40 : 50,
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.start,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    CircleAvatar(
                                      radius: constraints.maxWidth < 350 ? 14 : 16,
                                      backgroundColor: Color.fromRGBO(
                                        AppColors.primary.red.toInt(),
                                        AppColors.primary.green.toInt(), 
                                        AppColors.primary.blue.toInt(),
                                        0.1),
                                      child: Text(
                                        doctor.name.isNotEmpty ? doctor.name[0] : 'D',
                                        style: TextStyle(
                                          color: AppColors.primary,
                                          fontWeight: FontWeight.bold,
                                          fontSize: constraints.maxWidth < 350 ? 10 : 12,
                                        ),
                                      ),
                                    ),
                                    SizedBox(width: constraints.maxWidth < 350 ? 6 : 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            'Dr. ${doctor.name}',
                                            style: AppTypography.bodyMedium.copyWith(
                                              fontWeight: FontWeight.w600,
                                              fontSize: constraints.maxWidth < 350 ? 12 : 14,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                          Text(
                                            doctor.specialty,
                                            style: AppTypography.bodySmall.copyWith(
                                              color: AppColors.textSecondary,
                                              fontSize: constraints.maxWidth < 350 ? 10 : 12,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                            maxLines: 1,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (String? value) {
                            setState(() {
                              _selectedDoctorId = value;
                              // Reset slot selection when doctor changes
                              _selectedSlotId = null;
                              // Update slot information
                              _updateSlotsAsync();
                            });
                          },
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select a doctor';
                            }
                            return null;
                          },
                          dropdownColor: AppColors.surfaceLight,
                          isExpanded: true,
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
            ],
                  
            // Date and Time Selection - only shown after doctor is selected
            if (_selectedDoctorId != null) ...[
              Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Date picker section
                            Text(
                    'Select Date',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _selectDate(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: AppColors.surfaceDark,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.calendar_today,
                                      color: AppColors.textSecondary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                                      style: AppTypography.bodyMedium,
                                    ),
                                    const Spacer(),
                                    const Icon(
                                      Icons.arrow_drop_down,
                                      color: AppColors.textSecondary,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                  
                  const SizedBox(height: 24),
                  
                  // Appointment Type
                  Text(
                    'Appointment Type',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildAppointmentTypeCard(
                        title: 'In-Person',
                        icon: Icons.people_outline,
                        type: AppointmentType.inPerson,
                      ),
                      const SizedBox(width: 16),
                      _buildAppointmentTypeCard(
                        title: 'Video Call',
                        icon: Icons.videocam_outlined,
                        type: AppointmentType.video,
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 24),
                ],
              ),
            ],
                  
            // Time Slot Selection
            if (_selectedDoctorId != null) ...[
              Text(
                'Select Time Slot',
                style: AppTypography.titleMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              _buildTimeSlotSelection(),
              const SizedBox(height: 24),
            ],
                  
            // Reason for Visit
            Text(
              'Reason for Visit',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                hintText: 'Briefly describe your symptoms or reason',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 3,
              onChanged: (value) {
                setState(() {
                  _reasonForVisit = value;
                });
              },
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a reason for your visit';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // Additional Notes
            Text(
              'Additional Notes (Optional)',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              decoration: InputDecoration(
                hintText: 'Any additional information you want to provide',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: AppColors.surfaceLight,
                contentPadding: const EdgeInsets.all(16),
              ),
              maxLines: 2,
              onChanged: (value) {
                setState(() {
                  _additionalNotes = value;
                });
              },
            ),
            const SizedBox(height: 32),
            
            // Book Appointment Button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _bookAppointment,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
                        'Book Appointment',
                        style: AppTypography.titleMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
              ),
            ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildAppointmentTypeCard({
    required String title,
    required IconData icon,
    required AppointmentType type,
  }) {
    final isSelected = _appointmentType == type;
    
    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _appointmentType = type;
          });
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 16,
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            color: isSelected ? Color.fromRGBO(
              AppColors.primary.red,
              AppColors.primary.green,
              AppColors.primary.blue,
              0.1) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.transparent,
              width: 2,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
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
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _updateSlotsAsync();
    }
  }

  Widget _buildTimeSlotSelection() {
    if (_selectedDoctorId == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Text(
            'Please select a doctor first to view available time slots.',
            style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // If we already have slots loaded, show them immediately to reduce perceived loading time
    if (_availableSlots.isNotEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 12,
            children: _availableSlots.map((slot) {
              final isSelected = _selectedSlotId == slot.id;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedSlotId = slot.id;
                    debugPrint("Selected slot ID: ${slot.id}, time: ${slot.timeSlot}");
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.surfaceDark,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Text(
                    slot.timeSlot,
                    style: AppTypography.bodyMedium.copyWith(
                      color: isSelected ? Colors.white : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      );
    }

    // Make sure to update _slotsAsync if it's null
    if (_slotsAsync == null) {
      _updateSlotsAsync();
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 20.0),
          child: CircularProgressIndicator(),
        ),
      );
    }

    return FutureBuilder<List<AppointmentSlotModel>>(
      future: _slotsAsync,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 20.0),
              child: CircularProgressIndicator(),
            ),
          );
        } else if (snapshot.hasError) {
          // Handle error - either show error message or demo slots
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Text(
                  'Error loading time slots: ${snapshot.error}',
                  style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    // Set demo slots for display
                    _availableSlots = _createDefaultTimeSlots();
                    _selectedSlotId = null;
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                ),
                child: const Text('View Demo Time Slots'),
              ),
            ],
          );
        } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16.0),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.event_busy, size: 40, color: Colors.grey[500]),
                  const SizedBox(height: 8),
                  Text(
                    'No time slots available for this date. Please try another date.',
                    style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }

        _availableSlots = snapshot.data!;
        debugPrint("Available slots count: ${_availableSlots.length}");

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 12,
              children: _availableSlots.map((slot) {
                final isSelected = _selectedSlotId == slot.id;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSlotId = slot.id;
                      debugPrint("Selected slot ID: ${slot.id}, time: ${slot.timeSlot}");
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: isSelected ? AppColors.primary : AppColors.surfaceDark,
                        width: isSelected ? 2 : 1,
                      ),
                    ),
                    child: Text(
                      slot.timeSlot,
                      style: AppTypography.bodyMedium.copyWith(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  // Helper method to create demo time slots
  List<AppointmentSlotModel> _createDefaultTimeSlots() {
    final DateTime today = _selectedDate;
    
    List<AppointmentSlotModel> demoSlots = [];
    for (int i = 0; i < 8; i++) {
      final hour = 9 + (i ~/ 2);
      final minute = (i % 2) * 30;
      
      // Format hour with AM/PM
      final String hourStr = hour <= 12 ? '$hour' : '${hour - 12}';
      final String amPm = hour < 12 ? 'AM' : 'PM';
      final timeSlot = '$hourStr:${minute.toString().padLeft(2, '0')} $amPm';
      
      demoSlots.add(AppointmentSlotModel(
        id: 'demo-slot-$i',
        doctorId: _selectedDoctorId!,
        date: today,
        timeSlot: timeSlot,
        isBooked: false,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      ));
    }
    return demoSlots;
  }

  Future<void> _bookAppointment() async {
    // First check if the form is valid
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all the required fields'))
      );
      return;
    }
    
    // Save the form data
    _formKey.currentState!.save();
      
    // Validate selected doctor and time slot
    if (_selectedDoctorId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a doctor'))
      );
      return;
    }
      
    if (_selectedSlotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot'))
      );
      return;
    }

    // Validate reason for visit
    if (_reasonForVisit.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a reason for your visit'))
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final authService = ref.read(authServiceProvider);
      final firebaseService = ref.read(firebaseServiceProvider);
      final currentUser = await authService.getCurrentUser();
      
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You need to be logged in to book an appointment'))
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      
      debugPrint("Booking appointment with doctor ID: $_selectedDoctorId");
      debugPrint("Selected slot ID: $_selectedSlotId");
      debugPrint("Selected date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}");
      
      // Find the selected slot for time info
      final selectedSlot = _availableSlots.firstWhere(
        (slot) => slot.id == _selectedSlotId,
        orElse: () {
          debugPrint("Could not find selected slot with ID: $_selectedSlotId");
          debugPrint("Available slots: ${_availableSlots.map((s) => s.id).join(', ')}");
          
          // Create a default slot as fallback
          return AppointmentSlotModel(
            id: _selectedSlotId ?? '',
            doctorId: _selectedDoctorId!,
            date: _selectedDate,
            timeSlot: _selectedSlotId?.split('-').length == 3 ? _selectedSlotId!.split('-')[2] : "9:00 AM",
            isBooked: false,
            createdAt: Timestamp.now(),
            updatedAt: Timestamp.now()
          );
        }
      );
      
      debugPrint("Selected slot time: ${selectedSlot.timeSlot}");
        
      // Create the appointment model
      final appointment = AppointmentModel(
        id: '', // Will be generated by the service
        patientId: currentUser.uid,
        doctorId: _selectedDoctorId!,
        date: Timestamp.fromDate(_selectedDate),
        time: selectedSlot.timeSlot,
        status: AppointmentStatus.upcoming,
        type: _appointmentType,
        notes: _additionalNotes.isNotEmpty ? _additionalNotes : _reasonForVisit,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      
      debugPrint("Appointment model created, booking slot...");
      
      // Book the selected slot
      final appointmentId = await firebaseService.bookAppointmentSlot(appointment);
      
      if (appointmentId == null) {
        if (mounted) {
          debugPrint("Failed to book appointment: No appointmentId returned");
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Failed to book appointment. Please try a different time slot.'),
              backgroundColor: AppColors.error,
            ),
          );
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }
      
      debugPrint("Appointment booked successfully with ID: $appointmentId");
        
      // Show success message and navigate
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: AppColors.success,
          ),
        );
        
        // Navigate to appointments page after a short delay
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            Navigator.pop(context, true);
          }
        });
      }
    } catch (e) {
      debugPrint("Error booking appointment: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking appointment: ${e.toString()}'),
            backgroundColor: AppColors.error,
          ),
        );
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
} 