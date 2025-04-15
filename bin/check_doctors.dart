import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> main() async {
  await Firebase.initializeApp();
  
  final firestore = FirebaseFirestore.instance;
  final querySnapshot = await firestore.collection('users')
      .where('role', isEqualTo: 'doctor')
      .get();
  
  final doctors = querySnapshot.docs;
  
  int completedProfiles = 0;
  int incompleteProfiles = 0;
  
  for (final doctorDoc in doctors) {
    final data = doctorDoc.data();
    final doctorInfo = data['doctorInfo'];
    final name = data['name'] ?? 'Unknown';
    
    if (doctorInfo != null && 
        doctorInfo['specialty'] != null && 
        doctorInfo['education'] != null &&
        doctorInfo['licenseNumber'] != null) {
      completedProfiles++;
      print('✅ Doctor $name has completed profile');
    } else {
      incompleteProfiles++;
      print('❌ Doctor $name has incomplete profile');
      
      // Print what's missing
      if (doctorInfo == null) {
        print('   - Missing all doctor info');
      } else {
        if (doctorInfo['specialty'] == null) print('   - Missing specialty');
        if (doctorInfo['education'] == null) print('   - Missing education');
        if (doctorInfo['licenseNumber'] == null) print('   - Missing license number');
      }
    }
  }
  
  print('\n--- Summary ---');
  print('Total doctors: ${doctors.length}');
  print('Completed profiles: $completedProfiles');
  print('Incomplete profiles: $incompleteProfiles');
  print('Completion rate: ${doctors.isEmpty ? 0 : (completedProfiles / doctors.length * 100).toStringAsFixed(1)}%');
} 