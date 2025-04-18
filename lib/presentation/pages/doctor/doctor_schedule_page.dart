import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/doctor_model.dart';
import 'package:medi_connect/core/models/appointment_slot_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

// Provider for doctor's schedule data
final doctorScheduleProvider = FutureProvider.autoDispose<Map<String, List<String>>?>((ref) async {
  final firebaseService = FirebaseService();
  final authService = AuthService();
  final user = await authService.getCurrentUser();
  
  if (user != null) {
    final doctorData = await firebaseService.getUserById(user.uid);
    if (doctorData != null && doctorData.doctorInfo != null) {
      return doctorData.doctorInfo!['workSchedule'] as Map<String, List<String>>?;
    }
  }
  return null;
});

// Provider for doctor's available slots
final doctorAvailableSlotsProvider = FutureProvider.autoDispose<Map<String, List<String>>?>((ref) async {
  final firebaseService = FirebaseService();
  final authService = AuthService();
  final user = await authService.getCurrentUser();
  
  if (user != null) {
    final doctorData = await firebaseService.getUserById(user.uid);
    if (doctorData != null && doctorData.doctorInfo != null) {
      return doctorData.doctorInfo!['availableSlots'] as Map<String, List<String>>?;
    }
  }
  return null;
});

class DoctorSchedulePage extends ConsumerStatefulWidget {
  const DoctorSchedulePage({super.key});

  @override
  ConsumerState<DoctorSchedulePage> createState() => _DoctorSchedulePageState();
}

class _DoctorSchedulePageState extends ConsumerState<DoctorSchedulePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabs = ['Weekly Schedule', 'Date-specific Availability', 'Block Off Dates'];
  
  // Default work hours
  TimeOfDay _workDayStart = const TimeOfDay(hour: 9, minute: 0);
  TimeOfDay _workDayEnd = const TimeOfDay(hour: 18, minute: 0);
  int _slotDuration = 30; // minutes
  
  // Selected day for editing
  String _selectedWeekday = 'Monday';
  
  // For date-specific availability
  DateTime _selectedDate = DateTime.now().add(const Duration(days: 1));
  
  // For blocking off dates
  DateTimeRange? _blockedDateRange;
  final List<DateTimeRange> _blockedDates = [];
  
  // Loading state
  bool _isLoading = false;
  bool _isSaving = false;
  
  // Default weekly schedule
  Map<String, List<String>> _workSchedule = {};
  Map<String, List<String>> _availableSlots = {};

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
      final scheduleAsync = await ref.read(doctorScheduleProvider.future);
      final slotsAsync = await ref.read(doctorAvailableSlotsProvider.future);
      
      if (scheduleAsync != null) {
        _workSchedule = scheduleAsync;
      } else {
        // Use default schedule if none exists
        _workSchedule = DoctorModel.createDefaultSchedule();
      }
      
      if (slotsAsync != null) {
        _availableSlots = slotsAsync;
      } else {
        // Use default slots if none exist
        _availableSlots = DoctorModel.createInitialAvailableSlots();
      }
    } catch (e) {
      debugPrint('Error loading doctor schedule: $e');
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
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Availability'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: () {
              _showHelpDialog(context);
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : Column(
              children: [
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
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildWeeklyScheduleTab(),
                      _buildDateSpecificTab(),
                      _buildBlockOffDatesTab(),
                    ],
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
          const SizedBox(height: 8),
          _buildInfoCard(
            title: 'Set Your Weekly Schedule',
            content: 'Define your regular working hours for each day of the week. These settings will apply every week unless overridden by specific date settings.',
            icon: Icons.schedule,
          ),
          const SizedBox(height: 24),
          
          // Working hours card
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Default Working Hours',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Start and end time
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Start Time',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectTime(context, true),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.surfaceDark),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTimeOfDay(_workDayStart),
                                    style: AppTypography.bodyMedium,
                                  ),
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
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () => _selectTime(context, false),
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColors.surfaceDark),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.access_time,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _formatTimeOfDay(_workDayEnd),
                                    style: AppTypography.bodyMedium,
                                  ),
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
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.surfaceDark),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _slotDuration,
                          isExpanded: true,
                          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primary),
                          elevation: 16,
                          style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                          onChanged: (int? value) {
                            if (value != null) {
                              setState(() {
                                _slotDuration = value;
                              });
                            }
                          },
                          items: [15, 30, 45, 60].map<DropdownMenuItem<int>>((int value) {
                            return DropdownMenuItem<int>(
                              value: value,
                              child: Text('$value minutes'),
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Day selection
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Configure Days',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Day pills
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'].map((day) {
                    final isSelected = _selectedWeekday == day;
                    final isAvailable = _workSchedule.containsKey(day);
                    
                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedWeekday = day;
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected ? AppColors.primary : (isAvailable ? AppColors.surfaceLight : AppColors.surfaceMedium),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: isSelected ? AppColors.primary : (isAvailable ? AppColors.primary.withOpacity(0.3) : AppColors.surfaceDark),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isAvailable)
                              Icon(
                                Icons.check_circle,
                                size: 16,
                                color: isSelected ? Colors.white : AppColors.success,
                              ),
                            if (!isAvailable)
                              Icon(
                                Icons.cancel,
                                size: 16,
                                color: AppColors.textTertiary,
                              ),
                            const SizedBox(width: 6),
                            Text(
                              day.substring(0, 3),
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.w500,
                                color: isSelected ? Colors.white : (isAvailable ? AppColors.textPrimary : AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
                
                const SizedBox(height: 24),
                
                // Toggle for the selected day
                Row(
                  children: [
                    Switch(
                      value: _workSchedule.containsKey(_selectedWeekday),
                      onChanged: (value) {
                        setState(() {
                          if (value) {
                            // Enable the day with default slots
                            final List<String> slots = [];
                            for (int hour = _workDayStart.hour; hour < _workDayEnd.hour; hour++) {
                              for (int minute = 0; minute < 60; minute += _slotDuration) {
                                if (hour == _workDayStart.hour && minute < _workDayStart.minute) continue;
                                if (hour == _workDayEnd.hour && minute >= _workDayEnd.minute) continue;
                                
                                final String hourStr = hour <= 12 ? '$hour' : '${hour - 12}';
                                final String minuteStr = minute.toString().padLeft(2, '0');
                                final String amPm = hour < 12 ? 'AM' : 'PM';
                                
                                slots.add('$hourStr:$minuteStr $amPm');
                              }
                            }
                            
                            _workSchedule[_selectedWeekday] = slots;
                          } else {
                            // Disable the day
                            _workSchedule.remove(_selectedWeekday);
                          }
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _workSchedule.containsKey(_selectedWeekday) 
                          ? 'Available on $_selectedWeekday' 
                          : 'Unavailable on $_selectedWeekday',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                
                // Apply button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveWeeklySchedule(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Apply Schedule',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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

  Widget _buildDateSpecificTab() {
    // Get available slots for the selected date
    final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
    final availableSlots = _availableSlots[dateStr] ?? [];
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildInfoCard(
            title: 'Manage Date-Specific Availability',
            content: 'Add or remove available time slots for specific dates. This overrides your regular weekly schedule.',
            icon: Icons.event,
          ),
          const SizedBox(height: 24),
          
          // Date picker
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Date',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceDark),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_today,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          DateFormat('EEEE, MMMM d, yyyy').format(_selectedDate),
                          style: AppTypography.bodyMedium,
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Time slots
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Available Time Slots',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () {
                        // Generate slots based on weekly schedule
                        setState(() {
                          final weekday = DateFormat('EEEE').format(_selectedDate);
                          if (_workSchedule.containsKey(weekday)) {
                            _availableSlots[dateStr] = List.from(_workSchedule[weekday]!);
                          } else {
                            _availableSlots.remove(dateStr);
                          }
                        });
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Reset to Weekly'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (availableSlots.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_busy,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No time slots available for this date',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            onPressed: () {
                              _generateDefaultTimeSlots();
                            },
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Generate Default Slots'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: availableSlots.map((timeSlot) {
                      return Chip(
                        label: Text(timeSlot),
                        deleteIcon: const Icon(
                          Icons.close,
                          size: 18,
                        ),
                        onDeleted: () {
                          setState(() {
                            availableSlots.remove(timeSlot);
                            if (availableSlots.isEmpty) {
                              _availableSlots.remove(dateStr);
                            } else {
                              _availableSlots[dateStr] = availableSlots;
                            }
                          });
                        },
                        backgroundColor: AppColors.surfaceLight,
                        side: BorderSide(color: AppColors.surfaceDark),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                      );
                    }).toList(),
                  ),
                
                const SizedBox(height: 16),
                
                if (availableSlots.isNotEmpty)
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showAddTimeSlotDialog(context);
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Slot'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceLight,
                            foregroundColor: AppColors.primary,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: () {
                            setState(() {
                              _availableSlots.remove(dateStr);
                            });
                          },
                          icon: const Icon(Icons.delete_outline, size: 18),
                          label: const Text('Clear All'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.surfaceLight,
                            foregroundColor: AppColors.error,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(color: AppColors.error),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                
                const SizedBox(height: 16),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveDateSpecificSchedule(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Availability',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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

  Widget _buildBlockOffDatesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _buildInfoCard(
            title: 'Block Off Dates',
            content: 'Block off ranges of dates when you will be unavailable (vacation, conferences, etc). This will override all other availability settings.',
            icon: Icons.block,
          ),
          const SizedBox(height: 24),
          
          // Date range selection
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select Date Range',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: () => _selectDateRange(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceDark),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.date_range,
                          color: AppColors.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _blockedDateRange != null
                              ? '${DateFormat('MMM d').format(_blockedDateRange!.start)} - ${DateFormat('MMM d, yyyy').format(_blockedDateRange!.end)}'
                              : 'Select dates to block off',
                          style: AppTypography.bodyMedium,
                        ),
                        const Spacer(),
                        Icon(
                          Icons.arrow_drop_down,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _blockedDateRange == null 
                        ? null 
                        : () {
                            setState(() {
                              if (_blockedDateRange != null) {
                                _blockedDates.add(_blockedDateRange!);
                                _blockedDateRange = null;
                              }
                            });
                          },
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add to Blocked Dates'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                      disabledBackgroundColor: AppColors.surfaceMedium,
                      disabledForegroundColor: AppColors.textTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 24),
          
          // List of blocked dates
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Blocked Date Ranges',
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                if (_blockedDates.isEmpty)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          Icon(
                            Icons.event_available,
                            size: 48,
                            color: AppColors.textTertiary,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No blocked date ranges',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _blockedDates.length,
                    separatorBuilder: (context, index) => const Divider(),
                    itemBuilder: (context, index) {
                      final dateRange = _blockedDates[index];
                      return ListTile(
                        leading: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: AppColors.error.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.block,
                            color: AppColors.error,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          '${DateFormat('MMM d').format(dateRange.start)} - ${DateFormat('MMM d, yyyy').format(dateRange.end)}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          '${dateRange.duration.inDays + 1} days',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        trailing: IconButton(
                          icon: Icon(
                            Icons.delete_outline,
                            color: AppColors.error,
                          ),
                          onPressed: () {
                            setState(() {
                              _blockedDates.removeAt(index);
                            });
                          },
                        ),
                      );
                    },
                  ),
                
                const SizedBox(height: 16),
                
                // Save Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _isSaving ? null : () => _saveBlockedDates(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: _isSaving
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(
                            'Save Blocked Dates',
                            style: AppTypography.titleMedium.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
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

  // Helper method to build info cards
  Widget _buildInfoCard({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppColors.primaryLight, AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  content,
                  style: AppTypography.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Format TimeOfDay to string
  String _formatTimeOfDay(TimeOfDay time) {
    final hour = time.hourOfPeriod == 0 ? 12 : time.hourOfPeriod;
    final minute = time.minute.toString().padLeft(2, '0');
    final period = time.period == DayPeriod.am ? 'AM' : 'PM';
    return '$hour:$minute $period';
  }

  // Time picker
  Future<void> _selectTime(BuildContext context, bool isStartTime) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: isStartTime ? _workDayStart : _workDayEnd,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        if (isStartTime) {
          _workDayStart = picked;
        } else {
          _workDayEnd = picked;
        }
      });
    }
  }

  // Date picker
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  // Date range picker
  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      initialDateRange: _blockedDateRange,
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    
    if (picked != null) {
      setState(() {
        _blockedDateRange = picked;
      });
    }
  }

  // Generate default time slots for a specific date
  void _generateDefaultTimeSlots() {
    setState(() {
      final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
      
      final List<String> slots = [];
      for (int hour = _workDayStart.hour; hour < _workDayEnd.hour; hour++) {
        for (int minute = 0; minute < 60; minute += _slotDuration) {
          if (hour == _workDayStart.hour && minute < _workDayStart.minute) continue;
          if (hour == _workDayEnd.hour && minute >= _workDayEnd.minute) continue;
          
          final String hourStr = hour <= 12 ? '$hour' : '${hour - 12}';
          final String minuteStr = minute.toString().padLeft(2, '0');
          final String amPm = hour < 12 ? 'AM' : 'PM';
          
          slots.add('$hourStr:$minuteStr $amPm');
        }
      }
      
      _availableSlots[dateStr] = slots;
    });
  }

  // Show dialog to add a custom time slot
  void _showAddTimeSlotDialog(BuildContext context) {
    TimeOfDay selectedTime = TimeOfDay.now();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          'Add Time Slot',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select a time to add as an available slot',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: () async {
                final TimeOfDay? picked = await showTimePicker(
                  context: context,
                  initialTime: selectedTime,
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: const ColorScheme.light(
                          primary: AppColors.primary,
                          onPrimary: Colors.white,
                          onSurface: AppColors.textPrimary,
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                
                if (picked != null) {
                  selectedTime = picked;
                }
              },
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.surfaceDark),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.access_time,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _formatTimeOfDay(selectedTime),
                      style: AppTypography.bodyMedium,
                    ),
                    const Spacer(),
                    Icon(
                      Icons.arrow_drop_down,
                      color: AppColors.textSecondary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: Text(
              'Cancel',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              setState(() {
                final dateStr = '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}';
                final hour = selectedTime.hourOfPeriod == 0 ? 12 : selectedTime.hourOfPeriod;
                final minute = selectedTime.minute.toString().padLeft(2, '0');
                final period = selectedTime.period == DayPeriod.am ? 'AM' : 'PM';
                final timeSlot = '$hour:$minute $period';
                
                if (_availableSlots.containsKey(dateStr)) {
                  if (!_availableSlots[dateStr]!.contains(timeSlot)) {
                    _availableSlots[dateStr]!.add(timeSlot);
                    // Sort slots by time
                    _availableSlots[dateStr]!.sort((a, b) {
                      final timeA = DateFormat('h:mm a').parse(a);
                      final timeB = DateFormat('h:mm a').parse(b);
                      return timeA.compareTo(timeB);
                    });
                  }
                } else {
                  _availableSlots[dateStr] = [timeSlot];
                }
              });
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Add Slot',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Show help dialog
  void _showHelpDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.help_outline,
              color: AppColors.primary,
              size: 24,
            ),
            const SizedBox(width: 8),
            Text(
              'Managing Your Availability',
              style: AppTypography.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHelpSection(
              title: 'Weekly Schedule',
              content: 'Set your regular working hours for each day of the week. These settings apply by default.',
              icon: Icons.schedule,
            ),
            const SizedBox(height: 16),
            _buildHelpSection(
              title: 'Date-specific Availability',
              content: 'Override your regular schedule for specific dates when you need custom hours.',
              icon: Icons.event,
            ),
            const SizedBox(height: 16),
            _buildHelpSection(
              title: 'Block Off Dates',
              content: 'Block entire date ranges when you\'ll be unavailable (vacations, conferences, etc).',
              icon: Icons.block,
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Got it',
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
    );
  }

  // Helper for help dialog sections
  Widget _buildHelpSection({
    required String title,
    required String content,
    required IconData icon,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            color: AppColors.primary,
            size: 16,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                content,
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Save weekly schedule
  Future<void> _saveWeeklySchedule(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      final authService = AuthService();
      final firebaseService = FirebaseService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        // Update doctor's work schedule and available slots
        await firebaseService.updateDoctorAvailability(
          user.uid,
          _workSchedule,
          _availableSlots
        );
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Weekly schedule updated successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving weekly schedule: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving schedule: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Save date-specific availability
  Future<void> _saveDateSpecificSchedule(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      final authService = AuthService();
      final firebaseService = FirebaseService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        // Update doctor's available slots
        await firebaseService.updateDoctorAvailability(
          user.uid,
          _workSchedule,
          _availableSlots
        );
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Date-specific availability updated successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving date-specific availability: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving availability: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Save blocked dates
  Future<void> _saveBlockedDates(BuildContext context) async {
    setState(() {
      _isSaving = true;
    });
    
    try {
      final authService = AuthService();
      final firebaseService = FirebaseService();
      final user = await authService.getCurrentUser();
      
      if (user != null) {
        // Process blocked dates to remove availability
        for (final dateRange in _blockedDates) {
          final start = dateRange.start;
          final end = dateRange.end;
          
          // For each day in the range
          for (int i = 0; i <= dateRange.duration.inDays; i++) {
            final date = start.add(Duration(days: i));
            final dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
            
            // Remove availability for this date
            _availableSlots.remove(dateStr);
          }
        }
        
        // Convert blocked dates to the format expected by Firebase
        final blockedDatesForFirebase = _blockedDates.map((range) => {
          'start': Timestamp.fromDate(range.start),
          'end': Timestamp.fromDate(range.end),
        }).toList();
        
        // Update blocked dates in Firestore
        await firebaseService.blockDoctorDates(
          user.uid,
          blockedDatesForFirebase,
          _availableSlots
        );
        
        // Show success message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Blocked dates updated successfully!'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(10),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Error saving blocked dates: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving blocked dates: ${e.toString()}'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
            margin: const EdgeInsets.all(10),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }
} 