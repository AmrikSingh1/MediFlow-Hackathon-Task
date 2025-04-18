import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/rating_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';

final doctorProvider = FutureProvider.family<UserModel?, String>((ref, doctorId) async {
  final firebaseService = FirebaseService();
  return await firebaseService.getUserById(doctorId);
});

final ratingsProvider = FutureProvider.family<List<RatingModel>, String>((ref, doctorId) async {
  final firebaseService = FirebaseService();
  return await firebaseService.getDoctorRatings(doctorId);
});

class DoctorRatingPage extends ConsumerStatefulWidget {
  final String doctorId;
  
  const DoctorRatingPage({
    Key? key,
    required this.doctorId,
  }) : super(key: key);

  @override
  ConsumerState<DoctorRatingPage> createState() => _DoctorRatingPageState();
}

class _DoctorRatingPageState extends ConsumerState<DoctorRatingPage> {
  double _userRating = 0.0;
  final TextEditingController _commentController = TextEditingController();
  bool _isAnonymous = false;
  bool _isSubmitting = false;
  
  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }
  
  Future<void> _submitRating() async {
    // Validate rating
    if (_userRating == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a rating')),
      );
      return;
    }
    
    setState(() {
      _isSubmitting = true;
    });
    
    try {
      final authService = AuthService();
      final currentUser = authService.currentUser;
      
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('You must be logged in to rate doctors')),
        );
        return;
      }
      
      final firebaseService = FirebaseService();
      await firebaseService.addDoctorRating(
        doctorId: widget.doctorId,
        patientId: currentUser.uid,
        rating: _userRating,
        comment: _commentController.text.isNotEmpty ? _commentController.text : null,
        isAnonymous: _isAnonymous,
      );
      
      // Refresh ratings
      ref.refresh(ratingsProvider(widget.doctorId));
      ref.refresh(doctorProvider(widget.doctorId));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thank you for your feedback!'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reset form
        setState(() {
          _userRating = 0.0;
          _commentController.clear();
          _isAnonymous = false;
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error submitting rating: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final doctorAsync = ref.watch(doctorProvider(widget.doctorId));
    final ratingsAsync = ref.watch(ratingsProvider(widget.doctorId));
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Rating'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: doctorAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Center(
          child: Text('Error loading doctor: $error'),
        ),
        data: (doctor) {
          if (doctor == null) {
            return const Center(
              child: Text('Doctor not found'),
            );
          }
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor info
                _buildDoctorProfile(doctor),
                const SizedBox(height: 24),
                
                // Rating form
                _buildRatingForm(),
                const SizedBox(height: 32),
                
                // Reviews section
                _buildReviewsSection(ratingsAsync),
              ],
            ),
          );
        },
      ),
    );
  }
  
  Widget _buildDoctorProfile(UserModel doctor) {
    final specialty = doctor.doctorInfo?['specialty'] ?? 'General Practitioner';
    final hospital = doctor.doctorInfo?['hospitalAffiliation'] ?? 'Not specified';
    final rating = doctor.doctorInfo?['rating'] as double? ?? 0.0;
    final ratingCount = doctor.doctorInfo?['ratingCount'] as int? ?? 0;
    
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 40,
                  backgroundColor: AppColors.primary.withOpacity(0.1),
                  child: Text(
                    doctor.name.isNotEmpty ? doctor.name[0].toUpperCase() : 'D',
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 32,
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Dr. ${doctor.name}',
                        style: AppTypography.headlineSmall.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialty,
                        style: AppTypography.titleMedium.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _buildRatingStars(rating),
                          const SizedBox(width: 8),
                          Text(
                            '${rating.toStringAsFixed(1)} (${ratingCount.toString()} reviews)',
                            style: AppTypography.bodyMedium.copyWith(
                              color: AppColors.textSecondary,
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
            const Divider(),
            const SizedBox(height: 16),
            Row(
              children: [
                const Icon(
                  Icons.local_hospital,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    hospital,
                    style: AppTypography.bodyMedium,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildRatingForm() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Leave a Rating',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Tell others about your experience with this doctor',
              style: TextStyle(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            
            // Star rating
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (index) {
                return IconButton(
                  iconSize: 40,
                  icon: Icon(
                    index < _userRating ? Icons.star : Icons.star_border,
                    color: index < _userRating ? Colors.amber : Colors.grey,
                    size: 40,
                  ),
                  onPressed: () {
                    setState(() {
                      _userRating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 24),
            
            // Comment field
            TextField(
              controller: _commentController,
              decoration: InputDecoration(
                labelText: 'Your Review (Optional)',
                hintText: 'Share your experience with this doctor...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            
            // Anonymous checkbox
            Row(
              children: [
                Checkbox(
                  value: _isAnonymous,
                  onChanged: (value) {
                    setState(() {
                      _isAnonymous = value ?? false;
                    });
                  },
                ),
                const Text('Submit anonymously'),
              ],
            ),
            const SizedBox(height: 16),
            
            // Submit button
            GradientButton(
              text: 'Submit Review',
              onPressed: _isSubmitting ? null : () {
                _submitRating();
              },
              width: double.infinity,
              height: 50,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildReviewsSection(AsyncValue<List<RatingModel>> ratingsAsync) {
    return ratingsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Text('Error loading reviews: $error'),
      ),
      data: (ratings) {
        if (ratings.isEmpty) {
          return Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  Text(
                    'Reviews',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 40),
                  const Icon(
                    Icons.rate_review_outlined,
                    size: 64,
                    color: Colors.grey,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'No reviews yet',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Be the first to leave a review',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          );
        }
        
        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Reviews (${ratings.length})',
                      style: AppTypography.titleLarge.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // Show all reviews
                      },
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: ratings.length > 3 ? 3 : ratings.length,
                  separatorBuilder: (context, index) => const Divider(height: 32),
                  itemBuilder: (context, index) {
                    final rating = ratings[index];
                    return _buildReviewItem(rating);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildReviewItem(RatingModel rating) {
    final formattedDate = DateFormat('MMM d, yyyy').format(rating.createdAt.toDate());
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              rating.isAnonymous ? 'Anonymous User' : 'Patient',
              style: AppTypography.bodyLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              formattedDate,
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        _buildRatingStars(rating.rating),
        const SizedBox(height: 8),
        if (rating.comment != null && rating.comment!.isNotEmpty)
          Text(
            rating.comment!,
            style: AppTypography.bodyMedium,
          ),
      ],
    );
  }
  
  Widget _buildRatingStars(double rating) {
    return Row(
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          // Full star
          return const Icon(Icons.star, color: Colors.amber, size: 18);
        } else if (index < rating.ceil() && rating.floor() != rating.ceil()) {
          // Half star
          return const Icon(Icons.star_half, color: Colors.amber, size: 18);
        } else {
          // Empty star
          return const Icon(Icons.star_border, color: Colors.amber, size: 18);
        }
      }),
    );
  }
} 