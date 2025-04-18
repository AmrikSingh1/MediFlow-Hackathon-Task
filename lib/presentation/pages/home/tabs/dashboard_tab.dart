import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/models/doctor_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/presentation/pages/home/home_page.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:animated_text_kit/animated_text_kit.dart';

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

final recentDoctorsProvider = FutureProvider.autoDispose<List<DoctorModel>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  final user = await authService.getCurrentUser();
  
  if (user == null) return [];
  
  try {
    // In a real app, this would fetch recently consulted doctors
    // For now, just get a few doctors as demo data
    final doctors = await firebaseService.getDoctorsFromCollection();
    return doctors.take(2).toList();
  } catch (e) {
    debugPrint('Error loading recent doctors: $e');
    return [];
  }
});

// Saved conversations provider
final savedConversationsProvider = FutureProvider.autoDispose<List<Map<String, dynamic>>>((ref) async {
  try {
    final authService = ref.read(authServiceProvider);
    final firebaseService = ref.read(firebaseServiceProvider);
    final user = await authService.getCurrentUser();
    
    if (user == null) return [];
    
    debugPrint("Fetching saved conversations for user ${user.uid}");
    final conversations = await firebaseService.getSavedConversations(user.uid);
    debugPrint("Retrieved ${conversations.length} saved conversations");
    
    // If we have no saved conversations, attempt to save any recent AI chats for the user
    if (conversations.isEmpty) {
      debugPrint("No saved conversations found, attempting to save AI chat");
      await firebaseService.saveChatConversation(user.uid, '3'); // AI Assistant chat ID
      
      // Fetch conversations again
      final updatedConversations = await firebaseService.getSavedConversations(user.uid);
      debugPrint("After auto-saving, retrieved ${updatedConversations.length} saved conversations");
      return updatedConversations;
    }
    
    return conversations;
  } catch (e) {
    debugPrint("Error fetching saved conversations: $e");
    return [];
  }
});

class DashboardTab extends ConsumerStatefulWidget {
  const DashboardTab({super.key});

  @override
  ConsumerState<DashboardTab> createState() => _DashboardTabState();
}

class _DashboardTabState extends ConsumerState<DashboardTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  // Current location - changed default to New Delhi
  String _currentLocation = "New Delhi";
  
  // List of major cities in India
  final List<String> _indianCities = [
    "New Delhi",
    "Mumbai",
    "Bangalore",
    "Hyderabad",
    "Chennai",
    "Kolkata",
    "Pune",
    "Ahmedabad",
    "Jaipur",
    "Lucknow",
    "Chandigarh",
    "Kochi",
    "Indore",
    "Bhopal",
    "Guwahati",
    "Patna"
  ];
  
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
    ref.refresh(recentDoctorsProvider);
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userAsync = ref.watch(currentUserProvider);
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        onRefresh: () async {
          _refreshData();
        },
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
            
            return _buildPatientDashboard(user);
          },
        ),
      ),
    );
  }

  Widget _buildPatientDashboard(UserModel user) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // App Bar with Location
          _buildLocationHeader(user),
          
          // Search Box
          _buildSearchBox(),
          
          // Appointment Booking Options
          _buildBookingOptions(),
          
          // Health Problem Categories
          _buildHealthProblemSection(),
          
          // Recent Doctors
          _buildRecentDoctorsSection(),
        ],
      ),
    );
  }

  // Location Header with centered location selector
  Widget _buildLocationHeader(UserModel user) {
    return Container(
      padding: const EdgeInsets.only(top: 4, bottom: 0),
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Header with profile and location integrated into a single row
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  // User Profile Avatar
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: Colors.white,
                    backgroundImage: user.profileImageUrl != null
                        ? NetworkImage(user.profileImageUrl!)
                        : null,
                    child: user.profileImageUrl == null
                        ? const Icon(Icons.person, color: AppColors.primary, size: 28)
                        : null,
                  ),
                  Expanded(
                    child: Center(
                      child: InkWell(
                        onTap: () {
                          _showLocationPicker(context);
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: Colors.white,
                                size: 18,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _currentLocation,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
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
                      ),
                    ),
                  ),
                  // Balance the layout with empty space equal to avatar width
                  const SizedBox(width: 44),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Location Picker Dialog
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
                    onChanged: (value) {
                      // Implement search functionality as needed
                    },
                  ),
                ),
                
                // Divider
                const Divider(),
                
                // List of cities
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    itemCount: _indianCities.length,
                    itemBuilder: (context, index) {
                      final city = _indianCities[index];
                      final isSelected = city == _currentLocation;
                      
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
                          setState(() {
                            _currentLocation = city;
                          });
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
          },
        );
      },
    );
  }

  // Search Box
  Widget _buildSearchBox() {
    final typewriterTexts = [
      'Search for clinics and hospitals',
      'Find doctors by specialty',
      'Book your next appointment',
    ];
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Navigate to search page
            Navigator.pushNamed(context, Routes.findDoctor);
          },
          splashColor: Colors.white.withOpacity(0.1),
          highlightColor: Colors.white.withOpacity(0.1),
          borderRadius: BorderRadius.circular(30),
          child: Ink(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(30),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  const Icon(
                    Icons.search,
                    color: Colors.grey,
                    size: 22,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AnimatedTextKit(
                      animatedTexts: typewriterTexts.map((text) => TypewriterAnimatedText(
                        text,
                        speed: const Duration(milliseconds: 80),
                        textStyle: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 15,
                        ),
                      )).toList(),
                      repeatForever: true,
                      pause: const Duration(milliseconds: 2000),
                      displayFullTextOnTap: true,
                      stopPauseOnTap: true,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Booking Options
  Widget _buildBookingOptions() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          // In-Clinic Appointment
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, Routes.bookAppointment);
              },
              child: Container(
                height: 210, // Reduced height from 240 to fix overflow
                decoration: BoxDecoration(
                  color: Colors.lightBlue.shade100.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?q=80&w=2070&auto=format&fit=crop',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.primaryLight.withOpacity(0.2),
                              child: const Center(
                                child: Icon(
                                  Icons.local_hospital,
                                  size: 50,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Book In-Clinic Appointment',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 16,
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
          ),
          
          const SizedBox(width: 16),
          
          // Video Consultation
          Expanded(
            child: InkWell(
              onTap: () {
                Navigator.pushNamed(context, Routes.bookAppointment);
              },
              child: Container(
                height: 210, // Reduced height from 240 to fix overflow
                decoration: BoxDecoration(
                  color: Colors.lightBlue.shade100.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Expanded(
                      flex: 3,
                      child: ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(16),
                          topRight: Radius.circular(16),
                        ),
                        child: Image.network(
                          'https://images.unsplash.com/photo-1576091160550-2173dba999ef?q=80&w=1000&auto=format&fit=crop',
                          fit: BoxFit.cover,
                          width: double.infinity,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: AppColors.primaryLight.withOpacity(0.2),
                              child: const Center(
                                child: Icon(
                                  Icons.videocam,
                                  size: 50,
                                  color: AppColors.primary,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              'Instant Video Consultation',
                              style: AppTypography.bodyMedium.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                            ),
                          ),
                          Container(
                            width: 28,
                            height: 28,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primary,
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.arrow_forward,
                                color: Colors.white,
                                size: 16,
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
          ),
        ],
      ),
    );
  }

  // Health Problem Section
  Widget _buildHealthProblemSection() {
    final healthCategories = [
      {
        'title': 'General Physician',
        'icon': 'assets/icons/stethoscope.png',
        'color': Colors.blue.shade100,
      },
      {
        'title': 'Skin & Hair',
        'icon': 'assets/icons/skin.png',
        'color': Colors.purple.shade100,
      },
      {
        'title': 'Women\'s Health',
        'icon': 'assets/icons/woman.png',
        'color': Colors.pink.shade100,
      },
      {
        'title': 'Dental Care',
        'icon': 'assets/icons/tooth.png',
        'color': Colors.orange.shade100,
      },
      {
        'title': 'Child Specialist',
        'icon': 'assets/icons/baby.png',
        'color': Colors.purple.shade100,
      },
      {
        'title': 'Ear, Nose, Throat',
        'icon': 'assets/icons/ear.png',
        'color': Colors.teal.shade100,
      },
      {
        'title': 'Mental Wellness',
        'icon': 'assets/icons/brain.png',
        'color': Colors.red.shade100,
      },
      {
        'title': 'more',
        'icon': 'assets/icons/more.png',
        'color': Colors.blue.shade100,
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Text(
            'Find a Doctor for your Health Problem',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        // Using SizedBox to limit height and avoid overflow
        SizedBox(
          height: 210, // Fixed height to prevent overflow
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            shrinkWrap: true,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 8, // Reduced spacing
              mainAxisSpacing: 0, // Reduced spacing
              childAspectRatio: 0.9, // Adjusted ratio
            ),
            itemCount: healthCategories.length,
            itemBuilder: (context, index) {
              final category = healthCategories[index];
              return InkWell(
                onTap: () {
                  // Navigate to specialty doctors page
                  Navigator.pushNamed(
                    context, 
                    Routes.findDoctor, 
                    arguments: {'specialty': category['title']}
                  );
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 60, // Reduced size
                      height: 60, // Reduced size
                      decoration: BoxDecoration(
                        color: category['color'] as Color,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: category['title'] == 'more'
                            ? Text(
                                '20+',
                                style: TextStyle(
                                  color: Colors.indigo.shade700,
                                  fontSize: 18, // Slightly smaller
                                  fontWeight: FontWeight.bold,
                                ),
                              )
                            : Icon(
                                _getIconForCategory(category['title'] as String),
                                color: Colors.indigo.shade700,
                                size: 26, // Smaller icon
                              ),
                      ),
                    ),
                    const SizedBox(height: 4), // Reduced spacing
                    Text(
                      category['title'] as String,
                      textAlign: TextAlign.center,
                      style: AppTypography.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                        fontSize: 11, // Smaller text
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // Recent Doctors Section
  Widget _buildRecentDoctorsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
          child: Text(
            'Doctors you have consulted',
            style: AppTypography.headlineSmall.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        SizedBox(
          height: 90,
          child: Consumer(
            builder: (context, ref, child) {
              final doctorsAsync = ref.watch(recentDoctorsProvider);
              
              return doctorsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, stackTrace) => Center(
                  child: Text('Error loading doctors: $error'),
                ),
                data: (doctors) {
                  if (doctors.isEmpty) {
                    return Center(
                      child: Text(
                        'No recently consulted doctors',
                        style: AppTypography.bodyMedium,
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: doctors.length,
                    itemBuilder: (context, index) {
                      final doctor = doctors[index];
                      return InkWell(
                        onTap: () {
                          // Navigate to doctor details
                        },
                        child: Container(
                          width: 280,
                          margin: const EdgeInsets.only(right: 16),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(color: Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                radius: 28,
                                backgroundColor: Colors.grey.shade200,
                                backgroundImage: doctor.profileImageUrl != null
                                    ? NetworkImage(doctor.profileImageUrl)
                                    : null,
                                child: doctor.profileImageUrl == null
                                    ? Text(
                                        doctor.name.isNotEmpty ? doctor.name[0] : 'D',
                                        style: const TextStyle(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      )
                                    : null,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Dr. ${doctor.name}',
                                      style: AppTypography.titleMedium.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      doctor.specialty,
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.grey.shade600,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  // Helper method to get icons for each category
  IconData _getIconForCategory(String category) {
    switch (category) {
      case 'General Physician':
        return Icons.medical_services;
      case 'Skin & Hair':
        return Icons.face;
      case 'Women\'s Health':
        return Icons.pregnant_woman;
      case 'Dental Care':
        return Icons.cleaning_services;
      case 'Child Specialist':
        return Icons.child_care;
      case 'Ear, Nose, Throat':
        return Icons.hearing;
      case 'Mental Wellness':
        return Icons.psychology;
      default:
        return Icons.add;
    }
  }
} 