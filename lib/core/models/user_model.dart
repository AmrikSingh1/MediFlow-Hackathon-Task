import 'package:cloud_firestore/cloud_firestore.dart';

enum UserRole { patient, doctor }

class UserModel {
  final String id;
  final String name;
  final String email;
  final String? phoneNumber;
  final UserRole role;
  final String? profileImageUrl;
  final Map<String, dynamic>? medicalInfo;
  final Map<String, dynamic>? doctorInfo;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.phoneNumber,
    required this.role,
    this.profileImageUrl,
    this.medicalInfo,
    this.doctorInfo,
    required this.createdAt,
    required this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'role': role == UserRole.patient ? 'patient' : 'doctor',
      'profileImageUrl': profileImageUrl,
      'medicalInfo': medicalInfo,
      'doctorInfo': doctorInfo,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
  
  factory UserModel.fromMap(Map<String, dynamic> map, String documentId) {
    return UserModel(
      id: documentId,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phoneNumber: map['phoneNumber'],
      role: map['role'] == 'patient' ? UserRole.patient : UserRole.doctor,
      profileImageUrl: map['profileImageUrl'],
      medicalInfo: map['medicalInfo'],
      doctorInfo: map['doctorInfo'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  factory UserModel.empty() {
    return UserModel(
      id: '',
      name: '',
      email: '',
      role: UserRole.patient,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }
  
  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    UserRole? role,
    String? profileImageUrl,
    Map<String, dynamic>? medicalInfo,
    Map<String, dynamic>? doctorInfo,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      role: role ?? this.role,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      medicalInfo: medicalInfo ?? this.medicalInfo,
      doctorInfo: doctorInfo ?? this.doctorInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 