import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class DoctorDashboardPage extends StatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  State<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends State<DoctorDashboardPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final AuthService _authService = AuthService();
  bool _isLoading = true;
  UserModel? _currentDoctor;
  List<AppointmentModel> _todayAppointments = [];
  List<Map<String, dynamic>> _patientRequests = [];
  List<Map<String, dynamic>> _analytics = [];
  int _unreadMessageCount = 0;
  
  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }
  
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Get current doctor data
      final user = await _authService.getCurrentUser();
      if (user != null) {
        _currentDoctor = await _firebaseService.getUserById(user.uid);
        
        if (_currentDoctor != null) {
          // Load today's appointments
          final today = DateTime.now();
          final startOfDay = DateTime(today.year, today.month, today.day);
          final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
          
          final appointments = await _firebaseService.getAppointmentsForDoctor(
            _currentDoctor!.id,
            status: AppointmentStatus.upcoming,
          );
          
          // Filter for today's appointments
          _todayAppointments = appointments.where((appointment) {
            final appointmentDate = appointment.date.toDate();
            return appointmentDate.isAfter(startOfDay) && 
                   appointmentDate.isBefore(endOfDay);
          }).toList();
          
          // Sort by time
          _todayAppointments.sort((a, b) {
            final timeA = _parseTime(a.time);
            final timeB = _parseTime(b.time);
            return timeA.compareTo(timeB);
          });
          
          // Load patient requests (using mock data for now)
          _patientRequests = [
            {
              'id': 'req1',
              'patientName': 'Sarah Wilson',
              'type': 'Prescription Renewal',
              'date': DateTime.now().subtract(const Duration(hours: 3)),
              'message': 'Need a refill for hypertension medication',
              'isUrgent': true,
            },
            {
              'id': 'req2',
              'patientName': 'Robert Brown',
              'type': 'Medical Question',
              'date': DateTime.now().subtract(const Duration(hours: 6)),
              'message': 'Side effects of new medication',
              'isUrgent': false,
            },
          ];
          
          // Load unread messages count
          final chats = await _firebaseService.getChatsForUser(_currentDoctor!.id);
          _unreadMessageCount = chats.fold(0, (sum, chat) => sum + chat.unreadCount);
          
          // Load analytics (mock data for now, but would be derived from real appointments)
          final pastAppointments = await _firebaseService.getPastAppointments(_currentDoctor!.id, true);
          
          _analytics = [
            {
              'title': 'Patients Seen',
              'value': pastAppointments.length,
              'change': 8,
              'isIncrease': true,
              'icon': Icons.people_outline,
              'color': AppColors.primary,
            },
            {
              'title': 'Avg. Session Time',
              'value': 24,
              'unit': 'min',
              'change': 2,
              'isIncrease': true,
              'icon': Icons.timer_outlined,
              'color': AppColors.secondary,
            },
            {
              'title': 'Upcoming',
              'value': appointments.length,
              'change': 3,
              'isIncrease': true,
              'icon': Icons.calendar_today,
              'color': AppColors.accent,
            },
            {
              'title': 'Messages',
              'value': _unreadMessageCount,
              'change': 1,
              'isIncrease': true,
              'icon': Icons.message_outlined,
              'color': Colors.purple,
            },
          ];
        }
      }
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  // Helper function to parse time string for sorting
  DateTime _parseTime(String timeString) {
    final now = DateTime.now();
    final timeParts = timeString.split(' - ')[0]; // Take start time only
    
    try {
      final format = DateFormat('h:mm a');
      final time = format.parse(timeParts);
      return DateTime(now.year, now.month, now.day, time.hour, time.minute);
    } catch (e) {
      // Default to midnight if parsing fails
      return DateTime(now.year, now.month, now.day);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Dashboard'),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // Navigate to notifications
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () {
              // Navigate to settings
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _currentDoctor == null
            ? const Center(child: Text('Doctor information not found'))
            : RefreshIndicator(
                onRefresh: _loadDashboardData,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Doctor overview card
                      _buildDoctorOverviewCard(),
                      const SizedBox(height: 24),
                      
                      // Analytics
                      Text(
                        'This Week\'s Summary',
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _buildAnalyticsGrid(),
                      const SizedBox(height: 24),
                      
                      // Today's appointments
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Today\'s Appointments',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigate to appointments
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildAppointmentsList(),
                      const SizedBox(height: 24),
                      
                      // Patient requests
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Patient Requests',
                            style: AppTypography.headlineSmall.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton(
                            onPressed: () {
                              // Navigate to patient requests
                            },
                            child: const Text('View All'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      _buildPatientRequestsList(),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          // Navigate to create appointment
        },
        backgroundColor: AppColors.primary,
        label: const Text('New Appointment'),
        icon: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildDoctorOverviewCard() {
    if (_currentDoctor == null) return const SizedBox.shrink();
    
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _currentDoctor!.profileImageUrl != null
              ? CircleAvatar(
                  radius: 36,
                  backgroundImage: NetworkImage(_currentDoctor!.profileImageUrl!),
                )
              : CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    _getInitials(_currentDoctor!.name),
                    style: AppTypography.headlineMedium.copyWith(
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
                    'Dr. ${_currentDoctor!.name}',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    _currentDoctor!.medicalInfo?['specialty'] ?? 'Doctor',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _buildInfoChip(Icons.calendar_today, '${_todayAppointments.length} Appointments'),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.message_outlined, '$_unreadMessageCount Messages'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  String _getInitials(String name) {
    return name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
  }
  
  Widget _buildInfoChip(IconData icon, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surfaceMedium,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.5,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: _analytics.length,
      itemBuilder: (context, index) {
        final item = _analytics[index];
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      item['title'],
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    Icon(
                      item['icon'],
                      color: item['color'],
                      size: 24,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  '${item['value']}${item['unit'] ?? ''}',
                  style: AppTypography.headlineMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      item['isIncrease'] ? Icons.arrow_upward : Icons.arrow_downward,
                      color: item['isIncrease'] ? AppColors.success : AppColors.error,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${item['isIncrease'] ? '+' : '-'}${item['change']} vs last week',
                      style: AppTypography.bodySmall.copyWith(
                        color: item['isIncrease'] ? AppColors.success : AppColors.error,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildAppointmentsList() {
    return _todayAppointments.isEmpty
        ? _buildEmptyState(
            icon: Icons.calendar_today,
            title: 'No Appointments Today',
            subtitle: 'You have no scheduled appointments for today',
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _todayAppointments.length,
            itemBuilder: (context, index) {
              final appointment = _todayAppointments[index];
              final patientDetails = appointment.patientDetails!;
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      Routes.patientDetail,
                      arguments: appointment.patientId,
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: AppColors.primary.withOpacity(0.1),
                          child: Text(
                            patientDetails['name'].toString().split(' ').map((e) => e[0]).join(),
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
                                patientDetails['name'],
                                style: AppTypography.headlineSmall.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${patientDetails['age']} years, ${patientDetails['gender']}',
                                style: AppTypography.bodyMedium.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    appointment.time,
                                    style: AppTypography.bodyMedium,
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    appointment.type == AppointmentType.video ? Icons.videocam : Icons.location_on,
                                    size: 16,
                                    color: appointment.type == AppointmentType.video ? AppColors.accent : AppColors.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    appointment.type == AppointmentType.video ? 'Video' : 'In Person',
                                    style: AppTypography.bodyMedium,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Reason: ${patientDetails['reason']}',
                                style: AppTypography.bodyMedium,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: appointment.type == AppointmentType.video
                                    ? AppColors.accent.withOpacity(0.1)
                                    : AppColors.secondary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                appointment.type == AppointmentType.video ? 'Video' : 'In-person',
                                style: AppTypography.bodySmall.copyWith(
                                  color: appointment.type == AppointmentType.video
                                      ? AppColors.accent
                                      : AppColors.secondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildPatientRequestsList() {
    return _patientRequests.isEmpty
        ? _buildEmptyState(
            icon: Icons.inbox,
            title: 'No Patient Requests',
            subtitle: 'You have no pending patient requests',
          )
        : ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: _patientRequests.length,
            itemBuilder: (context, index) {
              final request = _patientRequests[index];
              
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                radius: 20,
                                backgroundColor: AppColors.surfaceMedium,
                                child: Text(
                                  request['patientName'].toString().split(' ').map((e) => e[0]).join(),
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request['patientName'],
                                    style: AppTypography.bodyLarge.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    request['type'],
                                    style: AppTypography.bodyMedium.copyWith(
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          if (request['isUrgent'] == true)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Urgent',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.error,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        request['message'],
                        style: AppTypography.bodyMedium,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatTimeAgo(request['date']),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                          Row(
                            children: [
                              TextButton(
                                onPressed: () {
                                  // Handle dismissing request
                                },
                                child: Text(
                                  'Dismiss',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ElevatedButton(
                                onPressed: () {
                                  // Handle responding to request
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                child: const Text('Respond'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
  }
  
  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: AppColors.surfaceDark,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
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
  
  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
} 