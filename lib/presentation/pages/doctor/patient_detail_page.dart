import 'package:flutter/material.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Define provider
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

class PatientDetailPage extends ConsumerStatefulWidget {
  final String patientId;
  
  const PatientDetailPage({super.key, required this.patientId});

  @override
  ConsumerState<PatientDetailPage> createState() => _PatientDetailPageState();
}

class _PatientDetailPageState extends ConsumerState<PatientDetailPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  UserModel? _patient;
  List<AppointmentModel> _appointments = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadPatientData();
  }

  Future<void> _loadPatientData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      
      // Load patient profile
      final patient = await firebaseService.getUserById(widget.patientId);
      
      // Load patient appointments - use generic appointment fetching
      // Since getAppointmentsByPatientId doesn't exist, we'll use a placeholder
      // In production, implement this method in FirebaseService
      final appointments = []; // Placeholder for appointments
      
      setState(() {
        _patient = patient;
        _appointments = []; // Empty list for now
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading patient data: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading patient data: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _patient?.name ?? 'Patient Details',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.call),
            onPressed: () {
              // Call patient functionality would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Calling patient...')),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.message),
            onPressed: () {
              // Message patient functionality would go here
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Opening message thread...')),
              );
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Overview'),
            Tab(text: 'Medical History'),
            Tab(text: 'Appointments'),
          ],
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _patient == null
          ? _buildErrorView()
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildMedicalHistoryTab(),
                _buildAppointmentsTab(),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add_comment, color: Colors.white),
        onPressed: () {
          // Add note or start new communication functionality
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Adding a new note...')),
          );
        },
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Patient not found',
            style: AppTypography.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'We couldn\'t find details for this patient',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            icon: const Icon(Icons.refresh),
            label: const Text('Try Again'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            onPressed: _loadPatientData,
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildPatientProfileCard(),
        const SizedBox(height: 16),
        _buildQuickStatsCard(),
        const SizedBox(height: 16),
        _buildUpcomingAppointmentCard(),
        const SizedBox(height: 16),
        _buildRecentVitalsCard(),
      ],
    );
  }

  Widget _buildPatientProfileCard() {
    final patient = _patient!;
    // Calculate age from medical info if available
    final medicalInfo = patient.medicalInfo ?? {};
    final dateOfBirth = medicalInfo['dateOfBirth'] as Timestamp?;
    final age = dateOfBirth != null 
        ? DateTime.now().year - dateOfBirth.toDate().year
        : null;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary.withOpacity(0.2),
                  child: Text(
                    patient.name.substring(0, 1).toUpperCase(),
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
                        patient.name,
                        style: AppTypography.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            age != null ? '$age years old' : 'Age not specified',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Icon(
                            medicalInfo['gender'] == 'female' ? Icons.female : Icons.male,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            medicalInfo['gender'] ?? 'Not specified',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(
                            Icons.email,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              patient.email,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      if (patient.phoneNumber != null) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              patient.phoneNumber!,
                              style: AppTypography.bodyMedium.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),
            if (medicalInfo['address'] != null) ...[
              Text(
                'Address',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                medicalInfo['address'] as String,
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
            ],
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildInfoItem('Blood Type', medicalInfo['bloodType'] ?? 'Not specified'),
                _buildInfoItem('Height', medicalInfo['height'] != null ? '${medicalInfo['height']} cm' : 'Not specified'),
                _buildInfoItem('Weight', medicalInfo['weight'] != null ? '${medicalInfo['weight']} kg' : 'Not specified'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTypography.bodySmall.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsCard() {
    final medicalInfo = _patient?.medicalInfo ?? {};
    final allergies = (medicalInfo['allergies'] as List<dynamic>?) ?? [];
    final medications = (medicalInfo['medications'] as List<dynamic>?) ?? [];
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Quick Stats',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem(
                  Icons.calendar_today,
                  _appointments.length.toString(),
                  'Total Visits',
                  AppColors.primary,
                ),
                _buildStatItem(
                  Icons.medication,
                  medications.length.toString(),
                  'Medications',
                  Colors.orange,
                ),
                _buildStatItem(
                  Icons.warning_amber,
                  allergies.length.toString(),
                  'Allergies',
                  Colors.red,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IconData icon, String value, String label, Color color) {
    return Column(
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: color.withOpacity(0.1),
          child: Icon(
            icon,
            color: color,
            size: 24,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: AppTypography.titleLarge.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: AppTypography.bodySmall.copyWith(
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  Widget _buildUpcomingAppointmentCard() {
    final upcomingAppointments = _appointments.where(
      (appointment) => appointment.status == AppointmentStatus.upcoming
    ).toList();
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Upcoming Appointment',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            if (upcomingAppointments.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.event_busy,
                      size: 48,
                      color: AppColors.textTertiary,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'No upcoming appointments',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: const Text('Schedule Appointment'),
                      onPressed: () {
                        // Schedule appointment functionality would go here
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Scheduling appointment...')),
                        );
                      },
                    ),
                  ],
                ),
              )
            else
              _buildAppointmentItem(upcomingAppointments.first),
          ],
        ),
      ),
    );
  }

  Widget _buildAppointmentItem(AppointmentModel appointment) {
    final dateFormatter = DateFormat('MMM dd, yyyy');
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.event,
                color: AppColors.primary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                dateFormatter.format(appointment.date.toDate()),
                style: AppTypography.bodyLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(appointment.status).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  _getStatusText(appointment.status),
                  style: AppTypography.bodySmall.copyWith(
                    color: _getStatusColor(appointment.status),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                Icons.access_time,
                color: AppColors.textSecondary,
                size: 20,
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
                Icons.local_hospital,
                color: AppColors.textSecondary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                _getAppointmentTypeText(appointment.type),
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton(
                onPressed: () {
                  // Reschedule functionality would go here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Rescheduling appointment...')),
                  );
                },
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('Reschedule'),
              ),
              const SizedBox(width: 8),
              ElevatedButton(
                onPressed: () {
                  // View details functionality would go here
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Viewing appointment details...')),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text('View Details'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.upcoming:
        return AppColors.primary;
      case AppointmentStatus.past:
        return AppColors.textSecondary;
      case AppointmentStatus.cancelled:
        return AppColors.error;
      default:
        return AppColors.textSecondary;
    }
  }

  String _getStatusText(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.upcoming:
        return 'Upcoming';
      case AppointmentStatus.past:
        return 'Past';
      case AppointmentStatus.cancelled:
        return 'Cancelled';
      default:
        return 'Unknown';
    }
  }

  String _getAppointmentTypeText(AppointmentType type) {
    switch (type) {
      case AppointmentType.inPerson:
        return 'In-Person';
      case AppointmentType.video:
        return 'Video';
      default:
        return 'Unknown';
    }
  }

  Widget _buildRecentVitalsCard() {
    return Card(
      elevation: 2,
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
                Text(
                  'Recent Vitals',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    // View all vitals functionality would go here
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Viewing all vitals...')),
                    );
                  },
                  child: const Text('View All'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _buildVitalRow(
              'Blood Pressure',
              '120/80 mmHg',
              Icons.favorite,
              Colors.red,
              'Normal',
              Colors.green,
            ),
            const Divider(),
            _buildVitalRow(
              'Heart Rate',
              '78 bpm',
              Icons.monitor_heart,
              Colors.redAccent,
              'Normal',
              Colors.green,
            ),
            const Divider(),
            _buildVitalRow(
              'Temperature',
              '37.0 °C',
              Icons.thermostat,
              Colors.orange,
              'Normal',
              Colors.green,
            ),
            const Divider(),
            _buildVitalRow(
              'Respiratory Rate',
              '16 rpm',
              Icons.air,
              Colors.blue,
              'Normal',
              Colors.green,
            ),
            const Divider(),
            _buildVitalRow(
              'Oxygen Saturation',
              '98%',
              Icons.bubble_chart,
              Colors.lightBlue,
              'Normal',
              Colors.green,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVitalRow(
    String title,
    String value,
    IconData icon,
    Color iconColor,
    String status,
    Color statusColor,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: iconColor,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Text(
              status,
              style: AppTypography.bodySmall.copyWith(
                color: statusColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMedicalHistoryTab() {
    final medicalInfo = _patient?.medicalInfo ?? {};
    final allergies = (medicalInfo['allergies'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final medications = (medicalInfo['medications'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final chronicConditions = (medicalInfo['chronicConditions'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final surgicalHistory = (medicalInfo['surgicalHistory'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    final familyHistory = (medicalInfo['familyHistory'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
    
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _buildMedicalInfoCard('Allergies', allergies),
        const SizedBox(height: 16),
        _buildMedicalInfoCard('Medications', medications),
        const SizedBox(height: 16),
        _buildMedicalInfoCard('Chronic Conditions', chronicConditions),
        const SizedBox(height: 16),
        _buildMedicalInfoCard('Surgical History', surgicalHistory),
        const SizedBox(height: 16),
        _buildMedicalInfoCard('Family History', familyHistory),
      ],
    );
  }

  Widget _buildMedicalInfoCard(String title, List<String> items) {
    return Card(
      elevation: 2,
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
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // Edit functionality would go here
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Editing $title...')),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 36,
                        color: AppColors.textTertiary,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No $title recorded',
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ...items.map((item) => _buildMedicalInfoItem(item)).toList(),
            const SizedBox(height: 8),
            Center(
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text('Add $title'),
                onPressed: () {
                  // Add functionality would go here
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Adding $title...')),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicalInfoItem(String item) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.circle,
            size: 8,
            color: AppColors.textSecondary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              item,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAppointmentsTab() {
    if (_appointments.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_busy,
              size: 64,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Appointments',
              style: AppTypography.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'This patient has no appointment history',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Schedule Appointment'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              onPressed: () {
                // Schedule appointment functionality would go here
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Scheduling appointment...')),
                );
              },
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _appointments.length,
      itemBuilder: (context, index) {
        final appointment = _appointments[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          child: _buildAppointmentItem(appointment),
        );
      },
    );
  }
} 