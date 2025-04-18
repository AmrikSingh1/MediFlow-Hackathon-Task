import 'package:cloud_firestore/cloud_firestore.dart';

class RatingModel {
  final String id;
  final String doctorId;
  final String patientId;
  final double rating;
  final String? comment;
  final Timestamp createdAt;
  final bool isAnonymous;
  
  RatingModel({
    required this.id,
    required this.doctorId,
    required this.patientId,
    required this.rating,
    this.comment,
    required this.createdAt,
    this.isAnonymous = false,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'doctorId': doctorId,
      'patientId': patientId,
      'rating': rating,
      'comment': comment,
      'createdAt': createdAt,
      'isAnonymous': isAnonymous,
    };
  }
  
  factory RatingModel.fromMap(Map<String, dynamic> map) {
    return RatingModel(
      id: map['id'] ?? '',
      doctorId: map['doctorId'] ?? '',
      patientId: map['patientId'] ?? '',
      rating: (map['rating'] ?? 0.0).toDouble(),
      comment: map['comment'],
      createdAt: map['createdAt'] ?? Timestamp.now(),
      isAnonymous: map['isAnonymous'] ?? false,
    );
  }
} 