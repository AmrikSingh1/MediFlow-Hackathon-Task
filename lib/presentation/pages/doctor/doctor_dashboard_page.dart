import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Provider for current doctor
final currentDoctorProvider = FutureProvider<UserModel?>((ref) async {
  final authService = AuthService();
  final firebaseService = FirebaseService();
  final user = await authService.getCurrentUser();
  if (user != null) {
    return await firebaseService.getUserById(user.uid);
  }
  return null;
});

// Provider for doctor's appointments
final doctorAppointmentsProvider = FutureProvider.family<List<AppointmentModel>, String>((ref, doctorId) async {
  final firebaseService = FirebaseService();
  return await firebaseService.getAppointmentsForDoctor(doctorId);
});

class DoctorDashboardPage extends ConsumerStatefulWidget {
  const DoctorDashboardPage({super.key});

  @override
  ConsumerState<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends ConsumerState<DoctorDashboardPage> {
  int _currentIndex = 0;
  UserModel? _doctor;
  bool _isProfileComplete = false;
  bool _isLoading = true;
  List<Widget> _tabs = [
    const Center(child: Text('Home')),
    const Center(child: Text('Appointments')),
    const Center(child: Text('Messages')),
    const Center(child: Text('Profile')),
  ];
  
  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }
  
  Future<void> _loadDoctorData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final doctor = await ref.read(currentDoctorProvider.future);
      
      debugPrint('Doctor data loaded: ${doctor?.id}');
      debugPrint('Doctor name: ${doctor?.name}');
      debugPrint('Doctor role: ${doctor?.role}');
      debugPrint('Doctor info available: ${doctor?.doctorInfo != null}');
      if (doctor?.doctorInfo != null) {
        debugPrint('Doctor specialty: ${doctor?.doctorInfo?['specialty']}');
      }
      
      setState(() {
        _doctor = doctor;
        _isProfileComplete = doctor != null ? _checkProfileComplete(doctor) : false;
        debugPrint('Profile complete: $_isProfileComplete');
        _isLoading = false;
        
        // Initialize tabs with doctor if available
        if (doctor != null) {
          _tabs = [
            DoctorHomeTab(doctor: doctor),
            DoctorAppointmentsTab(doctor: doctor),
            DoctorMessagesTab(doctor: doctor),
            DoctorProfileTab(doctor: doctor),
          ];
        }
      });
    } catch (e) {
      debugPrint('Error loading doctor data: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  bool _checkProfileComplete(UserModel doctor) {
    // Check if required doctor information is available
    // Allow dashboard to display even with incomplete information, just check basic fields
    return doctor.role == UserRole.doctor;
  }
  
  Widget _buildNoUserView(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'User Not Found',
            style: AppTypography.titleLarge,
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () {
              ref.invalidate(currentDoctorProvider);
              _loadDoctorData();
            },
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async => false,
      child: Scaffold(
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : _doctor == null
                ? _buildNoUserView(context)
                : !_isProfileComplete
                    ? _buildIncompleteProfileView(context)
                    : _tabs[_currentIndex],
        bottomNavigationBar: _doctor == null || !_isProfileComplete
            ? null
            : BottomNavigationBar(
                currentIndex: _currentIndex,
                onTap: _switchTab,
                type: BottomNavigationBarType.fixed,
                selectedItemColor: AppColors.primary,
                unselectedItemColor: AppColors.textSecondary,
                showUnselectedLabels: true,
                items: const [
                  BottomNavigationBarItem(
                    icon: Icon(Icons.home_outlined),
                    activeIcon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.calendar_month_outlined),
                    activeIcon: Icon(Icons.calendar_month),
                    label: 'Appointments',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.chat_outlined),
                    activeIcon: Icon(Icons.chat),
                    label: 'Messages',
                  ),
                  BottomNavigationBarItem(
                    icon: Icon(Icons.person_outlined),
                    activeIcon: Icon(Icons.person),
                    label: 'Profile',
                  ),
                ],
              ),
      ),
    );
  }

  void _switchTab(int index) {
    setState(() {
      _currentIndex = index;
      switch (index) {
        case 0:
          _tabs[0] = DoctorHomeTab(doctor: _doctor!);
          break;
        case 1:
          _tabs[1] = DoctorAppointmentsTab(doctor: _doctor!);
          break;
        case 2:
          _tabs[2] = DoctorMessagesTab(doctor: _doctor!);
          break;
        case 3:
          _tabs[3] = DoctorProfileTab(doctor: _doctor!);
          break;
      }
    });
  }
  
  String _getTabTitle() {
    switch (_currentIndex) {
      case 0:
        return 'Doctor Dashboard';
      case 1:
        return 'Appointments';
      case 2:
        return 'Messages';
      case 3:
        return 'Profile';
      default:
        return 'Doctor Dashboard';
    }
  }
  
  Widget _getTabContent(UserModel doctor) {
    switch (_currentIndex) {
      case 0:
        return DoctorHomeTab(doctor: doctor);
      case 1:
        return DoctorAppointmentsTab(doctor: doctor);
      case 2:
        return DoctorMessagesTab(doctor: doctor);
      case 3:
        return DoctorProfileTab(doctor: doctor);
      default:
        return DoctorHomeTab(doctor: doctor);
    }
  }
  
  Widget _buildIncompleteProfileView(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const Icon(
              Icons.account_circle_outlined,
              size: 80,
              color: AppColors.primary,
            ),
            const SizedBox(height: 24),
            Text(
              'Complete Your Doctor Profile',
              style: AppTypography.headlineSmall.copyWith(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Please complete your doctor profile before accessing the dashboard. Patients need to know your specialty and contact information to book appointments.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            GradientButton(
              text: 'Complete Profile',
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  Routes.doctorProfile,
                ).then((_) {
                  // Force refresh when returning from profile page
                  ref.invalidate(currentDoctorProvider);
                });
              },
            ),
          ],
        ),
      ),
    );
  }
}

// Doctor Dashboard Home Tab
class DoctorHomeTab extends ConsumerStatefulWidget {
  final UserModel doctor;

  const DoctorHomeTab({super.key, required this.doctor});

  @override
  ConsumerState<DoctorHomeTab> createState() => _DoctorHomeTabState();
}

class _DoctorHomeTabState extends ConsumerState<DoctorHomeTab> {
  List<AppointmentModel> _todayAppointments = [];
  List<Map<String, dynamic>> _patientRequests = [];
  List<Map<String, dynamic>> _analytics = [];
  int _unreadMessageCount = 0;
  bool _isLoading = true;

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
      final firebaseService = FirebaseService();
      
      // Load appointments
      final appointments = await firebaseService.getUpcomingAppointments(
        widget.doctor.id, 
        true
      );

      // Filter for today's appointments
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);
      
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
      
      // Load patient requests (mock data for now)
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
      
      // Load chats and count unread messages
      final chats = await firebaseService.getChatsForUser(widget.doctor.id);
      _unreadMessageCount = chats.fold(0, (sum, chat) => sum + chat.unreadCount);
      
      // Analytics (using real appointment data)
      final pastAppointments = await firebaseService.getPastAppointments(widget.doctor.id, true);
      final cancelledAppointments = await firebaseService.getCancelledAppointments(widget.doctor.id, true);
      
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
          'title': 'Avg. Session',
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
          'title': 'Cancelled',
          'value': cancelledAppointments.length,
          'change': 1,
          'isIncrease': false,
          'icon': Icons.cancel_outlined,
          'color': AppColors.error,
        },
      ];
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
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
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    debugPrint('DoctorHomeTab building UI');
    debugPrint('Doctor in tab: ${widget.doctor.id}');
    debugPrint('Doctor name: ${widget.doctor.name}');
    debugPrint('Has today\'s appointments: ${_todayAppointments.length}');
    debugPrint('Has patient requests: ${_patientRequests.length}');
    
    // Add error catching for the UI rendering
    try {
      return RefreshIndicator(
        onRefresh: _loadDashboardData,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Doctor overview card
              _buildDoctorOverviewCard(),
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
                      // Switch to appointments tab
                      ref.read(doctorAppointmentsProvider(widget.doctor.id));
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
                      // Show all patient requests
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
      );
    } catch (e) {
      debugPrint('Error rendering DoctorHomeTab: $e');
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            const Text(
              'Unable to display dashboard',
              style: AppTypography.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                'An error occurred while loading the dashboard. Error: $e',
                style: AppTypography.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboardData,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }
  }

  Widget _buildDoctorOverviewCard() {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            widget.doctor.profileImageUrl != null
              ? CircleAvatar(
                  radius: 36,
                  backgroundImage: NetworkImage(widget.doctor.profileImageUrl!),
                )
              : CircleAvatar(
                  radius: 36,
                  backgroundColor: Colors.white,
                  child: Text(
                    _getInitials(widget.doctor.name.isNotEmpty ? widget.doctor.name : "Doctor"),
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
                    widget.doctor.name.isNotEmpty ? 'Dr. ${widget.doctor.name}' : 'Doctor',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    widget.doctor.doctorInfo != null && widget.doctor.doctorInfo!.containsKey('specialty') 
                      ? widget.doctor.doctorInfo!['specialty'] 
                      : 'General Practitioner',
                    style: AppTypography.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildInfoChip(Icons.calendar_today, '${_todayAppointments.length} Today'),
                      const SizedBox(width: 8),
                      _buildInfoChip(Icons.message_outlined, '$_unreadMessageCount Unread'),
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w500,
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
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
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
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: InkWell(
                  onTap: () {
                    Navigator.of(context).pushNamed(
                      Routes.patientDetail.replaceAll(':id', appointment.patientId),
                    );
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 50,
                          height: 50,
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              appointment.patientDetails?['name']?.toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase() ?? 'P',
                              style: AppTypography.titleLarge.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                appointment.patientDetails?['name'] ?? 'Patient',
                                style: AppTypography.titleMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                '${appointment.patientDetails?['age'] ?? 'N/A'} years, ${appointment.patientDetails?['gender'] ?? 'N/A'}',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    size: 16,
                                    color: AppColors.textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    appointment.time,
                                    style: AppTypography.bodyMedium.copyWith(
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Icon(
                                    appointment.type == AppointmentType.video ? Icons.videocam : Icons.medical_services_outlined,
                                    size: 16,
                                    color: appointment.type == AppointmentType.video ? AppColors.accent : AppColors.secondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    appointment.type == AppointmentType.video ? 'Video' : 'In-person',
                                    style: AppTypography.bodySmall.copyWith(
                                      color: appointment.type == AppointmentType.video ? AppColors.accent : AppColors.secondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
              
              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
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
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceMedium,
                                  shape: BoxShape.circle,
                                ),
                                child: Center(
                                  child: Text(
                                    request['patientName'].toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.textPrimary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    request['patientName'],
                                    style: AppTypography.titleMedium.copyWith(
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  Text(
                                    request['type'],
                                    style: AppTypography.bodySmall.copyWith(
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
                      const SizedBox(height: 12),
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
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 0, maxWidth: 120),
                                child: OutlinedButton(
                                  onPressed: () {
                                    // Reject request
                                  },
                                  style: OutlinedButton.styleFrom(
                                    side: BorderSide(
                                      color: AppColors.error.withOpacity(0.5),
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                  child: const Text('Reject'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              ConstrainedBox(
                                constraints: const BoxConstraints(minWidth: 0, maxWidth: 150),
                                child: ElevatedButton.icon(
                                  onPressed: () {
                                    // Handle request
                                  },
                                  icon: const Icon(
                                    Icons.check_circle_outline,
                                    size: 18,
                                  ),
                                  label: const Text('Handle'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                  ),
                                ),
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
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 48,
            color: AppColors.surfaceDark,
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: AppTypography.titleLarge.copyWith(
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

// Doctor Appointments Tab
class DoctorAppointmentsTab extends ConsumerStatefulWidget {
  final UserModel doctor;

  const DoctorAppointmentsTab({super.key, required this.doctor});

  @override
  ConsumerState<DoctorAppointmentsTab> createState() => _DoctorAppointmentsTabState();
}

class _DoctorAppointmentsTabState extends ConsumerState<DoctorAppointmentsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Upcoming', 'Past', 'Cancelled'];
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.surfaceMedium,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((title) => Tab(text: title)).toList(),
              labelColor: AppColors.primary,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTypography.bodyMedium,
              padding: const EdgeInsets.all(4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
            ),
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UpcomingAppointmentsView(doctorId: widget.doctor.id),
              _PastAppointmentsView(doctorId: widget.doctor.id),
              _CancelledAppointmentsView(doctorId: widget.doctor.id),
            ],
          ),
        ),
      ],
    );
  }
}

// Upcoming Appointments View
class _UpcomingAppointmentsView extends ConsumerStatefulWidget {
  final String doctorId;

  const _UpcomingAppointmentsView({required this.doctorId});

  @override
  ConsumerState<_UpcomingAppointmentsView> createState() => _UpcomingAppointmentsViewState();
}

class _UpcomingAppointmentsViewState extends ConsumerState<_UpcomingAppointmentsView> {
  List<AppointmentModel> _appointments = [];
  List<AppointmentModel> _filteredAppointments = [];
  bool _isLoading = true;
  DateTime _selectedDate = DateTime.now();
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _searchController.addListener(_filterAppointments);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterAppointments);
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = FirebaseService();
      _appointments = await firebaseService.getUpcomingAppointments(widget.doctorId, true);
      _filterAppointments();
    } catch (e) {
      debugPrint('Error loading appointments: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _filterAppointments() {
    if (_searchController.text.isEmpty) {
      // Filter by selected date only
      _filteredAppointments = _appointments.where((appointment) {
        final appointmentDate = appointment.date.toDate();
        return appointmentDate.year == _selectedDate.year && 
               appointmentDate.month == _selectedDate.month && 
               appointmentDate.day == _selectedDate.day;
      }).toList();
    } else {
      // Filter by search text and selected date
      final searchText = _searchController.text.toLowerCase();
      _filteredAppointments = _appointments.where((appointment) {
        final appointmentDate = appointment.date.toDate();
        final matchesDate = appointmentDate.year == _selectedDate.year && 
                           appointmentDate.month == _selectedDate.month && 
                           appointmentDate.day == _selectedDate.day;
        
        final patientName = appointment.patientDetails?['name']?.toString().toLowerCase() ?? '';
        final matchesSearch = patientName.contains(searchText);
        
        return matchesDate && matchesSearch;
      }).toList();
    }
    
    // Sort by time
    _filteredAppointments.sort((a, b) {
      final timeA = _parseTime(a.time);
      final timeB = _parseTime(b.time);
      return timeA.compareTo(timeB);
    });
    
    setState(() {});
  }
  
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
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.surfaceDark,
                      width: 1,
                    ),
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search patients',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              GestureDetector(
                onTap: () async {
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime.now().subtract(const Duration(days: 365)),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  
                  if (pickedDate != null && pickedDate != _selectedDate) {
                    setState(() {
                      _selectedDate = pickedDate;
                    });
                    _filterAppointments();
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.surfaceDark,
                      width: 1,
                    ),
                  ),
                  child: const Icon(
                    Icons.calendar_today,
                    color: AppColors.textSecondary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredAppointments.length} appointment${_filteredAppointments.length != 1 ? 's' : ''}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAppointments.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAppointments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildAppointmentCard(_filteredAppointments[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.event_busy,
            size: 72,
            color: AppColors.surfaceDark,
          ),
          const SizedBox(height: 16),
          Text(
            'No Appointments',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'There are no appointments scheduled for this date',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Navigate to create appointment
            },
            icon: const Icon(Icons.add),
            label: const Text('New Appointment'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            Routes.patientDetail.replaceAll(':id', appointment.patientId),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        appointment.patientDetails?['name']?.toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase() ?? 'P',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientDetails?['name'] ?? 'Patient',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${appointment.patientDetails?['age'] ?? 'N/A'} years, ${appointment.patientDetails?['gender'] ?? 'N/A'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAppointmentDetail(
                    icon: Icons.access_time,
                    title: 'Time',
                    value: appointment.time,
                  ),
                  const SizedBox(width: 24),
                  _buildAppointmentDetail(
                    icon: Icons.description_outlined,
                    title: 'Reason',
                    value: appointment.patientDetails?['reason'] ?? 'Consultation',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  OutlinedButton(
                    onPressed: () {
                      // Cancel appointment
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.error,
                      side: BorderSide(color: AppColors.error.withOpacity(0.5)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    ),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton.icon(
                    onPressed: () {
                      // Start new chat with this patient
                    },
                    icon: Icon(
                      Icons.chat_outlined,
                    ),
                    label: Text(
                      'Message',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentDetail({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Past Appointments View
class _PastAppointmentsView extends ConsumerStatefulWidget {
  final String doctorId;

  const _PastAppointmentsView({required this.doctorId});

  @override
  ConsumerState<_PastAppointmentsView> createState() => _PastAppointmentsViewState();
}

class _PastAppointmentsViewState extends ConsumerState<_PastAppointmentsView> {
  List<AppointmentModel> _appointments = [];
  List<AppointmentModel> _filteredAppointments = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _searchController.addListener(_filterAppointments);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterAppointments);
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = FirebaseService();
      _appointments = await firebaseService.getPastAppointments(widget.doctorId, true);
      _filterAppointments();
    } catch (e) {
      debugPrint('Error loading past appointments: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _filterAppointments() {
    if (_searchController.text.isEmpty) {
      _filteredAppointments = List.from(_appointments);
    } else {
      final searchText = _searchController.text.toLowerCase();
      _filteredAppointments = _appointments.where((appointment) {
        final patientName = appointment.patientDetails?['name']?.toString().toLowerCase() ?? '';
        return patientName.contains(searchText);
      }).toList();
    }
    
    // Sort by date, most recent first
    _filteredAppointments.sort((a, b) => b.date.compareTo(a.date));
    
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.surfaceDark,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search past patients',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                Icons.history,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Past Appointments',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredAppointments.length} appointment${_filteredAppointments.length != 1 ? 's' : ''}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAppointments.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAppointments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildPastAppointmentCard(_filteredAppointments[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 72,
            color: AppColors.surfaceDark,
          ),
          const SizedBox(height: 16),
          Text(
            'No Past Appointments',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no past appointments',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPastAppointmentCard(AppointmentModel appointment) {
    final formattedDate = DateFormat('MMM d, yyyy').format(appointment.date.toDate());
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            Routes.patientDetail.replaceAll(':id', appointment.patientId),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.secondaryLight.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        appointment.patientDetails?['name']?.toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase() ?? 'P',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.secondary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientDetails?['name'] ?? 'Patient',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${appointment.patientDetails?['age'] ?? 'N/A'} years, ${appointment.patientDetails?['gender'] ?? 'N/A'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceMedium,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_circle_outline,
                          size: 16,
                          color: AppColors.success,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Completed',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.success,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAppointmentDetail(
                    icon: Icons.calendar_today,
                    title: 'Date',
                    value: formattedDate,
                  ),
                  const SizedBox(width: 24),
                  _buildAppointmentDetail(
                    icon: Icons.access_time,
                    title: 'Time',
                    value: appointment.time,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAppointmentDetail(
                    icon: appointment.type == AppointmentType.video
                        ? Icons.videocam
                        : Icons.medical_services_outlined,
                    title: 'Type',
                    value: appointment.type == AppointmentType.video
                        ? 'Video Consultation'
                        : 'In-person Visit',
                  ),
                  const SizedBox(width: 24),
                  _buildAppointmentDetail(
                    icon: Icons.description_outlined,
                    title: 'Reason',
                    value: appointment.patientDetails?['reason'] ?? 'Consultation',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // Show medical records
                    },
                    icon: const Icon(Icons.medical_information),
                    label: const Text('Medical Records'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {
                      // Start new chat with this patient
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Message Patient'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentDetail({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Cancelled Appointments View
class _CancelledAppointmentsView extends ConsumerStatefulWidget {
  final String doctorId;

  const _CancelledAppointmentsView({required this.doctorId});

  @override
  ConsumerState<_CancelledAppointmentsView> createState() => _CancelledAppointmentsViewState();
}

class _CancelledAppointmentsViewState extends ConsumerState<_CancelledAppointmentsView> {
  List<AppointmentModel> _appointments = [];
  List<AppointmentModel> _filteredAppointments = [];
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _loadAppointments();
    _searchController.addListener(_filterAppointments);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterAppointments);
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadAppointments() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = FirebaseService();
      _appointments = await firebaseService.getCancelledAppointments(widget.doctorId, true);
      _filterAppointments();
    } catch (e) {
      debugPrint('Error loading cancelled appointments: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _filterAppointments() {
    if (_searchController.text.isEmpty) {
      _filteredAppointments = List.from(_appointments);
    } else {
      final searchText = _searchController.text.toLowerCase();
      _filteredAppointments = _appointments.where((appointment) {
        final patientName = appointment.patientDetails?['name']?.toString().toLowerCase() ?? '';
        return patientName.contains(searchText);
      }).toList();
    }
    
    // Sort by date, most recent first
    _filteredAppointments.sort((a, b) => b.date.compareTo(a.date));
    
    setState(() {});
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.surfaceDark,
                width: 1,
              ),
            ),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search cancelled appointments',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                hintStyle: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textTertiary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Icon(
                Icons.cancel_outlined,
                size: 18,
                color: AppColors.error,
              ),
              const SizedBox(width: 8),
              Text(
                'Cancelled Appointments',
                style: AppTypography.titleMedium.copyWith(
                  color: AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${_filteredAppointments.length} appointment${_filteredAppointments.length != 1 ? 's' : ''}',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        const Divider(height: 1),
        const SizedBox(height: 8),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAppointments.isEmpty
                  ? _buildEmptyState()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAppointments.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        return _buildCancelledAppointmentCard(_filteredAppointments[index]);
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.cancel_outlined,
            size: 72,
            color: AppColors.surfaceDark,
          ),
          const SizedBox(height: 16),
          Text(
            'No Cancelled Appointments',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no cancelled appointments',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildCancelledAppointmentCard(AppointmentModel appointment) {
    final formattedDate = DateFormat('MMM d, yyyy').format(appointment.date.toDate());
    
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            Routes.patientDetail.replaceAll(':id', appointment.patientId),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        appointment.patientDetails?['name']?.toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase() ?? 'P',
                        style: AppTypography.titleLarge.copyWith(
                          color: AppColors.error,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appointment.patientDetails?['name'] ?? 'Patient',
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '${appointment.patientDetails?['age'] ?? 'N/A'} years, ${appointment.patientDetails?['gender'] ?? 'N/A'}',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.error.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.cancel_outlined,
                          size: 16,
                          color: AppColors.error,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Cancelled',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  _buildAppointmentDetail(
                    icon: Icons.calendar_today,
                    title: 'Original Date',
                    value: formattedDate,
                  ),
                  const SizedBox(width: 24),
                  _buildAppointmentDetail(
                    icon: Icons.access_time,
                    title: 'Time',
                    value: appointment.time,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildAppointmentDetail(
                    icon: appointment.type == AppointmentType.video
                        ? Icons.videocam
                        : Icons.medical_services_outlined,
                    title: 'Type',
                    value: appointment.type == AppointmentType.video
                        ? 'Video Consultation'
                        : 'In-person Visit',
                  ),
                  const SizedBox(width: 24),
                  _buildAppointmentDetail(
                    icon: Icons.description_outlined,
                    title: 'Reason',
                    value: appointment.patientDetails?['reason'] ?? 'Consultation',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  ElevatedButton(
                    onPressed: () {
                      // Reschedule appointment
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    child: const Text('Reschedule'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppointmentDetail({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 18,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Doctor Messages Tab
class DoctorMessagesTab extends ConsumerStatefulWidget {
  final UserModel doctor;

  const DoctorMessagesTab({super.key, required this.doctor});

  @override
  ConsumerState<DoctorMessagesTab> createState() => _DoctorMessagesTabState();
}

class _DoctorMessagesTabState extends ConsumerState<DoctorMessagesTab> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _chats = [];
  
  @override
  void initState() {
    super.initState();
    _loadChats();
  }
  
  Future<void> _loadChats() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = FirebaseService();
      final chats = await firebaseService.getChatsForUser(widget.doctor.id);
      
      _chats = [];
      for (final chat in chats) {
        // Get other user information
        final otherUserId = chat.participants.firstWhere((id) => id != widget.doctor.id);
        final otherUser = await firebaseService.getUserById(otherUserId);
        
        if (otherUser != null) {
          _chats.add({
            'chatId': chat.id,
            'user': otherUser,
            'lastMessage': chat.lastMessage,
            'lastMessageTime': chat.lastMessageTime,
            'unreadCount': chat.unreadCount,
          });
        }
      }
      
      // Sort by last message time
      _chats.sort((a, b) {
        final aTime = a['lastMessageTime'] as Timestamp;
        final bTime = b['lastMessageTime'] as Timestamp;
        return bTime.compareTo(aTime);
      });
    } catch (e) {
      debugPrint('Error loading chats: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    return _chats.isEmpty
        ? _buildEmptyState()
        : ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: _chats.length,
            separatorBuilder: (context, index) => const Divider(),
            itemBuilder: (context, index) {
              final chat = _chats[index];
              final user = chat['user'] as UserModel;
              final lastMessage = chat['lastMessage'] as String;
              final lastMessageTime = chat['lastMessageTime'] as Timestamp;
              final unreadCount = chat['unreadCount'] as int;
              
              return ListTile(
                onTap: () {
                  Navigator.of(context).pushNamed(
                    Routes.chat.replaceAll(':id', chat['chatId']),
                  );
                },
                contentPadding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                leading: CircleAvatar(
                  radius: 28,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    user.name.split(' ').map((e) => e[0]).join().toUpperCase(),
                    style: AppTypography.titleMedium.copyWith(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                title: Row(
                  children: [
                    Expanded(
                      child: Text(
                        user.name,
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(
                      _formatChatTime(lastMessageTime.toDate()),
                      style: AppTypography.bodySmall.copyWith(
                        color: AppColors.textTertiary,
                      ),
                    ),
                  ],
                ),
                subtitle: Row(
                  children: [
                    Expanded(
                      child: Text(
                        lastMessage,
                        style: AppTypography.bodyMedium.copyWith(
                          color: unreadCount > 0 
                              ? AppColors.textPrimary 
                              : AppColors.textSecondary,
                          fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          unreadCount.toString(),
                          style: AppTypography.bodySmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          );
  }
  
  String _formatChatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(time);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m';
    } else {
      return 'Just now';
    }
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 72,
            color: AppColors.surfaceDark,
          ),
          const SizedBox(height: 16),
          Text(
            'No Messages',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You have no messages',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // Start new chat
            },
            icon: const Icon(Icons.add),
            label: const Text('New Chat'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Doctor Profile Tab
class DoctorProfileTab extends ConsumerWidget {
  final UserModel doctor;

  const DoctorProfileTab({super.key, required this.doctor});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildProfileHeader(),
          const SizedBox(height: 24),
          _buildProfileInfo(),
          const SizedBox(height: 24),
          _buildSettingsSection(context),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Text(
              doctor.name.split(' ').map((e) => e[0]).join().toUpperCase(),
              style: AppTypography.displaySmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Dr. ${doctor.name}',
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            doctor.doctorInfo?['specialty'] ?? 'Doctor',
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('Experience', '${doctor.doctorInfo?['yearsExperience'] ?? 0} yrs'),
              const SizedBox(width: 24),
              _buildStat('Patients', '120+'),
              const SizedBox(width: 24),
              _buildStat('Rating', '4.9'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String title, String value) {
    return Column(
      children: [
        Text(
          value,
          style: AppTypography.headlineSmall.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: AppTypography.bodySmall.copyWith(
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileInfo() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional Information',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoItem(
            icon: Icons.school,
            title: 'Education',
            value: doctor.doctorInfo?['education'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.location_on,
            title: 'Clinic/Hospital',
            value: doctor.doctorInfo?['hospitalAffiliation'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.badge,
            title: 'License',
            value: doctor.doctorInfo?['licenseNumber'] ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.phone,
            title: 'Contact',
            value: doctor.phoneNumber ?? 'Not specified',
          ),
          _buildInfoItem(
            icon: Icons.email,
            title: 'Email',
            value: doctor.email,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Edit profile
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              minimumSize: const Size(double.infinity, 48),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Edit Profile',
              style: AppTypography.buttonMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textSecondary,
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Settings',
            style: AppTypography.titleLarge.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsItem(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            onTap: () {
              // Navigate to notifications settings
            },
          ),
          _buildSettingsItem(
            icon: Icons.lock_outline,
            title: 'Privacy & Security',
            onTap: () {
              // Navigate to privacy settings
            },
          ),
          _buildSettingsItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              // Navigate to help & support
            },
          ),
          _buildSettingsItem(
            icon: Icons.info_outline,
            title: 'About',
            onTap: () {
              // Navigate to about page
            },
          ),
          _buildSettingsItem(
            icon: Icons.logout,
            title: 'Sign Out',
            textColor: AppColors.error,
            onTap: () async {
              // Sign out
              await AuthService().signOut();
              if (context.mounted) {
                Navigator.of(context).pushReplacementNamed(Routes.login);
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
    Color? textColor,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(
              icon,
              color: textColor ?? AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                color: textColor ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            if (title != 'Sign Out')
              const Icon(
                Icons.chevron_right,
                color: AppColors.textTertiary,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
} 