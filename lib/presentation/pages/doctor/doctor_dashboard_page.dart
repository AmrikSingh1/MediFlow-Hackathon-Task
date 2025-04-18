import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:medi_connect/presentation/pages/doctor/doctor_schedule_page.dart';
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
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: AppColors.error,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'User Not Found',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: 200,
            height: 50,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  ref.invalidate(currentDoctorProvider);
                  _loadDoctorData();
                },
                borderRadius: BorderRadius.circular(16),
                child: Center(
                  child: Text(
                    'Retry',
                    style: AppTypography.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
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
        backgroundColor: const Color(0xFFF9FAFC),
        body: SafeArea(
          bottom: false,
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _doctor == null
                  ? _buildNoUserView(context)
                  : !_isProfileComplete
                      ? _buildIncompleteProfileView(context)
                      : _tabs[_currentIndex],
        ),
        bottomNavigationBar: _doctor == null || !_isProfileComplete
            ? null
            : Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 16,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12, bottom: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildNavItem(0, Icons.home_rounded, 'Home'),
                        _buildNavItem(1, Icons.calendar_month_rounded, 'Appointments'),
                        _buildNavItem(2, Icons.chat_rounded, 'Messages'),
                        _buildNavItem(3, Icons.person_rounded, 'Profile'),
                      ],
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () => _switchTab(index),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
              size: 24,
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTypography.bodySmall.copyWith(
                color: isSelected ? AppColors.primary : AppColors.textTertiary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
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
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.account_circle_outlined,
                size: 64,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
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
            Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      Routes.doctorProfile,
                    ).then((_) {
                      // Force refresh when returning from profile page
                      ref.invalidate(currentDoctorProvider);
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Center(
                    child: Text(
                      'Complete Profile',
                      style: AppTypography.bodyLarge.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
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
  // Removed patient requests
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
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading dashboard data: $e');
      setState(() {
        _isLoading = false;
      });
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
              
              // Analytics section instead of Patient Requests
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Performance Analytics',
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildAnalyticsGrid(),
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
          colors: [Color(0xFF5386DF), Color(0xFF3A6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5386DF).withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            widget.doctor.profileImageUrl != null
              ? Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    image: DecorationImage(
                      image: NetworkImage(widget.doctor.profileImageUrl!),
                      fit: BoxFit.cover,
                    ),
                  ),
                )
              : Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 3),
                    color: Colors.white.withOpacity(0.2),
                  ),
                  child: Center(
                    child: Text(
                      _getInitials(widget.doctor.name.isNotEmpty ? widget.doctor.name : "Doctor"),
                      style: AppTypography.headlineSmall.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            const SizedBox(width: 20),
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
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _buildInfoChip(Icons.calendar_today, '${_todayAppointments.length} Today'),
                      const SizedBox(width: 12),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 6),
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
              
              return _buildAppointmentCard(appointment);
            },
          );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              size: 36,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 20),
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
  
  // Build appointment card for home tab
  Widget _buildAppointmentCard(AppointmentModel appointment) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            Routes.patientDetail.replaceAll(':id', appointment.patientId),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Time indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.primaryDark],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  appointment.time.split(' - ')[0],
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              
              Expanded(
                child: Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            appointment.type == AppointmentType.video ? 
                              const Color(0xFF5BBFB2) : const Color(0xFFFFA952),
                            appointment.type == AppointmentType.video ? 
                              const Color(0xFF3A8C83) : const Color(0xFFFF8A00),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: (appointment.type == AppointmentType.video ? 
                              const Color(0xFF5BBFB2) : const Color(0xFFFFA952)).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Icon(
                          appointment.type == AppointmentType.video ? 
                            Icons.videocam_rounded : Icons.medical_services_rounded,
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
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
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  '${appointment.patientDetails?['age'] ?? 'N/A'} years',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  appointment.patientDetails?['gender'] ?? 'N/A',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
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
            ],
          ),
        ),
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
    
    return Stack(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with search
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Messages",
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 56,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 8,
                          spreadRadius: 1,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: InputDecoration(
                        hintText: 'Search conversations',
                        hintStyle: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        prefixIcon: const Icon(
                          Icons.search_rounded,
                          color: AppColors.textTertiary,
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Chats
            Expanded(
              child: _chats.isEmpty
                  ? _buildEmptyState()
                  : RefreshIndicator(
                      onRefresh: _loadChats,
                      child: ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16).copyWith(bottom: 80), // Add padding at the bottom for floating button
                        itemCount: _chats.length,
                        itemBuilder: (context, index) {
                          final chat = _chats[index];
                          final user = chat['user'] as UserModel;
                          final lastMessage = chat['lastMessage'] as String;
                          final lastMessageTime = chat['lastMessageTime'] as Timestamp;
                          final unreadCount = chat['unreadCount'] as int;
                          
                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.03),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: InkWell(
                              onTap: () {
                                Navigator.of(context).pushNamed(
                                  Routes.chat.replaceAll(':id', chat['chatId']),
                                ).then((_) => _loadChats());
                              },
                              borderRadius: BorderRadius.circular(20),
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Row(
                                  children: [
                                    // Avatar
                                    Stack(
                                      children: [
                                        user.profileImageUrl != null
                                          ? Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                image: DecorationImage(
                                                  image: NetworkImage(user.profileImageUrl!),
                                                  fit: BoxFit.cover,
                                                ),
                                              ),
                                            )
                                          : Container(
                                              width: 60,
                                              height: 60,
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Color(0xFF90A0F8), Color(0xFF6C7FDF)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Center(
                                                child: Text(
                                                  user.name.split(' ').map((e) => e[0]).join().toUpperCase(),
                                                  style: AppTypography.titleMedium.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        if (unreadCount > 0)
                                          Positioned(
                                            right: 0,
                                            top: 0,
                                            child: Container(
                                              width: 22,
                                              height: 22,
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                shape: BoxShape.circle,
                                                border: Border.all(
                                                  color: Colors.white,
                                                  width: 2,
                                                ),
                                              ),
                                              child: Center(
                                                child: Text(
                                                  unreadCount.toString(),
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(width: 16),
                                    
                                    // Chat info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  user.role == UserRole.doctor 
                                                    ? 'Dr. ${user.name}' 
                                                    : user.name,
                                                  style: AppTypography.titleMedium.copyWith(
                                                    fontWeight: unreadCount > 0 
                                                      ? FontWeight.bold 
                                                      : FontWeight.w600,
                                                    color: unreadCount > 0 
                                                      ? AppColors.textPrimary 
                                                      : AppColors.textPrimary,
                                                  ),
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                              ),
                                              Text(
                                                _formatChatTime(lastMessageTime.toDate()),
                                                style: AppTypography.bodySmall.copyWith(
                                                  color: unreadCount > 0 
                                                    ? AppColors.primary
                                                    : AppColors.textTertiary,
                                                  fontWeight: unreadCount > 0 
                                                    ? FontWeight.w500 
                                                    : FontWeight.normal,
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            lastMessage,
                                            style: AppTypography.bodyMedium.copyWith(
                                              color: unreadCount > 0 
                                                ? AppColors.textPrimary 
                                                : AppColors.textSecondary,
                                              fontWeight: unreadCount > 0 
                                                ? FontWeight.w500 
                                                : FontWeight.normal,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
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
                      ),
                    ),
            ),
          ],
        ),
        
        // Only show this button if we have chats to avoid duplication with the empty state button
        if (_chats.isNotEmpty)
          Positioned(
            bottom: 16,
            left: 16,
            right: 16,
            child: Container(
              width: double.infinity,
              height: 56,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    // Navigate to start new chat page
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.add_circle_outline_rounded,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Start New Conversation',
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
    );
  }
  
  String _formatChatTime(DateTime time) {
    final now = DateTime.now();
    final difference = now.difference(time);
    
    if (difference.inDays > 7) {
      return DateFormat('MMM d').format(time);
    } else if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'No Messages Yet',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start conversations with your patients to provide ongoing care and support',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 32),
          Container(
            height: 56,
            width: 240,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.primaryDark],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  // Start new chat
                },
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_circle_outline_rounded,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Start New Conversation',
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
          colors: [Color(0xFF5386DF), Color(0xFF3A6BC0)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF5386DF).withOpacity(0.25),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Profile photo
          doctor.profileImageUrl != null
            ? Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                  image: DecorationImage(
                    image: NetworkImage(doctor.profileImageUrl!),
                    fit: BoxFit.cover,
                  ),
                ),
              )
            : Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 4),
                ),
                child: Center(
                  child: Text(
                    doctor.name.split(' ').map((e) => e[0]).join().toUpperCase(),
                    style: AppTypography.displaySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
          const SizedBox(height: 20),
          Text(
            'Dr. ${doctor.name}',
            style: AppTypography.headlineMedium.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            doctor.doctorInfo?['specialty'] ?? 'Doctor',
            style: AppTypography.titleMedium.copyWith(
              color: Colors.white.withOpacity(0.9),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildStat('Experience', '${doctor.doctorInfo?['yearsExperience'] ?? 0} yrs'),
              _buildStatDivider(),
              _buildStat('Patients', '120+'),
              _buildStatDivider(),
              _buildStat('Rating', '4.9'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatDivider() {
    return Container(
      height: 40,
      width: 1,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white.withOpacity(0.2),
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
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
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          _buildInfoRow(
            icon: Icons.school_rounded,
            title: 'Education',
            value: doctor.doctorInfo?['education'] ?? 'Not specified',
          ),
          const Divider(height: 32),
          _buildInfoRow(
            icon: Icons.location_on_rounded,
            title: 'Clinic/Hospital',
            value: doctor.doctorInfo?['hospitalAffiliation'] ?? 'Not specified',
          ),
          const Divider(height: 32),
          _buildInfoRow(
            icon: Icons.badge_rounded,
            title: 'License',
            value: doctor.doctorInfo?['licenseNumber'] ?? 'Not specified',
          ),
          const Divider(height: 32),
          _buildInfoRow(
            icon: Icons.phone_rounded,
            title: 'Contact',
            value: doctor.phoneNumber ?? 'Not specified',
          ),
          const Divider(height: 32),
          _buildInfoRow(
            icon: Icons.email_rounded,
            title: 'Email',
            value: doctor.email,
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    required String title,
    required String value,
    bool isLast = false,
  }) {
    return Padding(
      padding: isLast ? EdgeInsets.zero : const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 16),
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
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
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
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 12,
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
            icon: Icons.event_available,
            title: 'Manage Availability',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DoctorSchedulePage(),
                ),
              );
            },
          ),
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

// Doctor Appointments Tab
class DoctorAppointmentsTab extends ConsumerStatefulWidget {
  final UserModel doctor;

  const DoctorAppointmentsTab({super.key, required this.doctor});

  @override
  ConsumerState<DoctorAppointmentsTab> createState() => _DoctorAppointmentsTabState();
}

class _DoctorAppointmentsTabState extends ConsumerState<DoctorAppointmentsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['All', 'Upcoming', 'Past', 'Cancelled'];
  
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
        // Header with blue background
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF5386DF), Color(0xFF3A6BC0)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Appointment with current time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Appointments",
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      "${DateFormat('h:mm').format(DateTime.now())} ${DateFormat('a').format(DateTime.now()).toUpperCase()}",
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF5386DF),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              // Clean search bar
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search patients',
                    hintStyle: AppTypography.bodyMedium.copyWith(
                      color: AppColors.textTertiary,
                    ),
                    prefixIcon: const Icon(
                      Icons.search_rounded,
                      color: AppColors.textTertiary,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                  ),
                ),
              ),
              // Removed date selector
            ],
          ),
        ),
        
        // Tab selector
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(30),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: _tabs.map((title) => Tab(text: title)).toList(),
                labelColor: Colors.white,
                unselectedLabelColor: AppColors.textSecondary,
                indicator: BoxDecoration(
                  color: const Color(0xFF5386DF),
                  borderRadius: BorderRadius.circular(30),
                ),
                dividerHeight: 0,
                labelPadding: EdgeInsets.zero,
                padding: const EdgeInsets.all(4),
                labelStyle: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w500,
                ),
                indicatorSize: TabBarIndicatorSize.tab,
              ),
            ),
          ),
        ),
        
        // Content area
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              _UpcomingAppointmentsView(doctorId: widget.doctor.id),
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
                  height: 52,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.06),
                        blurRadius: 8,
                        spreadRadius: 1,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search patients',
                      hintStyle: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textTertiary,
                      ),
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textTertiary,
                      ),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Container(
                height: 52,
                width: 52,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.06),
                      blurRadius: 8,
                      spreadRadius: 1,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.calendar_today_rounded,
                    color: AppColors.primary,
                  ),
                  onPressed: () async {
                    final pickedDate = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime.now().subtract(const Duration(days: 30)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                      builder: (context, child) {
                        return Theme(
                          data: Theme.of(context).copyWith(
                            colorScheme: const ColorScheme.light(
                              primary: AppColors.primary,
                              onPrimary: Colors.white,
                              surface: Colors.white,
                              onSurface: AppColors.textPrimary,
                            ),
                          ),
                          child: child!,
                        );
                      },
                    );
                    
                    if (pickedDate != null) {
                      setState(() {
                        _selectedDate = pickedDate;
                      });
                      _filterAppointments();
                    }
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Selected date indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.3),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.event,
                      size: 18,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      DateFormat('MMM d, yyyy').format(_selectedDate),
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_filteredAppointments.length} appointments',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Appointments list
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _filteredAppointments.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              color: AppColors.surfaceLight,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.event_busy,
                              size: 36,
                              color: AppColors.textTertiary,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            'No appointments found',
                            style: AppTypography.titleLarge.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'There are no appointments for the selected date',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: () {
                              setState(() {
                                _selectedDate = DateTime.now();
                              });
                              _filterAppointments();
                            },
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Reset Date'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredAppointments.length,
                      itemBuilder: (context, index) {
                        final appointment = _filteredAppointments[index];
                        return _buildAppointmentCard(appointment);
                      },
                    ),
        ),
      ],
    );
  }
  
  Widget _buildAppointmentCard(AppointmentModel appointment) {
    // Parse time for better display
    final timeRange = appointment.time;
    final startTime = timeRange.split(' - ')[0];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          Navigator.of(context).pushNamed(
            Routes.appointmentDetails.replaceAll(':id', appointment.id),
          );
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Time column
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF4275BD)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.25),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Text(
                      startTime,
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              
              // Content area
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        // Patient avatar
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF90A0F8), Color(0xFF6C7FDF)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6C7FDF).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Center(
                            child: Text(
                              appointment.patientDetails?['name']?.toString().split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase() ?? 'P',
                              style: AppTypography.titleMedium.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Patient info
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
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      '${appointment.patientDetails?['age'] ?? 'N/A'} years',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.surfaceLight,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      appointment.patientDetails?['gender'] ?? 'N/A',
                                      style: AppTypography.bodySmall.copyWith(
                                        color: AppColors.textSecondary,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1, thickness: 1, color: Color(0xFFF0F2F5)),
                    const SizedBox(height: 16),
                    
                    // Appointment type and actions
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: appointment.type == AppointmentType.video
                                ? const Color(0xFF5BBFB2).withOpacity(0.1)
                                : const Color(0xFFFFA952).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: appointment.type == AppointmentType.video
                                  ? const Color(0xFF5BBFB2).withOpacity(0.3)
                                  : const Color(0xFFFFA952).withOpacity(0.3),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                appointment.type == AppointmentType.video
                                    ? Icons.videocam_rounded
                                    : Icons.medical_services_rounded,
                                size: 16,
                                color: appointment.type == AppointmentType.video
                                    ? const Color(0xFF5BBFB2)
                                    : const Color(0xFFFFA952),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                appointment.type == AppointmentType.video ? 'Video Call' : 'In-person',
                                style: AppTypography.bodySmall.copyWith(
                                  color: appointment.type == AppointmentType.video
                                      ? const Color(0xFF5BBFB2)
                                      : const Color(0xFFFFA952),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          onPressed: () {
                            // Message patient
                            debugPrint('Message patient: ${appointment.patientId}');
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.primary.withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.message_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                          ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
                        ),
                        const SizedBox(width: 12),
                        IconButton(
                          onPressed: () {
                            // Call patient
                            debugPrint('Call patient: ${appointment.patientId}');
                          },
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF5BBFB2).withOpacity(0.1),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF5BBFB2).withOpacity(0.3),
                                width: 1,
                              ),
                            ),
                            child: const Icon(
                              Icons.call_rounded,
                              size: 16,
                              color: Color(0xFF5BBFB2),
                            ),
                          ),
                          constraints: const BoxConstraints(),
                          padding: EdgeInsets.zero,
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
  }
}