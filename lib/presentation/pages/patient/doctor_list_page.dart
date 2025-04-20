import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/doctor_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:medi_connect/presentation/pages/patient/find_doctor_page.dart';

// Provider for filtered doctors by specialty
final filteredDoctorsProvider = FutureProvider.family<List<DoctorModel>, String>((ref, specialty) async {
  final firebaseService = FirebaseService();
  
  // If "All Doctors" is selected, don't filter by specialty
  if (specialty == "All Doctors") {
    return await firebaseService.getDoctorsFromCollection();
  }
  
  return await firebaseService.getDoctorsFromCollection(specialty: specialty);
});

class DoctorListPage extends ConsumerStatefulWidget {
  final String specialty;
  
  const DoctorListPage({
    Key? key,
    required this.specialty,
  }) : super(key: key);

  @override
  ConsumerState<DoctorListPage> createState() => _DoctorListPageState();
}

class _DoctorListPageState extends ConsumerState<DoctorListPage> {
  final TextEditingController _searchController = TextEditingController();
  String _filterSelected = '';
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _showComingSoonDialog(String feature) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Coming Soon!'),
        content: Text('$feature feature will be available in the next update.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentLocation = ref.watch(currentLocationProvider);
    
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          widget.specialty == "All Doctors"
              ? 'All Doctors in $currentLocation'
              : '${widget.specialty}s in $currentLocation',
          style: AppTypography.titleMedium.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterChips(),
          Expanded(
            child: _buildDoctorList(),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Doctors, hospitals, specialties, services, diseases',
          hintStyle: TextStyle(color: Colors.grey),
          prefixIcon: Icon(Icons.search, color: Colors.grey),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(30),
            borderSide: BorderSide(color: AppColors.primary),
          ),
          contentPadding: EdgeInsets.symmetric(vertical: 0, horizontal: 16),
        ),
        onChanged: (value) {
          setState(() {
            // Search functionality would go here
          });
        },
      ),
    );
  }
  
  Widget _buildFilterChips() {
    return Container(
      height: 60,
      color: Colors.white,
      padding: EdgeInsets.symmetric(horizontal: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('Female Doctors', Icons.female),
            _buildFilterChip('Discounts', Icons.local_offer),
            _buildFilterChip('Lowest Fee', Icons.attach_money),
            _buildFilterChip('Available Today', Icons.today),
            _buildFilterChip('Top Rated', Icons.star),
          ],
        ),
      ),
    );
  }
  
  Widget _buildFilterChip(String label, IconData icon) {
    final isSelected = _filterSelected == label;
    
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: FilterChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppColors.primary,
            ),
            SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        selected: isSelected,
        backgroundColor: Colors.white,
        selectedColor: AppColors.primary,
        showCheckmark: false,
        shape: StadiumBorder(
          side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
        onSelected: (selected) {
          setState(() {
            _filterSelected = selected ? label : '';
          });
        },
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      ),
    );
  }
  
  Widget _buildDoctorList() {
    return Consumer(
      builder: (context, ref, child) {
        final doctorsAsync = ref.watch(filteredDoctorsProvider(widget.specialty));
        
        return doctorsAsync.when(
          loading: () => Center(child: CircularProgressIndicator()),
          error: (error, stackTrace) => Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: Colors.red),
                SizedBox(height: 16),
                Text('Error loading doctors'),
                SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    ref.refresh(filteredDoctorsProvider(widget.specialty));
                  },
                  child: Text('Try Again'),
                ),
              ],
            ),
          ),
          data: (doctors) {
            // If there are no doctors, show message
            if (doctors.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.search_off, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'No doctors found',
                      style: AppTypography.titleMedium,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Try changing your filters or specialty',
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              );
            }
            
            // Show number of doctors found
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.specialty == "All Doctors"
                          ? 'Top ${doctors.length} Doctors in ${ref.watch(currentLocationProvider)}'
                          : 'Top ${doctors.length} ${widget.specialty}s in ${ref.watch(currentLocationProvider)}',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: doctors.length,
                    itemBuilder: (context, index) {
                      return _buildDoctorCard(doctors[index]);
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }
  
  Widget _buildDoctorCard(DoctorModel doctor) {
    // Generate random values for wait time and patients count for demo purposes
    final waitTime = '15 - 30 Min';
    final experience = '${doctor.experience} Years';
    final patientsSatisfied = '${(doctor.rating * 20).toInt()}%';
    final patientsCount = (doctor.ratingCount * 10).toString();
    
    return Card(
      margin: EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      elevation: 1,
      child: Column(
        children: [
          // Doctor Info
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor Image
                CircleAvatar(
                  radius: 40,
                  backgroundColor: Colors.grey.shade200,
                  backgroundImage: doctor.profileImageUrl.isNotEmpty
                      ? NetworkImage(doctor.profileImageUrl)
                      : null,
                  child: doctor.profileImageUrl.isEmpty
                      ? Icon(Icons.person, size: 40, color: Colors.grey)
                      : null,
                ),
                SizedBox(width: 16),
                // Doctor Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor.name}',
                        style: AppTypography.titleLarge,
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${doctor.specialty}, Obstetrician',
                        style: AppTypography.bodyMedium.copyWith(
                          color: Colors.grey.shade600,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'M.D, F.C.P.S (${doctor.specialty} & Obstetrics), Certified',
                        style: AppTypography.bodySmall.copyWith(
                          color: Colors.grey.shade600,
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
          
          // Doctor Stats
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: IntrinsicHeight(
              child: Row(
                children: [
                  // Wait Time
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          waitTime,
                          style: AppTypography.titleMedium,
                        ),
                        Text(
                          'Wait Time',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical Divider
                  VerticalDivider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                    width: 32,
                  ),
                  // Experience
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          experience,
                          style: AppTypography.titleMedium,
                        ),
                        Text(
                          'Experience',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Vertical Divider
                  VerticalDivider(
                    color: Colors.grey.shade300,
                    thickness: 1,
                    width: 32,
                  ),
                  // Satisfied Patients
                  Expanded(
                    child: Column(
                      children: [
                        Text(
                          '$patientsSatisfied ($patientsCount)',
                          style: AppTypography.titleMedium,
                        ),
                        Text(
                          'Satisfied Patients',
                          style: AppTypography.bodyMedium.copyWith(
                            color: Colors.grey.shade600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          
          // Video Consultation
          Container(
            margin: EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.shade200),
              borderRadius: BorderRadius.circular(8),
            ),
            child: InkWell(
              onTap: () => _showComingSoonDialog('Video Consultation'),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Icon(
                      Icons.videocam,
                      color: AppColors.primary,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Online Video Consultation',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Spacer(),
                    Text(
                      'Rs. 1,500',
                      style: AppTypography.bodyLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // Available Tomorrow
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 16, 8),
            child: Row(
              children: [
                Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Available Tomorrow',
                  style: AppTypography.bodyMedium.copyWith(
                    color: Colors.green,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          
          // Discount Banner
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primaryLight],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.discount,
                  color: Colors.white,
                  size: 18,
                ),
                SizedBox(width: 8),
                Text(
                  'Pay Online & Get 10% OFF',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          // Action Buttons
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Video Consultation Button
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _showComingSoonDialog('Video Consultation'),
                    icon: Icon(Icons.videocam),
                    label: Text('Video Consultation'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: BorderSide(color: AppColors.primary),
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(width: 16),
                // Book Appointment Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushNamed(
                        context, 
                        '/patient/book-appointment',
                        arguments: {'doctorId': doctor.id},
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('Book Appointment'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
} 