import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:medi_connect/presentation/pages/patient/doctor_list_page.dart';

// List of cities available in the app
final List<String> kAppCities = [
  'New Delhi', 'Mumbai', 'Bangalore', 'Chennai', 'Kolkata', 
  'Hyderabad', 'Pune', 'Ahmedabad', 'Jaipur', 'Lucknow',
  'Lahore', 'Karachi', 'Islamabad', 'Rawalpindi', 'Faisalabad',
];

// Provider for the current location, shared across the app
final currentLocationProvider = StateProvider<String>((ref) => 'New Delhi');

// Provider for all doctors
final allDoctorsProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final firebaseService = FirebaseService();
  return await firebaseService.getDoctors();
});

// Provider for recent searches
final recentSearchesProvider = StateProvider<List<Map<String, dynamic>>>((ref) {
  return [
    {'specialty': 'ENT Specialist', 'icon': 'assets/icons/health_icons/conditions/throat.png'},
    {'specialty': 'Orthopedic', 'icon': 'assets/icons/health_icons/conditions/bone.png'},
    {'specialty': 'Gynecologist', 'icon': 'assets/icons/health_icons/conditions/female.png'},
  ];
});

class FindDoctorPage extends ConsumerStatefulWidget {
  const FindDoctorPage({Key? key}) : super(key: key);

  @override
  ConsumerState<FindDoctorPage> createState() => _FindDoctorPageState();
}

class _FindDoctorPageState extends ConsumerState<FindDoctorPage> {
  final TextEditingController _searchController = TextEditingController();
  String _currentLocation = 'Lahore';
  // Dark blue color that exactly matches the image
  final Color darkBlue = const Color(0xFF0C1A6B);
  
  final List<Map<String, dynamic>> _specialties = [
    {
      'specialty': 'General Physician',
      'icon': 'assets/icons/health_icons/devices/stethoscope.png',
      'color': Colors.blue.shade100,
    },
    {
      'specialty': 'Cardiologist',
      'icon': 'assets/icons/health_icons/conditions/heart.png',
      'color': Colors.red.shade100,
    },
    {
      'specialty': 'Dermatologist',
      'icon': 'assets/icons/health_icons/conditions/skin.png',
      'color': Colors.purple.shade100,
    },
    {
      'specialty': 'Neurologist',
      'icon': 'assets/icons/health_icons/conditions/brain.png',
      'color': Colors.red.shade100,
    },
    {
      'specialty': 'Pediatrician',
      'icon': 'assets/icons/health_icons/conditions/pediatric.png',
      'color': Colors.purple.shade100,
    },
    {
      'specialty': 'Psychiatrist',
      'icon': 'assets/icons/health_icons/conditions/mental.png',
      'color': Colors.amber.shade100,
    },
    {
      'specialty': 'Orthopedic',
      'icon': 'assets/icons/health_icons/conditions/bone.png',
      'color': Colors.blue.shade100,
    },
    {
      'specialty': 'Gynecologist',
      'icon': 'assets/icons/health_icons/conditions/female.png',
      'color': Colors.pink.shade100,
    },
    {
      'specialty': 'Ophthalmologist',
      'icon': 'assets/icons/health_icons/conditions/eye.png',
      'color': Colors.blue.shade100,
    },
    {
      'specialty': 'ENT Specialist',
      'icon': 'assets/icons/health_icons/conditions/throat.png',
      'color': Colors.red.shade100,
    },
    {
      'specialty': 'Dentist',
      'icon': 'assets/icons/health_icons/conditions/tooth.png',
      'color': Colors.blue.shade100,
    },
  ];
  
  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _showLocationPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      backgroundColor: Colors.white,
      isScrollControlled: true,
      builder: (BuildContext context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          expand: false,
          builder: (context, scrollController) {
            return _buildLocationPickerContent(context, scrollController);
          },
        );
      },
    );
  }
  
  Widget _buildLocationPickerContent(BuildContext context, ScrollController scrollController) {
    final currentLocation = ref.watch(currentLocationProvider);
    
    return Column(
      children: [
        // Handle
        Container(
          margin: const EdgeInsets.only(top: 10, bottom: 6),
          height: 4,
          width: 60,
          decoration: BoxDecoration(
            color: Colors.grey[300],
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Row(
            children: [
              Text(
                'Select City',
                style: AppTypography.titleLarge.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Search
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          child: TextFormField(
            decoration: InputDecoration(
              hintText: 'Search cities...',
              prefixIcon: const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              filled: true,
              fillColor: Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
            ),
          ),
        ),
        
        // Divider
        const Divider(),
        
        // List of cities
        Expanded(
          child: ListView.builder(
            controller: scrollController,
            itemCount: kAppCities.length,
            itemBuilder: (context, index) {
              final city = kAppCities[index];
              final isSelected = city == currentLocation;
              
              return ListTile(
                leading: Icon(
                  Icons.location_city,
                  color: isSelected ? AppColors.primary : Colors.grey[500],
                ),
                title: Text(
                  city,
                  style: TextStyle(
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                  ),
                ),
                trailing: isSelected 
                    ? const Icon(Icons.check_circle, color: AppColors.primary)
                    : null,
                onTap: () {
                  ref.read(currentLocationProvider.notifier).state = city;
                  Navigator.pop(context);

                  // Show feedback
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Location updated to $city'),
                      behavior: SnackBarBehavior.floating,
                      backgroundColor: AppColors.success,
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
  
  @override
  Widget build(BuildContext context) {
    final recentSearches = ref.watch(recentSearchesProvider);
    final currentLocation = ref.watch(currentLocationProvider);
    
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: AppColors.primary, // Use the standard blue from the app
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current city',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.normal,
              ),
            ),
            GestureDetector(
              onTap: () => _showLocationPicker(context),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    currentLocation,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Icon(
                    Icons.keyboard_arrow_down,
                    color: Colors.white,
                    size: 18,
                  ),
                ],
              ),
            ),
          ],
        ),
        automaticallyImplyLeading: false,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Search bar
            Container(
              color: AppColors.primary, // Use the standard blue from the app
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              alignment: Alignment.center,
              child: Container(
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      const Icon(Icons.search, color: Colors.grey),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AnimatedTextKit(
                          animatedTexts: [
                            TypewriterAnimatedText(
                              'Find Doctors, Specialties, Disease and Hospit...',
                              speed: const Duration(milliseconds: 80),
                              textStyle: const TextStyle(
                                color: Colors.grey,
                                fontSize: 14,
                              ),
                            ),
                          ],
                          repeatForever: true,
                          pause: const Duration(milliseconds: 2000),
                          displayFullTextOnTap: true,
                          stopPauseOnTap: true,
                          onTap: () {
                            // Focus on the search field when text is tapped
                            FocusScope.of(context).requestFocus(FocusNode());
                            _searchController.selection = TextSelection(
                              baseOffset: 0,
                              extentOffset: _searchController.text.length,
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            // Recent searches
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Recent searches',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      // Clear recent searches
                      ref.read(recentSearchesProvider.notifier).state = [];
                    },
                    child: const Text(
                      'Clear all',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            // Recent search items
            SizedBox(
              height: 110,
              child: recentSearches.isEmpty
                  ? const Center(
                      child: Text(
                        'No recent searches',
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: recentSearches.length,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemBuilder: (context, index) {
                        final search = recentSearches[index];
                        return _buildRecentSearchItem(search['specialty'], search['icon']);
                      },
                    ),
            ),
            
            // Search by specialty
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Search by specialty',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ),
            
            // Grid of specialties
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                children: [
                  // All Doctors button
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DoctorListPage(specialty: "All Doctors"),
                          ),
                        );
                      },
                      child: Card(
                        elevation: 2,
                        color: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: Colors.blue.shade50,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.group,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Text(
                                  "All Doctors",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                              Icon(
                                Icons.arrow_forward_ios,
                                color: AppColors.primary,
                                size: 16,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  // Specialty grid
                  GridView.builder(
                    physics: const NeverScrollableScrollPhysics(),
                    shrinkWrap: true,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      childAspectRatio: 2.2,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: _specialties.length,
                    itemBuilder: (context, index) {
                      final specialty = _specialties[index];
                      return _buildSpecialtyItem(
                        specialty['specialty'],
                        specialty['icon'],
                        specialty['color'],
                      );
                    },
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRecentSearchItem(String specialty, String iconPath) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorListPage(specialty: specialty),
          ),
        );
      },
      child: Container(
        width: 100,
        margin: const EdgeInsets.all(8),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                shape: BoxShape.circle,
              ),
              child: Image.asset(
                iconPath,
                color: AppColors.primary,
                width: 30,
                height: 30,
                errorBuilder: (context, error, stackTrace) {
                  return Icon(
                    Icons.medical_services,
                    color: AppColors.primary,
                    size: 24,
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Text(
              specialty,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSpecialtyItem(String specialty, String iconPath, Color backgroundColor) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DoctorListPage(specialty: specialty),
          ),
        );
      },
      child: Card(
        elevation: 2,
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  shape: BoxShape.circle,
                ),
                child: Image.asset(
                  iconPath,
                  color: AppColors.primary,
                  width: 24,
                  height: 24,
                  errorBuilder: (context, error, stackTrace) {
                    return Icon(
                      Icons.medical_services,
                      color: AppColors.primary,
                      size: 18,
                    );
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  specialty,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
} 