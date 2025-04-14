import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/services/ai_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/models/pre_anamnesis_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;

// Providers for services
final aiServiceProvider = Provider<AIService>((ref) {
  return AIService();
});

final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

final firebaseServiceProvider = Provider<FirebaseService>((ref) {
  return FirebaseService();
});

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final List<String>? options;
  final String? voiceNoteUrl;
  
  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.options,
    this.voiceNoteUrl,
  });
}

class PreAnamnesisPage extends ConsumerStatefulWidget {
  const PreAnamnesisPage({super.key});

  @override
  ConsumerState<PreAnamnesisPage> createState() => _PreAnamnesisPageState();
}

class _PreAnamnesisPageState extends ConsumerState<PreAnamnesisPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<ChatMessage> _messages = [];
  bool _isRecording = false;
  bool _isLoading = false;
  bool _isCompleted = false;
  
  // Patient data collected during the conversation
  final Map<String, dynamic> _patientData = {
    'mainSymptoms': '',
    'duration': '',
    'treatments': '',
    'painLevel': '',
    'medicalHistory': '',
    'additionalInfo': '',
  };
  
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _startChat();
  }

  Future<void> _loadUserData() async {
    final authService = ref.read(authServiceProvider);
    _currentUser = await authService.getCurrentUserData();
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _startChat() {
    // Initial message from AI
    _addBotMessage(
      'Hello! I\'m your MediConnect assistant. Before your appointment, I\'d like to ask you a few questions about your symptoms. This will help your doctor prepare for your visit. Would you like to proceed?',
      options: ['Yes, I\'m ready', 'No, maybe later'],
    );
  }

  void _addBotMessage(String text, {List<String>? options, String? voiceNoteUrl}) {
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
        options: options,
        voiceNoteUrl: voiceNoteUrl,
      ));
      _isLoading = false;
    });
    
    // Scroll to bottom after message is added
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _addUserMessage(String text) {
    if (text.trim().isEmpty) return;
    
    setState(() {
      _messages.add(ChatMessage(
        text: text,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      _messageController.clear();
      _isLoading = true;
    });
    
    // Scroll to bottom after message is added
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    // Handle user message with AI
    _handleUserMessage(text);
  }

  void _handleUserMessage(String text) async {
    final aiService = ref.read(aiServiceProvider);
    final currentMessageIndex = _messages.length;
    
    // Store user information in the appropriate category
    if (currentMessageIndex == 2) { // First user response
      if (text.toLowerCase().contains('no')) {
        _addBotMessage(
          'No problem. You can complete the assessment later when you\'re ready. Is there anything else I can help you with?',
          options: ['Return to home', 'Ask a quick question'],
        );
        return;
      }
    } else if (currentMessageIndex == 4) { // After symptom description
      _patientData['mainSymptoms'] = text;
    } else if (currentMessageIndex == 6) { // After timing response
      _patientData['duration'] = text;
    } else if (currentMessageIndex == 8) { // After medications response
      _patientData['treatments'] = text;
    } else if (currentMessageIndex == 10) { // After pain scale
      _patientData['painLevel'] = text;
    } else if (currentMessageIndex == 12) { // After allergies
      _patientData['medicalHistory'] = text;
    } else if (currentMessageIndex == 14) { // After additional info
      _patientData['additionalInfo'] = text;
    }
    
    try {
      String aiResponse = '';
      
      // Using conversation flow logic to determine AI response
      if (currentMessageIndex == 2) { // After first user response
        aiResponse = 'Great! Could you please describe the main reason for your visit? What symptoms are you experiencing?';
      } else if (currentMessageIndex == 4) { // After symptoms description
        aiResponse = 'Thank you for sharing that. When did these symptoms first start?';
      } else if (currentMessageIndex == 6) { // After timing response
        aiResponse = 'Have you tried any medications or treatments for this condition? If yes, please describe what you\'ve tried and whether it helped.';
      } else if (currentMessageIndex == 8) { // After medications response
        aiResponse = 'On a scale from 1 to 10, how would you rate your pain or discomfort?';
        _addBotMessage(aiResponse, options: ['1-3 (Mild)', '4-7 (Moderate)', '8-10 (Severe)']);
        return;
      } else if (currentMessageIndex == 10) { // After pain scale
        aiResponse = 'Do you have any known allergies or ongoing medical conditions I should be aware of?';
      } else if (currentMessageIndex == 12) { // After allergies
        aiResponse = 'Thank you for all this information. Is there anything else you\'d like to add that might be relevant for your doctor?';
      } else if (currentMessageIndex == 14) { // After final info
        aiResponse = 'I\'ve collected all the necessary information for your doctor. Would you like me to generate a pre-anamnesis report based on what you\'ve shared?';
        _addBotMessage(aiResponse, options: ['Yes, generate report', 'No, I\'m done']);
        return;
      } else if (currentMessageIndex == 16) { // After report request
        if (text.toLowerCase().contains('yes') || text.toLowerCase().contains('generate')) {
          setState(() {
            _isLoading = true;
          });
          
          // Generate pre-anamnesis report using AI
          final report = await aiService.generatePreAnamnesis(
            patientDescription: "Patient is seeking medical consultation.",
            symptoms: _patientData['mainSymptoms'],
            previousConditions: [_patientData['medicalHistory']],
          );
          
          // Save report to Firebase
          await _savePreAnamnesisToFirebase(report);
          
          aiResponse = 'Here\'s your pre-anamnesis report:\n\n$report\n\nThis information has been saved and will be available to your doctor before your appointment. Would you like to complete the session now?';
          setState(() {
            _isCompleted = true;
          });
          _addBotMessage(aiResponse, options: ['Complete session', 'Ask another question']);
          return;
        } else {
          aiResponse = 'Is there anything else you\'d like to discuss before we end the session?';
          _addBotMessage(aiResponse, options: ['Complete session', 'Ask another question']);
          return;
        }
      } else if (currentMessageIndex == 18) { // Final message
        if (text.toLowerCase().contains('complete')) {
          setState(() {
            _isCompleted = true;
          });
          aiResponse = 'Thank you for providing this information. Your doctor will review it before your appointment. See you soon!';
        } else {
          aiResponse = 'What else would you like to discuss or ask about?';
        }
      } else {
        // For any other messages, use the AI to generate a contextual response
        // Create conversation history for context
        List<Map<String, String>> conversationHistory = [];
        for (int i = 0; i < _messages.length; i++) {
          conversationHistory.add({
            'role': _messages[i].isUser ? 'user' : 'assistant',
            'content': _messages[i].text,
          });
        }
        
        // Get AI response
        aiResponse = await aiService.generateResponse(
          prompt: text,
          conversationHistory: conversationHistory,
        );
        
        // Add options for the user if at the end of the pre-anamnesis
        if (_isCompleted) {
          _addBotMessage(aiResponse, options: ['Complete session', 'Ask another question']);
          return;
        }
      }
      
      _addBotMessage(aiResponse);
    } catch (e) {
      _addBotMessage('I apologize, but I encountered an error processing your request. Please try again later.');
    }
  }

  Future<void> _savePreAnamnesisToFirebase(String reportContent) async {
    if (_currentUser == null) return;
    
    final firebaseService = ref.read(firebaseServiceProvider);
    
    final preAnamnesis = PreAnamnesisModel(
      id: '', // Will be set by the service
      patientId: _currentUser!.id,
      symptoms: _patientData['mainSymptoms'] ?? '',
      duration: _patientData['duration'] ?? '',
      painLevel: _patientData['painLevel'],
      medications: _patientData['treatments'],
      allergies: _patientData['medicalHistory'],
      additionalInfo: _patientData['additionalInfo'],
      createdAt: Timestamp.now(),
      updatedAt: Timestamp.now(),
    );
    
    await firebaseService.createPreAnamnesis(preAnamnesis);
  }

  void _handleOptionSelected(String option) {
    _addUserMessage(option);
  }

  void _toggleRecording() async {
    if (_isRecording) {
      // Stop recording
      setState(() {
        _isRecording = false;
        _isLoading = true;
      });
      
      // Simulate processing the audio
      // In a real app, this would be actual audio processing
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _isLoading = false;
      });
      
      // Add a simulated transcription
      _addUserMessage("I've been having headaches and feeling dizzy for the past few days, especially in the morning.");
    } else {
      // Start recording
      setState(() {
        _isRecording = true;
      });
      
      try {
        final aiService = ref.read(aiServiceProvider);
        final audioFile = await aiService.recordAudio();
        
        // This would be a real implementation in a production app
        // final transcription = await aiService.transcribeAudio(audioFile);
        // _addUserMessage(transcription);
      } catch (e) {
        setState(() {
          _isRecording = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not record audio: $e')),
        );
      }
    }
  }

  void _finishSession() {
    Navigator.of(context).pushReplacementNamed(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Pre-Visit Assessment'),
            Text(
              'AI Health Assistant',
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.info_outline),
            onPressed: () {
              // Show information about the chatbot
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('About Pre-Visit Assessment'),
                  content: const Text(
                    'This chatbot collects information about your symptoms before your appointment. '
                    'The data is securely stored and shared only with your healthcare provider. '
                    'This is not a diagnostic tool and does not replace medical advice.'
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Chat messages
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  // Show loading indicator
                  return Align(
                    alignment: Alignment.centerLeft,
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            spreadRadius: 1,
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.medical_services_rounded,
                              color: AppColors.primary,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Thinking...',
                            style: AppTypography.bodySmall,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                
                final message = _messages[index];
                final isUserMessage = message.isUser;
                
                return Align(
                  alignment: isUserMessage ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: isUserMessage ? AppColors.primary : AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(16).copyWith(
                        bottomRight: isUserMessage ? const Radius.circular(0) : null,
                        bottomLeft: !isUserMessage ? const Radius.circular(0) : null,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          spreadRadius: 1,
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Voice note player if available
                        if (message.voiceNoteUrl != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceMedium,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.play_arrow,
                                  color: AppColors.primary,
                                  size: 24,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Container(
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withOpacity(0.2),
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                    child: Align(
                                      alignment: Alignment.centerLeft,
                                      child: Container(
                                        width: 50,
                                        height: 4,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary,
                                          borderRadius: BorderRadius.circular(2),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '0:30',
                                  style: AppTypography.bodySmall.copyWith(
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 8),
                        ],
                        
                        // Message text
                        Text(
                          message.text,
                          style: AppTypography.bodyMedium.copyWith(
                            color: isUserMessage ? AppColors.textLight : AppColors.textPrimary,
                          ),
                        ),
                        
                        // Options buttons if available
                        if (message.options != null && message.options!.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: message.options!.map((option) {
                              return InkWell(
                                onTap: () => _handleOptionSelected(option),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                  decoration: BoxDecoration(
                                    color: isUserMessage 
                                        ? AppColors.surfaceLight 
                                        : AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: AppColors.primary.withOpacity(0.5),
                                    ),
                                  ),
                                  child: Text(
                                    option,
                                    style: AppTypography.bodySmall.copyWith(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ],
                        
                        // Timestamp
                        const SizedBox(height: 4),
                        Text(
                          '${message.timestamp.hour.toString().padLeft(2, '0')}:'
                          '${message.timestamp.minute.toString().padLeft(2, '0')}',
                          style: AppTypography.overline.copyWith(
                            color: isUserMessage 
                                ? AppColors.textLight.withOpacity(0.7) 
                                : AppColors.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Input area
          if (!_isCompleted)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    spreadRadius: 1,
                    blurRadius: 4,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  // Voice recording button
                  GestureDetector(
                    onTap: _toggleRecording,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _isRecording 
                            ? AppColors.error.withOpacity(0.1)
                            : AppColors.surfaceMedium,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _isRecording ? Icons.stop : Icons.mic,
                        color: _isRecording ? AppColors.error : AppColors.primary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Text input field
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      decoration: InputDecoration(
                        hintText: _isRecording 
                            ? 'Recording audio...' 
                            : 'Type your message...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        filled: true,
                        fillColor: AppColors.surfaceMedium,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        enabled: !_isRecording && !_isLoading,
                      ),
                      onSubmitted: _addUserMessage,
                    ),
                  ),
                  
                  const SizedBox(width: 12),
                  
                  // Send button
                  GestureDetector(
                    onTap: () => _addUserMessage(_messageController.text),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Transform.rotate(
                        angle: -math.pi / 4,
                        child: Icon(
                          Icons.send,
                          color: AppColors.textLight,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            )
          else
            Container(
              padding: const EdgeInsets.all(16),
              child: GradientButton(
                text: 'Return to Home',
                onPressed: _finishSession,
              ),
            ),
        ],
      ),
    );
  }
} 