import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final appointmentProvider = FutureProvider.family<AppointmentModel?, String>((ref, appointmentId) async {
  final firebaseService = FirebaseService();
  return await firebaseService.getAppointmentById(appointmentId);
});

final userProvider = FutureProvider.family<UserModel?, String>((ref, userId) async {
  final firebaseService = FirebaseService();
  return await firebaseService.getUserById(userId);
});

class AppointmentDetailsPage extends ConsumerStatefulWidget {
  final String appointmentId;
  
  const AppointmentDetailsPage({
    Key? key,
    required this.appointmentId,
  }) : super(key: key);

  @override
  ConsumerState<AppointmentDetailsPage> createState() => _AppointmentDetailsPageState();
}

class _AppointmentDetailsPageState extends ConsumerState<AppointmentDetailsPage> {
  bool _isLoading = false;
  bool _isCancelling = false;
  bool _isDoctor = false;
  String? _currentUserId;
  
  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }
  
  Future<void> _checkUserRole() async {
    final authService = AuthService();
    final user = await authService.getCurrentUser();
    if (user != null) {
      final userModel = await authService.getCurrentUserData();
      setState(() {
        _isDoctor = userModel?.role == UserRole.doctor;
        _currentUserId = user.uid;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final appointmentAsync = ref.watch(appointmentProvider(widget.appointmentId));
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog();
            },
          ),
        ],
      ),
      body: appointmentAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 60, color: AppColors.error),
              const SizedBox(height: 16),
              Text(
                'Error loading appointment',
                style: AppTypography.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(
                error.toString(),
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
        data: (appointment) {
          if (appointment == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event_busy, size: 60, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Appointment Not Found',
                    style: AppTypography.titleMedium,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    ),
                    child: const Text('Go Back'),
                  ),
                ],
              ),
            );
          }
          
          return _buildAppointmentDetails(appointment);
        },
      ),
    );
  }
  
  Widget _buildAppointmentDetails(AppointmentModel appointment) {
    // Determine if it's a doctor or patient
    final otherPartyId = _isDoctor ? appointment.patientId : appointment.doctorId;
    final otherPartyAsync = ref.watch(userProvider(otherPartyId));
    
    return RefreshIndicator(
      onRefresh: () async {
        // Refresh the appointment data
        ref.refresh(appointmentProvider(widget.appointmentId));
        // Refresh the other party data
        ref.refresh(userProvider(otherPartyId));
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status Indicator
            _buildStatusBadge(appointment.status),
            const SizedBox(height: 24),
            
            // Date and Time
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appointment Schedule',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.calendar_month,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Date',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              DateFormat('EEEE, MMMM d, yyyy').format(appointment.date.toDate()),
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.access_time,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Time',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              appointment.time,
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.videocam,
                            color: AppColors.primary,
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Type',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            Text(
                              appointment.type == AppointmentType.inPerson 
                                  ? 'In-Person Consultation' 
                                  : 'Video Consultation',
                              style: AppTypography.bodyLarge.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Doctor/Patient Information Card
            otherPartyAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Text('Error loading user: $error'),
              data: (otherParty) {
                if (otherParty == null) {
                  return const Card(
                    child: Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Text('User information not available'),
                    ),
                  );
                }
                
                return Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _isDoctor ? 'Patient Information' : 'Doctor Information',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            CircleAvatar(
                              radius: 30,
                              backgroundColor: AppColors.primary.withOpacity(0.1),
                              child: Text(
                                otherParty.name.isNotEmpty ? otherParty.name[0].toUpperCase() : '?',
                                style: const TextStyle(
                                  color: AppColors.primary,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _isDoctor ? otherParty.name : 'Dr. ${otherParty.name}',
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  if (!_isDoctor && otherParty.doctorInfo != null)
                                    Text(
                                      otherParty.doctorInfo!['specialty'] ?? 'General Practitioner',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: AppColors.textSecondary,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.message_outlined),
                              color: AppColors.primary,
                              onPressed: () {
                                // Navigate to chat screen with this user
                                Navigator.pushNamed(
                                  context, 
                                  '${Routes.chat.split('/:')[0]}/${otherParty.id}',
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.call_outlined),
                              color: AppColors.primary,
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Calling feature will be available soon'),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        if (otherParty.phoneNumber != null) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Icon(
                                Icons.phone,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                otherParty.phoneNumber!,
                                style: AppTypography.bodyMedium,
                              ),
                            ],
                          ),
                        ],
                        if (!_isDoctor && otherParty.doctorInfo != null && otherParty.doctorInfo!['hospitalAffiliation'] != null) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              const Icon(
                                Icons.local_hospital,
                                size: 16,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  otherParty.doctorInfo!['hospitalAffiliation'],
                                  style: AppTypography.bodyMedium,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            
            // Appointment Notes
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appointment Notes',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        appointment.notes ?? 'No notes provided for this appointment.',
                        style: AppTypography.bodyMedium,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            
            // Location (if in-person)
            if (appointment.type == AppointmentType.inPerson && appointment.location != null)
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Location',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.location_on,
                            color: AppColors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              appointment.location!,
                              style: AppTypography.bodyMedium,
                            ),
                          ),
                          OutlinedButton.icon(
                            icon: const Icon(Icons.map_outlined),
                            label: const Text('View Map'),
                            onPressed: () {
                              // Logic to open map
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Map view will be available soon'),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 32),
            
            // Action Buttons
            if (appointment.status == AppointmentStatus.upcoming) ...[
              if (appointment.type == AppointmentType.video)
                GradientButton(
                  text: 'Join Video Call',
                  onPressed: () {
                    // Logic to join video call
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Video call feature will be available soon'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.videocam, color: Colors.white),
                ),
              if (appointment.type == AppointmentType.video)
                const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _showRescheduleDialog(appointment),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: const Text('Reschedule'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _showCancelDialog(appointment),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppColors.error,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      child: _isCancelling 
                          ? const SizedBox(
                              height: 20, 
                              width: 20, 
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text('Cancel Appointment'),
                    ),
                  ),
                ],
              ),
            ],
            
            // If appointment is completed, show follow-up button
            if (appointment.status == AppointmentStatus.past) ...[
              GradientButton(
                text: 'Book Follow-Up',
                onPressed: () {
                  // Navigate to book appointment page with pre-filled doctor
                  Navigator.pushNamed(context, Routes.bookAppointment, arguments: {
                    'doctorId': appointment.doctorId,
                    'isFollowUp': true,
                    'previousAppointmentId': appointment.id,
                  });
                },
                icon: const Icon(Icons.add_circle_outline, color: Colors.white),
              ),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusBadge(AppointmentStatus status) {
    Color color;
    String text;
    IconData icon;
    
    switch (status) {
      case AppointmentStatus.upcoming:
        color = AppColors.primary;
        text = 'Upcoming';
        icon = Icons.event_available;
        break;
      case AppointmentStatus.past:
        color = AppColors.success;
        text = 'Completed';
        icon = Icons.check_circle;
        break;
      case AppointmentStatus.cancelled:
        color = AppColors.error;
        text = 'Cancelled';
        icon = Icons.cancel;
        break;
      default:
        color = AppColors.textSecondary;
        text = 'Unknown';
        icon = Icons.help_outline;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: color,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            text,
            style: AppTypography.bodyMedium.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Appointment Help'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Text('• You can view all details about your appointment here.'),
            SizedBox(height: 8),
            Text('• For upcoming appointments, you can reschedule or cancel if needed.'),
            SizedBox(height: 8),
            Text('• For completed appointments, you can book a follow-up.'),
            SizedBox(height: 8),
            Text('• You can message or call the other party directly from this screen.'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }
  
  void _showRescheduleDialog(AppointmentModel appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Reschedule Appointment'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Would you like to reschedule this appointment?',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            const Text(
              'You will be redirected to the appointment booking page with your current details pre-filled.',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep Appointment'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              
              // Navigate to reschedule page
              Navigator.pushNamed(
                context, 
                Routes.bookAppointment,
                arguments: {
                  'doctorId': appointment.doctorId,
                  'reschedulingAppointmentId': appointment.id,
                },
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
            ),
            child: const Text('Yes, Reschedule'),
          ),
        ],
      ),
    );
  }
  
  void _showCancelDialog(AppointmentModel appointment) {
    String reason = '';
    
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Cancel Appointment'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Are you sure you want to cancel this appointment?',
                  style: TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Please provide a reason for cancellation:',
                  style: TextStyle(fontSize: 14),
                ),
                const SizedBox(height: 8),
                TextField(
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText: 'Reason for cancellation',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) {
                    reason = value;
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('No, Keep Appointment'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (reason.trim().isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Please provide a reason for cancellation'),
                      ),
                    );
                    return;
                  }
                  
                  Navigator.pop(context);
                  
                  // Set cancelling state
                  setState(() {
                    _isCancelling = true;
                  });
                  
                  try {
                    // In a real app, this would be a call to cancel the appointment
                    // For now, show a success message after a delay
                    await Future.delayed(const Duration(seconds: 1));
                    
                    final firebaseService = FirebaseService();
                    await firebaseService.cancelAppointment(appointment.id, reason);
                    
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Appointment cancelled successfully'),
                          backgroundColor: Colors.green,
                        ),
                      );
                      
                      // Refresh the appointment data
                      ref.refresh(appointmentProvider(widget.appointmentId));
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error cancelling appointment: $e'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  } finally {
                    if (mounted) {
                      setState(() {
                        _isCancelling = false;
                      });
                    }
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.error,
                ),
                child: const Text('Yes, Cancel'),
              ),
            ],
          );
        }
      ),
    );
  }
} 