import 'package:cloud_firestore/cloud_firestore.dart';
import 'user_model.dart';

class PatientModel {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final String? profileImageUrl;
  final DateTime? dateOfBirth;
  final String? gender;
  final double? height;
  final double? weight;
  final String? bloodGroup;
  final List<String>? allergies;
  final List<String>? chronicConditions;
  final List<String>? medications;
  final Map<String, dynamic>? medicalHistory;
  final Map<String, dynamic>? emergencyContact;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  PatientModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    this.profileImageUrl,
    this.dateOfBirth,
    this.gender,
    this.height,
    this.weight,
    this.bloodGroup,
    this.allergies,
    this.chronicConditions,
    this.medications,
    this.medicalHistory,
    this.emergencyContact,
    required this.createdAt,
    required this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'profileImageUrl': profileImageUrl,
      'dateOfBirth': dateOfBirth != null ? Timestamp.fromDate(dateOfBirth!) : null,
      'gender': gender,
      'height': height,
      'weight': weight,
      'bloodGroup': bloodGroup,
      'allergies': allergies,
      'chronicConditions': chronicConditions,
      'medications': medications,
      'medicalHistory': medicalHistory,
      'emergencyContact': emergencyContact,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
  
  factory PatientModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PatientModel(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      profileImageUrl: map['profileImageUrl'],
      dateOfBirth: map['dateOfBirth'] != null ? (map['dateOfBirth'] as Timestamp).toDate() : null,
      gender: map['gender'],
      height: map['height']?.toDouble(),
      weight: map['weight']?.toDouble(),
      bloodGroup: map['bloodGroup'],
      allergies: map['allergies'] != null ? List<String>.from(map['allergies']) : null,
      chronicConditions: map['chronicConditions'] != null ? List<String>.from(map['chronicConditions']) : null,
      medications: map['medications'] != null ? List<String>.from(map['medications']) : null,
      medicalHistory: map['medicalHistory'],
      emergencyContact: map['emergencyContact'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  // Create a PatientModel from a UserModel
  factory PatientModel.fromUserModel(UserModel user) {
    final Map<String, dynamic> medicalInfo = user.medicalInfo ?? {};
    
    return PatientModel(
      id: user.id,
      name: user.name,
      email: user.email,
      phoneNumber: user.phoneNumber,
      profileImageUrl: user.profileImageUrl,
      dateOfBirth: medicalInfo['dateOfBirth'] != null ? 
        (medicalInfo['dateOfBirth'] is String ? 
          DateTime.tryParse(medicalInfo['dateOfBirth']) : 
          (medicalInfo['dateOfBirth'] as Timestamp?)?.toDate())
        : null,
      gender: medicalInfo['gender'],
      height: medicalInfo['height']?.toDouble(),
      weight: medicalInfo['weight']?.toDouble(),
      bloodGroup: medicalInfo['bloodGroup'],
      allergies: medicalInfo['allergies'] != null ? List<String>.from(medicalInfo['allergies']) : null,
      chronicConditions: medicalInfo['chronicConditions'] != null ? List<String>.from(medicalInfo['chronicConditions']) : null,
      medications: medicalInfo['medications'] != null ? List<String>.from(medicalInfo['medications']) : null,
      medicalHistory: medicalInfo['medicalHistory'],
      emergencyContact: medicalInfo['emergencyContact'],
      createdAt: user.createdAt,
      updatedAt: user.updatedAt,
    );
  }
  
  PatientModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    String? profileImageUrl,
    DateTime? dateOfBirth,
    String? gender,
    double? height,
    double? weight,
    String? bloodGroup,
    List<String>? allergies,
    List<String>? chronicConditions,
    List<String>? medications,
    Map<String, dynamic>? medicalHistory,
    Map<String, dynamic>? emergencyContact,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return PatientModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      dateOfBirth: dateOfBirth ?? this.dateOfBirth,
      gender: gender ?? this.gender,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      allergies: allergies ?? this.allergies,
      chronicConditions: chronicConditions ?? this.chronicConditions,
      medications: medications ?? this.medications,
      medicalHistory: medicalHistory ?? this.medicalHistory,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 