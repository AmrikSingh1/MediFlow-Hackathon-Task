import 'package:cloud_firestore/cloud_firestore.dart';

class ChatModel {
  final String id;
  final List<String> participants;
  final String lastMessage;
  final Timestamp lastMessageTime;
  final int unreadCount;
  final Timestamp createdAt;
  final Timestamp updatedAt;
  
  // UI display information
  final Map<String, dynamic>? participantDetails;
  
  ChatModel({
    required this.id,
    required this.participants,
    required this.lastMessage,
    required this.lastMessageTime,
    required this.unreadCount,
    required this.createdAt,
    required this.updatedAt,
    this.participantDetails,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'participants': participants,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime,
      'unreadCount': unreadCount,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
    };
  }
  
  factory ChatModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ChatModel(
      id: documentId,
      participants: List<String>.from(map['participants'] ?? []),
      lastMessage: map['lastMessage'] ?? '',
      lastMessageTime: map['lastMessageTime'] ?? Timestamp.now(),
      unreadCount: map['unreadCount'] ?? 0,
      createdAt: map['createdAt'] ?? Timestamp.now(),
      updatedAt: map['updatedAt'] ?? Timestamp.now(),
      participantDetails: map['participantDetails'],
    );
  }
  
  ChatModel copyWith({
    String? id,
    List<String>? participants,
    String? lastMessage,
    Timestamp? lastMessageTime,
    int? unreadCount,
    Timestamp? createdAt,
    Timestamp? updatedAt,
    Map<String, dynamic>? participantDetails,
  }) {
    return ChatModel(
      id: id ?? this.id,
      participants: participants ?? this.participants,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      participantDetails: participantDetails ?? this.participantDetails,
    );
  }
} 