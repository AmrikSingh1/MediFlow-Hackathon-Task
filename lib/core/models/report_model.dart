import 'package:cloud_firestore/cloud_firestore.dart';

enum ReportStatus {
  draft, // Initial state when sent by patient
  reviewed, // Doctor has reviewed but not finalized
  finalized, // Final report
}

class ReportModel {
  final String id;
  final String patientId;
  final String patientName;
  final String doctorId;
  final String? appointmentId;
  final String content;
  final String? correctedContent;
  final ReportStatus status;
  final bool isSavedToProfile;
  final bool isSentToPatient;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  final String? pdfUrl;
  
  ReportModel({
    required this.id,
    required this.patientId,
    required this.patientName,
    required this.doctorId,
    this.appointmentId,
    required this.content,
    this.correctedContent,
    required this.status,
    required this.isSavedToProfile,
    required this.isSentToPatient,
    required this.createdAt,
    required this.updatedAt,
    this.pdfUrl,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientId': patientId,
      'patientName': patientName,
      'doctorId': doctorId,
      'appointmentId': appointmentId,
      'content': content,
      'correctedContent': correctedContent,
      'status': _statusToString(status),
      'isSavedToProfile': isSavedToProfile,
      'isSentToPatient': isSentToPatient,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      'pdfUrl': pdfUrl,
    };
  }
  
  factory ReportModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ReportModel(
      id: documentId,
      patientId: map['patientId'] ?? '',
      patientName: map['patientName'] ?? 'Unknown Patient',
      doctorId: map['doctorId'] ?? '',
      appointmentId: map['appointmentId'],
      content: map['content'] ?? '',
      correctedContent: map['correctedContent'],
      status: _stringToStatus(map['status']),
      isSavedToProfile: map['isSavedToProfile'] ?? false,
      isSentToPatient: map['isSentToPatient'] ?? false,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
      pdfUrl: map['pdfUrl'],
    );
  }
  
  ReportModel copyWith({
    String? id,
    String? patientId,
    String? patientName,
    String? doctorId,
    String? appointmentId,
    String? content,
    String? correctedContent,
    ReportStatus? status,
    bool? isSavedToProfile,
    bool? isSentToPatient,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    String? pdfUrl,
  }) {
    return ReportModel(
      id: id ?? this.id,
      patientId: patientId ?? this.patientId,
      patientName: patientName ?? this.patientName,
      doctorId: doctorId ?? this.doctorId,
      appointmentId: appointmentId ?? this.appointmentId,
      content: content ?? this.content,
      correctedContent: correctedContent ?? this.correctedContent,
      status: status ?? this.status,
      isSavedToProfile: isSavedToProfile ?? this.isSavedToProfile,
      isSentToPatient: isSentToPatient ?? this.isSentToPatient,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      pdfUrl: pdfUrl ?? this.pdfUrl,
    );
  }
  
  // Helper methods for status conversion
  static String _statusToString(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return 'draft';
      case ReportStatus.reviewed:
        return 'reviewed';
      case ReportStatus.finalized:
        return 'finalized';
      default:
        return 'draft';
    }
  }
  
  static ReportStatus _stringToStatus(String? status) {
    switch (status) {
      case 'draft':
        return ReportStatus.draft;
      case 'reviewed':
        return ReportStatus.reviewed;
      case 'finalized':
        return ReportStatus.finalized;
      default:
        return ReportStatus.draft;
    }
  }

  // Public methods for status conversion (available externally)
  static String statusToString(ReportStatus status) {
    return _statusToString(status);
  }
  
  static ReportStatus stringToStatus(String? status) {
    return _stringToStatus(status);
  }
} 