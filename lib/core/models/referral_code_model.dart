import 'package:cloud_firestore/cloud_firestore.dart';

class ReferralCodeModel {
  final String id;
  final String code;
  final String doctorId;
  final String doctorName;
  final bool isUsed;
  final String? usedByPatientId;
  final String? usedByPatientName;
  final Timestamp createdAt;
  final Timestamp? usedAt;
  final Timestamp expiresAt;
  
  ReferralCodeModel({
    required this.id,
    required this.code,
    required this.doctorId,
    required this.doctorName,
    required this.isUsed,
    this.usedByPatientId,
    this.usedByPatientName,
    required this.createdAt,
    this.usedAt,
    required this.expiresAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'doctorId': doctorId,
      'doctorName': doctorName,
      'isUsed': isUsed,
      'usedByPatientId': usedByPatientId,
      'usedByPatientName': usedByPatientName,
      'createdAt': createdAt,
      'usedAt': usedAt,
      'expiresAt': expiresAt,
    };
  }
  
  factory ReferralCodeModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReferralCodeModel(
      id: documentId,
      code: map['code'] ?? '',
      doctorId: map['doctorId'] ?? '',
      doctorName: map['doctorName'] ?? '',
      isUsed: map['isUsed'] ?? false,
      usedByPatientId: map['usedByPatientId'],
      usedByPatientName: map['usedByPatientName'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      usedAt: map['usedAt'],
      expiresAt: map['expiresAt'] ?? Timestamp.now().toDate().add(const Duration(days: 30)),
    );
  }
  
  ReferralCodeModel copyWith({
    String? id,
    String? code,
    String? doctorId,
    String? doctorName,
    bool? isUsed,
    String? usedByPatientId,
    String? usedByPatientName,
    Timestamp? createdAt,
    Timestamp? usedAt,
    Timestamp? expiresAt,
  }) {
    return ReferralCodeModel(
      id: id ?? this.id,
      code: code ?? this.code,
      doctorId: doctorId ?? this.doctorId,
      doctorName: doctorName ?? this.doctorName,
      isUsed: isUsed ?? this.isUsed,
      usedByPatientId: usedByPatientId ?? this.usedByPatientId,
      usedByPatientName: usedByPatientName ?? this.usedByPatientName,
      createdAt: createdAt ?? this.createdAt,
      usedAt: usedAt ?? this.usedAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
  
  bool isExpired() {
    return expiresAt.toDate().isBefore(DateTime.now());
  }
  
  bool isValid() {
    return !isUsed && !isExpired();
  }
} 