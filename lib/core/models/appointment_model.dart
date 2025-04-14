import 'package:cloud_firestore/cloud_firestore.dart';

enum AppointmentStatus { upcoming, past, cancelled }
enum AppointmentType { inPerson, video }

class AppointmentModel {
  final String id;
  final String patientId;
  final String doctorId;
  final Timestamp date;
  final String time;
  final AppointmentStatus status;
  final AppointmentType type;
  final String? location;
  final String? notes;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  // Doctor and patient details for UI display
  final Map<String, dynamic>? doctorDetails;
  final Map<String, dynamic>? patientDetails;
  
  AppointmentModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.date,
    required this.time,
    required this.status,
    required this.type,
    this.location,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    this.doctorDetails,
    this.patientDetails,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'date': date,
      'time': time,
      'status': _statusToString(status),
      'type': type == AppointmentType.inPerson ? 'in-person' : 'video',
      'location': location,
      'notes': notes,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'doctorDetails': doctorDetails,
      'patientDetails': patientDetails,
    };
  }
  
  factory AppointmentModel.fromMap(Map<String, dynamic> map, String documentId) {
    return AppointmentModel(
      id: documentId,
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      date: map['date'] as Timestamp? ?? Timestamp.now(),
      time: map['time'] ?? '',
      status: _stringToStatus(map['status']),
      type: map['type'] == 'in-person' ? AppointmentType.inPerson : AppointmentType.video,
      location: map['location'],
      notes: map['notes'],
      createdAt: map['createdAt'] as Timestamp? ?? Timestamp.now(),
      updatedAt: map['updatedAt'] as Timestamp? ?? Timestamp.now(),
      doctorDetails: map['doctorDetails'],
      patientDetails: map['patientDetails'],
    );
  }
  
  static String _statusToString(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.upcoming:
        return 'upcoming';
      case AppointmentStatus.past:
        return 'past';
      case AppointmentStatus.cancelled:
        return 'cancelled';
      default:
        return 'upcoming';
    }
  }
  
  static AppointmentStatus _stringToStatus(String? status) {
    switch (status) {
      case 'upcoming':
        return AppointmentStatus.upcoming;
      case 'past':
        return AppointmentStatus.past;
      case 'cancelled':
        return AppointmentStatus.cancelled;
      default:
        return AppointmentStatus.upcoming;
    }
  }
  
  AppointmentModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    Timestamp? date,
    String? time,
    AppointmentStatus? status,
    AppointmentType? type,
    String? location,
    String? notes,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Map<String, dynamic>? doctorDetails,
    Map<String, dynamic>? patientDetails,
  }) {
    return AppointmentModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      date: date ?? this.date,
      time: time ?? this.time,
      status: status ?? this.status,
      type: type ?? this.type,
      location: location ?? this.location,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      doctorDetails: doctorDetails ?? this.doctorDetails,
      patientDetails: patientDetails ?? this.patientDetails,
    );
  }
} 