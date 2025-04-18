import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/appointment_model.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'auth_provider.dart';
import 'firebase_provider.dart';

class AppointmentsProvider extends ChangeNotifier {
  List<AppointmentModel> _upcomingAppointments = [];
  List<AppointmentModel> _pastAppointments = [];
  List<AppointmentModel> _cancelledAppointments = [];
  bool _isLoading = false;
  String? _errorMessage;
  
  List<AppointmentModel> get upcomingAppointments => _upcomingAppointments;
  List<AppointmentModel> get pastAppointments => _pastAppointments;
  List<AppointmentModel> get cancelledAppointments => _cancelledAppointments;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize the provider with Firebase service
  late final FirebaseService _firebaseService;
  late final AuthProvider _authProvider;
  
  void initialize(FirebaseProvider firebaseProvider, AuthProvider authProvider) {
    _firebaseService = firebaseProvider.service;
    _authProvider = authProvider;
    debugPrint('AppointmentsProvider: Initialized with Firebase service and Auth provider');
    loadAppointments();
  }
  
  // Load all appointments for the current user
  Future<void> loadAppointments() async {
    if (_authProvider.currentUser == null) {
      debugPrint('AppointmentsProvider: Current user is null, cannot load appointments');
      _errorMessage = 'User not logged in';
      notifyListeners();
      return;
    }
    
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      final userId = _authProvider.currentUser!.uid;
      final isDoctor = _authProvider.userModel?.role == UserRole.doctor;
      
      debugPrint('AppointmentsProvider: Loading appointments for ${isDoctor ? "doctor" : "patient"} with ID: $userId');
      
      // Fetch the appointments based on status
      _upcomingAppointments = await _firebaseService.getUpcomingAppointments(userId, isDoctor);
      debugPrint('AppointmentsProvider: Loaded ${_upcomingAppointments.length} upcoming appointments');
      
      _pastAppointments = await _firebaseService.getPastAppointments(userId, isDoctor);
      debugPrint('AppointmentsProvider: Loaded ${_pastAppointments.length} past appointments');
      
      _cancelledAppointments = await _firebaseService.getCancelledAppointments(userId, isDoctor);
      debugPrint('AppointmentsProvider: Loaded ${_cancelledAppointments.length} cancelled appointments');
      
    } catch (e) {
      debugPrint('AppointmentsProvider: Error loading appointments: $e');
      _errorMessage = 'Failed to load appointments: ${e.toString()}';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Create a new appointment
  Future<bool> createAppointment(AppointmentModel appointment) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('AppointmentsProvider: Creating appointment for doctor ${appointment.doctorId}');
      final appointmentId = await _firebaseService.createAppointment(appointment);
      debugPrint('AppointmentsProvider: Appointment created with ID: $appointmentId');
      
      // Refresh the appointment lists
      await loadAppointments();
      
      return true;
    } catch (e) {
      debugPrint('AppointmentsProvider: Error creating appointment: $e');
      _errorMessage = 'Failed to create appointment: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Update appointment status
  Future<bool> updateAppointmentStatus(String appointmentId, AppointmentStatus newStatus) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      // Find the appointment
      AppointmentModel? appointment = _findAppointmentById(appointmentId);
      if (appointment == null) {
        debugPrint('AppointmentsProvider: Appointment not found with ID: $appointmentId');
        _errorMessage = 'Appointment not found';
        _isLoading = false;
        notifyListeners();
        return false;
      }
      
      // Update the appointment status
      final updatedAppointment = appointment.copyWith(status: newStatus);
      await _firebaseService.updateAppointment(updatedAppointment);
      debugPrint('AppointmentsProvider: Updated appointment status to ${newStatus.toString()}');
      
      // Refresh the appointment lists
      await loadAppointments();
      
      return true;
    } catch (e) {
      debugPrint('AppointmentsProvider: Error updating appointment status: $e');
      _errorMessage = 'Failed to update appointment: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Helper method to find an appointment by id across all lists
  AppointmentModel? _findAppointmentById(String id) {
    // Check in all lists
    for (final appointment in _upcomingAppointments) {
      if (appointment.id == id) return appointment;
    }
    for (final appointment in _pastAppointments) {
      if (appointment.id == id) return appointment;
    }
    for (final appointment in _cancelledAppointments) {
      if (appointment.id == id) return appointment;
    }
    return null;
  }
  
  // Helper method to refresh appointment lists after status change
  void _refreshAppointmentLists(AppointmentModel updatedAppointment) {
    // Remove from all lists
    _upcomingAppointments.removeWhere((a) => a.id == updatedAppointment.id);
    _pastAppointments.removeWhere((a) => a.id == updatedAppointment.id);
    _cancelledAppointments.removeWhere((a) => a.id == updatedAppointment.id);
    
    // Add to appropriate list
    switch (updatedAppointment.status) {
      case AppointmentStatus.upcoming:
        _upcomingAppointments.add(updatedAppointment);
        break;
      case AppointmentStatus.past:
        _pastAppointments.add(updatedAppointment);
        break;
      case AppointmentStatus.cancelled:
        _cancelledAppointments.add(updatedAppointment);
        break;
    }
    
    notifyListeners();
  }

  // Force refresh all appointments
  Future<void> refreshAppointments() async {
    debugPrint('AppointmentsProvider: Refreshing appointments');
    await loadAppointments();
  }
  
  // Get appointment by ID
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('AppointmentsProvider: Getting appointment with ID: $appointmentId');
      final appointment = await _firebaseService.getAppointmentById(appointmentId);
      return appointment;
      
    } catch (e) {
      debugPrint('AppointmentsProvider: Error getting appointment by ID: $e');
      _errorMessage = 'Failed to get appointment: ${e.toString()}';
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  
  // Cancel an appointment with a reason
  Future<bool> cancelAppointment(String appointmentId, String reason) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('AppointmentsProvider: Cancelling appointment with ID: $appointmentId');
      await _firebaseService.cancelAppointment(appointmentId, reason);
      debugPrint('AppointmentsProvider: Appointment cancelled successfully');
      
      // Refresh the appointment lists
      await loadAppointments();
      return true;
      
    } catch (e) {
      debugPrint('AppointmentsProvider: Error cancelling appointment: $e');
      _errorMessage = 'Failed to cancel appointment: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
  
  // Reschedule an appointment
  Future<bool> rescheduleAppointment(String appointmentId, DateTime newDate, String newTime) async {
    try {
      _isLoading = true;
      _errorMessage = null;
      notifyListeners();
      
      debugPrint('AppointmentsProvider: Rescheduling appointment with ID: $appointmentId');
      await _firebaseService.rescheduleAppointment(appointmentId, newDate, newTime);
      debugPrint('AppointmentsProvider: Appointment rescheduled successfully');
      
      // Refresh the appointment lists
      await loadAppointments();
      return true;
      
    } catch (e) {
      debugPrint('AppointmentsProvider: Error rescheduling appointment: $e');
      _errorMessage = 'Failed to reschedule appointment: ${e.toString()}';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }
} 