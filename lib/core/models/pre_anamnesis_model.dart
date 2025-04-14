import 'package:cloud_firestore/cloud_firestore.dart';

class PreAnamnesisModel {
  final String id;
  final String patientId;
  final String? doctorId;
  final String? appointmentId;
  final String symptoms;
  final String duration;
  final String? medications;
  final String? painLevel;
  final String? allergies;
  final String? additionalInfo;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  PreAnamnesisModel({
    required this.id,
    required this.patientId,
    this.doctorId,
    this.appointmentId,
    required this.symptoms,
    required this.duration,
    this.medications,
    this.painLevel,
    this.allergies,
    this.additionalInfo,
    required this.createdAt,
    required this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'doctorId': doctorId,
      'appointmentId': appointmentId,
      'symptoms': symptoms,
      'duration': duration,
      'medications': medications,
      'painLevel': painLevel,
      'allergies': allergies,
      'additionalInfo': additionalInfo,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
  
  factory PreAnamnesisModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PreAnamnesisModel(
      id: documentId,
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'],
      appointmentId: map['appointmentId'],
      symptoms: map['symptoms'] ?? '',
      duration: map['duration'] ?? '',
      medications: map['medications'],
      painLevel: map['painLevel'],
      allergies: map['allergies'],
      additionalInfo: map['additionalInfo'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  PreAnamnesisModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? appointmentId,
    String? symptoms,
    String? duration,
    String? medications,
    String? painLevel,
    String? allergies,
    String? additionalInfo,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return PreAnamnesisModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      appointmentId: appointmentId ?? this.appointmentId,
      symptoms: symptoms ?? this.symptoms,
      duration: duration ?? this.duration,
      medications: medications ?? this.medications,
      painLevel: painLevel ?? this.painLevel,
      allergies: allergies ?? this.allergies,
      additionalInfo: additionalInfo ?? this.additionalInfo,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 