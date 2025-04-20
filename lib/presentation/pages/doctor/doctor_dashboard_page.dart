import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/models/chat_model.dart';
import 'package:medi_connect/core/models/report_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:medi_connect/presentation/pages/doctor/doctor_schedule_page.dart';
import 'package:medi_connect/presentation/pages/doctor/referral_code_page.dart';
import 'package:medi_connect/presentation/pages/doctor/referred_patients_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/services.dart';

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

// Add at the top near other providers
final selectedTabProvider = StateProvider<int>((ref) => 0);

class DoctorDashboardPage extends ConsumerStatefulWidget {
  final int initialTab;
  
  const DoctorDashboardPage({
    super.key,
    this.initialTab = 0,
  });

  @override
  ConsumerState<DoctorDashboardPage> createState() => _DoctorDashboardPageState();
}

class _DoctorDashboardPageState extends ConsumerState<DoctorDashboardPage> with SingleTickerProviderStateMixin {
  UserModel? _doctor;
  bool _isLoading = true;
  bool _isProfileComplete = false;
  int _currentIndex = 0;
  late List<Widget> _tabs;
  List<Map<String, dynamic>> _analytics = [];
  
  // Add animation controller for bottom nav bar
  late AnimationController _animationController;
  
  // Controller for bottom navigation
  final _navigatorKey = GlobalKey<ScaffoldState>();
  
  @override
  void initState() {
    super.initState();
    // Initialize animation controller
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    _tabs = [
      const Center(child: CircularProgressIndicator()),
      const Center(child: CircularProgressIndicator()),
      const Center(child: CircularProgressIndicator()),
      const Center(child: CircularProgressIndicator()),
      const Center(child: CircularProgressIndicator()),
    ];
    
    // Initialize current index from widget if provided
    _currentIndex = widget.initialTab;
    
    // Listen to tab change requests
    ref.listenManual(selectedTabProvider, (previous, next) {
      if (next != _currentIndex) {
        setState(() {
          _currentIndex = next;
        });
      }
    });
    
    _loadDashboardData();
    _initializeAnalytics();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  // Add this method
  Future<void> _loadDashboardData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await _loadDoctorData();
      // Additional dashboard data loading can be added here
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
  
  // Initialize analytics with default values for new doctors
  void _initializeAnalytics() {
    _analytics = [
      {
        'title': 'Total Patients',
        'value': 0,
        'icon': Icons.people_alt_rounded,
        'color': const Color(0xFF5BBFB2),
        'isIncrease': true,
        'change': '0%',
      },
      {
        'title': 'Appointments',
        'value': 0,
        'unit': '',
        'icon': Icons.calendar_today_rounded,
        'color': const Color(0xFF6C7FDF),
        'isIncrease': true,
        'change': '0%',
      },
      {
        'title': 'Completion Rate',
        'value': '0',
        'unit': '%',
        'icon': Icons.check_circle_outline_rounded,
        'color': const Color(0xFFFFA952),
        'isIncrease': true,
        'change': '0%',
      },
      {
        'title': 'Average Rating',
        'value': '0.0',
        'unit': '',
        'icon': Icons.star_rounded,
        'color': const Color(0xFFFF7272),
        'isIncrease': true,
        'change': '0%',
      },
    ];
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
            DoctorReportsTab(doctor: doctor),
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
            : _buildCustomBottomNavigationBar(),
      ),
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard),
            _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month),
            _buildNavItem(2, Icons.chat_outlined, Icons.chat),
            _buildNavItem(3, Icons.description_outlined, Icons.description),
            _buildNavItem(4, Icons.person_outline, Icons.person),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () {
        setState(() {
          _currentIndex = index;
          _animationController.reset();
          _animationController.forward();
          // Update the tab content
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
              _tabs[3] = DoctorReportsTab(doctor: _doctor!);
              break;
            case 4:
              _tabs[4] = DoctorProfileTab(doctor: _doctor!);
              break;
          }
        });
      },
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
              size: 24,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      width: 16 + 8 * _animationController.value,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(1.5),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
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
        return 'Reports';
      case 4:
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
        return DoctorReportsTab(doctor: doctor);
      case 4:
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
      
      // Calculate analytics metrics or use default values for new doctors
      final totalAppointments = appointments.length + pastAppointments.length + cancelledAppointments.length;
      final completedAppointments = pastAppointments.length;
      final completionRate = totalAppointments > 0 ? (completedAppointments / totalAppointments * 100).toStringAsFixed(0) : '0';
      
      // Set analytics data
      _analytics = [
        {
          'title': 'Total Patients',
          'value': _calculateUniquePatients(appointments, pastAppointments, cancelledAppointments),
          'icon': Icons.people_alt_rounded,
          'color': const Color(0xFF5BBFB2),
          'isIncrease': true,
          'change': '0%',
        },
        {
          'title': 'Appointments',
          'value': totalAppointments,
          'unit': '',
          'icon': Icons.calendar_today_rounded,
          'color': const Color(0xFF6C7FDF),
          'isIncrease': true,
          'change': '0%',
        },
        {
          'title': 'Completion Rate',
          'value': completionRate,
          'unit': '%',
          'icon': Icons.check_circle_outline_rounded,
          'color': const Color(0xFFFFA952),
          'isIncrease': true,
          'change': '0%',
        },
        {
          'title': 'Average Rating',
          'value': '0.0',
          'unit': '',
          'icon': Icons.star_rounded,
          'color': const Color(0xFFFF7272),
          'isIncrease': true,
          'change': '0%',
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
  
  // Helper method to calculate unique patients
  int _calculateUniquePatients(List<AppointmentModel> upcoming, List<AppointmentModel> past, List<AppointmentModel> cancelled) {
    // Combine all appointments
    final allAppointments = [...upcoming, ...past, ...cancelled];
    
    // Extract unique patient IDs
    final patientIds = <String>{};
    for (final appointment in allAppointments) {
      if (appointment.patientId.isNotEmpty) {
        patientIds.add(appointment.patientId);
      }
    }
    
    return patientIds.length;
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
                      // Navigate directly to the appointments tab
                      Navigator.of(context).pushReplacement(
                        MaterialPageRoute(
                          builder: (context) => const DoctorDashboardPage(initialTab: 1),
                        ),
                      );
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
    // Create default analytics data for new doctors
    if (_analytics.isEmpty) {
      _analytics = [
        {
          'title': 'Total Patients',
          'value': 0,
          'icon': Icons.people_alt_rounded,
          'color': const Color(0xFF5BBFB2),
          'isIncrease': true,
          'change': '0%',
        },
        {
          'title': 'Appointments',
          'value': 0,
          'unit': '',
          'icon': Icons.calendar_today_rounded,
          'color': const Color(0xFF6C7FDF),
          'isIncrease': true,
          'change': '0%',
        },
        {
          'title': 'Completion Rate',
          'value': '0',
          'unit': '%',
          'icon': Icons.check_circle_outline_rounded,
          'color': const Color(0xFFFFA952),
          'isIncrease': true,
          'change': '0%',
        },
        {
          'title': 'Average Rating',
          'value': '0.0',
          'unit': '',
          'icon': Icons.star_rounded,
          'color': const Color(0xFFFF7272),
          'isIncrease': true,
          'change': '0%',
        },
      ];
    }

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
    // Parse time for better display
    final timeRange = appointment.time;
    final startTime = timeRange.split(' - ')[0];
    final appointmentDate = appointment.date.toDate();
    final isToday = DateUtils.isSameDay(appointmentDate, DateTime.now());
    final dateStr = isToday ? 'Today' : DateFormat('MMM d, yyyy').format(appointmentDate);
    
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
              // Date and time indicator
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Date indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.error.withOpacity(0.9) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dateStr,
                      style: AppTypography.bodySmall.copyWith(
                        color: isToday ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                ],
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
class DoctorProfileTab extends StatelessWidget {
  final UserModel doctor;
  
  const DoctorProfileTab({
    Key? key,
    required this.doctor,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildProfileHeader(),
            const SizedBox(height: 20),
            _buildProfileInfo(),
            const SizedBox(height: 20),
            _buildSettingsSection(context),
          ],
        ),
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
              _buildStat('Patients', '${doctor.doctorInfo?['appointmentCount'] ?? 0}'),
              _buildStatDivider(),
              _buildStat('Rating', '${(doctor.doctorInfo?['rating'] ?? 0.0).toStringAsFixed(1)}'),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
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
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingsItem(
            icon: Icons.qr_code,
            title: 'Referral Codes',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => DoctorReferralCodePage(doctor: doctor),
                ),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.people,
            title: 'Referred Patients',
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => ReferredPatientsPage(doctor: doctor),
                ),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.schedule,
            title: 'Schedule Management',
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
              // TODO: Implement notification settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.lock_outline,
            title: 'Privacy & Security',
            onTap: () {
              // TODO: Implement privacy settings
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
          ),
          _buildSettingsItem(
            icon: Icons.help_outline,
            title: 'Help & Support',
            onTap: () {
              // TODO: Implement help & support
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Coming soon!')),
              );
            },
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),
          _buildSettingsItem(
            icon: Icons.logout,
            title: 'Sign Out',
            onTap: () {
              _showLogoutConfirmation(context);
            },
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        contentPadding: EdgeInsets.zero,
        content: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header with icon
              Container(
                padding: const EdgeInsets.only(top: 24, bottom: 16),
                child: Column(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.logout_rounded,
                        color: Colors.red.shade400,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Logout',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                        color: Colors.black.withOpacity(0.8),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              // Message
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: Text(
                  'Are you sure you want to logout from your account?',
                  textAlign: TextAlign.center,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              // Buttons
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: Row(
                  children: [
                    // Cancel button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.of(context).pop();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey.shade100,
                          foregroundColor: Colors.black.withOpacity(0.7),
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Logout button
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () async {
                          await AuthService().signOut();
                          if (context.mounted) {
                            Navigator.of(context).pushReplacementNamed(Routes.login);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red.shade400,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Logout',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
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

  Widget _buildSettingsItem({
    required IconData icon,
    required String title,
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
              color: AppColors.textSecondary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              title,
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
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
      // Show all appointments
      _filteredAppointments = List.from(_appointments);
    } else {
      // Filter by search text only
      final searchText = _searchController.text.toLowerCase();
      _filteredAppointments = _appointments.where((appointment) {
        final patientName = appointment.patientDetails?['name']?.toString().toLowerCase() ?? '';
        return patientName.contains(searchText);
      }).toList();
    }
    
    // Sort by date first, then by time
    _filteredAppointments.sort((a, b) {
      final dateA = a.date.toDate();
      final dateB = b.date.toDate();
      
      // First compare dates
      final dateComparison = dateA.compareTo(dateB);
      if (dateComparison != 0) return dateComparison;
      
      // If same date, compare times
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
            ],
          ),
        ),
        const SizedBox(height: 16),
        
        // Appointment count indicator
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Container(
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
                            'You have no upcoming appointments',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          ElevatedButton.icon(
                            onPressed: _loadAppointments,
                            icon: const Icon(Icons.refresh_rounded),
                            label: const Text('Refresh'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              minimumSize: const Size(120, 45),
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
    final appointmentDate = appointment.date.toDate();
    final isToday = DateUtils.isSameDay(appointmentDate, DateTime.now());
    final dateStr = isToday ? 'Today' : DateFormat('MMM d, yyyy').format(appointmentDate);
    
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
              // Time and date column
              Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  // Date indicator
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isToday ? AppColors.error.withOpacity(0.9) : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      dateStr,
                      style: AppTypography.bodySmall.copyWith(
                        color: isToday ? Colors.white : AppColors.textSecondary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  // Time indicator
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

// Doctor Reports Tab
class DoctorReportsTab extends ConsumerStatefulWidget {
  final UserModel doctor;

  const DoctorReportsTab({super.key, required this.doctor});

  @override
  ConsumerState<DoctorReportsTab> createState() => _DoctorReportsTabState();
}

class _DoctorReportsTabState extends ConsumerState<DoctorReportsTab> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<ReportModel> _draftReports = [];
  List<ReportModel> _reviewedReports = [];
  List<ReportModel> _finalizedReports = [];
  final TextEditingController _searchController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadReports();
    _searchController.addListener(_filterReports);
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _searchController.removeListener(_filterReports);
    _searchController.dispose();
    super.dispose();
  }
  
  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = FirebaseService();
      
      debugPrint('DoctorReportsTab: Loading reports for doctor ${widget.doctor.id}');
      debugPrint('DoctorReportsTab: Doctor name: ${widget.doctor.name}');
      debugPrint('DoctorReportsTab: Doctor role: ${widget.doctor.role}');
      
      // Load all reports by status
      _draftReports = await firebaseService.getReportsByStatus(widget.doctor.id, ReportStatus.draft);
      _reviewedReports = await firebaseService.getReportsByStatus(widget.doctor.id, ReportStatus.reviewed);
      _finalizedReports = await firebaseService.getReportsByStatus(widget.doctor.id, ReportStatus.finalized);
      
      debugPrint('DoctorReportsTab: Loaded ${_draftReports.length} draft reports, '
          '${_reviewedReports.length} reviewed reports, '
          '${_finalizedReports.length} finalized reports');
      
      // Check if all draft reports have proper fields
      if (_draftReports.isNotEmpty) {
        debugPrint('DoctorReportsTab: First draft report details:');
        debugPrint('  - ID: ${_draftReports[0].id}');
        debugPrint('  - Patient: ${_draftReports[0].patientName}');
        debugPrint('  - Status: ${_draftReports[0].status}');
        debugPrint('  - Content length: ${_draftReports[0].content.length} characters');
        debugPrint('  - Doctor ID: ${_draftReports[0].doctorId}');
      }
      
      // If no draft reports, try to get all reports to check if there's an issue
      if (_draftReports.isEmpty) {
        debugPrint('DoctorReportsTab: No draft reports found, checking for all reports');
        final allReports = await firebaseService.getReportsForDoctor(widget.doctor.id);
        debugPrint('DoctorReportsTab: Found ${allReports.length} total reports');
        
        if (allReports.isNotEmpty) {
          debugPrint('DoctorReportsTab: First report details:');
          debugPrint('  - ID: ${allReports[0].id}');
          debugPrint('  - Patient: ${allReports[0].patientName}');
          debugPrint('  - Status: ${allReports[0].status}');
          debugPrint('  - Doctor ID: ${allReports[0].doctorId}');
        } else {
          // Check if the doctor's ID is properly stored in the user collection
          final currentDoctor = await firebaseService.getUserById(widget.doctor.id);
          debugPrint('DoctorReportsTab: Verified doctor exists: ${currentDoctor != null}');
          
          // Check if there are any reports at all in the collection
          final allReportsSnapshot = await FirebaseFirestore.instance.collection('reports').get();
          debugPrint('DoctorReportsTab: Total reports in collection: ${allReportsSnapshot.docs.length}');
          
          if (allReportsSnapshot.docs.isNotEmpty) {
            final example = allReportsSnapshot.docs.first.data();
            debugPrint('DoctorReportsTab: Example report doctorId: ${example['doctorId']}');
          }
        }
      }
      
      _filterReports();
    } catch (e) {
      debugPrint('Error loading reports: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  void _filterReports() {
    // Can implement filtering logic here if needed
    setState(() {});
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
              // Reports heading with current time
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Medical Reports",
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
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search reports',
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
                color: const Color(0xFFF5F7FA),
                borderRadius: BorderRadius.circular(30),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(text: 'To Review'),
                  Tab(text: 'Reviewed'),
                  Tab(text: 'Finalized'),
                ],
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
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildReportsList(_draftReports, ReportStatus.draft),
                    _buildReportsList(_reviewedReports, ReportStatus.reviewed),
                    _buildReportsList(_finalizedReports, ReportStatus.finalized),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildReportsList(List<ReportModel> reports, ReportStatus status) {
    if (reports.isEmpty) {
      return _buildEmptyState(status);
    }
    
    return RefreshIndicator(
      onRefresh: _loadReports,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: reports.length,
        itemBuilder: (context, index) {
          return _buildReportCard(reports[index], status);
        },
      ),
    );
  }
  
  Widget _buildEmptyState(ReportStatus status) {
    String title;
    String message;
    IconData icon;
    
    switch (status) {
      case ReportStatus.draft:
        title = 'No Reports to Review';
        message = 'You don\'t have any patient reports that need review';
        icon = Icons.description_outlined;
        break;
      case ReportStatus.reviewed:
        title = 'No Reviewed Reports';
        message = 'You haven\'t reviewed any reports yet';
        icon = Icons.fact_check_outlined;
        break;
      case ReportStatus.finalized:
        title = 'No Finalized Reports';
        message = 'You haven\'t finalized any reports yet';
        icon = Icons.check_circle_outline;
        break;
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 72,
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              message,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(ReportModel report, ReportStatus status) {
    final formattedDate = DateFormat('MMM d, yyyy').format(report.createdAt.toDate());
    
    // Get status info
    Color statusColor;
    String statusText;
    IconData statusIcon;
    
    switch (status) {
      case ReportStatus.draft:
        statusColor = AppColors.warning;
        statusText = 'Needs Review';
        statusIcon = Icons.pending_outlined;
        break;
      case ReportStatus.reviewed:
        statusColor = AppColors.info;
        statusText = 'Reviewed';
        statusIcon = Icons.fact_check_outlined;
        break;
      case ReportStatus.finalized:
        statusColor = AppColors.success;
        statusText = 'Finalized';
        statusIcon = Icons.check_circle_outline;
        break;
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        onTap: () {
          // Navigate to report details or editing page
          Navigator.pushNamed(
            context, 
            '/reports/${report.id}',
          ).then((_) => _loadReports());
        },
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Patient avatar
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: const Color(0xFF6C7FDF).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        report.patientName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                        style: AppTypography.titleLarge.copyWith(
                          color: const Color(0xFF6C7FDF),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Report info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          report.patientName,
                          style: AppTypography.titleMedium.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Submitted on $formattedDate',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Status badge
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: statusColor.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          statusIcon,
                          size: 14,
                          color: statusColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          statusText,
                          style: AppTypography.bodySmall.copyWith(
                            color: statusColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              
              // Report preview
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Content:',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF9FAFC),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: const Color(0xFFE5E8EC),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      report.content.length > 100
                          ? '${report.content.substring(0, 100)}...'
                          : report.content,
                      style: AppTypography.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Action buttons based on status
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (status == ReportStatus.draft) ...[
                    _buildActionButton(
                      label: 'Review',
                      icon: Icons.edit_note,
                      isPrimary: true,
                      onTap: () {
                        // Navigate to review page
                        Navigator.pushNamed(
                          context, 
                          '/reports/${report.id}/review',
                        ).then((_) => _loadReports());
                      },
                    ),
                  ] else if (status == ReportStatus.reviewed) ...[
                    _buildActionButton(
                      label: 'Edit',
                      icon: Icons.edit,
                      isPrimary: false,
                      onTap: () {
                        // Navigate to edit review
                        Navigator.pushNamed(
                          context, 
                          '/reports/${report.id}/review',
                        ).then((_) => _loadReports());
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      label: 'Finalize',
                      icon: Icons.check_circle,
                      isPrimary: true,
                      onTap: () async {
                        // Finalize report
                        try {
                          final firebaseService = FirebaseService();
                          await firebaseService.finalizeAndSendReport(report.id, null);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report finalized and sent to patient')),
                            );
                            _loadReports();
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ] else if (status == ReportStatus.finalized) ...[
                    _buildActionButton(
                      label: 'View PDF',
                      icon: Icons.visibility,
                      isPrimary: false,
                      onTap: () {
                        // View PDF if available
                        if (report.pdfUrl != null) {
                          // Open PDF viewer
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('PDF not available for this report')),
                          );
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      label: 'Share',
                      icon: Icons.share_rounded,
                      isPrimary: false,
                      onTap: () async {
                        // Show share options dialog
                        final recipientId = await _showShareOptionsDialog(report);
                        if (recipientId != null && context.mounted) {
                          try {
                            final firebaseService = FirebaseService();
                            // Share the medical document
                            await firebaseService.shareMedicalDocument(
                              senderId: widget.doctor.id,
                              recipientId: recipientId,
                              documentName: 'Medical Report - ${report.patientName}',
                              documentUrl: report.pdfUrl ?? '',
                              documentType: 'medical_report',
                              description: 'Medical report based on pre-assessment data',
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Report shared successfully')),
                              );
                            }
                          } catch (e) {
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Error sharing report: $e')),
                              );
                            }
                          }
                        }
                      },
                    ),
                    const SizedBox(width: 12),
                    _buildActionButton(
                      label: 'Send Again',
                      icon: Icons.send,
                      isPrimary: true,
                      onTap: () async {
                        // Send report again
                        try {
                          final firebaseService = FirebaseService();
                          await firebaseService.finalizeAndSendReport(report.id, report.pdfUrl);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Report sent to patient again')),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Error: $e')),
                            );
                          }
                        }
                      },
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required bool isPrimary,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isPrimary ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isPrimary ? AppColors.primary : AppColors.surfaceDark,
              width: 1,
            ),
            boxShadow: isPrimary ? [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.2),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ] : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 18,
                color: isPrimary ? Colors.white : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.bodyMedium.copyWith(
                  color: isPrimary ? Colors.white : AppColors.primary,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Method to show share options dialog
  Future<String?> _showShareOptionsDialog(ReportModel report) async {
    // Default to the patient the report belongs to
    String? selectedRecipientId = report.patientId;
    
    // Show a dialog to confirm sharing
    return showDialog<String?>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Share Medical Report'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Share this report with:', style: AppTypography.titleSmall),
            const SizedBox(height: 16),
            // Simple option to share with the patient by default
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: RadioListTile<String>(
                title: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Center(
                        child: Text(
                          report.patientName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                          style: AppTypography.titleMedium.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(report.patientName, style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
                        Text('Patient', style: AppTypography.bodySmall.copyWith(color: AppColors.textSecondary)),
                      ],
                    ),
                  ],
                ),
                value: report.patientId,
                groupValue: selectedRecipientId,
                onChanged: (value) {
                  selectedRecipientId = value;
                },
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selectedRecipientId),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            child: const Text('Share'),
          ),
        ],
      ),
    );
  }
}