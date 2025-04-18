import 'package:cloud_firestore/cloud_firestore.dart';

class AppointmentSlotModel {
  final String id;
  final String doctorId;
  final String? patientId; // null means the slot is available
  final DateTime date;
  final String timeSlot;
  final bool isBooked;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  AppointmentSlotModel({
    required this.id,
    required this.doctorId,
    this.patientId,
    required this.date,
    required this.timeSlot,
    required this.isBooked,
    required this.createdAt,
    required this.updatedAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'doctorId': doctorId,
      'patientId': patientId,
      'date': Timestamp.fromDate(date),
      'timeSlot': timeSlot,
      'isBooked': isBooked,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
  
  factory AppointmentSlotModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AppointmentSlotModel(
      id: documentId,
      doctorId: map['doctorId'] ?? '',
      patientId: map['patientId'],
      date: map['date'] != null ? (map['date'] as Timestamp).toDate() : DateTime.now(),
      timeSlot: map['timeSlot'] ?? '',
      isBooked: map['isBooked'] ?? false,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
    );
  }
  
  // Create an available slot
  factory AppointmentSlotModel.available({
    required String doctorId, 
    required DateTime date, 
    required String timeSlot
  }) {
    return AppointmentSlotModel(
      id: '',
      doctorId: doctorId,
      patientId: null,
      date: date,
      timeSlot: timeSlot,
      isBooked: false,
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
  }
  
  // Book this slot for a patient
  AppointmentSlotModel book(String patientId) {
    return AppointmentSlotModel(
      id: id,
      doctorId: doctorId,
      patientId: patientId,
      date: date,
      timeSlot: timeSlot,
      isBooked: true,
      createdAt: createdAt,
      updatedAt: Timestamp.now(),
    );
  }
  
  // Cancel a booking
  AppointmentSlotModel cancel() {
    return AppointmentSlotModel(
      id: id,
      doctorId: doctorId,
      patientId: null,
      date: date,
      timeSlot: timeSlot,
      isBooked: false,
      createdAt: createdAt,
      updatedAt: Timestamp.now(),
    );
  }
  
  AppointmentSlotModel copyWith({
    String? id,
    String? doctorId,
    String? patientId,
    DateTime? date,
    String? timeSlot,
    bool? isBooked,
    Timestamp? createdAt,
    Timestamp? updatedAt,
  }) {
    return AppointmentSlotModel(
      id: id ?? this.id,
      doctorId: doctorId ?? this.doctorId,
      patientId: patientId ?? this.patientId,
      date: date ?? this.date,
      timeSlot: timeSlot ?? this.timeSlot,
      isBooked: isBooked ?? this.isBooked,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
} 