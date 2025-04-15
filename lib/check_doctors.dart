import 'package:flutter/material.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:firebase_core/firebase_core.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  final firebaseService = FirebaseService();
  final doctors = await firebaseService.getDoctors();
  
  int completedProfiles = 0;
  int incompleteProfiles = 0;
  
  for (final doctor in doctors) {
    if (doctor.doctorInfo != null && 
        doctor.doctorInfo!.containsKey('specialty') && 
        doctor.doctorInfo!.containsKey('education') &&
        doctor.doctorInfo!.containsKey('licenseNumber')) {
      completedProfiles++;
      print('✅ Doctor ${doctor.name} has completed profile');
    } else {
      incompleteProfiles++;
      print('❌ Doctor ${doctor.name} has incomplete profile');
      
      // Print what's missing
      if (doctor.doctorInfo == null) {
        print('   - Missing all doctor info');
      } else {
        if (!doctor.doctorInfo!.containsKey('specialty')) print('   - Missing specialty');
        if (!doctor.doctorInfo!.containsKey('education')) print('   - Missing education');
        if (!doctor.doctorInfo!.containsKey('licenseNumber')) print('   - Missing license number');
      }
    }
  }
  
  print('\n--- Summary ---');
  print('Total doctors: ${doctors.length}');
  print('Completed profiles: $completedProfiles');
  print('Incomplete profiles: $incompleteProfiles');
  print('Completion rate: ${doctors.isEmpty ? 0 : (completedProfiles / doctors.length * 100).toStringAsFixed(1)}%');
} 