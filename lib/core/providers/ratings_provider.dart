import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/rating_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';
import 'firebase_provider.dart';

class RatingsProvider extends ChangeNotifier {
  List<RatingModel> _doctorRatings = [];
  List<RatingModel> _patientRatings = [];
  bool _isLoading = false;
  
  List<RatingModel> get doctorRatings => _doctorRatings;
  List<RatingModel> get patientRatings => _patientRatings;
  bool get isLoading => _isLoading;

  // Initialize the provider with Firebase service
  late final FirebaseService _firebaseService;
  late final AuthProvider _authProvider;
  
  void initialize(FirebaseProvider firebaseProvider, AuthProvider authProvider) {
    _firebaseService = firebaseProvider.service;
    _authProvider = authProvider;
  }
  
  // Load ratings for a doctor
  Future<void> loadDoctorRatings(String doctorId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      _doctorRatings = await _firebaseService.getDoctorRatings(doctorId);
      
    } catch (e) {
      debugPrint('Error loading doctor ratings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Load ratings given by a patient
  Future<void> loadPatientRatings() async {
    if (_authProvider.currentUser == null) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      final userId = _authProvider.currentUser!.uid;
      _patientRatings = await _firebaseService.getPatientRatings(userId);
      
    } catch (e) {
      debugPrint('Error loading patient ratings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Add a rating for a doctor
  Future<void> addDoctorRating({
    required String doctorId,
    required double rating,
    String? comment,
    bool isAnonymous = false,
  }) async {
    if (_authProvider.currentUser == null) return;
    
    try {
      _isLoading = true;
      notifyListeners();
      
      final patientId = _authProvider.currentUser!.uid;
      
      await _firebaseService.addDoctorRating(
        doctorId: doctorId,
        patientId: patientId,
        rating: rating,
        comment: comment,
        isAnonymous: isAnonymous,
      );
      
      // Reload ratings
      await loadDoctorRatings(doctorId);
      await loadPatientRatings();
      
    } catch (e) {
      debugPrint('Error adding doctor rating: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Delete a rating
  Future<void> deleteRating(String ratingId, String doctorId) async {
    try {
      _isLoading = true;
      notifyListeners();
      
      await _firebaseService.deleteRating(ratingId);
      
      // Reload ratings
      await loadDoctorRatings(doctorId);
      await loadPatientRatings();
      
    } catch (e) {
      debugPrint('Error deleting rating: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Calculate average rating from a list of ratings
  double calculateAverageRating(List<RatingModel> ratings) {
    if (ratings.isEmpty) return 0.0;
    
    final totalRating = ratings.fold(0.0, (sum, rating) => sum + rating.rating);
    return totalRating / ratings.length;
  }
} 