import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, voice }

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final bool isRead;
  final Timestamp timestamp;
  final MessageType type;
  final String? attachmentUrl;
  
  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.isRead,
    required this.timestamp,
    required this.type,
    this.attachmentUrl,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'isRead': isRead,
      'timestamp': timestamp,
      'type': _messageTypeToString(type),
      'attachmentUrl': attachmentUrl,
    };
  }
  
  factory MessageModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MessageModel(
      id: documentId,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      isRead: map['isRead'] ?? false,
      timestamp: map['timestamp'] ?? Timestamp.now(),
      type: _stringToMessageType(map['type']),
      attachmentUrl: map['attachmentUrl'],
    );
  }
  
  static String _messageTypeToString(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.voice:
        return 'voice';
      default:
        return 'text';
    }
  }
  
  static MessageType _stringToMessageType(String? type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'voice':
        return MessageType.voice;
      default:
        return MessageType.text;
    }
  }
  
  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    bool? isRead,
    Timestamp? timestamp,
    MessageType? type,
    String? attachmentUrl,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      isRead: isRead ?? this.isRead,
      timestamp: timestamp ?? this.timestamp,
      type: type ?? this.type,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
    );
  }
} 