import 'package:cloud_firestore/cloud_firestore.dart';

class InvitationModel {
  final String id;
  final String doctorId;
  final String doctorName;
  final String patientEmail;
  final String status; // 'pending', 'accepted', 'declined'
  final String? message;
  final Timestamp createdAt;
  final Timestamp expiresAt;
  final Timestamp? acceptedAt;
  final Map<String, dynamic>? doctorDetails;

  InvitationModel({
    required this.id,
    required this.doctorId,
    required this.doctorName,
    required this.patientEmail,
    required this.status,
    this.message,
    required this.createdAt,
    required this.expiresAt,
    this.acceptedAt,
    this.doctorDetails,
  });

  factory InvitationModel.fromMap(Map<String, dynamic> map, String documentId) {
    return InvitationModel(
      id: documentId,
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      patientEmail: map['patientEmail'] ?? '',
      status: map['status'] ?? 'pending',
      message: map['message'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      expiresAt: map['expiresAt'] ?? Timestamp.fromDate(DateTime.now().add(const Duration(days: 7))),
      acceptedAt: map['acceptedAt'],
      doctorDetails: map['doctorDetails'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'doctorName': doctorName,
      'patientEmail': patientEmail,
      'status': status,
      'message': message,
      'createdAt': createdAt,
      'expiresAt': expiresAt,
      'acceptedAt': acceptedAt,
      'doctorDetails': doctorDetails,
    };
  }

  InvitationModel copyWith({
    String? id,
    String? doctorId,
    String? doctorName,
    String? patientEmail,
    String? status,
    String? message,
    Timestamp? createdAt,
    Timestamp? expiresAt,
    Timestamp? acceptedAt,
    Map<String, dynamic>? doctorDetails,
  }) {
    return InvitationModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      patientEmail: patientEmail ?? this.patientEmail,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      doctorDetails: doctorDetails ?? this.doctorDetails,
    );
  }
} 