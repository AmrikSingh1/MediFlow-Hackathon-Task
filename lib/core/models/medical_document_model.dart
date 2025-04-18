import 'package:cloud_firestore/cloud_firestore.dart';

class MedicalDocumentModel {
  final String id;
  final String senderId;
  final String recipientId;
  final String documentName;
  final String documentUrl;
  final String documentType;
  final String? description;
  final bool isRead;
  final Timestamp sharedAt;
  final Timestamp? readAt;
  
  MedicalDocumentModel({
    required this.id,
    required this.senderId,
    required this.recipientId,
    required this.documentName,
    required this.documentUrl,
    required this.documentType,
    this.description,
    required this.isRead,
    required this.sharedAt,
    this.readAt,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'senderId': senderId,
      'recipientId': recipientId,
      'documentName': documentName,
      'documentUrl': documentUrl,
      'documentType': documentType,
      'description': description,
      'isRead': isRead,
      'sharedAt': sharedAt,
      'readAt': readAt,
    };
  }
  
  factory MedicalDocumentModel.fromMap(Map<String, dynamic> map) {
    return MedicalDocumentModel(
      id: map['id'] ?? '',
      senderId: map['senderId'] ?? '',
      recipientId: map['recipientId'] ?? '',
      documentName: map['documentName'] ?? '',
      documentUrl: map['documentUrl'] ?? '',
      documentType: map['documentType'] ?? '',
      description: map['description'],
      isRead: map['isRead'] ?? false,
      sharedAt: map['sharedAt'] ?? Timestamp.now(),
      readAt: map['readAt'],
    );
  }
  
  MedicalDocumentModel copyWith({
    String? id,
    String? senderId,
    String? recipientId,
    String? documentName,
    String? documentUrl,
    String? documentType,
    String? description,
    bool? isRead,
    Timestamp? sharedAt,
    Timestamp? readAt,
  }) {
    return MedicalDocumentModel(
      id: id ?? this.id,
      senderId: senderId ?? this.senderId,
      recipientId: recipientId ?? this.recipientId,
      documentName: documentName ?? this.documentName,
      documentUrl: documentUrl ?? this.documentUrl,
      documentType: documentType ?? this.documentType,
      description: description ?? this.description,
      isRead: isRead ?? this.isRead,
      sharedAt: sharedAt ?? this.sharedAt,
      readAt: readAt ?? this.readAt,
    );
  }
} 