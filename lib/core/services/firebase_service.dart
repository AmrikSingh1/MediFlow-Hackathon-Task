import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/models/chat_model.dart';
import 'package:medi_connect/core/models/message_model.dart';
import 'package:medi_connect/core/models/pre_anamnesis_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  
  // Collections
  final String _usersCollection = 'users';
  final String _appointmentsCollection = 'appointments';
  final String _chatsCollection = 'chats';
  final String _messagesCollection = 'messages';
  final String _preAnamnesisCollection = 'pre_anamnesis';
  
  // User operations
  Future<void> createUser(UserModel user) async {
    try {
      debugPrint("FirebaseService: Creating user with ID ${user.id} in Firestore");
      final userMap = user.toMap();
      debugPrint("User data: $userMap");
      await _firestore.collection(_usersCollection).doc(user.id).set(userMap);
      debugPrint("FirebaseService: User created successfully in Firestore");
    } catch (e) {
      debugPrint("FirebaseService: Error creating user: $e");
      rethrow;
    }
  }
  
  Future<UserModel?> getUserById(String userId) async {
    try {
      debugPrint("FirebaseService: Fetching user with ID $userId from Firestore");
      final doc = await _firestore.collection(_usersCollection).doc(userId).get();
      
      if (doc.exists) {
        final userData = doc.data();
        if (userData != null) {
          debugPrint("FirebaseService: User found: ${userData['name']}");
          return UserModel.fromMap(userData, doc.id);
        } else {
          debugPrint("FirebaseService: User document exists but data is null");
          return null;
        }
      } else {
        debugPrint("FirebaseService: User not found in Firestore");
        return null;
      }
    } catch (e) {
      debugPrint("FirebaseService: Error fetching user: $e");
      rethrow;
    }
  }
  
  Future<void> updateUser(UserModel user) async {
    try {
      debugPrint("FirebaseService: Updating user with ID ${user.id} in Firestore");
      final userMap = user.toMap();
      debugPrint("User update data: $userMap");
      await _firestore.collection(_usersCollection).doc(user.id).update(userMap);
      debugPrint("FirebaseService: User updated successfully in Firestore");
    } catch (e) {
      debugPrint("FirebaseService: Error updating user: $e");
      rethrow;
    }
  }
  
  // Appointment operations
  Future<String> createAppointment(AppointmentModel appointment) async {
    final appointmentId = _uuid.v4();
    final appointmentWithId = appointment.copyWith(id: appointmentId);
    await _firestore.collection(_appointmentsCollection).doc(appointmentId).set(appointmentWithId.toMap());
    return appointmentId;
  }
  
  Future<List<AppointmentModel>> getAppointmentsForUser(String userId, {AppointmentStatus? status}) async {
    Query query = _firestore.collection(_appointmentsCollection)
        .where('patientId', isEqualTo: userId);
    
    if (status != null) {
      query = query.where('status', isEqualTo: _getStatusString(status));
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => AppointmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }
  
  Future<List<AppointmentModel>> getAppointmentsForDoctor(String doctorId, {AppointmentStatus? status}) async {
    Query query = _firestore.collection(_appointmentsCollection)
        .where('doctorId', isEqualTo: doctorId);
    
    if (status != null) {
      query = query.where('status', isEqualTo: _getStatusString(status));
    }
    
    final snapshot = await query.get();
    return snapshot.docs.map((doc) => AppointmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)).toList();
  }
  
  Future<void> updateAppointment(AppointmentModel appointment) async {
    await _firestore.collection(_appointmentsCollection).doc(appointment.id).update(appointment.toMap());
  }
  
  // Fetch upcoming appointments
  Future<List<AppointmentModel>> getUpcomingAppointments(String userId, bool isDoctor) async {
    try {
      String userField = isDoctor ? 'doctorId' : 'patientId';
      debugPrint("FirebaseService: Fetching upcoming appointments for $userField: $userId");
      
      final snapshot = await _firestore
          .collection(_appointmentsCollection)
          .where(userField, isEqualTo: userId)
          .where('status', isEqualTo: 'upcoming')
          .get();
          
      final appointments = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
          
      debugPrint("FirebaseService: Found ${appointments.length} upcoming appointments");
      return appointments;
    } catch (e) {
      debugPrint("FirebaseService: Error fetching upcoming appointments: $e");
      return [];
    }
  }

  // Fetch past appointments
  Future<List<AppointmentModel>> getPastAppointments(String userId, bool isDoctor) async {
    try {
      String userField = isDoctor ? 'doctorId' : 'patientId';
      debugPrint("FirebaseService: Fetching past appointments for $userField: $userId");
      
      final snapshot = await _firestore
          .collection(_appointmentsCollection)
          .where(userField, isEqualTo: userId)
          .where('status', isEqualTo: 'past')
          .get();
          
      final appointments = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
          
      debugPrint("FirebaseService: Found ${appointments.length} past appointments");
      return appointments;
    } catch (e) {
      debugPrint("FirebaseService: Error fetching past appointments: $e");
      return [];
    }
  }

  // Fetch cancelled appointments
  Future<List<AppointmentModel>> getCancelledAppointments(String userId, bool isDoctor) async {
    try {
      String userField = isDoctor ? 'doctorId' : 'patientId';
      debugPrint("FirebaseService: Fetching cancelled appointments for $userField: $userId");
      
      final snapshot = await _firestore
          .collection(_appointmentsCollection)
          .where(userField, isEqualTo: userId)
          .where('status', isEqualTo: 'cancelled')
          .get();
          
      final appointments = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
          
      debugPrint("FirebaseService: Found ${appointments.length} cancelled appointments");
      return appointments;
    } catch (e) {
      debugPrint("FirebaseService: Error fetching cancelled appointments: $e");
      return [];
    }
  }
  
  // Helper method to convert AppointmentStatus to string
  String _getStatusString(AppointmentStatus status) {
    switch (status) {
      case AppointmentStatus.upcoming:
        return 'upcoming';
      case AppointmentStatus.past:
        return 'past';
      case AppointmentStatus.cancelled:
        return 'cancelled';
    }
  }
  
  // Chat operations
  Future<String> createChat(ChatModel chat) async {
    try {
      debugPrint("FirebaseService: Creating new chat with ID ${chat.id}");
      final chatId = _uuid.v4();
      final chatWithId = chat.copyWith(id: chatId);
      await _firestore.collection(_chatsCollection).doc(chatId).set(chatWithId.toMap());
      debugPrint("FirebaseService: Chat created successfully");
      return chatId;
    } catch (e) {
      debugPrint("FirebaseService: Error creating chat: $e");
      rethrow;
    }
  }
  
  Future<List<ChatModel>> getChatsForUser(String userId) async {
    try {
      debugPrint("FirebaseService: Fetching chats for user $userId");
      final snapshot = await _firestore.collection(_chatsCollection)
          .where('participants', arrayContains: userId)
          .orderBy('lastMessageTime', descending: true)
          .get();
      
      final chats = snapshot.docs.map((doc) => ChatModel.fromMap(doc.data(), doc.id)).toList();
      
      // For each chat, get the other participant's details
      for (int i = 0; i < chats.length; i++) {
        final chat = chats[i];
        final otherParticipants = chat.participants.where((id) => id != userId).toList();
        
        if (otherParticipants.isNotEmpty) {
          // Get the first other participant (typically a doctor or assistant)
          final otherUserId = otherParticipants.first;
          
          try {
            final userDoc = await _firestore.collection(_usersCollection).doc(otherUserId).get();
            if (userDoc.exists) {
              final userData = userDoc.data();
              if (userData != null) {
                Map<String, dynamic> participantDetails = {
                  'name': userData['name'] ?? 'Unknown',
                  'role': userData['role'] ?? 'user',
                  'specialty': userData['specialty'] ?? 
                               (userData['medicalInfo'] != null ? userData['medicalInfo']['specialty'] : null),
                  'isOnline': false, // Default to offline
                };
                
                // Overwrite with any specific details 
                if (chat.participantDetails != null) {
                  participantDetails.addAll(chat.participantDetails!);
                }
                
                // Update the chat with participant details
                chats[i] = chat.copyWith(participantDetails: participantDetails);
              }
            }
          } catch (e) {
            debugPrint("FirebaseService: Error fetching participant details: $e");
          }
        }
      }
      
      debugPrint("FirebaseService: Retrieved ${chats.length} chats for user");
      return chats;
    } catch (e) {
      debugPrint("FirebaseService: Error fetching chats: $e");
      rethrow;
    }
  }
  
  Future<void> updateChatLastMessage(String chatId, String message, Timestamp timestamp) async {
    try {
      debugPrint("FirebaseService: Updating last message for chat $chatId");
      await _firestore.collection(_chatsCollection).doc(chatId).update({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'updatedAt': timestamp,
      });
      debugPrint("FirebaseService: Chat last message updated successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error updating chat last message: $e");
      rethrow;
    }
  }
  
  Future<void> incrementUnreadCount(String chatId) async {
    await _firestore.collection(_chatsCollection).doc(chatId).update({
      'unreadCount': FieldValue.increment(1),
    });
  }
  
  Future<void> resetUnreadCount(String chatId) async {
    await _firestore.collection(_chatsCollection).doc(chatId).update({
      'unreadCount': 0,
    });
  }
  
  // Message operations
  Future<String> sendMessage(MessageModel message) async {
    final messageId = _uuid.v4();
    final messageWithId = message.copyWith(id: messageId);
    
    await _firestore.collection(_messagesCollection).doc(messageId).set(messageWithId.toMap());
    
    // Update chat last message
    await updateChatLastMessage(message.chatId, message.text, message.timestamp);
    
    return messageId;
  }
  
  Future<List<MessageModel>> getMessagesForChat(String chatId) async {
    final snapshot = await _firestore.collection(_messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp')
        .get();
    
    return snapshot.docs.map((doc) => MessageModel.fromMap(doc.data(), doc.id)).toList();
  }
  
  Stream<List<MessageModel>> streamMessagesForChat(String chatId) {
    return _firestore.collection(_messagesCollection)
        .where('chatId', isEqualTo: chatId)
        .orderBy('timestamp')
        .snapshots()
        .map((snapshot) => snapshot.docs.map((doc) => 
            MessageModel.fromMap(doc.data(), doc.id)).toList());
  }
  
  // Pre-Anamnesis operations
  Future<String> createPreAnamnesis(PreAnamnesisModel preAnamnesis) async {
    final preAnamnesisId = _uuid.v4();
    final preAnamnesisWithId = preAnamnesis.copyWith(id: preAnamnesisId);
    
    await _firestore.collection(_preAnamnesisCollection)
        .doc(preAnamnesisId)
        .set(preAnamnesisWithId.toMap());
    
    return preAnamnesisId;
  }
  
  Future<List<PreAnamnesisModel>> getPreAnamnesisForPatient(String patientId) async {
    final snapshot = await _firestore.collection(_preAnamnesisCollection)
        .where('patientId', isEqualTo: patientId)
        .orderBy('createdAt', descending: true)
        .get();
    
    return snapshot.docs.map((doc) => 
        PreAnamnesisModel.fromMap(doc.data(), doc.id)).toList();
  }
  
  // File storage operations
  Future<String> uploadFileBytes(String path, List<int> bytes, String contentType) async {
    // This is a placeholder method for file upload since we're not using Firebase Storage
    debugPrint('Uploading file: $path');
    // In a real app, this would upload to Firebase Storage
    
    // Return a fake URL for testing
    return 'https://example.com/uploads/$path';
  }
  
  Future<void> deleteFile(String path) async {
    // This is a placeholder method for file deletion since we're not using Firebase Storage
    debugPrint('Deleting file: $path');
    // In a real app, this would delete from Firebase Storage
  }

  // Get all doctors
  Future<List<UserModel>> getDoctors() async {
    try {
      final querySnapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'doctor')
          .get();
      
      final doctors = querySnapshot.docs.map((doc) {
        return UserModel.fromMap(doc.data(), doc.id);
      }).toList();
      
      debugPrint('FirebaseService: Successfully retrieved ${doctors.length} doctors');
      return doctors;
    } catch (e) {
      debugPrint('FirebaseService: Error getting doctors: $e');
      return [];
    }
  }
} 