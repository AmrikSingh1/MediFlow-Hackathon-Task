import 'package:cloud_firestore/cloud_firestore.dart';

class PrescriptionMedicine {
  final String name;
  final String dosage;
  final String frequency;
  final bool isMorning;
  final bool isAfternoon;
  final bool isEvening;
  final bool isBeforeMeal;
  final String? duration;
  final String? instructions;

  PrescriptionMedicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    this.isMorning = false,
    this.isAfternoon = false,
    this.isEvening = false,
    this.isBeforeMeal = false,
    this.duration,
    this.instructions,
  });

  factory PrescriptionMedicine.fromMap(Map<String, dynamic> map) {
    return PrescriptionMedicine(
      name: map['name'] ?? '',
      dosage: map['dosage'] ?? '',
      frequency: map['frequency'] ?? '',
      isMorning: map['isMorning'] ?? false,
      isAfternoon: map['isAfternoon'] ?? false,
      isEvening: map['isEvening'] ?? false,
      isBeforeMeal: map['isBeforeMeal'] ?? false,
      duration: map['duration'],
      instructions: map['instructions'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'dosage': dosage,
      'frequency': frequency,
      'isMorning': isMorning,
      'isAfternoon': isAfternoon,
      'isEvening': isEvening,
      'isBeforeMeal': isBeforeMeal,
      'duration': duration,
      'instructions': instructions,
    };
  }
}

class PrescriptionModel {
  final String id;
  final String patientId;
  final String doctorId;
  final String appointmentId;
  final String? diagnosis;
  final List<PrescriptionMedicine> medicines;
  final String? instructions;
  final String? notes;
  final bool isRefillable;
  final int refillsRemaining;
  final Timestamp issuedAt;
  final Timestamp? validUntil;
  final Map<String, dynamic>? doctorDetails;
  final Map<String, dynamic>? patientDetails;
  final bool isFilled;
  final Timestamp? filledAt;
  final String? pharmacyId;
  final String? pharmacyNotes;
  final Timestamp updatedAt;

  PrescriptionModel({
    required this.id,
    required this.patientId,
    required this.doctorId,
    required this.appointmentId,
    this.diagnosis,
    required this.medicines,
    this.instructions,
    this.notes,
    this.isRefillable = false,
    this.refillsRemaining = 0,
    required this.issuedAt,
    this.validUntil,
    this.doctorDetails,
    this.patientDetails,
    this.isFilled = false,
    this.filledAt,
    this.pharmacyId,
    this.pharmacyNotes,
    Timestamp? updatedAt,
  }) : this.updatedAt = updatedAt ?? issuedAt;

  factory PrescriptionModel.fromMap(Map<String, dynamic> map, String documentId) {
    return PrescriptionModel(
      id: documentId,
      patientId: map['patientId'] ?? '',
      doctorId: map['doctorId'] ?? '',
      appointmentId: map['appointmentId'] ?? '',
      diagnosis: map['diagnosis'],
      medicines: (map['medicines'] as List<dynamic>?)
          ?.map((medicine) => PrescriptionMedicine.fromMap(medicine))
          .toList() ?? [],
      instructions: map['instructions'],
      notes: map['notes'],
      isRefillable: map['isRefillable'] ?? false,
      refillsRemaining: map['refillsRemaining'] ?? 0,
      issuedAt: map['issuedAt'] ?? Timestamp.now(),
      validUntil: map['validUntil'],
      doctorDetails: map['doctorDetails'],
      patientDetails: map['patientDetails'],
      isFilled: map['isFilled'] ?? false,
      filledAt: map['filledAt'],
      pharmacyId: map['pharmacyId'],
      pharmacyNotes: map['pharmacyNotes'],
      updatedAt: map['updatedAt'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'patientId': patientId,
      'doctorId': doctorId,
      'appointmentId': appointmentId,
      'diagnosis': diagnosis,
      'medicines': medicines.map((medicine) => medicine.toMap()).toList(),
      'instructions': instructions,
      'notes': notes,
      'isRefillable': isRefillable,
      'refillsRemaining': refillsRemaining,
      'issuedAt': issuedAt,
      'validUntil': validUntil,
      'doctorDetails': doctorDetails,
      'patientDetails': patientDetails,
      'isFilled': isFilled,
      'filledAt': filledAt,
      'pharmacyId': pharmacyId,
      'pharmacyNotes': pharmacyNotes,
      'updatedAt': updatedAt,
    };
  }

  PrescriptionModel copyWith({
    String? id,
    String? patientId,
    String? doctorId,
    String? appointmentId,
    String? diagnosis,
    List<PrescriptionMedicine>? medicines,
    String? instructions,
    String? notes,
    bool? isRefillable,
    int? refillsRemaining,
    Timestamp? issuedAt,
    Timestamp? validUntil,
    Map<String, dynamic>? doctorDetails,
    Map<String, dynamic>? patientDetails,
    bool? isFilled,
    Timestamp? filledAt,
    String? pharmacyId,
    String? pharmacyNotes,
    Timestamp? updatedAt,
  }) {
    return PrescriptionModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      doctorId: doctorId ?? this.doctorId,
      appointmentId: appointmentId ?? this.appointmentId,
      diagnosis: diagnosis ?? this.diagnosis,
      medicines: medicines ?? this.medicines,
      instructions: instructions ?? this.instructions,
      notes: notes ?? this.notes,
      isRefillable: isRefillable ?? this.isRefillable,
      refillsRemaining: refillsRemaining ?? this.refillsRemaining,
      issuedAt: issuedAt ?? this.issuedAt,
      validUntil: validUntil ?? this.validUntil,
      doctorDetails: doctorDetails ?? this.doctorDetails,
      patientDetails: patientDetails ?? this.patientDetails,
      isFilled: isFilled ?? this.isFilled,
      filledAt: filledAt ?? this.filledAt,
      pharmacyId: pharmacyId ?? this.pharmacyId,
      pharmacyNotes: pharmacyNotes ?? this.pharmacyNotes,
      updatedAt: updatedAt ?? Timestamp.now(),
    );
  }
} 