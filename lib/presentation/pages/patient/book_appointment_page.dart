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

// Provider for a specific doctor
final doctorProvider = FutureProvider.family<DoctorModel?, String>((ref, doctorId) async {
  final firebaseService = ref.read(firebaseServiceProvider);
  return await firebaseService.getDoctorById(doctorId);
});

// Provider for available slots for a specific doctor on a specific date
final availableSlotsProvider = FutureProvider.family<List<AppointmentSlotModel>, Map<String, dynamic>>((ref, params) async {
  final firebaseService = ref.read(firebaseServiceProvider);
  final doctorId = params['doctorId'] as String;
  final date = params['date'] as DateTime;
  return await firebaseService.getAvailableSlotsForDoctor(doctorId, date);
});

class BookAppointmentPage extends ConsumerStatefulWidget {
  final String doctorId;

  const BookAppointmentPage({
    super.key, 
    required this.doctorId,
  });

  @override
  ConsumerState<BookAppointmentPage> createState() => _BookAppointmentPageState();
}

class _BookAppointmentPageState extends ConsumerState<BookAppointmentPage> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  
  // Selected date is tomorrow by default
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  
  // Time slot selection
  AppointmentSlotModel? _selectedSlot;
  
  // Patient's reason for visit
  String _reasonForVisit = '';
  
  bool _isLoading = false;
  
  // Available date list for next 7 days
  late List<DateTime> _availableDates;
  
  // Time slots grouped by morning, afternoon, evening
  Map<String, List<AppointmentSlotModel>> _groupedSlots = {
    'Morning': [],
    'Afternoon': [],
    'Evening': [],
  };
  
  @override
  void initState() {
    super.initState();
    // Generate available dates for the next 7 days instead of 4
    _availableDates = List.generate(7, (index) {
      return DateTime.now().add(Duration(days: index));
    });
    
    // Load available slots for selected doctor and date
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadSlotsForDate(_selectedDate);
    });
  }

  // Load available slots for a specific date
  Future<void> _loadSlotsForDate(DateTime date) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final slots = await firebaseService.getAvailableSlotsForDoctor(
        widget.doctorId, 
        date
      );
      
      // Group slots by time of day
      final Map<String, List<AppointmentSlotModel>> grouped = {
        'Morning': [],
        'Afternoon': [],
        'Evening': [],
      };
      
      for (var slot in slots) {
        if (!slot.isBooked) {
          final timeStr = slot.timeSlot;
          final hour = _parseHourFromTimeSlot(timeStr);
          
          if (hour < 12) {
            grouped['Morning']!.add(slot);
          } else if (hour < 17) {
            grouped['Afternoon']!.add(slot);
          } else {
            grouped['Evening']!.add(slot);
          }
        }
      }
      
      // Sort slots within each group
      for (var key in grouped.keys) {
        grouped[key]!.sort((a, b) => _compareTimeSlots(a.timeSlot, b.timeSlot));
      }
      
      setState(() {
        _groupedSlots = grouped;
      });
    } catch (e) {
      debugPrint('Error loading slots: $e');
      // Show error snackbar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading time slots: $e'))
      );
    }
  }
  
  // Parse hour from a time slot string like "9:00 AM"
  int _parseHourFromTimeSlot(String timeSlot) {
    final regexTime = RegExp(r'(\d+):(\d+)\s+(AM|PM)');
    final match = regexTime.firstMatch(timeSlot);
    
    if (match == null) return 0;
    
    int hour = int.parse(match.group(1)!);
    
    // Convert to 24-hour format
    if (match.group(3) == 'PM' && hour < 12) hour += 12;
    if (match.group(3) == 'AM' && hour == 12) hour = 0;
    
    return hour;
  }
  
  // Compare time slots for sorting
  int _compareTimeSlots(String timeA, String timeB) {
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
  
  void _selectDate(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedSlot = null; // Reset selected slot when date changes
    });
    _loadSlotsForDate(date);
  }
  
  void _selectTimeSlot(AppointmentSlotModel slot) {
    setState(() {
      _selectedSlot = slot;
    });
  }
  
  Future<void> _confirmBooking() async {
    // Validate the form first
    if (_selectedSlot == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a time slot'))
      );
      return;
    }
    
    if (_reasonForVisit.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a reason for your visit'))
      );
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authService = ref.read(authServiceProvider);
      
      // Get current user
      final user = await authService.getCurrentUser();
      if (user == null) {
        throw Exception('User not logged in');
      }
      
      final userData = await authService.getCurrentUserData();
      if (userData == null) {
        throw Exception('User data not found');
      }
      
      // Get doctor data
      final doctor = await firebaseService.getDoctorById(widget.doctorId);
      if (doctor == null) {
        throw Exception('Doctor not found');
      }
      
      // Create appointment model with doctor and patient details
      final appointmentId = FirebaseFirestore.instance.collection('appointments').doc().id;
      
      // Create doctor details map
      final Map<String, dynamic> doctorDetails = {
        'name': doctor.name,
        'specialty': doctor.specialty,
        'profileImageUrl': doctor.profileImageUrl,
      };
      
      // Create patient details map
      final Map<String, dynamic> patientDetails = {
        'name': userData.name,
        'email': userData.email,
        'phoneNumber': userData.phoneNumber,
      };
      
      final appointment = AppointmentModel(
        id: appointmentId,
        patientId: userData.id,
        doctorId: widget.doctorId,
        date: Timestamp.fromDate(_selectedDate),
        time: _selectedSlot!.timeSlot,
        status: AppointmentStatus.upcoming,
        type: AppointmentType.inPerson,
        notes: _reasonForVisit,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
        doctorDetails: doctorDetails,
        patientDetails: patientDetails,
      );
      
      // Book appointment
      await _bookAppointment(appointment);
      
      // Mark slot as booked
      await _markSlotAsBooked(_selectedSlot!.id);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Appointment booked successfully!'),
            backgroundColor: Colors.green,
          )
        );
        
        // Return to previous screen
        Navigator.pop(context);
      }
    } catch (e) {
      debugPrint('Error booking appointment: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error booking appointment: $e'),
            backgroundColor: Colors.red,
          )
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
  
  Future<void> _bookAppointment(AppointmentModel appointment) async {
    // Validate that we have all required information
    if (appointment.doctorId.isEmpty) {
      debugPrint('Error: Doctor ID is empty');
      throw Exception('Missing doctor information');
    }

    if (appointment.time.isEmpty) {
      debugPrint('Error: No time slot selected');
      throw Exception('Please select a time slot');
    }

    if (appointment.notes == null || appointment.notes!.isEmpty) {
      debugPrint('Error: No reason for visit provided');
      throw Exception('Please provide a reason for your visit');
    }

    // Debug logging for booking process
    debugPrint('Booking appointment with:');
    debugPrint('- Doctor ID: ${appointment.doctorId}');
    debugPrint('- Date: ${appointment.date.toDate()}');
    debugPrint('- Time Slot: ${appointment.time}');

    try {
      // Add to appointments collection
      await FirebaseFirestore.instance
          .collection('appointments')
          .doc(appointment.id)
          .set(appointment.toMap());
      
      // Handle potential slot lookup issues
      String slotId = "";
      if (_selectedSlot != null) {
        slotId = _selectedSlot!.id;
      } else {
        // If for some reason the selected slot is null, create a fallback slot ID
        debugPrint('Warning: Selected slot is null, creating fallback slot ID');
        final dateStr = DateFormat('yyyy-MM-dd').format(appointment.date.toDate());
        slotId = "${appointment.doctorId}-$dateStr-${appointment.time}";
      }
      
      // Update doctor's appointment count - handle both doctors and users collections
      final doctorRef = FirebaseFirestore.instance.collection('users').doc(appointment.doctorId);
      try {
        await doctorRef.update({
          'doctorInfo.appointmentCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Updated doctor appointment count');
      } catch (e) {
        debugPrint('Warning: Could not update doctor info: $e');
        // Continue with the booking process even if this update fails
      }
      
      // Update patient's appointment history
      final patientRef = FirebaseFirestore.instance.collection('users').doc(appointment.patientId);
      try {
        await patientRef.update({
          'medicalInfo.appointmentCount': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('Updated patient appointment count');
      } catch (e) {
        debugPrint('Warning: Could not update patient info: $e');
        // Continue with the booking process even if this update fails
      }
      
      debugPrint('Appointment booked successfully with ID: ${appointment.id}');
    } catch (e) {
      debugPrint('Critical error booking appointment: $e');
      throw Exception('Failed to book appointment: $e');
    }
  }
  
  Future<void> _markSlotAsBooked(String slotId) async {
    try {
      // Parse the slot ID to get the date
      final parts = slotId.split('-');
      if (parts.length < 2) {
        debugPrint('Invalid slot ID format: $slotId');
        return;
      }
      
      final doctorId = parts[0];
      final date = parts[1];
      final timeSlot = parts.length > 2 ? parts[2] : null;
      
      debugPrint('Marking slot as booked: Doctor=$doctorId, Date=$date, Time=${timeSlot ?? "Unknown"}');
      
      // First, try to update in the doctors collection
      bool updatedInDoctorsCollection = false;
      try {
        // Update the doctor's available slots
        final doctorRef = FirebaseFirestore.instance.collection('doctors').doc(doctorId);
        final doctorDoc = await doctorRef.get();
        
        if (doctorDoc.exists && doctorDoc.data() != null) {
          final data = doctorDoc.data()!;
          if (data['availableSlots'] != null) {
            final Map<String, dynamic> availableSlots = Map<String, dynamic>.from(data['availableSlots']);
            
            if (availableSlots.containsKey(date) && availableSlots[date] is List) {
              final List<dynamic> slots = List<dynamic>.from(availableSlots[date]);
              
              // Find and remove the booked slot
              if (timeSlot != null) {
                final bool removed = slots.remove(timeSlot);
                debugPrint('Time slot ${timeSlot} ${removed ? "removed" : "not found"} in doctor document');
                
                // Update the slots for this date
                availableSlots[date] = slots;
                
                // Update the doctor document
                await doctorRef.update({
                  'availableSlots': availableSlots,
                  'updatedAt': FieldValue.serverTimestamp(),
                });
                
                updatedInDoctorsCollection = true;
                debugPrint('Updated available slots in doctor document');
              }
            } else {
              debugPrint('No available slots found for date $date');
            }
          } else {
            debugPrint('No availableSlots field found in doctor document');
          }
        } else {
          debugPrint('Doctor document not found in doctors collection');
        }
      } catch (e) {
        debugPrint('Error updating doctor document: $e');
        // Continue to the next step even if this fails
      }
      
      // Then, update or create the appointment_slots document
      try {
        final slotDocRef = FirebaseFirestore.instance.collection('appointment_slots').doc(slotId);
        final slotDocSnapshot = await slotDocRef.get();
        
        if (slotDocSnapshot.exists) {
          // Update the appointment_slots collection
          await slotDocRef.update({
            'isBooked': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('Updated slot $slotId as booked in appointment_slots collection');
        } else {
          // Create the document if it doesn't exist
          await slotDocRef.set({
            'id': slotId,
            'doctorId': doctorId,
            'date': date,
            'timeSlot': timeSlot ?? '',
            'isBooked': true,
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
          debugPrint('Created new slot document for $slotId in appointment_slots collection');
        }
      } catch (e) {
        debugPrint('Error updating appointment slot document: $e');
        // If both steps failed, log a warning but don't throw exception
        if (!updatedInDoctorsCollection) {
          debugPrint('WARNING: Failed to mark slot as booked in both collections');
        }
      }
    } catch (e) {
      // Log the error but don't throw it, as the appointment is still created
      debugPrint('Error in _markSlotAsBooked: $e');
      // The main appointment is still valid even if we fail to mark the slot
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final doctorAsync = ref.watch(doctorProvider(widget.doctorId));
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          "Select a Time Slot",
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: doctorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, stack) => Center(
          child: Text('Error loading doctor: $err'),
        ),
        data: (doctor) {
          if (doctor == null) {
            return const Center(child: Text('Doctor not found'));
          }
          
          return Column(
            children: [
              // Doctor info card
              _buildDoctorInfoCard(doctor),
              
              // Discount banner
              _buildDiscountBanner(),
              
              // Date selection and slots
              Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                      // Date selection
                      _buildDateSelection(),
                      
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'All time slots are in your local time',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      
                      // Time slots
                      _buildTimeSlots(),
                      
                      // Discount information
                      _buildDiscountInfo(),
                      
                      // Add extra padding to ensure discount info is fully visible above bottom sheet
                      const SizedBox(height: 180),
                    ],
                                  ),
                                ),
                              ),
            ],
          );
        },
      ),
      bottomSheet: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: const Offset(0, -3),
            ),
          ],
        ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
            if (_selectedSlot != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  children: [
                    const Icon(Icons.access_time, color: Colors.grey),
                    const SizedBox(width: 8),
                                    Text(
                      '${DateFormat('MMM d').format(_selectedDate)}, ${_selectedSlot!.timeSlot}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
            
            // Reason for visit text field
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: TextFormField(
                decoration: InputDecoration(
                  labelText: 'Reason for Visit',
                  hintText: 'E.g., Fever, Checkup, Follow-up',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.medical_services),
                ),
                maxLines: 2,
                onChanged: (value) {
                        setState(() {
                    _reasonForVisit = value;
                        });
                      },
                      validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please provide a reason for your visit';
                        }
                        return null;
                      },
              ),
            ),
            
            ElevatedButton(
              onPressed: _selectedSlot == null || _isLoading
                  ? null
                  : _confirmBooking,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
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
                  : const Text(
                      'Confirm Booking',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
      ),
    );
  }
  
  Widget _buildDoctorInfoCard(DoctorModel doctor) {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Doctor image
          CircleAvatar(
            radius: 32,
            backgroundImage: doctor.profileImageUrl.isNotEmpty
                ? NetworkImage(doctor.profileImageUrl)
                : null,
            child: doctor.profileImageUrl.isEmpty
                ? const Icon(Icons.person, size: 32, color: Colors.grey)
                : null,
                      ),
                      const SizedBox(width: 16),
                      
          // Doctor info
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                      'Dr. ${doctor.name}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text(
                        'Change',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                Text(
                  '${doctor.hospitalAffiliation} (${doctor.medicalInfo != null && doctor.medicalInfo!['city'] != null ? doctor.medicalInfo!['city'] : 'City'})',
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(
                        text: 'Fee: ',
                        style: TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
                      ),
                      TextSpan(
                        text: 'Rs. 2,500',
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 14,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const TextSpan(
                        text: ' Rs. 2,250',
                        style: TextStyle(
                          color: Colors.black,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDiscountBanner() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12),
      color: AppColors.primary,
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.discount,
            color: Colors.white,
            size: 16,
          ),
          SizedBox(width: 8),
                  Text(
            'Pay Online & Get Upto 10% OFF',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDateSelection() {
    return Column(
      children: [
        Container(
          height: 120,
          padding: const EdgeInsets.all(16),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _availableDates.length + 1, // +1 for the calendar button
            itemBuilder: (context, index) {
              // Add a calendar button at the end
              if (index == _availableDates.length) {
                return GestureDetector(
                  onTap: _showCalendarDatePicker,
                  child: Container(
                    // More responsive width based on screen size
                    width: MediaQuery.of(context).size.width < 360 ? 70 : 80,
                    margin: const EdgeInsets.only(right: 8), // Reduced margin
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.grey.shade300,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.calendar_month,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'More',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.normal,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
      ),
    );
  }

              final date = _availableDates[index];
              final isSelected = DateUtils.isSameDay(date, _selectedDate);
              final isToday = DateUtils.isSameDay(date, DateTime.now());
              final isTomorrow = DateUtils.isSameDay(
                date, 
                DateTime.now().add(const Duration(days: 1))
              );
              
              return GestureDetector(
                onTap: () => _selectDate(date),
        child: Container(
                  // Responsive width based on screen size
                  width: MediaQuery.of(context).size.width < 360 ? 70 : 80,
                  margin: const EdgeInsets.only(right: 8), // Reduced margin
          decoration: BoxDecoration(
                    color: isSelected ? Colors.orange.shade50 : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                      color: isSelected ? Colors.orange : Colors.grey.shade300,
                      width: 1,
            ),
          ),
                  child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
                      Text(
                        isToday ? 'Today' : (isTomorrow ? 'Tomorrow' : DateFormat('EEE').format(date)),
                        style: TextStyle(
                          color: isSelected ? Colors.orange : Colors.black,
                          fontWeight: FontWeight.normal,
                          fontSize: 14,
                        ),
                        overflow: TextOverflow.ellipsis, // Prevent text overflow
                      ),
                      const SizedBox(height: 4),
              Text(
                        DateFormat('d').format(date),
                        style: TextStyle(
                          color: isSelected ? Colors.orange : Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 24,
                ),
              ),
            ],
          ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Show calendar picker for selecting dates beyond the next 7 days
  Future<void> _showCalendarDatePicker() async {
    // Allow selection up to 3 months in the future
    final lastDate = DateTime.now().add(const Duration(days: 90));
    
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: lastDate,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (pickedDate != null && !DateUtils.isSameDay(pickedDate, _selectedDate)) {
      // If selected date is not in our available dates list, add it
      bool dateExists = _availableDates.any((date) => DateUtils.isSameDay(date, pickedDate));
      
      if (!dateExists) {
        setState(() {
          // Add the new date to available dates, keeping them sorted
          _availableDates.add(pickedDate);
          _availableDates.sort((a, b) => a.compareTo(b));
        });
      }
      
      _selectDate(pickedDate);
    }
  }

  Widget _buildTimeSlots() {
    // Check if we have slots for any time period
    final hasSlots = _groupedSlots.values.any((slots) => slots.isNotEmpty);
    
    if (!hasSlots) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(
          child: Text(
            'No time slots available for this date.',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey,
            ),
          ),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Only show time periods that have slots
        for (final entry in _groupedSlots.entries)
          if (entry.value.isNotEmpty)
            _buildTimePeriodSection(entry.key, entry.value),
      ],
    );
  }
  
  Widget _buildTimePeriodSection(String title, List<AppointmentSlotModel> slots) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Section title with icon
          Row(
            children: [
              Icon(
                title == 'Morning' 
                    ? Icons.wb_sunny 
                    : title == 'Afternoon' 
                        ? Icons.wb_cloudy 
                        : Icons.nightlight_round,
                color: Colors.amber,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                '$title Slots',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Time slots grid - Improved to be more responsive
          Wrap(
            spacing: 8, // Reduced spacing
            runSpacing: 10, // Slightly reduced run spacing
            children: slots.map((slot) {
              final isSelected = _selectedSlot?.id == slot.id;
              
              return GestureDetector(
                onTap: () => _selectTimeSlot(slot),
                child: Container(
                  // Use a flexible width that adapts to screen size
                  width: MediaQuery.of(context).size.width < 360 ? 90 : 100,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: isSelected ? Colors.blue.shade50 : Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : Colors.grey.shade300,
                      width: 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    slot.timeSlot,
                    style: TextStyle(
                      color: isSelected ? AppColors.primary : Colors.black,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis, // Prevent text overflow
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.discount, color: AppColors.primary),
              const SizedBox(width: 8),
              const Expanded(  // Added Expanded to prevent overflow
                child: Text(
                  'Discount information',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text('* 100% Secure', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          const Text('* Maximum applicable discount Rs. 250', style: TextStyle(fontSize: 14)),
          const SizedBox(height: 8),
          const Text('* Online advance payment is required to avail discount', style: TextStyle(fontSize: 14), overflow: TextOverflow.visible),
          const SizedBox(height: 8),
          Wrap(  // Changed Row to Wrap to handle overflow better
            children: const [
              Text('* Other ', style: TextStyle(fontSize: 14)),
              Text(
                'Terms and conditions',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
              Text(' apply', style: TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
} 