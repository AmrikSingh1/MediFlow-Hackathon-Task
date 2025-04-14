import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Providers
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final upcomingAppointmentsProvider = FutureProvider<List<AppointmentModel>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  final user = await authService.getCurrentUser();
  
  if (user == null) return [];
  return await firebaseService.getUpcomingAppointments(user.uid, false);
});

final pastAppointmentsProvider = FutureProvider<List<AppointmentModel>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  final user = await authService.getCurrentUser();
  
  if (user == null) return [];
  return await firebaseService.getPastAppointments(user.uid, false);
});

final cancelledAppointmentsProvider = FutureProvider<List<AppointmentModel>>((ref) async {
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

class _AppointmentsTabState extends ConsumerState<AppointmentsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabLabels = ['Upcoming', 'Past', 'Cancelled'];
  DateTime _selectedDate = DateTime.now();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabLabels.length, vsync: this);
  }
  
  void _refreshAppointments() {
    ref.refresh(upcomingAppointmentsProvider);
    ref.refresh(pastAppointmentsProvider);
    ref.refresh(cancelledAppointmentsProvider);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        _refreshAppointments();
      },
      child: Column(
        children: [
          // Calendar Strip
          _buildCalendarStrip(),
          
          // Tabs
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.surfaceDark,
                  width: 1,
                ),
              ),
            ),
            child: TabBar(
              controller: _tabController,
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              labelStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTypography.bodyMedium,
              indicatorColor: AppColors.primary,
              indicatorWeight: 3,
              tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
            ),
          ),
          
          // Tab Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildUpcomingAppointments(),
                _buildPastAppointments(),
                _buildCancelledAppointments(),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCalendarStrip() {
    final now = DateTime.now();
    final days = List.generate(7, (index) {
      return now.add(Duration(days: index));
    });
    
    return Container(
      height: 100,
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        itemBuilder: (context, index) {
          final day = days[index];
          final isToday = day.day == now.day && day.month == now.month && day.year == now.year;
          final isSelected = day.day == _selectedDate.day && 
                          day.month == _selectedDate.month && 
                          day.year == _selectedDate.year;
          
          // Get appointment count for this day from the appointments data
          final upcomingAppointments = ref.watch(upcomingAppointmentsProvider);
          int appointmentCount = 0;
          
          upcomingAppointments.whenData((appointments) {
            appointmentCount = appointments.where((apt) {
              final aptDate = apt.date.toDate();
              return aptDate.day == day.day && 
                     aptDate.month == day.month && 
                     aptDate.year == day.year;
            }).length;
          });
          
          return GestureDetector(
            onTap: () {
              setState(() {
                _selectedDate = day;
              });
            },
            child: Container(
              width: 60,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: isSelected 
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: isSelected
                  ? Border.all(color: AppColors.primary, width: 2)
                  : null,
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat('EEE').format(day).toUpperCase(),
                    style: AppTypography.bodySmall.copyWith(
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.primary : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        day.day.toString(),
                        style: AppTypography.bodyMedium.copyWith(
                          color: isToday ? Colors.white : AppColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (appointmentCount > 0)
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildUpcomingAppointments() {
    final upcomingAppointmentsAsync = ref.watch(upcomingAppointmentsProvider);
    
    return upcomingAppointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading appointments: $error'),
      ),
      data: (appointments) {
        // Filter appointments by selected date if needed
        final filteredAppointments = _selectedDate != null 
            ? appointments.where((apt) {
                final aptDate = apt.date.toDate();
                return aptDate.day == _selectedDate.day && 
                       aptDate.month == _selectedDate.month && 
                       aptDate.year == _selectedDate.year;
              }).toList()
            : appointments;
        
        return filteredAppointments.isEmpty
          ? _buildEmptyState('No upcoming appointments', 'Schedule a new appointment with your doctor')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: filteredAppointments.length,
              itemBuilder: (context, index) {
                return _buildAppointmentCard(filteredAppointments[index]);
              },
            );
      },
    );
  }
  
  Widget _buildPastAppointments() {
    final pastAppointmentsAsync = ref.watch(pastAppointmentsProvider);
    
    return pastAppointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading appointments: $error'),
      ),
      data: (appointments) {
        return appointments.isEmpty
          ? _buildEmptyState('No past appointments', 'Your appointment history will appear here')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                return _buildAppointmentCard(appointments[index], isPast: true);
              },
            );
      },
    );
  }
  
  Widget _buildCancelledAppointments() {
    final cancelledAppointmentsAsync = ref.watch(cancelledAppointmentsProvider);
    
    return cancelledAppointmentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading appointments: $error'),
      ),
      data: (appointments) {
        return appointments.isEmpty
          ? _buildEmptyState('No cancelled appointments', 'Cancelled appointments will appear here')
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: appointments.length,
              itemBuilder: (context, index) {
                return _buildAppointmentCard(appointments[index], isCancelled: true);
              },
            );
      },
    );
  }
  
  Widget _buildAppointmentCard(AppointmentModel appointment, {bool isPast = false, bool isCancelled = false}) {
    // Format date
    final appointmentDate = appointment.date.toDate();
    final isToday = DateFormat('yyyy-MM-dd').format(appointmentDate) == DateFormat('yyyy-MM-dd').format(DateTime.now());
    final formattedDate = isToday
        ? 'Today, ${DateFormat('MMM d').format(appointmentDate)}'
        : DateFormat('EEEE, MMM d').format(appointmentDate);
    
    // Get doctor info from appointment
    final doctorName = appointment.doctorDetails?['name'] ?? 'Doctor';
    final doctorSpecialty = appointment.doctorDetails?['specialty'] ?? 'Specialist';
    final appointmentLocation = appointment.location ?? 'Medical Center';
    final isVideo = appointment.type == AppointmentType.video;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    doctorName.toString().split(' ').map((e) => e.isEmpty ? '' : e[0]).join(),
                    style: AppTypography.headlineSmall.copyWith(
                      color: AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        doctorSpecialty,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: isPast || isCancelled
                                ? AppColors.textTertiary
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            formattedDate,
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time,
                            size: 16,
                            color: isPast || isCancelled
                                ? AppColors.textTertiary
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            appointment.time,
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            isVideo
                                ? Icons.videocam
                                : Icons.location_on,
                            size: 16,
                            color: isPast || isCancelled
                                ? AppColors.textTertiary
                                : AppColors.primary,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            isVideo
                                ? 'Video Consultation'
                                : appointmentLocation,
                            style: AppTypography.bodyMedium,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (!isPast && !isCancelled)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.surfaceDark,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // TODO: Reschedule appointment
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.calendar_month,
                              size: 20,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Reschedule',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: AppColors.surfaceDark,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // TODO: Cancel appointment
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.close,
                              size: 20,
                              color: AppColors.error,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Cancel',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.error,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else if (isPast)
            Container(
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.surfaceDark,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // TODO: View details
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.description_outlined,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'View Summary',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Container(
                    width: 1,
                    height: 44,
                    color: AppColors.surfaceDark,
                  ),
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        // TODO: Book follow-up
                      },
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.add_circle_outline,
                              size: 20,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Book Follow-up',
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.calendar_today,
              size: 80,
              color: AppColors.surfaceDark,
            ),
            const SizedBox(height: 24),
            Text(
              title,
              style: AppTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
} 