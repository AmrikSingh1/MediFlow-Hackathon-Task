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

// Provider for available slots for a specific doctor on a specific date
final availableSlotsProvider = FutureProvider.family<List<AppointmentSlotModel>, Map<String, dynamic>>((ref, params) async {
  final firebaseService = ref.read(firebaseServiceProvider);
  final doctorId = params['doctorId'] as String;
  final date = params['date'] as DateTime;
  return await firebaseService.getAvailableSlotsForDoctor(doctorId, date);
});

class BookingAppointmentPage extends ConsumerStatefulWidget {
  const BookingAppointmentPage({super.key});

  @override
  ConsumerState<BookingAppointmentPage> createState() => _BookingAppointmentPageState();
}

class _BookingAppointmentPageState extends ConsumerState<BookingAppointmentPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  String? _selectedDoctorId;
  AppointmentType _appointmentType = AppointmentType.inPerson;
  String _reasonForVisit = '';
  String _additionalNotes = '';
  String? _selectedSlotId;
  
  bool _isLoading = false;
  
  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(availableDoctorsProvider);
    
    // Watch available slots if doctor and date are selected
    final slotsAsync = _selectedDoctorId != null 
        ? ref.watch(availableSlotsProvider({'doctorId': _selectedDoctorId!, 'date': _selectedDate}))
        : null;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Appointment'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: doctorsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error loading doctors: $error'),
        ),
        data: (doctors) {
          if (doctors.isEmpty) {
            return const Center(
              child: Text('No doctors available at the moment'),
            );
          }
          
          return Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
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
                  
                  // Doctor Selection
                  Text(
                    'Select Doctor',
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
                    child: DropdownButtonFormField<String>(
                      value: _selectedDoctorId,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 4,
                        ),
                        hintText: 'Select a doctor',
                        filled: true,
                        fillColor: Colors.transparent,
                        isDense: true,
                      ),
                      menuMaxHeight: 300,
                      itemHeight: 40,
                      items: doctors.map((doctor) {
                        return DropdownMenuItem<String>(
                          value: doctor.id,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              maxHeight: 36,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                CircleAvatar(
                                  radius: 14,
                                  backgroundColor: Color.fromRGBO(
                                      AppColors.primary.red.toInt(),
                                      AppColors.primary.green.toInt(),
                                      AppColors.primary.blue.toInt(),
                                      0.1),
                                  child: Text(
                                    doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : 'D',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        'Dr. ${doctor.name}',
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                        maxLines: 1,
                                      ),
                                      const SizedBox(height: 1),
                                      Text(
                                        doctor.specialty,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                          fontSize: 10,
                                          height: 1.0,
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
                          _selectedSlotId = null; // Reset selected slot when doctor changes
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
                  ),
                  const SizedBox(height: 24),
                  
                  // Date and Time Selection
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Date picker
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            InkWell(
                              onTap: () => _selectDate(context),
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  color: AppColors.surfaceLight,
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: AppColors.primary,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('MMM dd, yyyy').format(_selectedDate),
                                      style: AppTypography.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Time slot selection
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time Slots',
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildTimeSlotSelection(slotsAsync),
                          ],
                        ),
                      ),
                    ],
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
                        icon: Icons.person,
                        type: AppointmentType.inPerson,
                      ),
                      const SizedBox(width: 16),
                      _buildAppointmentTypeCard(
                        title: 'Video Call',
                        icon: Icons.videocam,
                        type: AppointmentType.video,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
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
                      hintText: 'Briefly describe your reason for appointment',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: AppColors.surfaceLight,
                      contentPadding: const EdgeInsets.all(16),
                    ),
                    maxLines: 3,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please provide a reason for visit';
                      }
                      return null;
                    },
                    onChanged: (value) {
                      setState(() {
                        _reasonForVisit = value;
                      });
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
          );
        },
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
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isSelected ? Color.fromRGBO(
              AppColors.primary.red.toInt(),
              AppColors.primary.green.toInt(),
              AppColors.primary.blue.toInt(),
              0.1) : AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppColors.primary : AppColors.surfaceDark,
              width: isSelected ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? AppColors.primary : AppColors.textSecondary,
                size: 32,
              ),
              const SizedBox(height: 8),
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimeSlotSelection(AsyncValue<List<AppointmentSlotModel>>? slotsAsync) {
    if (_selectedDoctorId == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          'Please select a doctor first',
          style: AppTypography.bodyMedium.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      );
    }
    
    if (slotsAsync == null) {
      return Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }
    
    return slotsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (error, stackTrace) => Container(
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text('Error loading slots: $error'),
        ),
      ),
      data: (slots) {
        if (slots.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.event_busy,
                  color: AppColors.textSecondary,
                  size: 32,
                ),
                const SizedBox(height: 8),
                Text(
                  'No available slots for this date',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        
        return Container(
          padding: const EdgeInsets.all(12.0),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SingleChildScrollView(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: slots.map((slot) {
                final isSelected = _selectedSlotId == slot.id;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedSlotId = slot.id;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.surfaceDark,
                      ),
                    ),
                    child: Text(
                      slot.timeSlot,
                      style: AppTypography.bodySmall.copyWith(
                        color: isSelected
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
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
        _selectedSlotId = null; // Reset selected slot when date changes
      });
    }
  }

  Future<void> _bookAppointment() async {
    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      
      // Validate selected doctor and time slot
      if (_selectedDoctorId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a doctor')),
        );
        return;
      }
      
      if (_selectedSlotId == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a time slot')),
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
              const SnackBar(content: Text('You need to be logged in to book an appointment')),
            );
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
        
        // Find the selected slot for time info
        final selectedSlotParts = _selectedSlotId!.split('-');
        final slotTime = selectedSlotParts.length > 2 ? selectedSlotParts[2] : "09:00 AM";
        
        // Create the appointment model
        final appointment = AppointmentModel(
          id: '', // Will be generated by the service
          patientId: currentUser.uid,
          doctorId: _selectedDoctorId!,
          date: Timestamp.fromDate(_selectedDate),
          time: slotTime,
          status: AppointmentStatus.upcoming,
          type: _appointmentType,
          notes: _additionalNotes.isNotEmpty ? _additionalNotes : _reasonForVisit,
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
        );
        
        // Book the selected slot
        final appointmentId = await firebaseService.bookAppointmentSlot(appointment);
        
        if (appointmentId == null) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Failed to book appointment. This slot may no longer be available.'),
                backgroundColor: AppColors.error,
              ),
            );
            setState(() {
              _isLoading = false;
            });
          }
          return;
        }
        
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
} 