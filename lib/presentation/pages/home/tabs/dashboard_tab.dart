import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:intl/intl.dart';

// Providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final currentUserProvider = FutureProvider.autoDispose<UserModel?>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  final user = await authService.getCurrentUser();
  
  if (user == null) return null;
  return await firebaseService.getUserById(user.uid);
});

final upcomingAppointmentsProvider = FutureProvider.autoDispose<List<AppointmentModel>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  final user = await authService.getCurrentUser();
  
  if (user == null) return [];
  return await firebaseService.getUpcomingAppointments(user.uid, false);
});

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshData();
    });
  }
  
  void _refreshData() {
    ref.refresh(currentUserProvider);
    ref.refresh(upcomingAppointmentsProvider);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userAsync = ref.watch(currentUserProvider);
    final appointmentsAsync = ref.watch(upcomingAppointmentsProvider);
    
    return RefreshIndicator(
      onRefresh: () async {
        _refreshData();
      },
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: userAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Text('Error loading data: $error'),
          ),
          data: (user) {
            if (user == null) {
              return const Center(
                child: Text('User data not found. Please sign in again.'),
              );
            }
            
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Welcome Card
                _buildWelcomeCard(user, appointmentsAsync),
                const SizedBox(height: 24),
                
                // Quick Actions
                Text(
                  'Quick Actions',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: 16),
                _buildQuickActions(),
                const SizedBox(height: 24),
                
                // Upcoming Appointment
                Text(
                  'Upcoming Appointment',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: 16),
                _buildUpcomingAppointment(appointmentsAsync),
                const SizedBox(height: 24),
                
                // Health Stats
                Text(
                  'Health Statistics',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: 16),
                _buildHealthStats(user),
                const SizedBox(height: 24),
                
                // Medication Reminders
                Text(
                  'Medication Reminders',
                  style: AppTypography.headlineSmall,
                ),
                const SizedBox(height: 16),
                _buildMedicationReminders(user),
                const SizedBox(height: 32),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(UserModel user, AsyncValue<List<AppointmentModel>> appointmentsAsync) {
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: AppColors.primary,
      elevation: 4,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                user.profileImageUrl != null
                    ? CircleAvatar(
                        radius: 30,
                        backgroundImage: NetworkImage(user.profileImageUrl!),
                      )
                    : const CircleAvatar(
                        radius: 30,
                        backgroundColor: Colors.white,
                        child: Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.primary,
                        ),
                      ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome back,',
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      Text(
                        user.name,
                        style: AppTypography.headlineMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            appointmentsAsync.when(
              loading: () => const Center(
                child: SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
              error: (_, __) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Error loading appointment data',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.info_outline,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No upcoming appointments. Schedule one now!',
                            style: AppTypography.bodyMedium.copyWith(
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }
                
                // Sort appointments by date
                appointments.sort((a, b) => a.date.compareTo(b.date));
                final nextAppointment = appointments.first;
                final appointmentDate = nextAppointment.date.toDate();
                final dayFormat = DateFormat('EEEE, MMMM d');
                final timeFormat = DateFormat('h:mm a');
                
                String doctorName = 'your doctor';
                if (nextAppointment.doctorDetails != null && 
                    nextAppointment.doctorDetails!['name'] != null) {
                  doctorName = 'Dr. ${nextAppointment.doctorDetails!['name']}';
                }
                
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Colors.white,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Your next appointment is on ${dayFormat.format(appointmentDate)} at ${timeFormat.format(appointmentDate)} with $doctorName',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions() {
    final quickActions = [
      {
        'icon': Icons.calendar_month,
        'title': 'Book Appointment',
        'color': AppColors.primary,
      },
      {
        'icon': Icons.message,
        'title': 'Message Doctor',
        'color': AppColors.secondary,
      },
      {
        'icon': Icons.health_and_safety,
        'title': 'Check Symptoms',
        'color': AppColors.accent,
      },
      {
        'icon': Icons.medication,
        'title': 'Medications',
        'color': AppColors.success,
      },
    ];
    
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        mainAxisExtent: 100,
      ),
      itemCount: quickActions.length,
      itemBuilder: (context, index) {
        final action = quickActions[index];
        return InkWell(
          onTap: () {
            // TODO: Navigate to action
          },
          borderRadius: BorderRadius.circular(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (action['color'] as Color).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action['icon'] as IconData,
                  color: action['color'] as Color,
                  size: 24,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                action['title'] as String,
                style: AppTypography.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildUpcomingAppointment(AsyncValue<List<AppointmentModel>> appointmentsAsync) {
    return appointmentsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(),
      ),
      error: (error, _) => Center(
        child: Text('Error loading appointments: $error'),
      ),
      data: (appointments) {
        if (appointments.isEmpty) {
          return Card(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(
                    Icons.calendar_today_outlined,
                    size: 48,
                    color: AppColors.textTertiary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'No upcoming appointments',
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Schedule an appointment with a doctor',
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
        
        // Sort appointments by date
        appointments.sort((a, b) => a.date.compareTo(b.date));
        final nextAppointment = appointments.first;
        final appointmentDate = nextAppointment.date.toDate();
        final dayFormat = DateFormat('d');
        final monthFormat = DateFormat('MMM');
        
        String doctorName = 'Your Doctor';
        String doctorSpecialty = 'Medical Professional';
        
        if (nextAppointment.doctorDetails != null) {
          if (nextAppointment.doctorDetails!['name'] != null) {
            doctorName = 'Dr. ${nextAppointment.doctorDetails!['name']}';
          }
          if (nextAppointment.doctorDetails!['specialty'] != null) {
            doctorSpecialty = nextAppointment.doctorDetails!['specialty'];
          }
        }
        
        final timeFormat = DateFormat('h:mm a');
        final formattedStartTime = timeFormat.format(appointmentDate);
        
        // Calculate end time (assuming 30 min appointment)
        final endTime = appointmentDate.add(const Duration(minutes: 30));
        final formattedEndTime = timeFormat.format(endTime);
        
        return Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        dayFormat.format(appointmentDate),
                        style: AppTypography.headlineSmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        monthFormat.format(appointmentDate),
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        doctorName,
                        style: AppTypography.headlineSmall,
                      ),
                      Text(
                        doctorSpecialty,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          const Icon(
                            Icons.access_time,
                            size: 16,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$formattedStartTime - $formattedEndTime',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMedium,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: Icon(
                      nextAppointment.type == AppointmentType.video
                          ? Icons.videocam_outlined
                          : Icons.local_hospital_outlined,
                      color: AppColors.primary,
                    ),
                    onPressed: () {
                      // TODO: Start video call or show location
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHealthStats(UserModel user) {
    // Get medical info if available
    final medicalInfo = user.medicalInfo ?? {};
    
    // Get health data if available in medical info
    int? systolic = medicalInfo['blood_pressure_systolic'];
    int? diastolic = medicalInfo['blood_pressure_diastolic'];
    
    // Use real data if available, otherwise use sample data
    final List<FlSpot> systolicSpots = systolic != null
        ? [
            FlSpot(0, systolic.toDouble()),
            FlSpot(1, (systolic + 5).toDouble()),
            FlSpot(2, (systolic - 2).toDouble()),
            FlSpot(3, (systolic + 10).toDouble()),
            FlSpot(4, (systolic + 3).toDouble()),
            FlSpot(5, (systolic + 8).toDouble()),
            FlSpot(6, (systolic + 2).toDouble()),
          ]
        : const [
            FlSpot(0, 120),
            FlSpot(1, 125),
            FlSpot(2, 118),
            FlSpot(3, 130),
            FlSpot(4, 123),
            FlSpot(5, 128),
            FlSpot(6, 122),
          ];
          
    final List<FlSpot> diastolicSpots = diastolic != null
        ? [
            FlSpot(0, diastolic.toDouble()),
            FlSpot(1, (diastolic - 2).toDouble()),
            FlSpot(2, (diastolic + 2).toDouble()),
            FlSpot(3, (diastolic + 5).toDouble()),
            FlSpot(4, diastolic.toDouble()),
            FlSpot(5, (diastolic + 3).toDouble()),
            FlSpot(6, (diastolic - 1).toDouble()),
          ]
        : const [
            FlSpot(0, 80),
            FlSpot(1, 78),
            FlSpot(2, 82),
            FlSpot(3, 85),
            FlSpot(4, 80),
            FlSpot(5, 83),
            FlSpot(6, 79),
          ];

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Blood Pressure',
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  'Last 7 days',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 180,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        getTitlesWidget: (value, meta) {
                          return Text(
                            value.toInt().toString(),
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textTertiary,
                            ),
                          );
                        },
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          const days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
                          if (value.toInt() >= 0 && value.toInt() < days.length) {
                            return Text(
                              days[value.toInt()],
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textTertiary,
                              ),
                            );
                          }
                          return const Text('');
                        },
                      ),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    // Systolic
                    LineChartBarData(
                      spots: systolicSpots,
                      isCurved: true,
                      color: AppColors.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.primary.withOpacity(0.1),
                      ),
                    ),
                    // Diastolic
                    LineChartBarData(
                      spots: diastolicSpots,
                      isCurved: true,
                      color: AppColors.secondary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(show: false),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.secondary.withOpacity(0.1),
                      ),
                    ),
                  ],
                  minX: 0,
                  maxX: 6,
                  minY: 60,
                  maxY: 140,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildLegendItem('Systolic', AppColors.primary),
                const SizedBox(width: 24),
                _buildLegendItem('Diastolic', AppColors.secondary),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(
          title,
          style: AppTypography.bodySmall,
        ),
      ],
    );
  }

  Widget _buildMedicationReminders(UserModel user) {
    // Get medication data from user's medical info if available
    final medicalInfo = user.medicalInfo ?? {};
    final medications = medicalInfo['medications'];
    
    List<Map<String, dynamic>> medicationList = [];
    
    // If medications are stored in user data, use them
    if (medications is List) {
      for (var med in medications) {
        if (med is Map<String, dynamic>) {
          medicationList.add(med);
        }
      }
    }
    
    // If no medications found, use sample data
    if (medicationList.isEmpty) {
      medicationList = [
        {
          'name': 'Aspirin',
          'dosage': '100mg',
          'time': '8:00 AM',
          'status': 'Taken',
        },
        {
          'name': 'Lisinopril',
          'dosage': '10mg',
          'time': '9:00 AM',
          'status': 'Missed',
        },
        {
          'name': 'Vitamin D',
          'dosage': '1000 IU',
          'time': '8:00 PM',
          'status': 'Upcoming',
        },
      ];
    }
    
    return Column(
      children: medicationList.map((med) {
        Color statusColor;
        IconData statusIcon;
        
        switch (med['status']) {
          case 'Taken':
            statusColor = AppColors.success;
            statusIcon = Icons.check_circle;
            break;
          case 'Missed':
            statusColor = AppColors.error;
            statusIcon = Icons.cancel;
            break;
          case 'Upcoming':
          default:
            statusColor = AppColors.accent;
            statusIcon = Icons.timer;
            break;
        }
        
        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceMedium,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.medication,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        med['name'] as String,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      Text(
                        '${med['dosage']} - ${med['time']}',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  statusIcon,
                  color: statusColor,
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
} 