import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';

// Provider for all doctors
final allDoctorsProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final firebaseService = FirebaseService();
  return await firebaseService.getDoctors();
});

class FindDoctorPage extends ConsumerStatefulWidget {
  const FindDoctorPage({Key? key}) : super(key: key);

  @override
  ConsumerState<FindDoctorPage> createState() => _FindDoctorPageState();
}

class _FindDoctorPageState extends ConsumerState<FindDoctorPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedSpecialty = 'All Specialties';
  String _selectedAvailability = 'Any Availability';
  bool _showFilters = false;
  List<UserModel> _filteredDoctors = [];
  
  final List<String> _specialties = [
    'All Specialties',
    'Cardiology',
    'Dermatology',
    'Endocrinology',
    'Family Medicine',
    'Gastroenterology',
    'Neurology',
    'Obstetrics & Gynecology',
    'Oncology',
    'Ophthalmology',
    'Orthopedics',
    'Pediatrics',
    'Psychiatry',
    'Pulmonology',
    'Rheumatology',
    'Urology',
  ];
  
  final List<String> _availabilityOptions = [
    'Any Availability',
    'Available Today',
    'Available This Week',
    'Available Next Week',
  ];
  
  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterDoctors);
  }
  
  @override
  void dispose() {
    _searchController.removeListener(_filterDoctors);
    _searchController.dispose();
    super.dispose();
  }
  
  void _filterDoctors() {
    final doctorsAsync = ref.read(allDoctorsProvider);
    doctorsAsync.whenData((doctors) {
      setState(() {
        _filteredDoctors = doctors.where((doctor) {
          // Filter by search text
          final name = doctor.name.toLowerCase();
          final specialty = doctor.doctorInfo?['specialty']?.toString().toLowerCase() ?? '';
          final searchText = _searchController.text.toLowerCase();
          final matchesSearch = name.contains(searchText) || specialty.contains(searchText);
          
          // Filter by specialty
          bool matchesSpecialty = true;
          if (_selectedSpecialty != 'All Specialties') {
            matchesSpecialty = specialty.contains(_selectedSpecialty.toLowerCase());
          }
          
          // Filter by availability (this would need server-side implementation)
          bool matchesAvailability = true;
          // This is a placeholder for availability filtering
          // In a complete implementation, this would check against doctor's schedule
          
          return matchesSearch && matchesSpecialty && matchesAvailability;
        }).toList();
        
        // Sort by rating (placeholder - would need rating data)
        _filteredDoctors.sort((a, b) {
          final ratingA = a.doctorInfo?['rating'] as double? ?? 0.0;
          final ratingB = b.doctorInfo?['rating'] as double? ?? 0.0;
          return ratingB.compareTo(ratingA);
        });
      });
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final doctorsAsync = ref.watch(allDoctorsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Find a Doctor'),
        elevation: 0,
        backgroundColor: Colors.white,
        actions: [
          IconButton(
            icon: Icon(
              _showFilters ? Icons.filter_list_off : Icons.filter_list,
              color: AppColors.primary,
            ),
            onPressed: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by name or specialty',
                prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: AppColors.surfaceDark),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          
          // Filters
          if (_showFilters)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Filter by:',
                    style: AppTypography.bodyMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  
                  // Specialty dropdown
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceDark),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedSpecialty,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        elevation: 16,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedSpecialty = value;
                              _filterDoctors();
                            });
                          }
                        },
                        items: _specialties.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Availability dropdown
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.surfaceDark),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedAvailability,
                        isExpanded: true,
                        icon: const Icon(Icons.arrow_drop_down),
                        elevation: 16,
                        style: AppTypography.bodyMedium.copyWith(color: AppColors.textPrimary),
                        onChanged: (String? value) {
                          if (value != null) {
                            setState(() {
                              _selectedAvailability = value;
                              _filterDoctors();
                            });
                          }
                        },
                        items: _availabilityOptions.map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text(value),
                          );
                        }).toList(),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  // Clear filters button
                  Center(
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _selectedSpecialty = 'All Specialties';
                          _selectedAvailability = 'Any Availability';
                          _searchController.clear();
                          _filterDoctors();
                        });
                      },
                      icon: const Icon(Icons.clear_all, size: 18),
                      label: const Text('Clear all filters'),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.primary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Divider(),
                ],
              ),
            ),
          
          // Results
          Expanded(
            child: doctorsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.error),
                    const SizedBox(height: 16),
                    Text(
                      'Error loading doctors',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Please try again later',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
              data: (doctors) {
                if (_filteredDoctors.isEmpty && _searchController.text.isEmpty && 
                    _selectedSpecialty == 'All Specialties' && _selectedAvailability == 'Any Availability') {
                  _filteredDoctors = List.from(doctors);
                }
                
                if (_filteredDoctors.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.search_off, size: 48, color: AppColors.textSecondary),
                        const SizedBox(height: 16),
                        Text(
                          'No doctors found',
                          style: AppTypography.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Try adjusting your filters',
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount: _filteredDoctors.length,
                  itemBuilder: (context, index) {
                    final doctor = _filteredDoctors[index];
                    return _buildDoctorCard(doctor);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildDoctorCard(UserModel doctor) {
    final specialty = doctor.doctorInfo?['specialty'] ?? 'General Practitioner';
    final hospital = doctor.doctorInfo?['hospitalAffiliation'] ?? 'Not specified';
    final rating = doctor.doctorInfo?['rating'] as double? ?? 4.0;
    final experience = doctor.doctorInfo?['experience'] as int? ?? 5;
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Doctor avatar
                CircleAvatar(
                  radius: 36,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 28,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                
                // Doctor info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor.name}',
                        style: AppTypography.titleMedium.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        style: AppTypography.bodyMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star,
                            size: 16,
                            color: Colors.amber[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$rating',
                            style: AppTypography.bodySmall,
                          ),
                          const SizedBox(width: 16),
                          Icon(
                            Icons.work_outline,
                            size: 16,
                            color: Colors.blue[700],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '$experience years',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Hospital affiliation
            Row(
              children: [
                const Icon(Icons.local_hospital_outlined, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    hospital,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            
            // Availability (placeholder)
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppColors.textSecondary),
                const SizedBox(width: 8),
                Text(
                  'Available today',
                  style: AppTypography.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Action buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pushNamed('${Routes.chat.split('/:')[0]}/${doctor.id}');
                    },
                    icon: const Icon(Icons.message_outlined, size: 18),
                    label: const Text('Message'),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      side: const BorderSide(color: AppColors.primary),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GradientButton(
                    text: 'Book',
                    onPressed: () {
                      Navigator.of(context).pushNamed(
                        Routes.bookAppointment,
                        arguments: {'doctorId': doctor.id},
                      );
                    },
                    icon: const Icon(Icons.calendar_month, color: Colors.white, size: 18),
                    height: 48,
                    borderRadius: 8,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
} 