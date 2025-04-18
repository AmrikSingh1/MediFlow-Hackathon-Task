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
  
  // List to store available slots
  List<AppointmentSlotModel> _availableSlots = [];
  
  // Cache for slots - Map of doctorId-date to slots
  Map<String, List<AppointmentSlotModel>> _slotsCache = {};
  
  // Loading state for slots
  bool _isSlotsLoading = false;
  
  // Error message for slots loading
  String? _slotsErrorMessage;

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
    // No need to call _updateSlotsAsync here as it will be called when doctor is selected
  }

  // Optimized method to load slots with caching
  Future<void> _loadAvailableSlots() async {
    if (_selectedDoctorId == null) return;
    
    final cacheKey = '${_selectedDoctorId}-${DateFormat('yyyy-MM-dd').format(_selectedDate)}';
    
    // Check if slots are already in cache
    if (_slotsCache.containsKey(cacheKey)) {
      setState(() {
        _availableSlots = _slotsCache[cacheKey]!;
        _isSlotsLoading = false;
        _slotsErrorMessage = null;
      });
      return;
    }
    
    setState(() {
      _isSlotsLoading = true;
      _slotsErrorMessage = null;
    });
    
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final slots = await firebaseService.getAvailableSlotsForDoctor(
        _selectedDoctorId!, 
        _selectedDate
      );
      
      // Filter out any booked slots - only show available ones
      final availableSlots = slots.where((slot) => !slot.isBooked).toList();
      
      // Sort slots by time
      availableSlots.sort((a, b) => _compareTimeSlots(a.timeSlot, b.timeSlot));
      
      // Cache the result
      _slotsCache[cacheKey] = availableSlots;
      
      if (mounted) {
        setState(() {
          _availableSlots = availableSlots;
          _isSlotsLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading slots: $e');
      if (mounted) {
        setState(() {
          _slotsErrorMessage = 'Failed to load time slots: $e';
          _isSlotsLoading = false;
        });
      }
    }
  }
  
  // Helper to compare time slots for sorting
  int _compareTimeSlots(String timeA, String timeB) {
    // Parse times like "9:00 AM", "10:30 AM", "2:00 PM"
    final regexTime = RegExp(r'(\d+):(\d+)\s+(AM|PM)');
    final matchA = regexTime.firstMatch(timeA);
    final matchB = regexTime.firstMatch(timeB);
    
    if (matchA == null || matchB == null) return 0;
    
    int hourA = int.parse(matchA.group(1)!);
    int hourB = int.parse(matchB.group(1)!);
    
    // Convert to 24-hour format
    if (matchA.group(3) == 'PM' && hourA < 12) hourA += 12;
    if (matchA.group(3) == 'AM' && hourA == 12) hourA = 0;
    if (matchB.group(3) == 'PM' && hourB < 12) hourB += 12;
    if (matchB.group(3) == 'AM' && hourB == 12) hourB = 0;
    
    if (hourA != hourB) return hourA.compareTo(hourB);
    
    // Compare minutes if hours are equal
    return int.parse(matchA.group(2)!).compareTo(int.parse(matchB.group(2)!));
  }
  
  // Called when doctor or date changes
  void _onDoctorOrDateChanged() {
    if (_selectedDoctorId != null) {
      _loadAvailableSlots();
    }
  }
  
  @override
  void didUpdateWidget(covariant BookAppointmentPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset selection when widget updates
    setState(() {
      _selectedSlotId = null;
    });
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
              Consumer(
                builder: (context, ref, child) {
                  final doctorsAsyncValue = ref.watch(
                    specialtyDoctorsProvider(_selectedSpecialty)
                  );
                  
                  return doctorsAsyncValue.when(
                    loading: () => const Center(child: CircularProgressIndicator()),
                    error: (error, stackTrace) => Center(
                      child: Text('Error loading doctors: $error'),
                    ),
                    data: (doctors) {
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
                      
                      return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: AppColors.surfaceLight,
                    ),
                    child: DropdownButtonFormField<String>(
                      value: _selectedDoctorId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        hintText: 'Select a doctor',
                        filled: true,
                        fillColor: Colors.transparent,
                        isDense: true,
                      ),
                      menuMaxHeight: 300,
                      itemHeight: 60.0,
                      items: doctors.map((doctor) {
                        return DropdownMenuItem<String>(
                          value: doctor.id,
                          child: Container(
                            constraints: const BoxConstraints(
                              minHeight: 60,
                            ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                  radius: 16,
                                  backgroundColor: Color.fromRGBO(
                                    AppColors.primary.red.toInt(),
                                    AppColors.primary.green.toInt(), 
                                    AppColors.primary.blue.toInt(),
                                    0.1),
                                child: Text(
                                  doctor.name.isNotEmpty ? doctor.name[0] : 'D',
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                              Expanded(
                                  child: Text(
                                      'Dr. ${doctor.name}',
                                      style: AppTypography.bodyMedium.copyWith(
                                        fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                    maxLines: 1,
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
                          _selectedSlotId = null; // Reset selected slot when doctor changes
                        });
                        // Immediately load available slots when a doctor is selected
                        _onDoctorOrDateChanged();
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
      // Load slots for the new date immediately
      _onDoctorOrDateChanged();
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

    // Show loading indicator if slots are loading
    if (_isSlotsLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20.0),
        child: Center(
          child: Column(
            children: [
              SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(height: 12),
              Text("Loading available slots..."),
            ],
          ),
        ),
      );
    }

    // Show error if there was a problem loading slots
    if (_slotsErrorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error: $_slotsErrorMessage',
              style: TextStyle(color: Colors.red[700], fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _onDoctorOrDateChanged,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Show message if no slots are available
    if (_availableSlots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.event_busy, size: 40, color: Colors.grey[500]),
              const SizedBox(height: 8),
              Text(
                'No time slots available for this date.',
                style: TextStyle(fontWeight: FontWeight.w500, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Please try selecting a different date.',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => _selectDate(context),
                icon: const Icon(Icons.calendar_today, size: 16),
                label: const Text('Select Another Date'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Show available slots
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Show date and count info
        Padding(
          padding: const EdgeInsets.only(bottom: 12.0),
          child: Row(
            children: [
              Icon(Icons.event_available, size: 16, color: Colors.green[700]),
              const SizedBox(width: 8),
              Text(
                '${_availableSlots.length} available slots on ${DateFormat('EEE, MMM d').format(_selectedDate)}',
                style: TextStyle(
                  color: Colors.green[700],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        // Show time slots in a grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.5,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
          ),
          itemCount: _availableSlots.length,
          itemBuilder: (context, index) {
            final slot = _availableSlots[index];
            final isSelected = _selectedSlotId == slot.id;
            
            return GestureDetector(
              onTap: () {
                setState(() {
                  _selectedSlotId = slot.id;
                  debugPrint("Selected slot ID: ${slot.id}, time: ${slot.timeSlot}");
                });
              },
              child: Container(
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary : AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.surfaceDark,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  slot.timeSlot,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 13,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
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