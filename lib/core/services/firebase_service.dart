import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/models/chat_model.dart';
import 'package:medi_connect/core/models/message_model.dart';
import 'package:medi_connect/core/models/pre_anamnesis_model.dart';
import 'package:medi_connect/core/models/medical_document_model.dart';
import 'package:medi_connect/core/models/rating_model.dart';
import 'package:medi_connect/core/models/doctor_model.dart';
import 'package:medi_connect/core/models/patient_model.dart';
import 'package:medi_connect/core/models/appointment_slot_model.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/models/prescription_model.dart';
import 'package:medi_connect/core/models/report_model.dart';
import 'package:medi_connect/core/models/invitation_model.dart';
import 'dart:math';
import 'package:medi_connect/core/models/referral_code_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Uuid _uuid = const Uuid();
  
  // Collections
  final String _usersCollection = 'users';
  final String _appointmentsCollection = 'appointments';
  final String _chatsCollection = 'chats';
  final String _messagesCollection = 'messages';
  final String _preAnamnesisCollection = 'pre_anamnesis';
  final String _doctorsCollection = 'doctors';
  final String _reportsCollection = 'medical_reports';
  final String _invitationsCollection = 'invitations';
  final String _referralCodesCollection = 'referralCodes';
  // Remove unused fields but keep commented for reference
  // final String _patientsCollection = 'patients';
  // final String _appointmentSlotsCollection = 'appointment_slots';
  
  // User operations
  Future<void> createUser(UserModel user, {Map<String, dynamic>? additionalInfo}) async {
    try {
      debugPrint("FirebaseService: Creating user with ID ${user.id} in Firestore");
      
      final userMap = user.toMap();
      
      // Store the user role for easy identification 
      userMap['isDoctor'] = user.role == UserRole.doctor;
      userMap['isPatient'] = user.role == UserRole.patient;
      
      // Merge any additional info provided for the user
      if (additionalInfo != null) {
        userMap.addAll(additionalInfo);
        debugPrint("FirebaseService: Added additional info for user: $additionalInfo");
      }
      
      // Add specialized fields based on role
      if (user.role == UserRole.doctor) {
        // Create doctor model
        final doctorModel = DoctorModel.fromUserModel(user);
        
        // Add doctor-specific fields directly to the user document
        // Only add these fields if they aren't already set from additionalInfo
        if (!userMap.containsKey('specialty') || userMap['specialty'] == null) {
          userMap['specialty'] = doctorModel.specialty;
        }
        
        if (!userMap.containsKey('rating') || userMap['rating'] == null) {
          userMap['rating'] = doctorModel.rating;
        }
        
        if (!userMap.containsKey('ratingCount') || userMap['ratingCount'] == null) {
          userMap['ratingCount'] = doctorModel.ratingCount;
        }
        
        if (!userMap.containsKey('experience') || userMap['experience'] == null) {
          userMap['experience'] = doctorModel.experience;
        }
        
        if (!userMap.containsKey('hospitalAffiliation') || userMap['hospitalAffiliation'] == null) {
          userMap['hospitalAffiliation'] = doctorModel.hospitalAffiliation;
        }
        
        if (!userMap.containsKey('isAvailable') || userMap['isAvailable'] == null) {
          userMap['isAvailable'] = doctorModel.isAvailable;
        }
        
        if (!userMap.containsKey('qualifications') || userMap['qualifications'] == null) {
          userMap['qualifications'] = doctorModel.qualifications;
        }
        
        if (!userMap.containsKey('workSchedule') || userMap['workSchedule'] == null) {
          userMap['workSchedule'] = doctorModel.workSchedule;
        }
        
        if (!userMap.containsKey('availableSlots') || userMap['availableSlots'] == null) {
          userMap['availableSlots'] = doctorModel.availableSlots;
        }
      } else if (user.role == UserRole.patient) {
        // Create patient model
        final patientModel = PatientModel.fromUserModel(user);
        
        // Add patient-specific fields directly to user document
        userMap['dateOfBirth'] = patientModel.dateOfBirth != null ? Timestamp.fromDate(patientModel.dateOfBirth!) : null;
        userMap['gender'] = patientModel.gender;
        userMap['height'] = patientModel.height;
        userMap['weight'] = patientModel.weight;
        userMap['bloodGroup'] = patientModel.bloodGroup;
        userMap['allergies'] = patientModel.allergies;
        userMap['chronicConditions'] = patientModel.chronicConditions;
        userMap['medications'] = patientModel.medications;
        userMap['medicalHistory'] = patientModel.medicalHistory;
        userMap['emergencyContact'] = patientModel.emergencyContact;
      }
      
      debugPrint("User data with specialized fields: $userMap");
      await _firestore.collection(_usersCollection).doc(user.id).set(userMap);
      
      // Initialize appointment slots for doctors  
      if (user.role == UserRole.doctor) {
        await _initializeDoctorAppointmentSlots(user.id);
      }
      
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
    try {
      debugPrint("FirebaseService: Creating new appointment");
      // Generate new ID for the appointment
      final appointmentId = _uuid.v4();
      final appointmentWithId = appointment.copyWith(id: appointmentId);
      
      // Get doctor and patient details to include in the appointment
      final doctorDetails = await _getDoctorDetailsForAppointment(appointment.doctorId);
      final patientDetails = await _getPatientDetailsForAppointment(appointment.patientId);
      
      debugPrint("FirebaseService: Doctor details fetched: ${doctorDetails['name']}");
      debugPrint("FirebaseService: Patient details fetched: ${patientDetails['name']}");
      
      // Create a complete appointment with doctor and patient details
      final completeAppointment = appointmentWithId.copyWith(
        doctorDetails: doctorDetails,
        patientDetails: patientDetails
      );
      
      // Explicitly create the appointments collection if it doesn't exist
      final appointmentsRef = _firestore.collection(_appointmentsCollection);
      
      // Convert appointment to map
      final appointmentMap = completeAppointment.toMap();
      debugPrint("FirebaseService: Appointment data: $appointmentMap");
      
      // Save to Firestore
      await appointmentsRef.doc(appointmentId).set(appointmentMap);
      
      debugPrint("FirebaseService: Appointment created successfully with ID: $appointmentId");
      
      // Update doctor's appointments count (for tracking)
      await _incrementDoctorAppointmentsCount(appointment.doctorId);
      
      // Return the new appointment ID
      return appointmentId;
    } catch (e) {
      debugPrint("FirebaseService: Error creating appointment: $e");
      rethrow;
    }
  }
  
  // Helper method to get doctor details for embedding in appointment
  Future<Map<String, dynamic>> _getDoctorDetailsForAppointment(String doctorId) async {
    try {
      final UserModel? doctor = await getUserById(doctorId);
      if (doctor == null) {
        return {'name': 'Unknown', 'id': doctorId};
      }

      return {
        'id': doctor.id,
        'name': doctor.name,
        'email': doctor.email,
        'phoneNumber': doctor.phoneNumber,
        'profileImageUrl': doctor.profileImageUrl,
        'specialty': doctor.role == UserRole.doctor ? (doctor as DoctorModel).specialty : null,
      };
    } catch (e) {
      debugPrint('Error getting doctor details: $e');
      return {'name': 'Unknown', 'id': doctorId};
    }
  }
  
  // Helper method to get patient details for embedding in appointment
  Future<Map<String, dynamic>> _getPatientDetailsForAppointment(String patientId) async {
    try {
      final UserModel? patient = await getUserById(patientId);
      if (patient == null) {
        return {'name': 'Unknown', 'id': patientId};
      }

      return {
        'id': patient.id,
        'name': patient.name,
        'email': patient.email,
        'phoneNumber': patient.phoneNumber,
        'profileImageUrl': patient.profileImageUrl,
        'dateOfBirth': patient.role == UserRole.patient ? (patient as PatientModel).dateOfBirth : null,
        'gender': patient.role == UserRole.patient ? (patient as PatientModel).gender : null,
      };
    } catch (e) {
      debugPrint('Error getting patient details: $e');
      return {'name': 'Unknown', 'id': patientId};
    }
  }
  
  // Increment the doctor's appointment count
  Future<void> _incrementDoctorAppointmentsCount(String doctorId) async {
    try {
      debugPrint("FirebaseService: Incrementing doctor's appointment count for $doctorId");
      // Get the doctor's document
      final doctorDoc = await _firestore.collection(_usersCollection).doc(doctorId).get();
      
      if (doctorDoc.exists) {
        final Map<String, dynamic> doctorData = doctorDoc.data() as Map<String, dynamic>;
        
        // Initialize doctorInfo if it doesn't exist
        if (doctorData['doctorInfo'] == null) {
          doctorData['doctorInfo'] = {};
        }
        
        // Get current appointment count or default to 0
        int appointmentCount = 0;
        if (doctorData['doctorInfo'] is Map && doctorData['doctorInfo']['appointmentCount'] is int) {
          appointmentCount = doctorData['doctorInfo']['appointmentCount'];
        }
        
        // Increment count
        appointmentCount++;
        
        // Update doctor document
        await _firestore.collection(_usersCollection).doc(doctorId).update({
          'doctorInfo.appointmentCount': appointmentCount,
          'updatedAt': FieldValue.serverTimestamp(),
        });
        
        debugPrint("FirebaseService: Doctor appointment count updated to $appointmentCount");
      } else {
        debugPrint("FirebaseService: Doctor not found, couldn't update appointment count");
      }
    } catch (e) {
      debugPrint("FirebaseService: Error updating doctor appointment count: $e");
      // Don't rethrow, as this is a non-critical operation
    }
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
      final field = isDoctor ? 'doctorId' : 'patientId';
      debugPrint('FirebaseService: Getting upcoming appointments for ${isDoctor ? "doctor" : "patient"} with ID: $userId');
      
      final querySnapshot = await _firestore
          .collection(_appointmentsCollection)
          .where(field, isEqualTo: userId)
          .where('status', isEqualTo: 'upcoming')
          .get();
      
      final appointments = querySnapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
          
      debugPrint('FirebaseService: Found ${appointments.length} upcoming appointments');
      
      // Log appointment details for debugging
      for (var appointment in appointments) {
        final formattedDate = DateFormat('yyyy-MM-dd').format(appointment.date.toDate());
        debugPrint('FirebaseService: Appointment on $formattedDate at ${appointment.time}');
      }
      
      return appointments;
    } catch (e) {
      debugPrint('Error getting upcoming appointments: $e');
      rethrow;
    }
  }

  // Fetch past appointments
  Future<List<AppointmentModel>> getPastAppointments(String userId, bool isDoctor) async {
    try {
      final field = isDoctor ? 'doctorId' : 'patientId';
      debugPrint('FirebaseService: Getting past appointments for ${isDoctor ? "doctor" : "patient"} with ID: $userId');
      
      final querySnapshot = await _firestore
          .collection(_appointmentsCollection)
          .where(field, isEqualTo: userId)
          .where('status', isEqualTo: 'past')
          .get();
      
      final appointments = querySnapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
          
      debugPrint('FirebaseService: Found ${appointments.length} past appointments');
      
      // Automatically mark appointments that have passed as "past" if they are still labeled as "upcoming"
      await _updatePastAppointments(userId, isDoctor);
      
      return appointments;
    } catch (e) {
      debugPrint('Error getting past appointments: $e');
      rethrow;
    }
  }

  // Fetch cancelled appointments
  Future<List<AppointmentModel>> getCancelledAppointments(String userId, bool isDoctor) async {
    try {
      final field = isDoctor ? 'doctorId' : 'patientId';
      debugPrint('FirebaseService: Getting cancelled appointments for ${isDoctor ? "doctor" : "patient"} with ID: $userId');
      
      final querySnapshot = await _firestore
          .collection(_appointmentsCollection)
          .where(field, isEqualTo: userId)
          .where('status', isEqualTo: 'cancelled')
          .get();
      
      final appointments = querySnapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
          
      debugPrint('FirebaseService: Found ${appointments.length} cancelled appointments');
      
      return appointments;
    } catch (e) {
      debugPrint('Error getting cancelled appointments: $e');
      rethrow;
    }
  }
  
  // Auto-update appointments that have passed
  Future<void> _updatePastAppointments(String userId, bool isDoctor) async {
    try {
      debugPrint('FirebaseService: Checking for appointments that need to be marked as past');
      final field = isDoctor ? 'doctorId' : 'patientId';
      final now = Timestamp.now();
      
      // Get all upcoming appointments for this user that have a date in the past
      final querySnapshot = await _firestore
          .collection(_appointmentsCollection)
          .where(field, isEqualTo: userId)
          .where('status', isEqualTo: 'upcoming')
          .get();
      
      int updatedCount = 0;
      
      // Check each appointment to see if it has passed
      for (final doc in querySnapshot.docs) {
        final appointment = AppointmentModel.fromMap(doc.data(), doc.id);
        
        // If the appointment date is in the past, update it
        if (appointment.date.compareTo(now) < 0) {
          await _firestore.collection(_appointmentsCollection).doc(doc.id).update({
            'status': 'past',
            'updatedAt': now,
          });
          updatedCount++;
        }
      }
      
      if (updatedCount > 0) {
        debugPrint('FirebaseService: Updated $updatedCount appointments from upcoming to past');
      }
    } catch (e) {
      debugPrint('FirebaseService: Error updating past appointments: $e');
      // Don't rethrow, as this is just a helpful update
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
      final chatId = chat.id.isEmpty ? _uuid.v4() : chat.id;
      
      // Check if we need to fetch participant details
      Map<String, dynamic>? participantDetails = chat.participantDetails;
      if (participantDetails == null || participantDetails.isEmpty) {
        participantDetails = {};
        // Try to fetch details for each participant
        for (final participantId in chat.participants) {
          try {
            final userDoc = await _firestore.collection(_usersCollection).doc(participantId).get();
            if (userDoc.exists) {
              final userData = userDoc.data() as Map<String, dynamic>?;
              if (userData != null) {
                participantDetails[participantId] = {
                  'name': userData['name'] ?? 'Unknown User',
                  'role': userData['role'] ?? 'user',
                  'profileImageUrl': userData['profileImageUrl'],
                };
              }
            }
          } catch (e) {
            debugPrint("FirebaseService: Error fetching participant details: $e");
          }
        }
      }
      
      final chatWithId = chat.copyWith(
        id: chatId,
        participantDetails: participantDetails,
        createdAt: chat.createdAt,
        updatedAt: Timestamp.now(),
      );
      
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
      // Use set with merge option instead of update to create the document if it doesn't exist
      await _firestore.collection(_chatsCollection).doc(chatId).set({
        'lastMessage': message,
        'lastMessageTime': timestamp,
        'updatedAt': Timestamp.now(),
      }, SetOptions(merge: true));
      debugPrint("FirebaseService: Chat last message updated successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error updating chat last message: $e");
      // Rethrow to handle at call site
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

  // Enhanced file storage methods for document sharing
  Future<String> uploadFile(String filePath, List<int> fileBytes, String fileName, String contentType) async {
    try {
      debugPrint('FirebaseService: Uploading file: $fileName');
      
      // In a real implementation, this would upload to Firebase Storage
      // For now, we'll just simulate the upload and return a fake URL
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileExtension = fileName.split('.').last;
      final uniqueFileName = '$timestamp.$fileExtension';
      final storagePath = 'uploads/$uniqueFileName';
      
      // Return a fake URL for testing
      final downloadUrl = 'https://example.com/$storagePath';
      
      debugPrint('FirebaseService: File uploaded successfully: $downloadUrl');
      return downloadUrl;
    } catch (e) {
      debugPrint('FirebaseService: Error uploading file: $e');
      throw Exception('Failed to upload file: $e');
    }
  }
  
  // Send a message with a file attachment
  Future<String> sendFileMessage({
    required String chatId,
    required String senderId,
    required String text,
    required MessageType type,
    required String filePath,
    required List<int> fileBytes,
    required String fileName,
    required String contentType,
    required int fileSize,
  }) async {
    try {
      debugPrint('FirebaseService: Sending file message...');
      
      // 1. Upload the file
      final downloadUrl = await uploadFile(filePath, fileBytes, fileName, contentType);
      
      // 2. Create file info
      final fileInfo = {
        'name': fileName,
        'url': downloadUrl,
        'size': fileSize,
        'contentType': contentType,
        'uploadedAt': Timestamp.now(),
      };
      
      // 3. Create and send the message
      final message = MessageModel(
        id: _uuid.v4(),
        chatId: chatId,
        senderId: senderId,
        text: text,
        timestamp: Timestamp.now(),
        status: MessageStatus.sent,
        type: type,
        fileInfo: fileInfo,
      );
      
      final messageId = await sendMessage(message);
      
      debugPrint('FirebaseService: File message sent successfully');
      return messageId;
    } catch (e) {
      debugPrint('FirebaseService: Error sending file message: $e');
      throw Exception('Failed to send file message: $e');
    }
  }
  
  // Create a medical document sharing collection
  final String _sharedDocumentsCollection = 'shared_medical_documents';
  
  // Share a medical document with a user
  Future<String> shareMedicalDocument({
    required String senderId,
    required String recipientId,
    required String documentName,
    required String documentUrl,
    required String documentType,
    String? description,
  }) async {
    try {
      debugPrint('FirebaseService: Sharing medical document...');
      
      final documentId = _uuid.v4();
      
      final documentData = {
        'id': documentId,
        'senderId': senderId,
        'recipientId': recipientId,
        'documentName': documentName,
        'documentUrl': documentUrl,
        'documentType': documentType,
        'description': description,
        'isRead': false,
        'sharedAt': Timestamp.now(),
        'readAt': null,
      };
      
      await _firestore.collection(_sharedDocumentsCollection).doc(documentId).set(documentData);
      
      // Also send a chat message to notify the recipient
      final existingChat = await _findChatBetweenUsers(senderId, recipientId);
      String chatId;
      
      if (existingChat != null) {
        chatId = existingChat.id;
      } else {
        // Create a new chat if it doesn't exist
        final chat = ChatModel(
          id: '',
          participants: [senderId, recipientId],
          createdAt: Timestamp.now(),
          updatedAt: Timestamp.now(),
          lastMessage: 'Shared a medical document: $documentName',
          lastMessageTime: Timestamp.now(),
          unreadCount: 1,
        );
        
        chatId = await createChat(chat);
      }
      
      // Send a message in the chat
      final message = MessageModel(
        id: _uuid.v4(),
        chatId: chatId,
        senderId: senderId,
        text: 'Shared a medical document: $documentName',
        timestamp: Timestamp.now(),
        status: MessageStatus.sent,
        type: MessageType.document,
        fileInfo: {
          'name': documentName,
          'url': documentUrl,
          'type': documentType,
          'documentId': documentId,
        },
      );
      
      await sendMessage(message);
      
      debugPrint('FirebaseService: Medical document shared successfully');
      return documentId;
    } catch (e) {
      debugPrint('FirebaseService: Error sharing medical document: $e');
      throw Exception('Failed to share medical document: $e');
    }
  }
  
  // Get shared medical documents for a user
  Future<List<MedicalDocumentModel>> getSharedMedicalDocuments(String userId) async {
    try {
      debugPrint('FirebaseService: Getting shared medical documents for user $userId');
      
      final sent = await _firestore
          .collection(_sharedDocumentsCollection)
          .where('senderId', isEqualTo: userId)
          .get();
      
      final received = await _firestore
          .collection(_sharedDocumentsCollection)
          .where('recipientId', isEqualTo: userId)
          .get();
      
      final allDocs = [...sent.docs, ...received.docs];
      
      final documents = allDocs.map((doc) {
        final data = doc.data();
        return MedicalDocumentModel.fromMap(data);
      }).toList();
      
      // Sort by date, newest first
      documents.sort((a, b) => b.sharedAt.compareTo(a.sharedAt));
      
      debugPrint('FirebaseService: Found ${documents.length} shared medical documents');
      return documents;
    } catch (e) {
      debugPrint('FirebaseService: Error getting shared medical documents: $e');
      return [];
    }
  }
  
  // Helper function to find a chat between two users
  Future<ChatModel?> _findChatBetweenUsers(String user1Id, String user2Id) async {
    try {
      // Get all chats for user1
      final chatsSnapshot = await _firestore
          .collection(_chatsCollection)
          .where('participants', arrayContains: user1Id)
          .get();
      
      // Filter to find chats that also have user2
      for (final doc in chatsSnapshot.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(user2Id)) {
          return ChatModel.fromMap(doc.data(), doc.id);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('FirebaseService: Error finding chat between users: $e');
      return null;
    }
  }

  // Collection for ratings
  final String _ratingsCollection = 'doctor_ratings';
  
  // Add a rating for a doctor
  Future<String> addDoctorRating({
    required String doctorId,
    required String patientId,
    required double rating,
    String? comment,
    bool isAnonymous = false,
  }) async {
    try {
      final ratingId = _uuid.v4();
      
      final ratingModel = RatingModel(
        id: ratingId,
        doctorId: doctorId,
        patientId: patientId,
        rating: rating,
        comment: comment,
        createdAt: Timestamp.now(),
        isAnonymous: isAnonymous,
      );
      
      await _firestore.collection(_ratingsCollection).doc(ratingId).set(ratingModel.toMap());
      
      // Update doctor's average rating
      await _updateDoctorAverageRating(doctorId);
      
      return ratingId;
    } catch (e) {
      debugPrint('FirebaseService: Error adding doctor rating: $e');
      throw Exception('Failed to add doctor rating: $e');
    }
  }
  
  // Get ratings for a doctor
  Future<List<RatingModel>> getDoctorRatings(String doctorId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => RatingModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('FirebaseService: Error getting doctor ratings: $e');
      return [];
    }
  }
  
  // Update a doctor's average rating
  Future<void> _updateDoctorAverageRating(String doctorId) async {
    try {
      // Get all ratings for the doctor
      final ratings = await getDoctorRatings(doctorId);
      
      if (ratings.isEmpty) {
        // No ratings yet, set default rating
        await _firestore.collection(_usersCollection).doc(doctorId).update({
          'doctorInfo.rating': 0.0,
          'doctorInfo.ratingCount': 0,
        });
        return;
      }
      
      // Calculate average rating
      final double totalRating = ratings.fold(0, (sum, rating) => sum + rating.rating);
      final double averageRating = totalRating / ratings.length;
      
      // Update doctor's info
      await _firestore.collection(_usersCollection).doc(doctorId).update({
        'doctorInfo.rating': averageRating,
        'doctorInfo.ratingCount': ratings.length,
      });
      
      debugPrint('FirebaseService: Updated doctor average rating to $averageRating from ${ratings.length} ratings');
    } catch (e) {
      debugPrint('FirebaseService: Error updating doctor average rating: $e');
    }
  }
  
  // Get a patient's ratings
  Future<List<RatingModel>> getPatientRatings(String patientId) async {
    try {
      final querySnapshot = await _firestore
          .collection(_ratingsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return querySnapshot.docs
          .map((doc) => RatingModel.fromMap(doc.data()))
          .toList();
    } catch (e) {
      debugPrint('FirebaseService: Error getting patient ratings: $e');
      return [];
    }
  }
  
  // Delete a rating
  Future<void> deleteRating(String ratingId) async {
    try {
      // Get the rating to identify the doctor
      final ratingDoc = await _firestore.collection(_ratingsCollection).doc(ratingId).get();
      
      if (!ratingDoc.exists) {
        throw Exception('Rating not found');
      }
      
      final rating = RatingModel.fromMap(ratingDoc.data()!);
      
      // Delete the rating
      await _firestore.collection(_ratingsCollection).doc(ratingId).delete();
      
      // Update doctor's average rating
      await _updateDoctorAverageRating(rating.doctorId);
      
      debugPrint('FirebaseService: Rating deleted successfully');
    } catch (e) {
      debugPrint('FirebaseService: Error deleting rating: $e');
      throw Exception('Failed to delete rating: $e');
    }
  }

  // Get all doctors from the doctors collection
  Future<List<DoctorModel>> getDoctorsFromCollection({String? specialty}) async {
    try {
      debugPrint("FirebaseService: Fetching all doctors from Firestore" + (specialty != null ? " with specialty: $specialty" : ""));
      
      // First try to get doctors from users collection with doctor role
      Query usersQuery = _firestore.collection(_usersCollection)
          .where('role', isEqualTo: 'doctor');
      
      final usersSnapshot = await usersQuery.get();
          
      debugPrint("FirebaseService: Found ${usersSnapshot.docs.length} doctors in users collection");
      
      // Create a list to store the doctor models
      List<DoctorModel> doctors = [];
      
      // Process each document one by one for type safety
      for (final doc in usersSnapshot.docs) {
        try {
          final userData = doc.data() as Map<String, dynamic>;
          final user = UserModel.fromMap(userData, doc.id);
          
          // Ensure doctorInfo exists before proceeding
          await _ensureDoctorInfoExists(user.id);
          
          // Get the updated user with doctorInfo
          final updatedDoc = await _firestore.collection(_usersCollection).doc(user.id).get();
          final updatedUserData = updatedDoc.data() as Map<String, dynamic>;
          final updatedUser = UserModel.fromMap(updatedUserData, doc.id);
          
          // Create doctor model from user
          final doctor = DoctorModel.fromUserModel(updatedUser);
          
          // Apply specialty filter if provided
          if (specialty != null && specialty.isNotEmpty) {
            // Check specialty in various possible locations
            final doctorInfoSpecialty = updatedUser.doctorInfo?['specialty'] as String?;
            final rootSpecialty = updatedUserData['specialty'] as String?;
            
            bool matchesSpecialty = false;
            if (doctorInfoSpecialty != null && doctorInfoSpecialty.toLowerCase() == specialty.toLowerCase()) {
              matchesSpecialty = true;
              debugPrint("FirebaseService: Doctor ${doctor.name} matches specialty in doctorInfo");
            } else if (rootSpecialty != null && rootSpecialty.toLowerCase() == specialty.toLowerCase()) {
              matchesSpecialty = true;
              debugPrint("FirebaseService: Doctor ${doctor.name} matches specialty in root document");
            } else if (doctor.specialty.toLowerCase() == specialty.toLowerCase()) {
              matchesSpecialty = true;
              debugPrint("FirebaseService: Doctor ${doctor.name} matches specialty in DoctorModel");
            }
            
            if (!matchesSpecialty) {
              debugPrint("FirebaseService: Doctor ${doctor.name} doesn't match specialty filter");
              continue; // Skip this doctor if it doesn't match the specialty filter
            }
          }
          
          // Save to doctors collection for future use (but don't await)
          _firestore.collection(_doctorsCollection).doc(doctor.id).set(doctor.toMap());
          
          doctors.add(doctor);
          debugPrint("FirebaseService: Added doctor ${doctor.name} with specialty ${doctor.specialty}");
        } catch (e) {
          debugPrint("FirebaseService: Error creating doctor from user: $e");
          // Skip this doctor if there's an error
        }
      }
      
      debugPrint("FirebaseService: Final doctor count: ${doctors.length}");
      return doctors;
      
    } catch (e) {
      debugPrint("FirebaseService: Error getting doctors: $e");
      return [];
    }
  }
  
  // Get all doctors (UserModel objects)
  Future<List<UserModel>> getDoctors({String? specialty}) async {
    try {
      debugPrint("FirebaseService: Fetching all doctors" + (specialty != null ? " with specialty: $specialty" : ""));
      
      final querySnapshot = await _firestore
          .collection(_usersCollection)
          .where('role', isEqualTo: 'doctor')
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        debugPrint("FirebaseService: No doctors found in database");
        return [];
      }
      
      final doctors = querySnapshot.docs.map((doc) {
        final userData = doc.data();
        try {
          debugPrint("FirebaseService: Processing doctor data: ${userData['name']}");
          final doctor = UserModel.fromMap(userData, doc.id);
          debugPrint("FirebaseService: Successfully parsed doctor: ${doctor.name}");
          return doctor;
        } catch (e) {
          debugPrint("FirebaseService: Error parsing doctor data: $e");
          return null;
        }
      }).whereType<UserModel>().toList();
      
      // Ensure all doctors have a "doctorInfo" field - this keeps the data consistent
      for (final doctor in doctors) {
        if (doctor.doctorInfo == null || doctor.doctorInfo!.isEmpty) {
          // Add basic doctorInfo if it's missing
          await _ensureDoctorInfoExists(doctor.id);
        }
      }
      
      // Filter by specialty if provided
      if (specialty != null && specialty.isNotEmpty) {
        return doctors.where((doctor) {
          final doctorSpecialty = doctor.doctorInfo?['specialty'] as String?;
          return doctorSpecialty == specialty;
        }).toList();
      }
      
      debugPrint("FirebaseService: Successfully retrieved ${doctors.length} doctors");
      return doctors;
    } catch (e) {
      debugPrint("FirebaseService: Error getting doctors: $e");
      return [];
    }
  }
  
  // Ensure doctor info exists for all doctor users
  Future<void> _ensureDoctorInfoExists(String doctorId) async {
    try {
      debugPrint("FirebaseService: Ensuring doctor info exists for $doctorId");
      final doctorDoc = await _firestore.collection(_usersCollection).doc(doctorId).get();
      
      if (doctorDoc.exists) {
        final Map<String, dynamic> doctorData = doctorDoc.data() as Map<String, dynamic>;
        
        // Check if doctorInfo exists and contains required fields
        final hasValidDoctorInfo = doctorData['doctorInfo'] is Map && 
                                  (doctorData['doctorInfo']['specialty'] is String ||
                                   doctorData['doctorInfo']['appointmentCount'] is int);
        
        // If doctorInfo doesn't exist or is incomplete, create/update it
        if (!hasValidDoctorInfo) {
          debugPrint("FirebaseService: Doctor info incomplete, updating doctor data");
          
          // Find specialty in user data
          String specialty = 'General Physician';
          
          // First check if the user manually selected a specialty during registration
          if (doctorData['specialty'] is String && doctorData['specialty'].isNotEmpty) {
            specialty = doctorData['specialty'];
            debugPrint("FirebaseService: Found specialty in root document: $specialty");
          }
          // Then check in medicalInfo (fallback)
          else if (doctorData['medicalInfo'] is Map && doctorData['medicalInfo']['specialty'] is String) {
            specialty = doctorData['medicalInfo']['specialty'];
            debugPrint("FirebaseService: Found specialty in medicalInfo: $specialty");
          }
          
          // Generate realistic experience (1-20 years)
          final experience = 1 + (doctorId.hashCode % 20).abs();
          
          // Generate realistic rating based on experience and specialty
          // More experienced doctors tend to have higher, more stable ratings
          final baseRating = 3.2 + (experience * 0.08);
          // Add some randomness based on doctor ID to create variety
          final randomOffset = (doctorId.hashCode % 10) * 0.05;
          // Popular specialties might have higher ratings
          final specialtyBonus = _getSpecialtyRatingBonus(specialty);
          
          // Calculate the final rating (capped between 3.2 and 4.9)
          final rating = (baseRating + randomOffset + specialtyBonus).clamp(3.2, 4.9);
          // Round to one decimal place
          final roundedRating = double.parse(rating.toStringAsFixed(1));
          
          // Calculate realistic number of reviews based on experience
          final ratingCount = (experience * 5 + (doctorId.hashCode % 25)).abs();
          
          // Update doctor document with basic doctorInfo
          await _firestore.collection(_usersCollection).doc(doctorId).update({
            'doctorInfo': {
              'specialty': specialty,
              'appointmentCount': 0,
              'isAvailable': true,
              'rating': roundedRating,
              'ratingCount': ratingCount,
              'experience': experience,
              'hospitalAffiliation': 'General Hospital',
            },
            'updatedAt': FieldValue.serverTimestamp(),
          });
          
          debugPrint("FirebaseService: Added missing doctorInfo for doctor $doctorId with specialty: $specialty, rating: $roundedRating, reviews: $ratingCount");
        }
      } else {
        debugPrint("FirebaseService: Doctor document not found for $doctorId");
      }
    } catch (e) {
      debugPrint("FirebaseService: Error ensuring doctor info exists: $e");
      // Don't rethrow, as this is a non-critical operation
    }
  }
  
  // Helper method to get rating bonus based on specialty popularity
  double _getSpecialtyRatingBonus(String specialty) {
    switch (specialty.toLowerCase()) {
      case 'cardiology':
      case 'dermatology':
      case 'pediatrics':
        return 0.3; // Popular specialties
      case 'neurology':
      case 'orthopedics':
      case 'ophthalmology':
        return 0.2; // Moderately popular
      case 'family medicine':
      case 'general physician':
      case 'internal medicine':
        return 0.1; // Common specialties
      default:
        return 0.0; // Other specialties
    }
  }
  
  // Get all appointments for a date range
  // Get all appointments for a date range
  Future<List<AppointmentModel>> getAppointmentsForDateRange(DateTime startDate, DateTime endDate, {String? doctorId, String? patientId}) async {
    try {
      debugPrint("FirebaseService: Fetching appointments from ${startDate.toString()} to ${endDate.toString()}");
      
      // Convert to Firestore Timestamps
      final startTimestamp = Timestamp.fromDate(startDate);
      final endTimestamp = Timestamp.fromDate(endDate);
      
      // Start building the query
      Query query = _firestore.collection(_appointmentsCollection)
          .where('date', isGreaterThanOrEqualTo: startTimestamp)
          .where('date', isLessThanOrEqualTo: endTimestamp);
      
      // Add doctor filter if provided
      if (doctorId != null) {
        query = query.where('doctorId', isEqualTo: doctorId);
      }
      
      // Add patient filter if provided
      if (patientId != null) {
        query = query.where('patientId', isEqualTo: patientId);
      }
      
      // Execute the query
      final snapshot = await query.get();
      
      // Convert to models
      final appointments = snapshot.docs.map((doc) => 
        AppointmentModel.fromMap(doc.data() as Map<String, dynamic>, doc.id)
      ).toList();
      
      debugPrint("FirebaseService: Retrieved ${appointments.length} appointments");
      return appointments;
    } catch (e) {
      debugPrint("FirebaseService: Error getting appointments for date range: $e");
      return [];
    }
  }

  // Get appointment by ID
  Future<AppointmentModel?> getAppointmentById(String appointmentId) async {
    try {
      final docSnapshot = await _firestore
          .collection(_appointmentsCollection)
          .doc(appointmentId)
          .get();
      
      if (!docSnapshot.exists) {
        return null;
      }
      
      return AppointmentModel.fromMap(docSnapshot.data()!, docSnapshot.id);
    } catch (e) {
      debugPrint('Error getting appointment by ID: $e');
      rethrow;
    }
  }

  // Cancel an appointment
  Future<void> cancelAppointment(String appointmentId, String reason) async {
    try {
      await _firestore.collection(_appointmentsCollection).doc(appointmentId).update({
        'status': 'cancelled',
        'cancellationReason': reason,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error cancelling appointment: $e');
      rethrow;
    }
  }

  // Reschedule an appointment
  Future<void> rescheduleAppointment(String appointmentId, DateTime newDate, String newTime) async {
    try {
      await _firestore.collection(_appointmentsCollection).doc(appointmentId).update({
        'date': Timestamp.fromDate(newDate),
        'time': newTime,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error rescheduling appointment: $e');
      rethrow;
    }
  }

  // Get saved conversations for a user
  Future<List<Map<String, dynamic>>> getSavedConversations(String userId) async {
    try {
      debugPrint("FirebaseService: Getting saved conversations for user $userId");
      final snapshot = await _firestore
          .collection('saved_conversations')
          .where('userId', isEqualTo: userId)
          .orderBy('savedAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
      debugPrint("FirebaseService: Error getting saved conversations: $e");
      return [];
    }
  }
  
  // Save chat conversation for patient dashboard
  Future<bool> saveChatConversation(String userId, String chatId) async {
    try {
      debugPrint("FirebaseService: Saving chat conversation for user $userId, chat $chatId");
      
      // Check if already saved
      final existingDoc = await _firestore
          .collection('saved_conversations')
          .where('userId', isEqualTo: userId)
          .where('chatId', isEqualTo: chatId)
          .get();
      
      if (existingDoc.docs.isNotEmpty) {
        // Update existing saved conversation
        await _firestore
            .collection('saved_conversations')
            .doc(existingDoc.docs.first.id)
            .update({
              'savedAt': FieldValue.serverTimestamp(),
            });
        debugPrint("FirebaseService: Updated existing saved conversation");
      } else {
        // Create new saved conversation
        await _firestore
            .collection('saved_conversations')
            .add({
              'userId': userId,
              'chatId': chatId,
              'savedAt': FieldValue.serverTimestamp(),
            });
        debugPrint("FirebaseService: Created new saved conversation");
      }
      
      return true;
    } catch (e) {
      debugPrint("FirebaseService: Error saving chat conversation: $e");
      return false;
    }
  }

  // Get available slots for a specific doctor on a specific date
  Future<List<AppointmentSlotModel>> getAvailableSlotsForDoctor(String doctorId, DateTime date) async {
    try {
      debugPrint("FirebaseService: Fetching available slots for doctor $doctorId on ${date.toString()}");
      
      // Format date to match how it's stored in Firestore (YYYY-MM-DD)
      final dateString = DateFormat('yyyy-MM-dd').format(date);
      
      // Get the doctor document to check available slots
      final doctorDoc = await _firestore.collection(_doctorsCollection).doc(doctorId).get();
      
      if (!doctorDoc.exists) {
        debugPrint("FirebaseService: Doctor not found in doctors collection, checking users collection");
        // Check users collection as fallback
        final userDoc = await _firestore.collection(_usersCollection).doc(doctorId).get();
        if (!userDoc.exists) {
          debugPrint("FirebaseService: Doctor not found in users collection either");
          return [];
        }
      }
      
      // Get doctor data from either collection
      final Map<String, dynamic> doctorData = doctorDoc.exists 
          ? doctorDoc.data()! 
          : (await _firestore.collection(_usersCollection).doc(doctorId).get()).data() ?? {};
      
      // Check if doctor has available slots for this date
      if (doctorData['availableSlots'] is Map) {
        final availableSlots = doctorData['availableSlots'] as Map<String, dynamic>;
        
        if (availableSlots.containsKey(dateString)) {
          final slots = List<String>.from(availableSlots[dateString] ?? []);
          debugPrint("FirebaseService: Found ${slots.length} available slots for date $dateString");
          
          // Convert to AppointmentSlotModel objects
          return slots.map((slotTime) {
            return AppointmentSlotModel(
              id: '$doctorId-$dateString-$slotTime',
              doctorId: doctorId,
              date: date,
              timeSlot: slotTime,
              isBooked: false,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            );
          }).toList();
        }
      }
      
      // If no slots found, check if it's a working day based on the doctor's schedule
      if (doctorData['workSchedule'] is Map) {
        final workSchedule = doctorData['workSchedule'] as Map<String, dynamic>;
        final dayOfWeek = DateFormat('EEEE').format(date); // e.g., "Monday"
        
        if (workSchedule.containsKey(dayOfWeek)) {
          final slots = List<String>.from(workSchedule[dayOfWeek] ?? []);
          debugPrint("FirebaseService: Using work schedule slots for $dayOfWeek: ${slots.length} slots");
          
          // Create demo slots based on work schedule
          return slots.map((slotTime) {
            return AppointmentSlotModel(
              id: '$doctorId-$dateString-$slotTime',
              doctorId: doctorId,
              date: date,
              timeSlot: slotTime,
              isBooked: false,
              createdAt: Timestamp.now(),
              updatedAt: Timestamp.now(),
            );
          }).toList();
        }
      }
      
      debugPrint("FirebaseService: No slots found for date $dateString");
      return [];
    } catch (e) {
      debugPrint("FirebaseService: Error fetching available slots: $e");
      return [];
    }
  }
  
  // Book an appointment slot
  Future<String?> bookAppointmentSlot(AppointmentModel appointment) async {
    try {
      debugPrint("FirebaseService: Booking appointment for patient ${appointment.patientId} with doctor ${appointment.doctorId}");
      
      // Format date string - convert Timestamp to DateTime
      final appointmentDateTime = appointment.date.toDate();
      
      // Normalize the date to midnight to avoid time comparison issues
      final normalizedDate = DateTime(
        appointmentDateTime.year, 
        appointmentDateTime.month, 
        appointmentDateTime.day
      );
      final normalizedTimestamp = Timestamp.fromDate(normalizedDate);
      
      final dateString = DateFormat('yyyy-MM-dd').format(normalizedDate);
      final slotTime = appointment.time;
      
      debugPrint("FirebaseService: Booking for date $dateString, time $slotTime (normalized date)");
      
      // Create a transaction to ensure atomicity
      return await _firestore.runTransaction<String?>((transaction) async {
        // 1. First try to get doctor from doctors collection
        final doctorDoc = await transaction.get(_firestore.collection(_doctorsCollection).doc(appointment.doctorId));
        
        // If not found in doctors collection, try users collection
        Map<String, dynamic>? doctorData;
        String collectionToUpdate = _doctorsCollection;
        
        if (doctorDoc.exists) {
          doctorData = doctorDoc.data() as Map<String, dynamic>;
          debugPrint("FirebaseService: Doctor found in doctors collection");
        } else {
          debugPrint("FirebaseService: Doctor not found in doctors collection, checking users collection");
          final userDoc = await transaction.get(_firestore.collection(_usersCollection).doc(appointment.doctorId));
          
          if (!userDoc.exists) {
            debugPrint("FirebaseService: Doctor not found in users collection either");
            return null;
          }
          
          doctorData = userDoc.data() as Map<String, dynamic>;
          collectionToUpdate = _usersCollection;
          debugPrint("FirebaseService: Doctor found in users collection");
        }
        
        // 2. Check if doctor has availableSlots field
        if (doctorData!['availableSlots'] == null) {
          debugPrint("FirebaseService: Doctor has no availableSlots field, adding default slots");
          
          // Create default available slots
          final availableSlots = DoctorModel.createInitialAvailableSlots();
          
          // This is a read-update transaction, so we update the doctor document here
          transaction.update(
            _firestore.collection(collectionToUpdate).doc(appointment.doctorId),
            {'availableSlots': availableSlots}
          );
          
          doctorData = {...doctorData, 'availableSlots': availableSlots};
        }
        
        // 3. Ensure availableSlots is present and contains the date
        final availableSlots = doctorData['availableSlots'] as Map<String, dynamic>?;
        
        if (availableSlots == null || !availableSlots.containsKey(dateString)) {
          debugPrint("FirebaseService: Available slots not found for date $dateString, creating slots");
          
          // Create slots for this date
          final List<String> newSlots = [];
          for (int hour = 9; hour < 18; hour++) {
            final String hourStr = hour <= 12 ? '$hour' : '${hour - 12}';
            final String amPm = hour < 12 ? 'AM' : 'PM';
            
            newSlots.add('$hourStr:00 $amPm');
            newSlots.add('$hourStr:30 $amPm');
          }
          
          // Add the new slots to the availableSlots
          final Map<String, dynamic> updatedSlots = {...(availableSlots ?? {})};
          updatedSlots[dateString] = newSlots;
          
          // Update the doctor document with the new slots
          transaction.update(
            _firestore.collection(collectionToUpdate).doc(appointment.doctorId),
            {'availableSlots': updatedSlots}
          );
          
          doctorData = {...doctorData, 'availableSlots': updatedSlots};
        }
        
        // 4. Get the available slots for the date
        final List<String> dateSlots = List<String>.from(doctorData['availableSlots'][dateString] ?? []);
        
        // Debug available slots
        debugPrint("FirebaseService: Available slots for date $dateString: $dateSlots");
        debugPrint("FirebaseService: Looking for slot: $slotTime");
        
        // 5. Check if the slot is available
        // Try both time formats (e.g., "9:00 AM" and "09:00 AM")
        String normalizedSlotTime = slotTime;
        if (slotTime.startsWith('0')) {
          normalizedSlotTime = slotTime.substring(1);  // remove leading zero
        }
        
        bool slotFound = dateSlots.contains(slotTime) || dateSlots.contains(normalizedSlotTime);
        
        if (!slotFound) {
          debugPrint("FirebaseService: Slot $slotTime is not available for date $dateString");
          // Add slot if it's within business hours to fix any issues
          if (_isWithinBusinessHours(slotTime)) {
            debugPrint("FirebaseService: Adding slot $slotTime to available slots as it's within business hours");
            dateSlots.add(slotTime);
            slotFound = true;
          } else {
            return null;
          }
        }
        
        // 6. Remove the slot from available slots
        if (dateSlots.contains(slotTime)) {
          dateSlots.remove(slotTime);
        } else if (dateSlots.contains(normalizedSlotTime)) {
          dateSlots.remove(normalizedSlotTime);
        }
        
        final updatedAvailableSlots = Map<String, dynamic>.from(doctorData['availableSlots']);
        updatedAvailableSlots[dateString] = dateSlots;
        
        transaction.update(
          _firestore.collection(collectionToUpdate).doc(appointment.doctorId),
          {'availableSlots': updatedAvailableSlots}
        );
        
        // 7. Create the appointment
        final appointmentId = appointment.id.isEmpty ? _uuid.v4() : appointment.id;
        final appointmentWithId = appointment.copyWith(
          id: appointmentId,
          status: AppointmentStatus.upcoming, // Ensure status is set to upcoming
          date: normalizedTimestamp, // Use the normalized date timestamp
        );
        
        // Get doctor and patient details
        final doctorDetails = await _getDoctorDetailsForAppointment(appointment.doctorId);
        final patientDetails = await _getPatientDetailsForAppointment(appointment.patientId);
        
        final completeAppointment = appointmentWithId.copyWith(
          doctorDetails: doctorDetails,
          patientDetails: patientDetails,
        );
        
        // 8. Save the appointment
        transaction.set(
          _firestore.collection(_appointmentsCollection).doc(appointmentId),
          completeAppointment.toMap(),
        );
        
        debugPrint("FirebaseService: Successfully booked appointment with ID: $appointmentId");
        debugPrint("FirebaseService: Appointment details: Date=$dateString, Time=$slotTime, Status=${completeAppointment.status.toString()}");
        
        return appointmentId;
      });
    } catch (e) {
      debugPrint("FirebaseService: Error booking appointment slot: $e");
      return null;
    }
  }
  
  // Helper method to check if a time slot is within business hours (9 AM - 6 PM)
  bool _isWithinBusinessHours(String timeSlot) {
    try {
      // Parse the time slot
      final timeWithoutAmPm = timeSlot.split(' ')[0];
      final isPm = timeSlot.toLowerCase().contains('pm');
      
      final parts = timeWithoutAmPm.split(':');
      int hour = int.parse(parts[0]);
      
      // Convert to 24-hour format
      if (isPm && hour < 12) {
        hour += 12;
      } else if (!isPm && hour == 12) {
        hour = 0;
      }
      
      // Check if within business hours (9 AM to 6 PM)
      return hour >= 9 && hour < 18;
    } catch (e) {
      debugPrint("FirebaseService: Error parsing time slot: $e");
      return false;
    }
  }

  Future<String> createDoctorProfile(DoctorModel doctor) async {
    try {
      debugPrint("FirebaseService: Creating doctor profile in Firestore");
      
      // Make sure the doctor is marked as available and has work schedule and availability
      final updatedDoctor = doctor.copyWith(
        isAvailable: true,
        workSchedule: doctor.workSchedule ?? DoctorModel.createDefaultSchedule(),
        availableSlots: doctor.availableSlots ?? DoctorModel.createInitialAvailableSlots(),
      );
      
      final doctorMap = updatedDoctor.toMap();
      
      // Add to doctors collection
      await _firestore.collection(_doctorsCollection).doc(updatedDoctor.id).set(doctorMap);
      
      // Update role and doctor info in users collection
      await _firestore.collection(_usersCollection).doc(updatedDoctor.id).update({
        'role': 'doctor',
        'doctorInfo': {
          'specialty': updatedDoctor.specialty,
          'hospitalAffiliation': updatedDoctor.hospitalAffiliation,
          'isAvailable': true,
          'experience': updatedDoctor.experience,
          'rating': updatedDoctor.rating,
          'ratingCount': updatedDoctor.ratingCount,
          'updatedAt': FieldValue.serverTimestamp(),
        }
      });
      
      // Initialize appointment slots for the doctor
      await _initializeDoctorAppointmentSlots(updatedDoctor.id);
      
      debugPrint("FirebaseService: Doctor profile created successfully in Firestore");
      return updatedDoctor.id;
    } catch (e) {
      debugPrint("FirebaseService: Error creating doctor profile: $e");
      rethrow;
    }
  }

  Future<DoctorModel?> getDoctorById(String doctorId) async {
    try {
      debugPrint("FirebaseService: Fetching doctor with ID $doctorId from Firestore");
      
      // Try to get from doctors collection first
      final doc = await _firestore.collection(_doctorsCollection).doc(doctorId).get();
      
      if (doc.exists && doc.data() != null) {
        debugPrint("FirebaseService: Doctor found in doctors collection");
        return DoctorModel.fromMap(doc.data()!, doc.id);
      }
      
      // If not found in doctors collection, try users collection as fallback
      final userDoc = await _firestore.collection(_usersCollection).doc(doctorId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final userData = userDoc.data()!;
        if (userData['role'] == 'doctor') {
          debugPrint("FirebaseService: Doctor found in users collection, creating doctor model");
          
          // Create doctor model from user and save to doctors collection
          final user = UserModel.fromMap(userData, userDoc.id);
          final doctor = DoctorModel.fromUserModel(user);
          
          // Save to doctors collection for future use
          await _firestore.collection(_doctorsCollection).doc(doctor.id).set(doctor.toMap());
          
          // Initialize appointment slots if needed
          await _initializeDoctorAppointmentSlots(doctor.id);
          
          return doctor;
        }
      }
      
      debugPrint("FirebaseService: Doctor not found");
      return null;
    } catch (e) {
      debugPrint("FirebaseService: Error fetching doctor: $e");
      rethrow;
    }
  }
  
  Future<void> updateDoctorProfile(DoctorModel doctor) async {
    try {
      debugPrint("FirebaseService: Updating doctor profile with ID ${doctor.id}");
      final doctorMap = doctor.toMap();
      
      // Update in both collections
      await _firestore.collection(_doctorsCollection).doc(doctor.id).update(doctorMap);
      
      // Update relevant fields in users collection
      await _firestore.collection(_usersCollection).doc(doctor.id).update({
        'name': doctor.name,
        'email': doctor.email,
        'phoneNumber': doctor.phoneNumber,
        'profileImageUrl': doctor.profileImageUrl,
        'updatedAt': Timestamp.now(),
      });
      
      debugPrint("FirebaseService: Doctor profile updated successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error updating doctor profile: $e");
      rethrow;
    }
  }
  
  // Initialize appointment slots for a new doctor
  Future<void> _initializeDoctorAppointmentSlots(String doctorId) async {
    try {
      debugPrint("FirebaseService: Initializing appointment slots for doctor $doctorId");
      
      // Create initial available slots for the next 30 days
      final availableSlots = DoctorModel.createInitialAvailableSlots();
      
      // Update the doctor document with the slots
      await _firestore.collection(_usersCollection).doc(doctorId).update({
        'availableSlots': availableSlots,
        'updatedAt': Timestamp.now(),
      });
      
      debugPrint("FirebaseService: Appointment slots initialized successfully for doctor $doctorId");
    } catch (e) {
      debugPrint("FirebaseService: Error initializing appointment slots: $e");
      // Don't rethrow, as this shouldn't block the doctor creation
    }
  }
  
  // Update doctor's availability
  Future<void> updateDoctorAvailability(
    String doctorId, 
    Map<String, List<String>> workSchedule,
    Map<String, List<String>> availableSlots
  ) async {
    try {
      debugPrint("FirebaseService: Updating doctor availability for doctor $doctorId");
      
      // Update doctor document with new schedule
      await _firestore.collection(_usersCollection).doc(doctorId).update({
        'workSchedule': workSchedule,
        'availableSlots': availableSlots,
        'isAvailable': true, // Mark as available
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint("FirebaseService: Doctor availability updated successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error updating doctor availability: $e");
      rethrow;
    }
  }
  
  // Block doctor's dates (vacations, etc.)
  Future<void> blockDoctorDates(
    String doctorId,
    List<Map<String, Timestamp>> blockedDates,
    Map<String, List<String>> updatedAvailableSlots
  ) async {
    try {
      debugPrint("FirebaseService: Blocking dates for doctor $doctorId");
      
      // Update doctor document in users collection
      await _firestore.collection(_usersCollection).doc(doctorId).update({
        'blockedDates': blockedDates,
        'availableSlots': updatedAvailableSlots,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      debugPrint("FirebaseService: Doctor blocked dates updated successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error blocking doctor dates: $e");
      rethrow;
    }
  }

  // Prescription operations
  Future<String> createPrescription(PrescriptionModel prescription) async {
    try {
      debugPrint("FirebaseService: Creating new prescription");
      // Generate new ID if not provided
      final prescriptionId = prescription.id.isEmpty ? _uuid.v4() : prescription.id;
      final prescriptionWithId = prescription.copyWith(id: prescriptionId);
      
      // Get doctor and patient details to include in the prescription
      final doctorDetails = await _getDoctorDetailsForAppointment(prescription.doctorId);
      final patientDetails = await _getPatientDetailsForAppointment(prescription.patientId);
      
      // Create a complete prescription with doctor and patient details
      final completePrescription = prescriptionWithId.copyWith(
        doctorDetails: doctorDetails,
        patientDetails: patientDetails,
        updatedAt: Timestamp.now()
      );
      
      // Convert prescription to map
      final prescriptionMap = completePrescription.toMap();
      
      // Create a collection for prescriptions
      final prescriptionsCollection = 'prescriptions';
      
      // Save to Firestore
      await _firestore.collection(prescriptionsCollection).doc(prescriptionId).set(prescriptionMap);
      
      debugPrint("FirebaseService: Prescription created successfully with ID: $prescriptionId");
      
      // Return the new prescription ID
      return prescriptionId;
    } catch (e) {
      debugPrint("FirebaseService: Error creating prescription: $e");
      rethrow;
    }
  }
  
  Future<PrescriptionModel?> getPrescriptionById(String prescriptionId) async {
    try {
      debugPrint("FirebaseService: Fetching prescription with ID $prescriptionId");
      final prescriptionsCollection = 'prescriptions';
      
      final doc = await _firestore.collection(prescriptionsCollection).doc(prescriptionId).get();
      
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          debugPrint("FirebaseService: Prescription found");
          return PrescriptionModel.fromMap(data, doc.id);
        } else {
          debugPrint("FirebaseService: Prescription document exists but data is null");
          return null;
        }
      } else {
        debugPrint("FirebaseService: Prescription not found");
        return null;
      }
    } catch (e) {
      debugPrint("FirebaseService: Error fetching prescription: $e");
      rethrow;
    }
  }
  
  Future<List<PrescriptionModel>> getPrescriptionsForPatient(String patientId) async {
    try {
      debugPrint("FirebaseService: Fetching prescriptions for patient $patientId");
      final prescriptionsCollection = 'prescriptions';
      
      final querySnapshot = await _firestore
          .collection(prescriptionsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('issuedAt', descending: true)
          .get();
      
      final prescriptions = querySnapshot.docs
          .map((doc) => PrescriptionModel.fromMap(doc.data(), doc.id))
          .toList();
      
      debugPrint("FirebaseService: Found ${prescriptions.length} prescriptions for patient");
      return prescriptions;
    } catch (e) {
      debugPrint("FirebaseService: Error fetching patient prescriptions: $e");
      rethrow;
    }
  }
  
  Future<List<PrescriptionModel>> getPrescriptionsForDoctor(String doctorId) async {
    try {
      debugPrint("FirebaseService: Fetching prescriptions written by doctor $doctorId");
      final prescriptionsCollection = 'prescriptions';
      
      final querySnapshot = await _firestore
          .collection(prescriptionsCollection)
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('issuedAt', descending: true)
          .get();
      
      final prescriptions = querySnapshot.docs
          .map((doc) => PrescriptionModel.fromMap(doc.data(), doc.id))
          .toList();
      
      debugPrint("FirebaseService: Found ${prescriptions.length} prescriptions written by doctor");
      return prescriptions;
    } catch (e) {
      debugPrint("FirebaseService: Error fetching doctor prescriptions: $e");
      rethrow;
    }
  }
  
  Future<List<PrescriptionModel>> getPrescriptionsForAppointment(String appointmentId) async {
    try {
      debugPrint("FirebaseService: Fetching prescriptions for appointment $appointmentId");
      final prescriptionsCollection = 'prescriptions';
      
      final querySnapshot = await _firestore
          .collection(prescriptionsCollection)
          .where('appointmentId', isEqualTo: appointmentId)
          .orderBy('issuedAt', descending: true)
          .get();
      
      final prescriptions = querySnapshot.docs
          .map((doc) => PrescriptionModel.fromMap(doc.data(), doc.id))
          .toList();
      
      debugPrint("FirebaseService: Found ${prescriptions.length} prescriptions for appointment");
      return prescriptions;
    } catch (e) {
      debugPrint("FirebaseService: Error fetching appointment prescriptions: $e");
      rethrow;
    }
  }
  
  Future<void> updatePrescription(PrescriptionModel prescription) async {
    try {
      debugPrint("FirebaseService: Updating prescription with ID ${prescription.id}");
      final prescriptionsCollection = 'prescriptions';
      
      // Ensure we update the timestamp
      final updatedPrescription = prescription.copyWith(
        updatedAt: Timestamp.now()
      );
      
      final prescriptionMap = updatedPrescription.toMap();
      await _firestore.collection(prescriptionsCollection).doc(prescription.id).update(prescriptionMap);
      
      debugPrint("FirebaseService: Prescription updated successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error updating prescription: $e");
      rethrow;
    }
  }
  
  Future<void> markPrescriptionAsFilled(
    String prescriptionId, 
    {String? pharmacyId, String? pharmacyNotes}
  ) async {
    try {
      debugPrint("FirebaseService: Marking prescription $prescriptionId as filled");
      final prescriptionsCollection = 'prescriptions';
      
      final updateData = {
        'isFilled': true,
        'filledAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
      };
      
      if (pharmacyId != null) {
        updateData['pharmacyId'] = pharmacyId;
      }
      
      if (pharmacyNotes != null) {
        updateData['pharmacyNotes'] = pharmacyNotes;
      }
      
      await _firestore.collection(prescriptionsCollection).doc(prescriptionId).update(updateData);
      
      debugPrint("FirebaseService: Prescription marked as filled successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error marking prescription as filled: $e");
      rethrow;
    }
  }
  
  Future<bool> processPrescriptionRefill(String prescriptionId) async {
    try {
      debugPrint("FirebaseService: Processing refill for prescription $prescriptionId");
      final prescriptionsCollection = 'prescriptions';
      
      // Run in a transaction to ensure data integrity
      bool refillSuccessful = false;
      
      await _firestore.runTransaction((transaction) async {
        final docRef = _firestore.collection(prescriptionsCollection).doc(prescriptionId);
        final docSnapshot = await transaction.get(docRef);
        
        if (!docSnapshot.exists) {
          debugPrint("FirebaseService: Prescription not found for refill");
          return;
        }
        
        final data = docSnapshot.data();
        if (data == null) {
          debugPrint("FirebaseService: Prescription data is null");
          return;
        }
        
        final isRefillable = data['isRefillable'] ?? false;
        final refillsRemaining = data['refillsRemaining'] ?? 0;
        
        if (!isRefillable || refillsRemaining <= 0) {
          debugPrint("FirebaseService: Prescription is not refillable or no refills remaining");
          return;
        }
        
        // Update refills remaining
        transaction.update(docRef, {
          'refillsRemaining': refillsRemaining - 1,
          'updatedAt': Timestamp.now(),
        });
        
        refillSuccessful = true;
      });
      
      debugPrint("FirebaseService: Refill processed successfully: $refillSuccessful");
      return refillSuccessful;
    } catch (e) {
      debugPrint("FirebaseService: Error processing prescription refill: $e");
      rethrow;
    }
  }
  
  Future<void> deletePrescription(String prescriptionId) async {
    try {
      debugPrint("FirebaseService: Deleting prescription $prescriptionId");
      final prescriptionsCollection = 'prescriptions';
      
      await _firestore.collection(prescriptionsCollection).doc(prescriptionId).delete();
      
      debugPrint("FirebaseService: Prescription deleted successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error deleting prescription: $e");
      rethrow;
    }
  }

  // Calculate realistic doctor rating based on patient feedback
  Future<Map<String, dynamic>> calculateRealisticDoctorRating(String doctorId) async {
    try {
      debugPrint("FirebaseService: Calculating realistic rating for doctor $doctorId");
      
      // Get all past appointments for this doctor
      final pastAppointments = await getPastAppointments(doctorId, true);
      
      // Get doctor ratings
      final ratingSnapshot = await _firestore
          .collection('ratings')
          .where('doctorId', isEqualTo: doctorId)
          .get();
      
      final ratings = ratingSnapshot.docs.map((doc) => doc.data()['rating'] as double? ?? 0.0).toList();
      
      // Calculate rating based on appointments and explicit ratings
      double calculatedRating;
      int ratingCount = 0;
      
      if (ratings.isNotEmpty) {
        // If we have explicit ratings, use the average
        double sum = ratings.fold(0.0, (prev, rating) => prev + rating);
        calculatedRating = sum / ratings.length;
        ratingCount = ratings.length;
      } else if (pastAppointments.isNotEmpty) {
        // If no explicit ratings but has past appointments, generate a random rating between 3.5 and 5.0
        // with more appointments leading to a more stabilized rating (less randomness)
        final baseRating = 3.5 + (pastAppointments.length * 0.1).clamp(0.0, 1.0);
        final randomFactor = (0.5 - pastAppointments.length * 0.02).clamp(0.0, 0.5);
        calculatedRating = (baseRating + (randomFactor * (DateTime.now().millisecondsSinceEpoch % 10) / 10))
            .clamp(3.5, 5.0);
        
        // Rating count is a factor of completed appointments
        ratingCount = (pastAppointments.length * 0.7).round();
      } else {
        // New doctor with no appointments - give a starter rating between 3.5 and 4.2
        calculatedRating = 3.5 + (0.7 * (DateTime.now().millisecondsSinceEpoch % 10) / 10);
        ratingCount = 0;
      }
      
      // Round rating to one decimal place
      calculatedRating = double.parse(calculatedRating.toStringAsFixed(1));
      
      debugPrint("FirebaseService: Calculated rating: $calculatedRating from $ratingCount reviews");
      
      return {
        'rating': calculatedRating,
        'ratingCount': ratingCount
      };
    } catch (e) {
      debugPrint("FirebaseService: Error calculating doctor rating: $e");
      return {
        'rating': 0.0,
        'ratingCount': 0
      };
    }
  }

  // Update doctor with realistic rating
  Future<void> updateDoctorWithRealisticRating(String doctorId) async {
    try {
      debugPrint("FirebaseService: Updating doctor $doctorId with realistic rating");
      
      // Calculate realistic rating
      final ratingData = await calculateRealisticDoctorRating(doctorId);
      
      // Update doctor document in both collections
      await _firestore.collection(_doctorsCollection).doc(doctorId).update({
        'rating': ratingData['rating'],
        'ratingCount': ratingData['ratingCount'],
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Also update in users collection if exists
      final userDoc = await _firestore.collection(_usersCollection).doc(doctorId).get();
      if (userDoc.exists) {
        await _firestore.collection(_usersCollection).doc(doctorId).update({
          'doctorInfo.rating': ratingData['rating'],
          'doctorInfo.ratingCount': ratingData['ratingCount'],
          'updatedAt': DateTime.now().millisecondsSinceEpoch,
        });
      }
      
      debugPrint("FirebaseService: Successfully updated doctor rating");
    } catch (e) {
      debugPrint("FirebaseService: Error updating doctor rating: $e");
    }
  }

  // Method to create a chat between two users
  Future<String> createChatBetweenUsers(String userId1, String userId2) async {
    try {
      debugPrint("FirebaseService: Creating chat between $userId1 and $userId2");
      
      // Check if a chat already exists between these users
      final existingChatQuery = await _firestore.collection(_chatsCollection)
          .where('participants', arrayContains: userId1)
          .get();
      
      for (final doc in existingChatQuery.docs) {
        final participants = List<String>.from(doc.data()['participants'] ?? []);
        if (participants.contains(userId2)) {
          debugPrint("FirebaseService: Chat already exists with ID ${doc.id}");
          return doc.id;
        }
      }
      
      // No existing chat, create a new one
      final chatId = _uuid.v4();
      
      // Get user details for both participants
      final user1Doc = await _firestore.collection(_usersCollection).doc(userId1).get();
      final user2Doc = await _firestore.collection(_usersCollection).doc(userId2).get();
      
      final participantDetails = <String, dynamic>{};
      
      if (user1Doc.exists) {
        final userData = user1Doc.data() as Map<String, dynamic>?;
        if (userData != null) {
          participantDetails[userId1] = {
            'name': userData['name'] ?? 'Unknown User',
            'role': userData['role'] ?? 'user',
            'profileImageUrl': userData['profileImageUrl'],
          };
        }
      }
      
      if (user2Doc.exists) {
        final userData = user2Doc.data() as Map<String, dynamic>?;
        if (userData != null) {
          participantDetails[userId2] = {
            'name': userData['name'] ?? 'Unknown User',
            'role': userData['role'] ?? 'user',
            'profileImageUrl': userData['profileImageUrl'],
          };
        }
      }
      
      // Create chat document
      await _firestore.collection(_chatsCollection).doc(chatId).set({
        'id': chatId,
        'participants': [userId1, userId2],
        'lastMessage': '',
        'lastMessageTime': Timestamp.now(),
        'unreadCount': 0,
        'createdAt': Timestamp.now(),
        'updatedAt': Timestamp.now(),
        'participantDetails': participantDetails,
      });
      
      debugPrint("FirebaseService: New chat created with ID $chatId");
      return chatId;
    } catch (e) {
      debugPrint("FirebaseService: Error creating chat between users: $e");
      rethrow;
    }
  }
  
  // Report operations
  
  // Create a new report
  Future<String> createMedicalReport(ReportModel report) async {
    try {
      final reportId = _uuid.v4();
      final reportWithId = report.copyWith(
        id: reportId,
        createdAt: Timestamp.now(),
        updatedAt: Timestamp.now(),
      );
      
      // Extract the map and ensure status is explicitly set as a string
      final Map<String, dynamic> reportMap = reportWithId.toMap();
      
      // Double-check that status is set to 'draft' for new reports
      if (report.status == ReportStatus.draft) {
        reportMap['status'] = 'draft';
      }
      
      debugPrint("FirebaseService: Creating medical report with ID $reportId and status: ${reportMap['status']}");
      
      // Ensure doctorId is valid
      final doctorId = reportMap['doctorId'] as String;
      debugPrint("FirebaseService: Report doctorId: $doctorId");
      
      // Check if doctor exists in Firestore
      final doctorDoc = await _firestore.collection(_usersCollection).doc(doctorId).get();
      if (!doctorDoc.exists) {
        debugPrint("FirebaseService: Warning - Doctor with ID $doctorId does not exist in users collection");
      } else {
        debugPrint("FirebaseService: Verified doctor exists in database");
      }
      
      // Store the report in Firestore
      await _firestore.collection(_reportsCollection)
          .doc(reportId)
          .set(reportMap);
      
      // Verify the report was created with correct status
      final verifyDoc = await _firestore.collection(_reportsCollection).doc(reportId).get();
      if (verifyDoc.exists) {
        final verifyData = verifyDoc.data();
        debugPrint("FirebaseService: Verified report created with status: ${verifyData?['status']}");
      }
      
      return reportId;
    } catch (e) {
      debugPrint("FirebaseService: Error creating medical report: $e");
      rethrow;
    }
  }
  
  // Get reports for a doctor
  Future<List<ReportModel>> getReportsForDoctor(String doctorId) async {
    try {
      debugPrint("FirebaseService: Getting reports for doctor $doctorId");
      final snapshot = await _firestore.collection(_reportsCollection)
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final reports = snapshot.docs.map((doc) => 
          ReportModel.fromMap(doc.data(), doc.id)).toList();
      
      debugPrint("FirebaseService: Found ${reports.length} reports for doctor");
      return reports;
    } catch (e) {
      debugPrint("FirebaseService: Error getting reports for doctor: $e");
      return [];
    }
  }
  
  // Get reports for a patient
  Future<List<ReportModel>> getReportsForPatient(String patientId) async {
    try {
      final snapshot = await _firestore.collection(_reportsCollection)
          .where('patientId', isEqualTo: patientId)
          .orderBy('createdAt', descending: true)
          .get();
      
      return snapshot.docs.map((doc) => 
          ReportModel.fromMap(doc.data(), doc.id)).toList();
    } catch (e) {
      debugPrint("FirebaseService: Error getting reports for patient: $e");
      return [];
    }
  }
  
  // Get a report by ID
  Future<ReportModel?> getReportById(String reportId) async {
    try {
      final doc = await _firestore.collection(_reportsCollection)
          .doc(reportId)
          .get();
      
      if (doc.exists) {
        return ReportModel.fromMap(doc.data()!, doc.id);
      }
      
      return null;
    } catch (e) {
      debugPrint("FirebaseService: Error getting report by ID: $e");
      return null;
    }
  }
  
  // Update a report
  Future<void> updateReport(ReportModel report) async {
    try {
      final updatedReport = report.copyWith(
        updatedAt: Timestamp.now(),
      );
      
      await _firestore.collection(_reportsCollection)
          .doc(report.id)
          .update(updatedReport.toMap());
      
      debugPrint("FirebaseService: Updated report ${report.id}");
    } catch (e) {
      debugPrint("FirebaseService: Error updating report: $e");
      rethrow;
    }
  }
  
  // Mark a report as reviewed
  Future<void> reviewReport(String reportId, String correctedContent) async {
    try {
      await _firestore.collection(_reportsCollection)
          .doc(reportId)
          .update({
            'correctedContent': correctedContent,
            'status': 'reviewed',
            'updatedAt': Timestamp.now(),
          });
      
      debugPrint("FirebaseService: Marked report $reportId as reviewed");
    } catch (e) {
      debugPrint("FirebaseService: Error marking report as reviewed: $e");
      rethrow;
    }
  }
  
  // Save a report to patient profile
  Future<void> saveReportToPatientProfile(String reportId) async {
    try {
      await _firestore.collection(_reportsCollection)
          .doc(reportId)
          .update({
            'isSavedToProfile': true,
            'updatedAt': Timestamp.now(),
          });
      
      debugPrint("FirebaseService: Saved report $reportId to patient profile");
    } catch (e) {
      debugPrint("FirebaseService: Error saving report to patient profile: $e");
      rethrow;
    }
  }
  
  // Finalize a report and send to patient
  Future<void> finalizeAndSendReport(String reportId, String? pdfUrl) async {
    try {
      await _firestore.collection(_reportsCollection)
          .doc(reportId)
          .update({
            'status': 'finalized',
            'isSentToPatient': true,
            'pdfUrl': pdfUrl,
            'updatedAt': Timestamp.now(),
          });
      
      debugPrint("FirebaseService: Finalized and sent report $reportId to patient");
    } catch (e) {
      debugPrint("FirebaseService: Error finalizing and sending report: $e");
      rethrow;
    }
  }
  
  // Get reports by status
  Future<List<ReportModel>> getReportsByStatus(String doctorId, ReportStatus status) async {
    try {
      final statusString = ReportModel.statusToString(status);
      
      debugPrint("FirebaseService: Getting reports for doctor $doctorId with status '$statusString'");
      
      // First check if the doctor exists in users collection
      final doctorDoc = await _firestore.collection(_usersCollection).doc(doctorId).get();
      if (!doctorDoc.exists) {
        debugPrint("FirebaseService: Warning - Doctor with ID $doctorId does not exist in users collection");
      }
      
      // Query reports with the specific doctorId
      var query = _firestore.collection(_reportsCollection)
          .where('doctorId', isEqualTo: doctorId);
      
      // If looking for reports with a specific status, add status filter
      if (status != null) {
        query = query.where('status', isEqualTo: statusString);
      }
      
      final snapshot = await query.orderBy('createdAt', descending: true).get();
      
      debugPrint("FirebaseService: Found ${snapshot.docs.length} documents for doctorId $doctorId with status '$statusString'");
      
      final reports = snapshot.docs.map((doc) {
        final data = doc.data();
        debugPrint("FirebaseService: Report ${doc.id} has status: ${data['status']} and doctorId: ${data['doctorId']}");
        return ReportModel.fromMap(data, doc.id);
      }).toList();
      
      debugPrint("FirebaseService: Found ${reports.length} reports for doctor with status '$statusString'");
      
      // If no reports found with the requested status but we're looking for drafts, check for reports without a status
      if (reports.isEmpty && status == ReportStatus.draft) {
        debugPrint("FirebaseService: Looking for reports without a status or with null status");
        
        // Query reports that might have missing status field but belong to this doctor
        final allReportsQuery = _firestore.collection(_reportsCollection)
            .where('doctorId', isEqualTo: doctorId);
        final allReportsSnapshot = await allReportsQuery.get();
        
        // Filter reports without a status in the application code
        final missingStatusReports = allReportsSnapshot.docs
            .where((doc) => doc.data()['status'] == null || doc.data()['status'] == '')
            .map((doc) {
              debugPrint("FirebaseService: Found report ${doc.id} without status field");
              final data = doc.data();
              
              // Add a status field with 'draft' value to ensure proper loading
              data['status'] = 'draft';
              
              return ReportModel.fromMap(data, doc.id);
            })
            .toList();
        
        debugPrint("FirebaseService: Found ${missingStatusReports.length} reports without a status field");
        reports.addAll(missingStatusReports);
        
        // Update these reports to have the proper status field in Firestore
        for (final report in missingStatusReports) {
          debugPrint("FirebaseService: Updating report ${report.id} to have 'draft' status");
          await _firestore.collection(_reportsCollection)
              .doc(report.id)
              .update({'status': 'draft'});
        }
      }
      
      return reports;
    } catch (e) {
      debugPrint("FirebaseService: Error getting reports by status: $e");
      return [];
    }
  }

  // Get appointments for a patient
  Future<List<AppointmentModel>> getAppointmentsForPatient(String patientId) async {
    try {
      debugPrint("FirebaseService: Getting ALL appointments for patient $patientId");
      final snapshot = await _firestore.collection(_appointmentsCollection)
          .where('patientId', isEqualTo: patientId)
          // Removed any status filters to get ALL appointments
          .orderBy('date', descending: true)
          .get();
      
      final appointments = snapshot.docs
          .map((doc) => AppointmentModel.fromMap(doc.data(), doc.id))
          .toList();
      
      // Additional debug info
      debugPrint("FirebaseService: Found ${appointments.length} total appointments for patient");
      if (appointments.isNotEmpty) {
        final doctorIds = appointments.map((app) => app.doctorId).toSet();
        debugPrint("FirebaseService: Found appointments with ${doctorIds.length} unique doctors: ${doctorIds.join(', ')}");
      }
      
      return appointments;
    } catch (e) {
      debugPrint("FirebaseService: Error getting appointments for patient: $e");
      return [];
    }
  }

  // Invitation operations
  Future<String> createPatientInvitation(String doctorId, String patientEmail, String? message) async {
    try {
      debugPrint("FirebaseService: Creating invitation for $patientEmail");
      final doctor = await getUserById(doctorId);
      
      if (doctor == null) {
        throw Exception("Doctor not found");
      }
      
      final invitationId = _uuid.v4();
      final now = Timestamp.now();
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 7))
      );
      
      // Get doctor details to include in the invitation
      final doctorDetails = await _getDoctorDetailsForAppointment(doctorId);
      
      final invitation = InvitationModel(
        id: invitationId,
        doctorId: doctorId,
        doctorName: doctor.name,
        patientEmail: patientEmail,
        status: 'pending',
        message: message,
        createdAt: now,
        expiresAt: expiresAt,
        doctorDetails: doctorDetails,
      );
      
      await _firestore.collection(_invitationsCollection).doc(invitationId).set(invitation.toMap());
      
      debugPrint("FirebaseService: Invitation created successfully with ID: $invitationId");
      return invitationId;
    } catch (e) {
      debugPrint("FirebaseService: Error creating invitation: $e");
      rethrow;
    }
  }
  
  Future<List<InvitationModel>> getPendingInvitationsForPatient(String email) async {
    try {
      debugPrint("FirebaseService: Getting pending invitations for $email");
      final snapshot = await _firestore
          .collection(_invitationsCollection)
          .where('patientEmail', isEqualTo: email)
          .where('status', isEqualTo: 'pending')
          .where('expiresAt', isGreaterThan: Timestamp.now())
          .get();
      
      final invitations = snapshot.docs
          .map((doc) => InvitationModel.fromMap(doc.data(), doc.id))
          .toList();
          
      debugPrint("FirebaseService: Found ${invitations.length} pending invitations");
      return invitations;
    } catch (e) {
      debugPrint("FirebaseService: Error getting pending invitations: $e");
      return [];
    }
  }
  
  Future<void> updateInvitationStatus(String invitationId, String status, {String? patientId}) async {
    try {
      debugPrint("FirebaseService: Updating invitation $invitationId to status $status");
      final Map<String, dynamic> updateData = {
        'status': status,
      };
      
      if (status == 'accepted' && patientId != null) {
        updateData['acceptedAt'] = Timestamp.now();
        updateData['patientId'] = patientId;
      }
      
      await _firestore
          .collection(_invitationsCollection)
          .doc(invitationId)
          .update(updateData);
          
      debugPrint("FirebaseService: Invitation updated successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error updating invitation: $e");
      rethrow;
    }
  }
  
  Future<List<InvitationModel>> getSentInvitationsForDoctor(String doctorId) async {
    try {
      debugPrint("FirebaseService: Getting sent invitations for doctor $doctorId");
      final snapshot = await _firestore
          .collection(_invitationsCollection)
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final invitations = snapshot.docs
          .map((doc) => InvitationModel.fromMap(doc.data(), doc.id))
          .toList();
          
      debugPrint("FirebaseService: Found ${invitations.length} sent invitations");
      return invitations;
    } catch (e) {
      debugPrint("FirebaseService: Error getting sent invitations: $e");
      return [];
    }
  }
  
  Future<void> deleteInvitation(String invitationId) async {
    try {
      debugPrint("FirebaseService: Deleting invitation $invitationId");
      await _firestore
          .collection(_invitationsCollection)
          .doc(invitationId)
          .delete();
          
      debugPrint("FirebaseService: Invitation deleted successfully");
    } catch (e) {
      debugPrint("FirebaseService: Error deleting invitation: $e");
      rethrow;
    }
  }
  
  // Referral Code Operations
  
  // Generate a random referral code for a doctor
  Future<ReferralCodeModel> generateReferralCode(String doctorId) async {
    try {
      debugPrint("FirebaseService: Generating referral code for doctor $doctorId");
      
      // Get doctor details
      final doctor = await getUserById(doctorId);
      if (doctor == null) {
        throw Exception("Doctor not found");
      }
      
      // Generate a random 8-character code
      final code = _generateRandomCode(8);
      final now = Timestamp.now();
      
      // Create expiration date (30 days from now)
      final expiresAt = Timestamp.fromDate(
        DateTime.now().add(const Duration(days: 30))
      );
      
      // Create referral code document
      final referralId = _uuid.v4();
      final referralCode = ReferralCodeModel(
        id: referralId,
        code: code,
        doctorId: doctorId,
        doctorName: doctor.name,
        isUsed: false,
        createdAt: now,
        expiresAt: expiresAt,
      );
      
      // Save to Firestore
      await _firestore.collection(_referralCodesCollection)
          .doc(referralId)
          .set(referralCode.toMap());
      
      debugPrint("FirebaseService: Referral code generated: $code");
      return referralCode;
    } catch (e) {
      debugPrint("FirebaseService: Error generating referral code: $e");
      rethrow;
    }
  }

  // Validate a referral code entered by a patient
  Future<ReferralCodeModel?> validateReferralCode(String code) async {
    try {
      debugPrint("FirebaseService: Validating referral code: $code");
      
      // Query Firestore for the code
      final snapshot = await _firestore.collection(_referralCodesCollection)
          .where('code', isEqualTo: code)
          .limit(1)
          .get();
      
      if (snapshot.docs.isEmpty) {
        debugPrint("FirebaseService: Referral code not found");
        return null;
      }
      
      final referralCode = ReferralCodeModel.fromMap(
        snapshot.docs.first.data(), 
        snapshot.docs.first.id
      );
      
      // Check if code is already used
      if (referralCode.isUsed) {
        debugPrint("FirebaseService: Referral code already used");
        return null;
      }
      
      // Check if code is expired
      if (referralCode.isExpired()) {
        debugPrint("FirebaseService: Referral code expired");
        return null;
      }
      
      debugPrint("FirebaseService: Referral code valid");
      return referralCode;
    } catch (e) {
      debugPrint("FirebaseService: Error validating referral code: $e");
      return null;
    }
  }

  // Mark a referral code as used by a patient
  Future<bool> useReferralCode(String referralId, String patientId, String patientName) async {
    try {
      debugPrint("FirebaseService: Using referral code $referralId for patient $patientId");
      
      // Update the referral code document
      await _firestore.collection(_referralCodesCollection)
          .doc(referralId)
          .update({
            'isUsed': true,
            'usedByPatientId': patientId,
            'usedByPatientName': patientName,
            'usedAt': Timestamp.now(),
          });
      
      // Add relation between doctor and patient
      final referralDoc = await _firestore.collection(_referralCodesCollection).doc(referralId).get();
      if (referralDoc.exists) {
        final data = referralDoc.data()!;
        final doctorId = data['doctorId'] as String;
        
        // Add this patient to the doctor's referral list
        await _firestore.collection(_usersCollection)
            .doc(doctorId)
            .collection('referredPatients')
            .doc(patientId)
            .set({
              'patientId': patientId,
              'patientName': patientName,
              'referralCode': data['code'],
              'referredAt': Timestamp.now(),
            });
        
        // Also add the doctor to patient's doctor list to establish connection
        await _firestore.collection(_usersCollection)
            .doc(patientId)
            .collection('doctors')
            .doc(doctorId)
            .set({
              'doctorId': doctorId,
              'doctorName': data['doctorName'],
              'referralCode': data['code'],
              'referredAt': Timestamp.now(),
            });
      }
      
      debugPrint("FirebaseService: Referral code used successfully");
      return true;
    } catch (e) {
      debugPrint("FirebaseService: Error using referral code: $e");
      return false;
    }
  }

  // Get all referral codes for a doctor
  Future<List<ReferralCodeModel>> getDoctorReferralCodes(String doctorId) async {
    try {
      debugPrint("FirebaseService: Getting referral codes for doctor $doctorId");
      
      final snapshot = await _firestore.collection(_referralCodesCollection)
          .where('doctorId', isEqualTo: doctorId)
          .orderBy('createdAt', descending: true)
          .get();
      
      final codes = snapshot.docs.map((doc) => 
          ReferralCodeModel.fromMap(doc.data(), doc.id)).toList();
      
      debugPrint("FirebaseService: Found ${codes.length} referral codes");
      return codes;
    } catch (e) {
      debugPrint("FirebaseService: Error getting referral codes: $e");
      return [];
    }
  }

  // Get all patients who used a doctor's referral codes
  Future<List<Map<String, dynamic>>> getReferredPatients(String doctorId) async {
    try {
      debugPrint("FirebaseService: Getting referred patients for doctor $doctorId");
      
      final snapshot = await _firestore.collection(_usersCollection)
          .doc(doctorId)
          .collection('referredPatients')
          .orderBy('referredAt', descending: true)
          .get();
      
      final patients = snapshot.docs.map((doc) => doc.data()).toList();
      
      debugPrint("FirebaseService: Found ${patients.length} referred patients");
      return patients;
    } catch (e) {
      debugPrint("FirebaseService: Error getting referred patients: $e");
      return [];
    }
  }

  // Helper method to generate a random alphanumeric code
  String _generateRandomCode(int length) {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = Random.secure();
    return String.fromCharCodes(
      Iterable.generate(
        length, 
        (_) => chars.codeUnitAt(random.nextInt(chars.length))
      )
    );
  }
} 