import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class DoctorModel {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final String profileImageUrl;
  final String specialty;
  final double rating;
  final int ratingCount;
  final int experience;
  final String hospitalAffiliation;
  final bool isAvailable;
  final List<String> qualifications;
  final Map<String, List<String>>? workSchedule;
  final Map<String, List<String>>? availableSlots;
  final DateTime createdAt;
  final DateTime updatedAt;
  final Map<String, dynamic>? medicalInfo;
  
  DoctorModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.profileImageUrl,
    required this.specialty,
    required this.rating,
    required this.ratingCount,
    required this.experience,
    required this.hospitalAffiliation,
    required this.isAvailable,
    required this.qualifications,
    this.workSchedule,
    this.availableSlots,
    required this.createdAt,
    required this.updatedAt,
    this.medicalInfo,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'specialty': specialty,
      'rating': rating,
      'ratingCount': ratingCount,
      'experience': experience,
      'hospitalAffiliation': hospitalAffiliation,
      'isAvailable': isAvailable,
      'qualifications': qualifications,
      'workSchedule': workSchedule,
      'availableSlots': availableSlots,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'updatedAt': updatedAt.millisecondsSinceEpoch,
      'medicalInfo': medicalInfo,
    };
  }
  
  factory DoctorModel.fromMap(Map<String, dynamic> map, [String? docId]) {
    return DoctorModel(
      id: docId ?? map['id'] ?? '',
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'] ?? '',
      profileImageUrl: map['profileImageUrl'] ?? '',
      specialty: map['specialty'] ?? '',
      rating: map['rating']?.toDouble() ?? 0.0,
      ratingCount: map['ratingCount']?.toInt() ?? 0,
      experience: map['experience']?.toInt() ?? 0,
      hospitalAffiliation: map['hospitalAffiliation'] ?? '',
      isAvailable: map['isAvailable'] ?? false,
      qualifications: List<String>.from(map['qualifications'] ?? []),
      workSchedule: map['workSchedule'] != null
          ? Map<String, List<String>>.from(
              map['workSchedule']?.map(
                (key, value) => MapEntry(
                  key,
                  List<String>.from(value),
                ),
              ),
            )
          : null,
      availableSlots: map['availableSlots'] != null
          ? Map<String, List<String>>.from(
              map['availableSlots']?.map(
                (key, value) => MapEntry(
                  key,
                  List<String>.from(value),
                ),
              ),
            )
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['createdAt']),
      updatedAt: DateTime.fromMillisecondsSinceEpoch(map['updatedAt']),
      medicalInfo: map['medicalInfo'],
    );
  }
  
  // Create a default work schedule (Mon-Sat, 9AM-6PM, 30-min slots)
  static Map<String, List<String>> createDefaultSchedule() {
    final Map<String, List<String>> schedule = {};
    final List<String> weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    
    for (final day in weekdays) {
      final List<String> slots = [];
      // Create slots from 9:00 AM to 6:00 PM with 30-minute intervals
      for (int hour = 9; hour < 18; hour++) {
        final String hourStr = hour <= 12 ? '$hour' : '${hour - 12}';
        final String amPm = hour < 12 ? 'AM' : 'PM';
        
        slots.add('$hourStr:00 $amPm');
        slots.add('$hourStr:30 $amPm');
      }
      schedule[day] = slots;
    }
    
    return schedule;
  }
  
  // Create initial available slots based on the current date
  static Map<String, List<String>> createInitialAvailableSlots() {
    final Map<String, List<String>> availableSlots = {};
    final DateTime now = DateTime.now();
    
    // Create slots for the next 30 days
    for (int i = 0; i < 30; i++) {
      final DateTime date = now.add(Duration(days: i));
      final String dateStr = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      
      // Skip Sundays
      if (date.weekday == 7) continue;
      
      final List<String> slots = [];
      // Create slots from 9:00 AM to 6:00 PM with 30-minute intervals
      for (int hour = 9; hour < 18; hour++) {
        final String hourStr = hour <= 12 ? '$hour' : '${hour - 12}';
        final String amPm = hour < 12 ? 'AM' : 'PM';
        
        slots.add('$hourStr:00 $amPm');
        slots.add('$hourStr:30 $amPm');
      }
      
      availableSlots[dateStr] = slots;
    }
    
    return availableSlots;
  }
  
  // Create a DoctorModel from a UserModel
  factory DoctorModel.fromUserModel(UserModel user) {
    return DoctorModel(
      id: user.id,
      name: user.name,
      email: user.email,
      phoneNumber: user.phoneNumber ?? '',
      profileImageUrl: user.profileImageUrl ?? '',
      specialty: '',
      rating: 0.0,
      ratingCount: 0,
      experience: 0,
      hospitalAffiliation: '',
      isAvailable: true,
      qualifications: [],
      workSchedule: createDefaultSchedule(),
      availableSlots: createInitialAvailableSlots(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      medicalInfo: {},
    );
  }
  
  DoctorModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    String? specialty,
    double? rating,
    int? ratingCount,
    int? experience,
    String? hospitalAffiliation,
    bool? isAvailable,
    List<String>? qualifications,
    Map<String, List<String>>? workSchedule,
    Map<String, List<String>>? availableSlots,
    DateTime? createdAt,
    DateTime? updatedAt,
    Map<String, dynamic>? medicalInfo,
  }) {
    return DoctorModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      specialty: specialty ?? this.specialty,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      experience: experience ?? this.experience,
      hospitalAffiliation: hospitalAffiliation ?? this.hospitalAffiliation,
      isAvailable: isAvailable ?? this.isAvailable,
      qualifications: qualifications ?? this.qualifications,
      workSchedule: workSchedule ?? this.workSchedule,
      availableSlots: availableSlots ?? this.availableSlots,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      medicalInfo: medicalInfo ?? this.medicalInfo,
    );
  }
} 