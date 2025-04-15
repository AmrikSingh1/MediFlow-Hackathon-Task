import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:intl/intl.dart';

// Providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final upcomingAppointmentsProvider = FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  final user = await authService.getCurrentUser();
  
  if (user == null) return [];
  return await firebaseService.getUpcomingAppointments(user.uid, false);
});

final pastAppointmentsProvider = FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  final user = await authService.getCurrentUser();
  
  if (user == null) return [];
  return await firebaseService.getPastAppointments(user.uid, false);
});

final cancelledAppointmentsProvider = FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  final user = await authService.getCurrentUser();
  
  if (user == null) return [];
  return await firebaseService.getCancelledAppointments(user.uid, false);
});

class AppointmentsTab extends ConsumerStatefulWidget {
  const AppointmentsTab({super.key});

  @override
  ConsumerState<AppointmentsTab> createState() => _AppointmentsTabState();
}

class _AppointmentsTabState extends ConsumerState<AppointmentsTab> with TickerProviderStateMixin {
  late TabController _tabController;
  DateTime _selectedDate = DateTime.now();
  late List<DateTime> _calendarDates;
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        _refreshData();
      }
    });
    
    // Initialize calendar dates
    _generateCalendarDates();
    
    // Initial data load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
      // Scroll to today's date
      _scrollToSelectedDate();
    });
  }
  
  void _generateCalendarDates() {
    // Generate dates from 30 days in the past to 90 days in the future
    final DateTime startDate = DateTime.now().subtract(const Duration(days: 30));
    final DateTime endDate = DateTime.now().add(const Duration(days: 90));
    
    _calendarDates = [];
    for (DateTime date = startDate; date.isBefore(endDate); date = date.add(const Duration(days: 1))) {
      _calendarDates.add(DateTime(date.year, date.month, date.day));
    }
  }
  
  void _scrollToSelectedDate() {
    // Find index of today's date
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    
    final index = _calendarDates.indexWhere((date) => 
      date.year == today.year && 
      date.month == today.month && 
      date.day == today.day
    );
    
    if (index != -1) {
      // Scroll to today with some padding
      Future.delayed(const Duration(milliseconds: 100), () {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            (index * 70.0) - 100.0, // 70 is the width of each date item + padding
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      });
    }
  }
  
  void _refreshData() {
    switch (_tabController.index) {
      case 0:
        ref.refresh(upcomingAppointmentsProvider);
        break;
      case 1:
        ref.refresh(pastAppointmentsProvider);
        break;
      case 2:
        ref.refresh(cancelledAppointmentsProvider);
        break;
    }
  }
  
  void _onDateSelected(DateTime date) {
    setState(() {
      _selectedDate = date;
    });
    _refreshData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        children: [
          // Calendar Strip
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: _buildCalendarStrip(),
          ),
          const SizedBox(height: 16),
          
          // Tab Bar
          TabBar(
            controller: _tabController,
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Upcoming'),
              Tab(text: 'Past'),
              Tab(text: 'Cancelled'),
            ],
          ),
          
          // Tab Bar View
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildAppointmentList(0),
                _buildAppointmentList(1),
                _buildAppointmentList(2),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCalendarStrip() {
    return Container(
      height: 100,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              DateFormat('MMMM yyyy').format(_selectedDate),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              itemCount: _calendarDates.length,
              itemBuilder: (context, index) {
                final date = _calendarDates[index];
                final isSelected = date.day == _selectedDate.day && 
                              date.month == _selectedDate.month && 
                              date.year == _selectedDate.year;
                final isToday = date.day == DateTime.now().day && 
                            date.month == DateTime.now().month && 
                            date.year == DateTime.now().year;
                
                return GestureDetector(
                  onTap: () => _onDateSelected(date),
                  child: Container(
                    width: 60,
                    margin: const EdgeInsets.symmetric(horizontal: 5.0),
                    decoration: BoxDecoration(
                      color: isSelected ? AppColors.primary : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          DateFormat('E').format(date).toUpperCase(),
                          style: TextStyle(
                            fontSize: 11,
                            color: isSelected ? Colors.white : 
                                  isToday ? AppColors.primary : Colors.grey,
                            fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          date.day.toString(),
                          style: TextStyle(
                            fontSize: 15,
                            color: isSelected ? Colors.white : 
                                  isToday ? AppColors.primary : Colors.black,
                            fontWeight: isSelected || isToday ? FontWeight.bold : FontWeight.normal,
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
      ),
    );
  }

  Widget _buildAppointmentList(int tabIndex) {
    final provider = tabIndex == 0 
        ? upcomingAppointmentsProvider 
        : tabIndex == 1 
            ? pastAppointmentsProvider 
            : cancelledAppointmentsProvider;
    
    return ref.watch(provider).when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 16),
            Text('Error loading appointments: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (appointments) {
        // Filter appointments by selected date if needed
        final filteredAppointments = tabIndex == 0
            ? appointments.where((appointment) {
                final appointmentDate = appointment.date.toDate();
                return appointmentDate.day == _selectedDate.day &&
                       appointmentDate.month == _selectedDate.month &&
                       appointmentDate.year == _selectedDate.year;
              }).toList()
            : appointments;
            
        if (filteredAppointments.isEmpty) {
          return _buildEmptyState(tabIndex);
        }
        
        // Sort appointments by date (newest first for past, soonest first for upcoming)
        filteredAppointments.sort((a, b) => tabIndex == 1
            ? b.date.compareTo(a.date)  // Past - newest first
            : a.date.compareTo(b.date)); // Upcoming - soonest first
        
        return RefreshIndicator(
          onRefresh: () async {
            _refreshData();
          },
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredAppointments.length,
            itemBuilder: (context, index) {
              return _buildAppointmentCard(filteredAppointments[index]);
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(int tabIndex) {
    String message;
    IconData icon;
    
    switch (tabIndex) {
      case 0:
        message = 'No upcoming appointments for this date';
        icon = Icons.event_available;
        break;
      case 1:
        message = 'No past appointments';
        icon = Icons.history;
        break;
      case 2:
        message = 'No cancelled appointments';
        icon = Icons.event_busy;
        break;
      default:
        message = 'No appointments found';
        icon = Icons.calendar_today;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey.shade400),
          const SizedBox(height: 16),
          Text(
            message,
            style: AppTypography.bodyLarge.copyWith(
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 24),
          if (tabIndex == 0)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              child: Material(
                elevation: 4,
                shadowColor: AppColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(16),
                child: InkWell(
                  onTap: () => _navigateToBookAppointment(),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppColors.primary,
                          AppColors.primary.withBlue(255),
                        ],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    width: double.infinity,
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.add_circle_outline,
                          color: Colors.white,
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Book Appointment',
                          style: AppTypography.bodyLarge.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Navigate to book appointment page
  void _navigateToBookAppointment() {
    Navigator.of(context).pushNamed(Routes.bookAppointment).then((_) {
      _refreshData(); // Refresh data when returning from booking page
    });
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    final appointmentDate = appointment.date.toDate();
    final dayFormat = DateFormat('E, MMM d');
    final timeFormat = DateFormat('h:mm a');
    
    // Get doctor details
    String doctorName = 'Doctor';
    String doctorSpecialty = 'Medical Professional';
    String? doctorImageUrl;
    
    if (appointment.doctorDetails != null) {
      if (appointment.doctorDetails!['name'] != null) {
        doctorName = 'Dr. ${appointment.doctorDetails!['name']}';
      }
      if (appointment.doctorDetails!['specialty'] != null) {
        doctorSpecialty = appointment.doctorDetails!['specialty'];
      }
      if (appointment.doctorDetails!['profileImageUrl'] != null) {
        doctorImageUrl = appointment.doctorDetails!['profileImageUrl'];
      }
    }
    
    // Status color based on appointment status
    Color statusColor;
    switch (appointment.status) {
      case AppointmentStatus.upcoming:
        statusColor = AppColors.primary;
        break;
      case AppointmentStatus.past:
        statusColor = AppColors.success;
        break;
      case AppointmentStatus.cancelled:
        statusColor = AppColors.error;
        break;
      default:
        statusColor = AppColors.primary;
    }
    
    // Type icon based on appointment type
    IconData typeIcon;
    String typeText;
    switch (appointment.type) {
      case AppointmentType.video:
        typeIcon = Icons.videocam_outlined;
        typeText = 'Video Call';
        break;
      case AppointmentType.inPerson:
        typeIcon = Icons.local_hospital_outlined;
        typeText = 'In-Person';
        break;
      default:
        typeIcon = Icons.local_hospital_outlined;
        typeText = 'In-Person';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // TODO: Navigate to appointment details
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  // Doctor Avatar
                  doctorImageUrl != null
                      ? CircleAvatar(
                          radius: 24,
                          backgroundImage: NetworkImage(doctorImageUrl),
                        )
                      : CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: const Icon(
                            Icons.person,
                            color: AppColors.primary,
                          ),
                        ),
                  const SizedBox(width: 16),
                  
                  // Doctor Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorName,
                          style: AppTypography.bodyLarge.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          doctorSpecialty,
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Appointment Type
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          typeIcon,
                          size: 16,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          typeText,
                          style: AppTypography.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const Divider(height: 24),
              
              // Appointment Details
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildDetailItem(
                    Icons.calendar_today,
                    'Date',
                    dayFormat.format(appointmentDate),
                  ),
                  _buildDetailItem(
                    Icons.access_time,
                    'Time',
                    timeFormat.format(appointmentDate),
                  ),
                  _buildDetailItem(
                    Icons.timelapse,
                    'Duration',
                    '30 mins',
                  ),
                ],
              ),
              
              const SizedBox(height: 16),
              
              // Action Buttons
              if (_tabController.index == 0)
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton(
                      onPressed: () {
                        _showCancelDialog(appointment);
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                      ),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      onPressed: () {
                        // TODO: Navigate to reschedule page
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                      ),
                      child: appointment.type == AppointmentType.video
                          ? const Text('Join Call')
                          : const Text('View Details'),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Column(
      children: [
        Icon(
          icon,
          color: AppColors.primary,
          size: 22,
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.grey.shade600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: AppTypography.bodyMedium.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
  
  void _showCancelDialog(AppointmentModel appointment) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Appointment'),
        content: const Text(
          'Are you sure you want to cancel this appointment? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('No, Keep it'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _cancelAppointment(appointment);
            },
            style: TextButton.styleFrom(
              foregroundColor: AppColors.error,
            ),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _cancelAppointment(AppointmentModel appointment) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      
      // Update appointment status
      final updatedAppointment = appointment.copyWith(
        status: AppointmentStatus.cancelled,
      );
      
      await firebaseService.updateAppointment(updatedAppointment);
      
      // Refresh data
      _refreshData();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Appointment cancelled successfully'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to cancel appointment: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }
} 