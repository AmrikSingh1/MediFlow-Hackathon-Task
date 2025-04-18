import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/doctor_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';

// Provider for the current doctor's data
final currentDoctorProvider = FutureProvider<DoctorModel?>((ref) async {
  final authService = AuthService();
  final firebaseService = FirebaseService();
  final user = await authService.getCurrentUser();
  if (user != null) {
    final userData = await firebaseService.getUserById(user.uid);
    if (userData != null && userData.role == UserRole.doctor) {
      return DoctorModel.fromUserModel(userData);
    }
  }
  return null;
});

class ScheduleManagementPage extends ConsumerStatefulWidget {
  const ScheduleManagementPage({super.key});

  @override
  ConsumerState<ScheduleManagementPage> createState() => _ScheduleManagementPageState();
}

class _ScheduleManagementPageState extends ConsumerState<ScheduleManagementPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Weekly Schedule', 'Special Days', 'Time Off'];
  
  // Default work schedule (to be loaded from doctor model)
  Map<String, List<String>> _workSchedule = {};
  
  // Time slot settings
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _endTime = const TimeOfDay(hour: 17, minute: 0);
  int _slotDuration = 30; // in minutes
  
  bool _isLoading = true;
  bool _isSaving = false;
  
  // Selected days for weekly schedule
  final Map<String, bool> _selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };
  
  // Special days (custom availability for specific dates)
  final List<Map<String, dynamic>> _specialDays = [];
  
  // Time off periods
  final List<Map<String, dynamic>> _timeOffPeriods = [];
  
  // Selected date for special days
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  
  // Selected day for editing
  String _selectedDay = 'Monday';
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _loadDoctorSchedule();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadDoctorSchedule() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final doctorAsync = await ref.read(currentDoctorProvider.future);
      
      if (doctorAsync != null) {
        // Load work schedule
        if (doctorAsync.workSchedule != null) {
          setState(() {
            _workSchedule = Map<String, List<String>>.from(
              doctorAsync.workSchedule!.map((key, value) => 
                MapEntry(key, List<String>.from(value))
              )
            );
            
            // Set selected days based on work schedule
            for (final day in _selectedDays.keys.toList()) {
              _selectedDays[day] = _workSchedule.containsKey(day);
            }
            
            // Set start and end time based on first available day or defaults
            final firstDay = _workSchedule.entries.firstOrNull;
            if (firstDay != null && firstDay.value.isNotEmpty) {
              // Try to parse start time from first slot
              final firstSlot = firstDay.value.first;
              final lastSlot = firstDay.value.last;
              
              // Parse times like "9:00 AM" or "5:00 PM"
              final firstTimeParts = firstSlot.split(' ');
              final lastTimeParts = lastSlot.split(' ');
              
              if (firstTimeParts.length >= 2 && lastTimeParts.length >= 2) {
                _startTime = _parseTimeString(firstTimeParts[0], firstTimeParts[1]);
                
                // For end time, need to add duration to the start time of the last slot
                final lastStartTime = _parseTimeString(lastTimeParts[0], lastTimeParts[1]);
                final minutes = lastStartTime.hour * 60 + lastStartTime.minute + _slotDuration;
                _endTime = TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60);
              }
            }
            
            // Set selected day to first day in schedule or Monday
            _selectedDay = _workSchedule.isNotEmpty 
                ? _workSchedule.keys.first 
                : 'Monday';
          });
        } else {
          // Create default schedule if none exists
          setState(() {
            _workSchedule = DoctorModel.createDefaultSchedule();
          });
        }
        
        // TODO: Load special days and time off periods from Firestore
      }
    } catch (e) {
      debugPrint('Error loading doctor schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading schedule: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _saveSchedule() async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      final authService = AuthService();
      final firebaseService = FirebaseService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        final userData = await firebaseService.getUserById(user.uid);
        
        if (userData != null && userData.role == UserRole.doctor) {
          // Create filtered work schedule (only selected days)
          final filteredSchedule = <String, List<String>>{};
          for (final day in _selectedDays.entries) {
            if (day.value && _workSchedule.containsKey(day.key)) {
              filteredSchedule[day.key] = _workSchedule[day.key]!;
            }
          }
          
          // Update doctor info with new work schedule
          final doctorInfo = userData.doctorInfo ?? {};
          doctorInfo['workSchedule'] = filteredSchedule;
          
          // Update user model
          final updatedUser = userData.copyWith(
            doctorInfo: doctorInfo,
            updatedAt: Timestamp.now(),
          );
          
          // Save to Firestore
          await firebaseService.updateUser(updatedUser);
          
          // TODO: Save special days and time off periods to Firestore
          
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Schedule saved successfully!'),
              backgroundColor: AppColors.success,
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving schedule: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving schedule: ${e.toString()}'),
          backgroundColor: AppColors.error,
        ),
      );
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  void _updateWorkingHours() {
    // Regenerate time slots for all days based on new working hours
    for (final day in _workSchedule.keys) {
      _workSchedule[day] = _generateTimeSlots(_startTime, _endTime, _slotDuration);
    }
    setState(() {});
  }
  
  List<String> _generateTimeSlots(TimeOfDay start, TimeOfDay end, int slotDuration) {
    final slots = <String>[];
    int startMinutes = start.hour * 60 + start.minute;
    final endMinutes = end.hour * 60 + end.minute;
    
    while (startMinutes < endMinutes) {
      final hour = startMinutes ~/ 60;
      final minute = startMinutes % 60;
      
      final hourStr = hour <= 12 ? '$hour' : '${hour - 12}';
      final minuteStr = minute.toString().padLeft(2, '0');
      final amPm = hour < 12 ? 'AM' : 'PM';
      
      slots.add('$hourStr:$minuteStr $amPm');
      
      startMinutes += slotDuration;
    }
    
    return slots;
  }

  TimeOfDay _parseTimeString(String time, String period) {
    final parts = time.split(':');
    if (parts.length == 2) {
      var hour = int.tryParse(parts[0]) ?? 0;
      final minute = int.tryParse(parts[1]) ?? 0;
      
      // Convert to 24-hour format
      if (period == 'PM' && hour < 12) {
        hour += 12;
      } else if (period == 'AM' && hour == 12) {
        hour = 0;
      }
      
      return TimeOfDay(hour: hour, minute: minute);
    }
    return const TimeOfDay(hour: 9, minute: 0);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Schedule Management'),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Management'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Tab bar
          Container(
            margin: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TabBar(
              controller: _tabController,
              tabs: _tabs.map((title) => Tab(text: title)).toList(),
              labelColor: Colors.white,
              unselectedLabelColor: AppColors.textSecondary,
              indicator: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              labelStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w500,
              ),
              padding: const EdgeInsets.all(4),
              labelPadding: const EdgeInsets.symmetric(horizontal: 8),
              dividerColor: Colors.transparent,
            ),
          ),
          
          // Content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildWeeklyScheduleTab(),
                _buildSpecialDaysTab(),
                _buildTimeOffTab(),
              ],
            ),
          ),
          
          // Save button
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: GradientButton(
              text: 'Save Schedule',
              onPressed: _isSaving ? null : _saveSchedule,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildWeeklyScheduleTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Working hours section
          _buildSectionHeader('Working Hours'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                // Start time and End time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Time',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final selectedTime = await showTimePicker(
                                context: context,
                                initialTime: _startTime,
                              );
                              if (selectedTime != null) {
                                setState(() {
                                  _startTime = selectedTime;
                                });
                                _updateWorkingHours();
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.surfaceDark,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTimeOfDay(_startTime),
                                    style: AppTypography.bodyMedium,
                                  ),
                                  const Icon(Icons.access_time, size: 18),
                                ],
                              ),
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
                            'End Time',
                            style: AppTypography.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final selectedTime = await showTimePicker(
                                context: context,
                                initialTime: _endTime,
                              );
                              if (selectedTime != null) {
                                setState(() {
                                  _endTime = selectedTime;
                                });
                                _updateWorkingHours();
                              }
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: AppColors.surfaceDark,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    _formatTimeOfDay(_endTime),
                                    style: AppTypography.bodyMedium,
                                  ),
                                  const Icon(Icons.access_time, size: 18),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                // Slot duration
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Appointment Duration',
                      style: AppTypography.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<int>(
                      value: _slotDuration,
                      decoration: InputDecoration(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: AppColors.surfaceDark),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 15,
                          child: const Text('15 minutes'),
                        ),
                        DropdownMenuItem(
                          value: 30,
                          child: const Text('30 minutes'),
                        ),
                        DropdownMenuItem(
                          value: 45,
                          child: const Text('45 minutes'),
                        ),
                        DropdownMenuItem(
                          value: 60,
                          child: const Text('60 minutes'),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() {
                            _slotDuration = value;
                          });
                          _updateWorkingHours();
                        }
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          
          // Working days section
          _buildSectionHeader('Working Days'),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: _selectedDays.entries.map((entry) {
                return CheckboxListTile(
                  title: Text(
                    entry.key,
                    style: AppTypography.bodyMedium,
                  ),
                  value: entry.value,
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  onChanged: (value) {
                    setState(() {
                      _selectedDays[entry.key] = value ?? false;
                      
                      // If newly selected, make sure it has time slots
                      if (value == true && (!_workSchedule.containsKey(entry.key) || _workSchedule[entry.key]!.isEmpty)) {
                        _workSchedule[entry.key] = _generateTimeSlots(_startTime, _endTime, _slotDuration);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 24),
          
          // Available time slots preview section
          _buildSectionHeader('Preview Available Time Slots'),
          for (final day in _selectedDays.entries.where((entry) => entry.value))
            _buildDayTimeSlots(day.key),
        ],
      ),
    );
  }
  
  Widget _buildSpecialDaysTab() {
    return Center(
      child: Text(
        'Special Days feature coming soon!',
        style: AppTypography.bodyLarge,
      ),
    );
  }
  
  Widget _buildTimeOffTab() {
    return Center(
      child: Text(
        'Time Off scheduling feature coming soon!',
        style: AppTypography.bodyLarge,
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
  
  Widget _buildDayTimeSlots(String day) {
    final slots = _workSchedule[day] ?? [];
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                day,
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${slots.length} available slots',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: slots.map((slot) {
              return Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: AppColors.surfaceDark,
                  ),
                ),
                child: Text(
                  slot,
                  style: AppTypography.bodySmall,
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Schedule Management Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Weekly Schedule',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Set your regular working hours and days. Patients will be able to book appointments during these times.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Special Days',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Configure unique hours for specific dates that differ from your regular schedule.',
                style: AppTypography.bodyMedium,
              ),
              const SizedBox(height: 16),
              Text(
                'Time Off',
                style: AppTypography.titleSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Block off periods when you are unavailable, such as vacations or conferences.',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }
} 