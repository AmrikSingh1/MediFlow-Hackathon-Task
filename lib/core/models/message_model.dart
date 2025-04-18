import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType { text, image, document, audio, video, location }
enum MessageStatus { sent, delivered, read }

class MessageModel {
  final String id;
  final String chatId;
  final String senderId;
  final String text;
  final Timestamp timestamp;
  final MessageStatus status;
  final MessageType type;
  final Map<String, dynamic>? fileInfo;
  
  MessageModel({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.text,
    required this.timestamp,
    required this.status,
    this.type = MessageType.text,
    this.fileInfo,
  });
  
  Map<String, dynamic> toMap() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'text': text,
      'timestamp': timestamp,
      'status': _statusToString(status),
      'type': _typeToString(type),
      'fileInfo': fileInfo,
    };
  }
  
  factory MessageModel.fromMap(Map<String, dynamic> map, String documentId) {
    return MessageModel(
      id: documentId,
      chatId: map['chatId'] ?? '',
      senderId: map['senderId'] ?? '',
      text: map['text'] ?? '',
      timestamp: map['timestamp'] as Timestamp? ?? Timestamp.now(),
      status: _stringToStatus(map['status']),
      type: _stringToType(map['type']),
      fileInfo: map['fileInfo'],
    );
  }
  
  MessageModel copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? text,
    Timestamp? timestamp,
    MessageStatus? status,
    MessageType? type,
    Map<String, dynamic>? fileInfo,
  }) {
    return MessageModel(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      text: text ?? this.text,
      timestamp: timestamp ?? this.timestamp,
      status: status ?? this.status,
      type: type ?? this.type,
      fileInfo: fileInfo ?? this.fileInfo,
    );
  }
  
  static String _statusToString(MessageStatus status) {
    switch (status) {
      case MessageStatus.sent:
        return 'sent';
      case MessageStatus.delivered:
        return 'delivered';
      case MessageStatus.read:
        return 'read';
      default:
        return 'sent';
    }
  }
  
  static MessageStatus _stringToStatus(String? status) {
    switch (status) {
      case 'sent':
        return MessageStatus.sent;
      case 'delivered':
        return MessageStatus.delivered;
      case 'read':
        return MessageStatus.read;
      default:
        return MessageStatus.sent;
    }
  }
  
  static String _typeToString(MessageType type) {
    switch (type) {
      case MessageType.text:
        return 'text';
      case MessageType.image:
        return 'image';
      case MessageType.document:
        return 'document';
      case MessageType.audio:
        return 'audio';
      case MessageType.video:
        return 'video';
      case MessageType.location:
        return 'location';
      default:
        return 'text';
    }
  }
  
  static MessageType _stringToType(String? type) {
    switch (type) {
      case 'text':
        return MessageType.text;
      case 'image':
        return MessageType.image;
      case 'document':
        return MessageType.document;
      case 'audio':
        return MessageType.audio;
      case 'video':
        return MessageType.video;
      case 'location':
        return MessageType.location;
      default:
        return MessageType.text;
    }
  }
} 