import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/services/ai_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/models/message_model.dart' as model;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:location/location.dart' as location_plugin;
import 'dart:io';
import 'dart:async';

// Audio recording and playback
import 'package:record/record.dart' as record_package;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

// AI Service provider
final aiServiceProvider = Provider<AIService>((ref) => AIService());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

enum AttachmentType {
  none,
  image,
  document,
  location,
  audio
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isRead;
  final String? attachmentUrl;
  final AttachmentType attachmentType;
  final Duration? audioDuration;
  final Map<String, dynamic>? metadata;
  final bool isTyping;
  
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentType = AttachmentType.none,
    this.audioDuration,
    this.metadata,
    this.isTyping = false,
  });
}

class ChatPage extends ConsumerStatefulWidget {
  final String chatId;
  
  const ChatPage({
    super.key,
    required this.chatId,
  });

  @override
  ConsumerState<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends ConsumerState<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isAttaching = false;
  bool _isRecording = false;
  bool _isTyping = false;
  bool _showSuggestions = true; // Track whether to show suggestion chips
  String _selectedLanguage = 'english'; // Default language
  String? _attachmentPath;
  AttachmentType _currentAttachmentType = AttachmentType.none;
  
  // Added for model selection
  late AIService _aiService;
  String _currentModelId = '';
  final bool _showModelSelector = false;
  
  // Sample data - in a real app, this would come from a database
  late List<ChatMessage> _messages;
  late Map<String, dynamic> _chatInfo;
  
  // For AI conversation
  final _conversationHistory = <Map<String, String>>[];
  
  // Example questions for the AI assistant - English
  final List<String> _exampleQuestions = [
    "I have a persistent headache for 3 days",
    "How can I manage my diabetes better?",
    "What are signs of high blood pressure?",
    "Can you recommend exercises for back pain?",
    "What should I know about COVID-19 vaccines?",
  ];
  
  // Hinglish example questions
  final List<String> _hinglishExampleQuestions = [
    "Mujhe 3 din se headache hai",
    "Main apne diabetes ko better manage kaise kar sakta hoon?",
    "High blood pressure ke kya signs hote hain?",
    "Back pain ke liye kya exercises recommend karenge?",
    "COVID-19 vaccines ke bare mein mujhe kya janna chahiye?",
  ];
  
  // Hindi example questions
  final List<String> _hindiExampleQuestions = [
    "मुझे 3 दिनों से सिरदर्द है",
    "मैं अपने मधुमेह को बेहतर कैसे नियंत्रित कर सकता हूँ?",
    "उच्च रक्तचाप के क्या लक्षण होते हैं?",
    "पीठ दर्द के लिए कौन से व्यायाम अच्छे हैं?",
    "COVID-19 टीकों के बारे में मुझे क्या जानना चाहिए?",
  ];
  
  // Audio recording variables
  bool _isRecordingPaused = false;
  int _recordingDuration = 0;
  Timer? _timer;
  String? _audioFilePath;
  File? _currentAudioFile;
  bool _isPlayingAudio = false;
  String? _currentlyPlayingAudioId;
  
  // Audio recording and playback instances
  final _audioRecorder = record_package.AudioRecorder();
  final Map<String, AudioPlayer> _audioPlayers = {};
  
  @override
  void initState() {
    super.initState();
    _loadChatData();
    _testAIConnection();
    
    // Check and create a valid chat connection
    _checkAndCreateChatConnection();
    
    // Initialize AI service
    _aiService = ref.read(aiServiceProvider);
    _currentModelId = _aiService.currentModelId;
    
    // Show language selection dialog for AI Assistant when first opened
    if (widget.chatId == '3') {
      Future.delayed(Duration.zero, () {
        _showLanguageSelectionDialog();
      });
    }
    
    // Check for microphone permission status
    _checkMicrophonePermission();
    
    // For debugging: Save chat data to ensure Firestore is working
    Future.delayed(const Duration(seconds: 2), () {
      _saveAllMessagesToFirestore();
    });
  }
  
  // Method to check and create a valid chat connection if needed
  Future<void> _checkAndCreateChatConnection() async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      
      if (user == null) {
        debugPrint('Cannot check chat connection: user not logged in');
        return;
      }
      
      // Skip for AI assistant chat which has a fixed ID
      if (widget.chatId == '3') {
        return;
      }
      
      // Check if we're using a user ID as chat ID (doctor-patient direct chat)
      final otherUserId = widget.chatId;
      if (otherUserId.isNotEmpty && otherUserId != user.uid) {
        debugPrint('Checking chat connection between ${user.uid} and $otherUserId');
        
        // Try to create a chat connection, or get the existing one
        final chatId = await firebaseService.createChatBetweenUsers(user.uid, otherUserId);
        
        // If the chatId is different than the current widget.chatId, we would
        // ideally navigate to the correct chat. However, since we can't modify the
        // widget chatId property, we'll just use what we have.
        if (chatId != widget.chatId) {
          debugPrint('Note: Real chat ID is $chatId but using ${widget.chatId}');
        }
      }
    } catch (e) {
      debugPrint('Error checking chat connection: $e');
    }
  }
  
  // Save all existing messages to Firestore
  Future<void> _saveAllMessagesToFirestore() async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      
      if (user == null) {
        debugPrint('Cannot save messages: user not logged in');
        return;
      }
      
      debugPrint('Saving all ${_messages.length} messages to Firestore');
      
      // Ensure chat document exists first
      final chatExists = await _ensureChatExists(firebaseService, user.uid);
      if (!chatExists) {
        debugPrint('Could not create or verify chat document');
        return;
      }
      
      // Save each message to Firestore
      for (final message in _messages) {
        // Skip temporary messages
        if (message.id.startsWith('processing-')) continue;
        
        // Convert AttachmentType to MessageType
        model.MessageType messageType = model.MessageType.text;
        if (message.attachmentType == AttachmentType.image) {
          messageType = model.MessageType.image;
        } else if (message.attachmentType == AttachmentType.audio) {
          messageType = model.MessageType.audio;
        }
        
        // Save message to Firestore
        await firebaseService.sendMessage(
          model.MessageModel(
            id: message.id,
            chatId: widget.chatId,
            senderId: message.isUser ? user.uid : (widget.chatId == '3' ? 'ai-assistant' : widget.chatId),
            text: message.text,
            timestamp: Timestamp.fromDate(message.timestamp),
            status: model.MessageStatus.sent,
            type: messageType,
            fileInfo: message.attachmentUrl != null ? {'url': message.attachmentUrl} : null,
          ),
        );
      }
      
      // Update the chat's last message in Firestore if there are messages
      if (_messages.isNotEmpty) {
        final lastMessage = _messages.last;
        await firebaseService.updateChatLastMessage(
          widget.chatId,
          lastMessage.text,
          Timestamp.fromDate(lastMessage.timestamp),
        );
        
        // Save conversation for easy access in messages tab
        await firebaseService.saveChatConversation(user.uid, widget.chatId);
        
        debugPrint('All messages saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving all messages to Firestore: $e');
    }
  }
  
  // Helper method to ensure the chat document exists
  Future<bool> _ensureChatExists(FirebaseService firebaseService, String userId) async {
    try {
      // Check if chat document exists
      final chatDoc = await FirebaseFirestore.instance
          .collection('chats')
          .doc(widget.chatId)
          .get();
      
      if (!chatDoc.exists) {
        debugPrint('Chat document does not exist. Creating it...');
        
        // Get the other participant details (assuming it's a doctor or assistant chat)
        String otherParticipantId = '';
        String? otherParticipantName;
        
        if (widget.chatId == '3') {
          // AI Assistant chat
          otherParticipantId = 'ai-assistant';
          otherParticipantName = 'MediConnect Assistant';
        } else {
          // Check if the chatId represents a doctor/user ID
          otherParticipantId = widget.chatId;
          final userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(otherParticipantId)
              .get();
          
          if (userDoc.exists) {
            otherParticipantName = userDoc.data()?['name'];
          }
        }
        
        if (otherParticipantId.isEmpty) {
          debugPrint('Could not determine other participant ID');
          return false;
        }
        
        // Create the chat document
        await FirebaseFirestore.instance.collection('chats').doc(widget.chatId).set({
          'participants': [userId, otherParticipantId],
          'lastMessage': _messages.isNotEmpty ? _messages.last.text : '',
          'lastMessageTime': _messages.isNotEmpty 
              ? Timestamp.fromDate(_messages.last.timestamp) 
              : Timestamp.now(),
          'unreadCount': 0,
          'createdAt': Timestamp.now(),
          'updatedAt': Timestamp.now(),
          'participantDetails': {
            otherParticipantId: {
              'name': otherParticipantName ?? 'Unknown User',
              'role': widget.chatId == '3' ? 'assistant' : 'doctor',
            }
          }
        });
        
        debugPrint('Chat document created successfully');
      }
      
      return true;
    } catch (e) {
      debugPrint('Error ensuring chat exists: $e');
      return false;
    }
  }
  
  void _loadChatData() {
    // Simulate loading chat data based on chatId
    switch (widget.chatId) {
      case '1':
        _chatInfo = {
          'name': 'Dr. Sarah Johnson',
          'specialty': 'Cardiologist',
          'avatar': null,
          'isOnline': true,
          'lastSeen': DateTime.now(),
        };
        break;
      case '3':
        _chatInfo = {
          'name': 'MediConnect Assistant',
          'specialty': 'AI Health Assistant',
          'avatar': Icons.smart_toy,
          'isOnline': true,
          'lastSeen': DateTime.now(),
        };
        break;
      default:
        _chatInfo = {
          'name': 'Dr. Unknown',
          'specialty': 'Physician',
          'avatar': null,
          'isOnline': false,
          'lastSeen': DateTime.now().subtract(const Duration(minutes: 30)),
        };
    }
    
    if (widget.chatId == '3') { // AI Assistant
      // Initialize with empty messages as we'll show language selection first
      _messages = [];
      
      // Don't add initial message since we're showing language selection first
      
    } else {
      // Sample messages for doctor chats
      _messages = [
        ChatMessage(
          id: '1',
          text: 'Hello, how can I help you today?',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 2)),
          isRead: true,
        ),
        ChatMessage(
          id: '2',
          text: 'I\'ve been experiencing some chest pain lately.',
          isUser: true,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 45)),
          isRead: true,
        ),
        ChatMessage(
          id: '3',
          text: 'I\'m sorry to hear that. Can you describe the pain? Is it sharp, dull, or pressuring?',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 30)),
          isRead: true,
        ),
        ChatMessage(
          id: '4',
          text: 'It\'s more of a pressure. Sometimes it feels like there\'s something heavy on my chest.',
          isUser: true,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1, minutes: 15)),
          isRead: true,
        ),
        ChatMessage(
          id: '5',
          text: 'And how long does it typically last?',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(days: 1, hours: 1)),
          isRead: true,
        ),
        ChatMessage(
          id: '6',
          text: 'About 5-10 minutes. It usually happens after climbing stairs or walking for a while.',
          isUser: true,
          timestamp: DateTime.now().subtract(const Duration(days: 1, minutes: 45)),
          isRead: true,
        ),
        ChatMessage(
          id: '7',
          text: 'I think we should schedule an appointment to evaluate this. These symptoms could indicate several different conditions. Would you be available this week?',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(days: 1, minutes: 30)),
          isRead: true,
        ),
        ChatMessage(
          id: '8',
          text: 'Yes, I can come in. Should I bring anything or prepare in any way?',
          isUser: true,
          timestamp: DateTime.now().subtract(const Duration(days: 1, minutes: 15)),
          isRead: true,
        ),
        ChatMessage(
          id: '9',
          text: 'Please bring a list of any medications you\'re currently taking. Also, try to keep a log of when you experience the chest pain, what activities trigger it, and how long it lasts until your appointment.',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(hours: 23)),
          isRead: true,
        ),
        ChatMessage(
          id: '10',
          text: 'I will. Thank you, doctor.',
          isUser: true,
          timestamp: DateTime.now().subtract(const Duration(hours: 22, minutes: 45)),
          isRead: true,
        ),
        ChatMessage(
          id: '11',
          text: 'Good morning! Just checking in - how are you feeling today?',
          isUser: false,
          timestamp: DateTime.now().subtract(const Duration(hours: 2)),
          isRead: false,
        ),
      ];
    }
    
    // Scroll to bottom after loading messages
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

  Future<void> _testAIConnection() async {
    if (widget.chatId == '3') {
      // Test AI connection for AI Assistant chat
      final aiService = ref.read(aiServiceProvider);
      final isConnected = await aiService.testConnection();
      
      if (!isConnected && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not connect to AI service. Some features may be limited.'),
            backgroundColor: Colors.red,
          ),
        );
      } else if (mounted) {
        // Get available models
        _currentModelId = aiService.currentModelId;
        setState(() {});
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _timer?.cancel();
    
    // Dispose audio recorder and players
    _audioRecorder.dispose();
    for (final player in _audioPlayers.values) {
      player.dispose();
    }
    
    super.dispose();
  }
  
  Future<void> _sendMessage() async {
    final messageText = _messageController.text.trim();
    if (messageText.isEmpty) return;
    
    setState(() {
      _isTyping = true;
    });
    
    _messageController.clear();
    
    // Add user message
    final userMessage = ChatMessage(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      text: messageText,
      isUser: true,
      timestamp: DateTime.now(),
    );
    
    setState(() {
      _messages.add(userMessage);
      _scrollToBottom();
    });
    
    // Get AI response
    if (widget.chatId == '3') {
      await _processMessageWithAI(messageText);
    } else {
      // Mock response for other chats
      await Future.delayed(const Duration(seconds: 1));
      _addResponse('Thanks for your message. I will get back to you soon.');
    }
    
    // Save messages to Firestore
    await _saveConversationToFirestore();
    
    // Ensure the conversation is saved to the dashboard
    await _saveConversationToDashboard();
    
    setState(() {
      _isTyping = false;
    });
  }
  
  void _scrollToBottom() {
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
  
  void _toggleAttachments() {
    setState(() {
      _isAttaching = !_isAttaching;
    });
  }
  
  void _toggleRecording() {
    if (_isRecording) {
      // Stop recording
      _stopRecording();
    } else {
      // Start recording
      _startRecording();
    }
  }
  
  Future<bool> _requestMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    }
    
    final result = await Permission.microphone.request();
    return result.isGranted;
  }
  
  void _startRecording() async {
    // Request permission with improved handling
    final hasPermission = await _requestMicrophonePermission();
    
    if (!hasPermission) {
      return; // The permission dialog was already shown in _requestMicrophonePermission
    }
    
    try {
      // Get temporary directory to save the recording
      final tempDir = await getTemporaryDirectory();
      final filePath = '${tempDir.path}/audio_${DateTime.now().millisecondsSinceEpoch}.m4a';
      
      // Configure the recorder
      if (!await _audioRecorder.isRecording()) {
        // Start recording with config object
        await _audioRecorder.start(
          record_package.RecordConfig(
            encoder: record_package.AudioEncoder.aacLc,
            bitRate: 128000,
            sampleRate: 44100,
          ),
          path: filePath,
        );
        
        setState(() {
          _isRecording = true;
          _isRecordingPaused = false;
          _recordingDuration = 0;
          _currentAudioFile = File(filePath);
        });
        
        // Start timer to track recording duration
        _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
          if (!_isRecordingPaused && _isRecording) {
            setState(() {
              _recordingDuration++;
            });
          }
        });
        
        debugPrint('Recording started at: $filePath');
      } else {
        debugPrint('Already recording');
        // Show an error message
      }
    } catch (e) {
      debugPrint('Error starting recording: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Error starting recording: $e',
            style: const TextStyle(color: Colors.white),
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      );
      _stopRecording(canceled: true);
    }
  }
  
  void _toggleRecordingPause() async {
    if (await _audioRecorder.isPaused()) {
      await _audioRecorder.resume();
      setState(() {
        _isRecordingPaused = false;
      });
    } else {
      await _audioRecorder.pause();
      setState(() {
        _isRecordingPaused = true;
      });
    }
  }
  
  Future<void> _stopRecording({bool canceled = false}) async {
    if (!_isRecording) return;
    
    final path = await _audioRecorder.stop();
    _audioFilePath = path;
    
    setState(() {
      _isRecording = false;
      _isRecordingPaused = false;
      _recordingDuration = 0;
      _timer?.cancel();
      _timer = null;
    });
    
    if (canceled || _audioFilePath == null) {
      debugPrint('Recording canceled or no file path');
      return;
    }
    
    final audioFile = File(_audioFilePath!);
    
    if (await audioFile.exists()) {
      debugPrint('Audio file saved: $_audioFilePath');
      
      setState(() {
        _isTyping = true;
      });
      
      // Add user audio message
      final userMessage = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: 'Voice message',
        isUser: true,
        timestamp: DateTime.now(),
        attachmentType: AttachmentType.audio,
        attachmentUrl: _audioFilePath,
        metadata: {'audioPath': _audioFilePath},
      );
      
      setState(() {
        _messages.add(userMessage);
        _scrollToBottom();
      });
      
      // Process the voice message
      await _processVoiceMessageWithAI(audioFile);
      
      // Save messages to Firestore
      await _saveConversationToFirestore();
      
      // Save to dashboard
      await _saveConversationToDashboard();
      
      setState(() {
        _isTyping = false;
      });
    } else {
      debugPrint('Audio file does not exist: $_audioFilePath');
    }
  }
  
  // Toggle audio playback
  void _toggleAudioPlayback(ChatMessage message) async {
    if (message.attachmentUrl == null) return;
    
    final audioId = message.id;
    
    // Check if currently playing this audio
    if (_isPlayingAudio && _currentlyPlayingAudioId == audioId) {
      // Stop playing the current audio
      if (_audioPlayers.containsKey(audioId)) {
        final player = _audioPlayers[audioId]!;
        await player.stop();
        
        setState(() {
          _isPlayingAudio = false;
          _currentlyPlayingAudioId = null;
        });
      }
    } else {
      // Stop any currently playing audio
      if (_isPlayingAudio && _currentlyPlayingAudioId != null && _audioPlayers.containsKey(_currentlyPlayingAudioId)) {
        await _audioPlayers[_currentlyPlayingAudioId]!.stop();
      }
      
      // Create a new player if needed
      if (!_audioPlayers.containsKey(audioId)) {
        _audioPlayers[audioId] = AudioPlayer();
      }
      
      final player = _audioPlayers[audioId]!;
      
      try {
        // Set the audio source
        await player.setFilePath(message.attachmentUrl!);
        
        // Start playing
        await player.play();
        
        setState(() {
          _isPlayingAudio = true;
          _currentlyPlayingAudioId = audioId;
        });
        
        // Listen for playback completion
        player.playerStateStream.listen((state) {
          if (state.processingState == ProcessingState.completed) {
            setState(() {
              if (_currentlyPlayingAudioId == audioId) {
                _isPlayingAudio = false;
                _currentlyPlayingAudioId = null;
              }
            });
          }
        });
      } catch (e) {
        debugPrint('Error playing audio: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error playing audio: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
  
  // Process voice message with AI
  Future<void> _processVoiceMessageWithAI(File audioFile) async {
    // Show a temporary message indicating that the voice is being processed
    final tempMessageId = 'processing-${DateTime.now().millisecondsSinceEpoch}';
    
    setState(() {
      _isTyping = true;
      // Add a temporary message to indicate processing
      _messages.add(ChatMessage(
        id: tempMessageId,
        text: "Processing your voice message...",
        isUser: false,
        timestamp: DateTime.now(),
      ));
      _scrollToBottom();
    });
    
    try {
      // Transcribe the audio file using AIService
      final aiService = ref.read(aiServiceProvider);
      String transcribedText;
      
      try {
        transcribedText = await aiService.transcribeAudio(audioFile);
        debugPrint('Transcription successful: $transcribedText');
      } catch (e) {
        debugPrint('Error transcribing audio: $e');
        transcribedText = '';
      }
      
      // If transcription is empty, prompt the user to type their question
      if (transcribedText.isEmpty) {
        transcribedText = "I couldn't understand your voice message. Could you please type your question instead?";
      }
      
      // Remove the temporary message
      setState(() {
        _messages.removeWhere((msg) => msg.id == tempMessageId);
      });
      
      // Add the transcribed text as a user message
      final transcribedMessageId = 'transcription-${DateTime.now().millisecondsSinceEpoch}';
      _messages.add(ChatMessage(
        id: transcribedMessageId,
        text: transcribedText,
        isUser: true,
        timestamp: DateTime.now(),
      ));
      
      // Add to conversation history
      _conversationHistory.add({
        'role': 'user',
        'content': transcribedText
      });
      
      // Get AI response
      await _processMessageWithAI(transcribedText);
      
    } catch (e) {
      // Remove the temporary message
      setState(() {
        _messages.removeWhere((msg) => msg.id == tempMessageId);
      });
      
      // Add error message
      _messages.add(ChatMessage(
        id: 'error-${DateTime.now().millisecondsSinceEpoch}',
        text: "Sorry, I couldn't process your voice message. Please try again or type your message.",
        isUser: false,
        timestamp: DateTime.now(),
      ));
      
      debugPrint('Error processing voice message: $e');
    } finally {
      // Ensure typing indicator is off
      setState(() {
        _isTyping = false;
      });
    }
  }
  
  // Build audio message bubble with waveform
  Widget _buildAudioMessageBubble(ChatMessage message) {
    final isPlaying = _isPlayingAudio && _currentlyPlayingAudioId == message.id;
    final duration = message.audioDuration ?? const Duration(seconds: 30);
    final minutes = (duration.inSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    final durationText = '$minutes:$seconds';
    
    return InkWell(
      onTap: () => _toggleAudioPlayback(message),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Play/Pause button
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: message.isUser ? Colors.white.withOpacity(0.2) : AppColors.primary.withOpacity(0.2),
              ),
              child: Icon(
                isPlaying ? Icons.pause : Icons.play_arrow,
                color: message.isUser ? Colors.white : AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 8),
            
            // Audio waveform visualization
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 30,
                    child: CustomPaint(
                      painter: AudioWaveformPainter(
                        waveColor: message.isUser ? Colors.white.withOpacity(0.7) : AppColors.primary.withOpacity(0.7),
                        isPlaying: isPlaying,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Voice Message',
                        style: TextStyle(
                          color: message.isUser ? Colors.white.withOpacity(0.8) : AppColors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                      Text(
                        durationText,
                        style: TextStyle(
                          color: message.isUser ? Colors.white.withOpacity(0.8) : AppColors.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Only show save dialog for AI Assistant chat and if there are messages
        if (widget.chatId == '3' && _messages.isNotEmpty && _messages.any((msg) => msg.isUser)) {
          return await _showSaveConversationDialog();
        }
        return true; // Allow pop for other chats
      },
      child: Scaffold(
        appBar: AppBar(
          title: LayoutBuilder(
            builder: (context, constraints) {
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _chatInfo['avatar'] is IconData
                    ? Icon(_chatInfo['avatar'] as IconData, color: AppColors.primary)
                    : CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        radius: 16,
                        child: Text(
                          _chatInfo['name'].toString().substring(0, 1),
                          style: const TextStyle(
                            color: Colors.black87,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _chatInfo['name'],
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: _chatInfo['isOnline'] ? Colors.green : Colors.grey,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                _chatInfo['isOnline'] 
                                    ? 'Online' 
                                    : 'Last seen ${_formatRelativeTime(_chatInfo['lastSeen'])}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
          ),
          titleSpacing: 0,
          actions: [
            // Model selector (only for AI chat)
            if (widget.chatId == '3')
              IconButton(
                icon: const Icon(Icons.auto_awesome),
                tooltip: 'Change AI Model',
                onPressed: () {
                  _showModelSelectionDialog();
                },
              ),
            // Language menu (only for AI chat)
            if (widget.chatId == '3')
              PopupMenuButton<String>(
                onSelected: (value) {
                  setState(() {
                    _selectedLanguage = value;
                  });
                  _showLanguageGreeting(value);
                },
                icon: const Icon(Icons.language),
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'english',
                    child: Text('English'),
                  ),
                  const PopupMenuItem(
                    value: 'hinglish',
                    child: Text('Hinglish'),
                  ),
                  const PopupMenuItem(
                    value: 'hindi',
                    child: Text('हिंदी (Hindi)'),
                  ),
                ],
              ),
            // Video call and voice call buttons (only for doctor chats, not AI)
            if (widget.chatId != '3')
              IconButton(
                icon: const Icon(Icons.videocam),
                onPressed: () {
                  // TODO: Implement video call
                },
              ),
            if (widget.chatId != '3')
              IconButton(
                icon: const Icon(Icons.call),
                onPressed: () {
                  // TODO: Implement voice call
                },
              ),
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () {
                // TODO: Show more options
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16).copyWith(
                        bottom: _showSuggestions && widget.chatId == '3' && !_messages.any((msg) => msg.isUser) ? 100 : 16,
                      ),
                      itemCount: _messages.length,
                      itemBuilder: (context, index) {
                        final message = _messages[index];
                        return _buildMessageBubble(message);
                      },
                    ),
                    
                    // Show suggestion chips if enabled (only for AI chat and when no messages from user yet)
                    if (_showSuggestions && 
                        widget.chatId == '3' && 
                        !_messages.any((msg) => msg.isUser))
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: _buildSuggestionChips(),
                      ),
                  ],
                ),
              ),
              
              // Typing indicator
              if (_isTyping)
                Container(
                  padding: const EdgeInsets.only(left: 16, bottom: 8),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            _buildTypingDot(1),
                            _buildTypingDot(2),
                            _buildTypingDot(3),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'MediConnect Assistant is typing...',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              
              // Message input
              Container(
                padding: EdgeInsets.only(
                  left: 16, 
                  right: 16, 
                  top: 12, 
                  bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? 12 : 12 + MediaQuery.of(context).padding.bottom,
                ),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      offset: const Offset(0, -2),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.attach_file),
                      color: AppColors.textSecondary,
                      onPressed: _toggleAttachments,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: TextField(
                          controller: _messageController,
                          decoration: InputDecoration(
                            hintText: _getHintTextForLanguage(),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _sendMessage(),
                        ),
                      ),
                    ),
                    // Recording button with additional UI for recording state
                    _isRecording
                        ? Row(
                            children: [
                              // Recording indicator with timer
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.red.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: _isRecordingPaused ? Colors.grey : Colors.red,
                                      ),
                                    ),
                                    const SizedBox(width: 5),
                                    Text(
                                      '${(_recordingDuration ~/ 60).toString().padLeft(2, '0')}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Pause/resume button
                              IconButton(
                                icon: Icon(_isRecordingPaused ? Icons.play_arrow : Icons.pause),
                                color: AppColors.textSecondary,
                                onPressed: _toggleRecordingPause,
                              ),
                              // Stop recording button - cancels recording
                              IconButton(
                                icon: const Icon(Icons.stop),
                                color: Colors.red,
                                onPressed: () => _stopRecording(canceled: true),
                                tooltip: 'Cancel recording',
                              ),
                              // Send audio message button
                              IconButton(
                                icon: const Icon(Icons.send),
                                color: AppColors.primary,
                                onPressed: () => _stopRecording(),
                                tooltip: 'Send voice message',
                              ),
                            ],
                          )
                        : Row(
                            children: [
                              IconButton(
                                icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                                color: _isRecording ? Colors.red : AppColors.textSecondary,
                                onPressed: _toggleRecording,
                              ),
                              IconButton(
                                icon: const Icon(Icons.send),
                                color: AppColors.primary,
                                onPressed: _sendMessage,
                              ),
                            ],
                          ),
                  ],
                ),
              ),
              
              if (_isAttaching) _buildAttachmentOptions(),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildMessageBubble(ChatMessage message) {
    final timeString = _formatMessageTime(message.timestamp);
    final isAI = !message.isUser && widget.chatId == '3';
    
    return Container(
      margin: EdgeInsets.only(
        top: 8,
        bottom: 8,
        left: message.isUser ? 64 : 16,
        right: message.isUser ? 16 : 64,
      ),
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: message.isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: message.isUser ? AppColors.primary : AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(20).copyWith(
                bottomRight: message.isUser ? const Radius.circular(0) : null,
                bottomLeft: !message.isUser ? const Radius.circular(0) : null,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Show typing indicator if message is a typing indicator
                if (message.isTyping)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildTypingDot(0),
                      _buildTypingDot(1),
                      _buildTypingDot(2),
                    ],
                  )
                // Show text content if present and not a voice message
                else if (message.text.isNotEmpty && message.attachmentType != AttachmentType.audio)
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                
                // Show attachment based on type
                if (!message.isTyping && message.attachmentType == AttachmentType.audio) 
                  _buildAudioMessageBubble(message)
                else if (!message.isTyping && message.attachmentUrl != null && message.attachmentType != AttachmentType.none) 
                  _buildAttachmentByType(message),
              ],
            ),
          ),
          if (!message.isTyping)
            Padding(
              padding: const EdgeInsets.only(top: 4, left: 4, right: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isAI) 
                    const Icon(
                      Icons.smart_toy, 
                      size: 12, 
                      color: AppColors.textTertiary,
                    ),
                  if (isAI) 
                    const SizedBox(width: 4),
                  Text(
                    timeString,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                  const SizedBox(width: 4),
                  if (message.isUser && message.isRead)
                    const Icon(
                      Icons.done_all,
                      size: 14,
                      color: AppColors.success,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildAttachmentByType(ChatMessage message) {
    switch (message.attachmentType) {
      case AttachmentType.image:
        return Padding(
          padding: const EdgeInsets.only(top: 8),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: Image.file(
              File(message.attachmentUrl!),
              width: 200,
              height: 200,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey.shade300,
                  child: const Center(
                    child: Icon(
                      Icons.broken_image,
                      size: 40,
                      color: Colors.grey,
                    ),
                  ),
                );
              },
            ),
          ),
        );
        
      case AttachmentType.document:
        final fileExtension = message.attachmentUrl!.split('.').last.toLowerCase();
        IconData iconData;
        Color iconColor;
        
        switch (fileExtension) {
          case 'pdf':
            iconData = Icons.picture_as_pdf;
            iconColor = Colors.red;
            break;
          case 'doc':
          case 'docx':
            iconData = Icons.article;
            iconColor = Colors.blue;
            break;
          default:
            iconData = Icons.description;
            iconColor = Colors.orange;
            break;
        }
        
        return Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: message.isUser ? Colors.white.withOpacity(0.2) : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                iconData,
                color: iconColor,
                size: 30,
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  message.attachmentUrl!.split('/').last,
                  style: TextStyle(
                    color: message.isUser ? Colors.white : AppColors.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
        
      case AttachmentType.location:
        // No additional UI needed for location as it's displayed in text
        return const SizedBox.shrink();
        
      default:
        return const SizedBox.shrink();
    }
  }
  
  Widget _buildTypingDot(int position) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600),
      curve: Curves.easeInOut,
      builder: (context, value, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 2),
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(
              (math.sin((value * math.pi * 2) + (position * 0.5)) + 1) / 2,
            ),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
  
  Widget _buildAttachmentOptions() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        border: Border(
          top: BorderSide(
            color: AppColors.surfaceDark,
            width: 1,
          ),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildAttachmentOption(
            icon: Icons.photo,
            label: 'Image',
            color: Colors.blue,
            onTap: () {
              _pickImage();
              _toggleAttachments();
            },
          ),
          _buildAttachmentOption(
            icon: Icons.camera_alt,
            label: 'Camera',
            color: Colors.green,
            onTap: () {
              _takePhoto();
              _toggleAttachments();
            },
          ),
          _buildAttachmentOption(
            icon: Icons.insert_drive_file,
            label: 'Document',
            color: Colors.orange,
            onTap: () {
              _pickDocument();
              _toggleAttachments();
            },
          ),
          _buildAttachmentOption(
            icon: Icons.location_on,
            label: 'Location',
            color: Colors.red,
            onTap: () {
              _shareLocation();
              _toggleAttachments();
            },
          ),
        ],
      ),
    );
  }
  
  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTypography.bodySmall,
          ),
        ],
      ),
    );
  }

  String _formatMessageTime(DateTime time) {
    return '${time.hour}:${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(date.year, date.month, date.day);
    
    if (messageDate == today) {
      return 'Today';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else {
      return '${date.day}/${date.month}/${date.year}';
    }
  }
  
  bool _isSameDay(DateTime date1, DateTime date2) {
    return date1.year == date2.year &&
        date1.month == date2.month &&
        date1.day == date2.day;
  }
  
  // Get hint text based on selected language
  String _getHintTextForLanguage() {
    switch (_selectedLanguage) {
      case 'hindi':
        return 'अपना संदेश लिखें...';
      case 'hinglish':
        return 'Apna message likhein...';
      default:
        return 'Type your message...';
    }
  }
  
  // Builds the suggestion chips for quick questions based on selected language
  Widget _buildSuggestionChips() {
    // Choose example questions based on selected language
    final exampleQuestions = _selectedLanguage == 'hindi' 
        ? _hindiExampleQuestions 
        : (_selectedLanguage == 'hinglish' 
            ? _hinglishExampleQuestions 
            : _exampleQuestions);
    
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.95),
            Colors.white,
          ],
        ),
        border: Border(
          top: BorderSide(
            color: AppColors.surfaceDark.withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 12),
            child: Text(
              _selectedLanguage == 'hindi' 
                  ? 'पूछें:' 
                  : (_selectedLanguage == 'hinglish' 
                      ? 'Poochein:' 
                      : 'Try asking:'),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Container(
            height: 48,
            margin: const EdgeInsets.only(bottom: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: exampleQuestions.map((question) => 
                  ActionChip(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                    label: Text(
                      question,
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _messageController.text = question;
                        _showSuggestions = false; // Hide suggestions after selection
                      });
                      _sendMessage();
                    },
                  )
                ).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  // Show greeting in the selected language when language is changed
  void _showLanguageGreeting(String language) {
    String greeting;
    
    setState(() {
      _isTyping = true;
    });
    
    // Call the AI service to generate an appropriate greeting
    final aiService = ref.read(aiServiceProvider);
    
    try {
      // Clear conversation history to start fresh with new language
      _conversationHistory.clear();
      
      // Set default greeting based on language
      switch (language) {
        case 'hindi':
          greeting = 'नमस्ते! मैं मेडीकनेक्ट AI स्वास्थ्य सहायक हूँ। आपकी स्वास्थ्य संबंधित प्रश्नों में सहायता करने के लिए मैं यहां हूँ।';
          break;
        case 'hinglish':
          greeting = 'Hello! Main MediConnect AI Health Assistant hoon. Aapki health questions mein help karne ke liye main yahan hoon.';
          break;
        default:
          greeting = 'Hello! I\'m the MediConnect AI Health Assistant. I\'m here to help with your health-related questions.';
      }
      
      // Add initial greeting to chat
      final greetingId = 'language-greeting-${DateTime.now().millisecondsSinceEpoch}';
      
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            id: greetingId,
            text: greeting,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
        
        // Add greeting to conversation history
        _conversationHistory.add({
          'role': 'assistant',
          'content': greeting
        });
        
        // Update example questions based on language
        _showSuggestions = true;
      });
      
      // Generate a real AI greeting in the selected language
      String greetingPrompt;
      switch (language) {
        case 'hindi':
          greetingPrompt = "मेडीकनेक्ट AI स्वास्थ्य सहायक के रूप में खुद का परिचय दें और उपयोगकर्ता का स्वागत करें। यह संक्षिप्त लेकिन मित्रवत होना चाहिए।";
          break;
        case 'hinglish':
          greetingPrompt = "MediConnect AI Health Assistant ke roop mein khud ka parichay dein aur user ka swagat karein. Yeh brief lekin friendly hona chahiye.";
          break;
        default:
          greetingPrompt = "Please introduce yourself as MediConnect AI Health Assistant and welcome the user. Keep it brief but friendly.";
      }
      
      // Add this prompt to history for context
      _conversationHistory.add({
        'role': 'user',
        'content': greetingPrompt
      });
      
      // Get AI response
      aiService.generateResponse(
        prompt: greetingPrompt,
        conversationHistory: [], // Fresh conversation
        language: language,
      ).then((aiGreeting) {
        if (mounted && aiGreeting.isNotEmpty) {
          setState(() {
            _messages.add(
              ChatMessage(
                id: 'ai-greeting-${DateTime.now().millisecondsSinceEpoch}',
                text: aiGreeting,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
            
            // Replace the initial greeting in the conversation history
            if (_conversationHistory.isNotEmpty && _conversationHistory.first['role'] == 'assistant') {
              _conversationHistory[0] = {
                'role': 'assistant',
                'content': aiGreeting
              };
            } else {
              // Or add if there isn't one
              _conversationHistory.add({
                'role': 'assistant',
                'content': aiGreeting
              });
            }
            
            // Scroll to the bottom
            _scrollToBottom();
          });
        }
      }).catchError((e) {
        debugPrint("Error generating AI greeting: $e");
      });
      
      // Scroll to bottom after sending greeting
      _scrollToBottom();
    } catch (e) {
      setState(() {
        _isTyping = false;
      });
      debugPrint("Error in _showLanguageGreeting: $e");
    }
  }

  // Check microphone permission
  Future<void> _checkMicrophonePermission() async {
    final status = await Permission.microphone.status;
    if (status.isDenied) {
      // We'll request permission when user tries to record
      debugPrint('Microphone permission is currently denied');
    }
  }
  
  // Show custom permission dialog
  Future<void> _showPermissionDialog() async {
    return showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.mic_off,
                color: AppColors.primary,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                'Microphone Access Required',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'To send voice messages, MediConnect needs access to your microphone. Please enable microphone access in your device settings.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      openAppSettings();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Open Settings',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Image picker method
  Future<void> _pickImage() async {
    bool hasPermission = await _requestPhotoPermission();
    
    if (!hasPermission) return;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (image != null) {
        _handleAttachment('image', image.path);
      }
    } catch (e) {
      debugPrint('Error picking image: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
  
  // Camera method
  Future<void> _takePhoto() async {
    bool hasPermission = await _requestCameraPermission();
    
    if (!hasPermission) return;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? photo = await picker.pickImage(
        source: ImageSource.camera,
        imageQuality: 70,
      );
      
      if (photo != null) {
        _handleAttachment('photo', photo.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error taking photo: $e')),
      );
    }
  }
  
  // Document picker method
  Future<void> _pickDocument() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'doc', 'docx', 'txt'],
      );
      
      if (result != null && result.files.single.path != null) {
        _handleAttachment('document', result.files.single.path!);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking document: $e')),
      );
    }
  }
  
  // Location sharing method
  Future<void> _shareLocation() async {
    bool hasPermission = await _requestLocationPermission();
    
    if (!hasPermission) return;
    
    try {
      final locationPlugin = location_plugin.Location();
      bool serviceEnabled = await locationPlugin.serviceEnabled();
      
      if (!serviceEnabled) {
        serviceEnabled = await locationPlugin.requestService();
        if (!serviceEnabled) return;
      }
      
      location_plugin.PermissionStatus permissionStatus = await locationPlugin.hasPermission();
      
      if (permissionStatus == location_plugin.PermissionStatus.denied) {
        permissionStatus = await locationPlugin.requestPermission();
        if (permissionStatus != location_plugin.PermissionStatus.granted) return;
      }
      
      final locationData = await locationPlugin.getLocation();
      
      // Create a location message with coordinates
      final locationMessage = "My current location: https://maps.google.com/maps?q=${locationData.latitude},${locationData.longitude}";
      
      // Send the location message
      _messageController.text = locationMessage;
      _sendMessage();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error sharing location: $e')),
      );
    }
  }
  
  // Request photo permission
  Future<bool> _requestPhotoPermission() async {
    var status = await Permission.photos.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      status = await Permission.photos.request();
      return status.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      _showGenericPermissionDialog('Photos');
      return false;
    }
    
    return false;
  }
  
  // Request camera permission
  Future<bool> _requestCameraPermission() async {
    var status = await Permission.camera.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      status = await Permission.camera.request();
      return status.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      _showGenericPermissionDialog('Camera');
      return false;
    }
    
    return false;
  }
  
  // Request location permission
  Future<bool> _requestLocationPermission() async {
    var status = await Permission.location.status;
    
    if (status.isGranted) {
      return true;
    }
    
    if (status.isDenied) {
      status = await Permission.location.request();
      return status.isGranted;
    }
    
    if (status.isPermanentlyDenied) {
      _showGenericPermissionDialog('Location');
      return false;
    }
    
    return false;
  }
  
  // Show generic permission dialog for other permissions
  void _showGenericPermissionDialog(String permissionName) {
    showDialog(
      context: context,
      builder: (BuildContext context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                permissionName == 'Photos' ? Icons.photo_library :
                permissionName == 'Camera' ? Icons.camera_alt :
                permissionName == 'Location' ? Icons.location_on : Icons.settings,
                color: AppColors.primary,
                size: 50,
              ),
              const SizedBox(height: 16),
              Text(
                '$permissionName Access Required',
                style: AppTypography.headlineSmall.copyWith(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'To use this feature, MediConnect needs access to your $permissionName. Please enable $permissionName access in your device settings.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Cancel',
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    onPressed: () {
                      openAppSettings();
                      Navigator.pop(context);
                    },
                    child: Text(
                      'Open Settings',
                      style: AppTypography.bodyMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  // Handle the attachment
  void _handleAttachment(String type, String path) {
    // In a real app, you would upload the file to Firebase Storage
    // and then send a message with the attachment URL
    
    setState(() {
      // Determine attachment type
      AttachmentType attachmentType = AttachmentType.none;
      String messageText = "";
      
      if (type == 'image' || type == 'photo') {
        attachmentType = AttachmentType.image;
        messageText = type == 'photo' ? "📷 Camera photo" : "🖼️ Image";
      } else if (type == 'document') {
        attachmentType = AttachmentType.document;
        messageText = "📄 Document attachment: ${path.split('/').last}";
      } else if (type == 'location') {
        attachmentType = AttachmentType.location;
        messageText = path; // The location message/URL
      }
      
      // Add a message with attachment info
      final message = ChatMessage(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        text: messageText,
        isUser: true,
        timestamp: DateTime.now(),
        attachmentUrl: path,
        attachmentType: attachmentType,
      );
      
      _messages.add(message);
      
      // If it's a chat with AI assistant, add the user message to conversation history
      if (widget.chatId == '3') {
        _conversationHistory.add({
          'role': 'user',
          'content': message.text,
        });
        
        // Show typing indicator
        _isTyping = true;
        
        // Simulate AI response for attachment
        _generateAIResponse("I've received your ${type == 'photo' ? 'photo' : type}. If you need any health-related information, please let me know how I can assist you.");
      }
    });
    
    // Scroll to bottom after sending message
    _scrollToBottom();
  }
  
  // Generate AI response
  Future<void> _generateAIResponse(String responseText) async {
    // Simulate a brief typing delay
    await Future.delayed(const Duration(milliseconds: 1500));
    
    if (mounted) {
      setState(() {
        _isTyping = false;
        _messages.add(
          ChatMessage(
            id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
            text: responseText,
            isUser: false,
            timestamp: DateTime.now(),
          ),
        );
      });
      
      // Add to conversation history
      _conversationHistory.add({
        'role': 'assistant',
        'content': responseText
      });
      
      // Scroll to bottom after receiving response
      _scrollToBottom();
    }
  }

  // Format the relative time for showing last seen
  String _formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);
    
    if (difference.inMinutes < 1) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} minute${difference.inMinutes == 1 ? '' : 's'} ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} hour${difference.inHours == 1 ? '' : 's'} ago';
    } else {
      return '${difference.inDays} day${difference.inDays == 1 ? '' : 's'} ago';
    }
  }

  // Add model selection dialog
  void _showModelSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.auto_awesome,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select AI Model',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(
                      Icons.close,
                      color: AppColors.textSecondary,
                      size: 24,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Choose the AI model that powers your health assistant',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: _aiService.availableModels.map((model) {
                      final isSelected = model.id == _currentModelId;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: isSelected 
                              ? AppColors.primary.withOpacity(0.1) 
                              : Colors.white,
                          border: Border.all(
                            color: isSelected 
                                ? AppColors.primary 
                                : Colors.grey.shade300,
                            width: 1.5,
                          ),
                        ),
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _currentModelId = model.id;
                              _aiService.currentModelId = model.id;
                            });
                            
                            // Show a confirmation message
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('AI model changed to ${model.name}'),
                                backgroundColor: AppColors.primary,
                                duration: const Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            );
                            
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              children: [
                                Container(
                                  width: 24,
                                  height: 24,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isSelected 
                                        ? AppColors.primary 
                                        : Colors.transparent,
                                    border: isSelected 
                                        ? null 
                                        : Border.all(color: Colors.grey.shade400),
                                  ),
                                  child: isSelected 
                                      ? const Icon(
                                          Icons.check,
                                          color: Colors.white,
                                          size: 16,
                                        ) 
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        model.name,
                                        style: AppTypography.bodyMedium.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        model.description,
                                        style: AppTypography.bodySmall.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Language selection dialog for pre-visit assessment
  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        elevation: 8,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.language,
                    color: AppColors.primary,
                    size: 28,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Select Language',
                      style: AppTypography.headlineSmall.copyWith(
                        color: AppColors.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                'Choose a language for communication with your health assistant',
                style: AppTypography.bodySmall.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 20),
              _buildLanguageOption(
                'English',
                'English',
                _selectedLanguage == 'english',
                Icons.check_circle_outline,
                onTap: () {
                  setState(() {
                    _selectedLanguage = 'english';
                  });
                  _showLanguageGreeting('english');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _buildLanguageOption(
                'Hinglish',
                'Hindi + English',
                _selectedLanguage == 'hinglish',
                Icons.check_circle_outline,
                onTap: () {
                  setState(() {
                    _selectedLanguage = 'hinglish';
                  });
                  _showLanguageGreeting('hinglish');
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 10),
              _buildLanguageOption(
                'हिंदी (Hindi)',
                'Hindi',
                _selectedLanguage == 'hindi',
                Icons.check_circle_outline,
                onTap: () {
                  setState(() {
                    _selectedLanguage = 'hindi';
                  });
                  _showLanguageGreeting('hindi');
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildLanguageOption(
    String title,
    String subtitle,
    bool isSelected,
    IconData trailingIcon, {
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              trailingIcon,
              color: isSelected ? AppColors.primary : Colors.grey.shade400,
              size: 24,
            ),
          ],
        ),
      ),
    );
  }

  // Save conversation to Firestore after sending/receiving message
  Future<void> _saveConversationToFirestore() async {
    if (widget.chatId != '3') return; // Only save AI assistant conversations
    
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      final authService = ref.read(authServiceProvider);
      final user = await authService.getCurrentUser();
      
      if (user == null) {
        debugPrint('Cannot save conversation: user not logged in');
        return;
      }
      
      // Update the chat's last message in Firestore
      if (_messages.isNotEmpty) {
        final lastMessage = _messages.last;
        
        // Update last message in chat collection
        await firebaseService.updateChatLastMessage(
          widget.chatId,
          lastMessage.text,
          Timestamp.fromDate(lastMessage.timestamp),
        );
        
        // Convert AttachmentType to MessageType
        model.MessageType messageType = model.MessageType.text;
        if (lastMessage.attachmentType == AttachmentType.image) {
          messageType = model.MessageType.image;
        } else if (lastMessage.attachmentType == AttachmentType.audio) {
          messageType = model.MessageType.audio;
        }
        
        // Save message to Firestore
        await firebaseService.sendMessage(
          model.MessageModel(
            id: lastMessage.id,
            chatId: widget.chatId,
            senderId: lastMessage.isUser ? user.uid : 'ai-assistant',
            text: lastMessage.text,
            timestamp: Timestamp.fromDate(lastMessage.timestamp),
            status: model.MessageStatus.sent,
            type: messageType,
            fileInfo: lastMessage.attachmentUrl != null ? {'url': lastMessage.attachmentUrl} : null,
          ),
        );
        
        // Save conversation for easy access in messages tab
        await firebaseService.saveChatConversation(user.uid, widget.chatId);
        
        debugPrint('Conversation with AI saved to Firestore');
      }
    } catch (e) {
      debugPrint('Error saving conversation to Firestore: $e');
    }
  }

  // Show dialog to save conversation before leaving
  Future<bool> _showSaveConversationDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            'Save Conversation?',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Would you like to save this conversation to view it in your Messages tab later?',
            style: AppTypography.bodyMedium,
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(true); // Don't save, but allow pop
              },
              child: Text(
                'Don\'t Save',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                // Save conversation
                await _saveConversationToFirestore();
                
                // Show success toast
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Conversation saved'),
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 2),
                      backgroundColor: AppColors.success,
                    ),
                  );
                }
                
                // Allow pop
                Navigator.of(context).pop(true);
              },
              child: Text(
                'Save',
                style: AppTypography.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
    
    // Default to allow pop if dialog is dismissed somehow
    return result ?? true;
  }

  // Save conversation to dashboard
  Future<void> _saveConversationToDashboard() async {
    try {
      final authService = ref.read(authServiceProvider);
      final firebaseService = ref.read(firebaseServiceProvider);
      final user = await authService.getCurrentUser();
      
      if (user == null) {
        debugPrint('Cannot save conversation: No authenticated user');
        return;
      }
      
      // Save conversation for messages tab
      final success = await firebaseService.saveChatConversation(user.uid, widget.chatId);
      debugPrint('Conversation saved to dashboard: $success');
    } catch (e) {
      debugPrint('Error saving conversation to dashboard: $e');
    }
  }

  // Add a response message (called by _sendMessage when not using AI)
  void _addResponse(String text) {
    setState(() {
      _messages.add(ChatMessage(
        id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
        text: text,
        isUser: false,
        timestamp: DateTime.now(),
      ));
    });
    _scrollToBottom();
  }

  // Process a message with AI (called by _sendMessage)
  Future<void> _processMessageWithAI(String messageText) async {
    // Add to conversation history
    _conversationHistory.add({
      'role': 'user',
      'content': messageText
    });
    
    try {
      // Use the AIService to generate a response
      final aiService = ref.read(aiServiceProvider);
      
      // Display conversation history for debugging
      debugPrint("ChatPage: Conversation history (${_conversationHistory.length} messages):");
      for (var i = 0; i < _conversationHistory.length; i++) {
        final msg = _conversationHistory[i];
        final preview = msg['content'].toString().length > 30 
            ? msg['content'].toString().substring(0, 30) + "..." 
            : msg['content'];
        debugPrint("  ${i+1}. ${msg['role']}: $preview");
      }
      
      // Send the user's message to the AI service
      final response = await aiService.generateResponse(
        prompt: messageText,
        conversationHistory: _conversationHistory,
        language: _selectedLanguage,
      );
      
      if (mounted) {
        setState(() {
          _messages.add(ChatMessage(
            id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        
        // Add to conversation history
        _conversationHistory.add({
          'role': 'assistant',
          'content': response
        });
        
        // Scroll to bottom after receiving response
        _scrollToBottom();
      }
    } catch (e) {
      // Handle errors
      debugPrint("ChatPage: Error getting AI response: $e");
      
      if (mounted) {
        setState(() {
          // Error message in the selected language
          String errorMessage;
          switch (_selectedLanguage) {
            case 'hindi':
              errorMessage = 'मुझे क्षमा करें, आपके अनुरोध को संसाधित करते समय मुझे एक समस्या का सामना करना पड़ा। कृपया एक अलग प्रश्न के साथ फिर से प्रयास करें।';
              break;
            case 'hinglish':
              errorMessage = 'I\'m sorry, aapke request ko process karte waqt mujhe ek issue face karna pada. Please kisi different question ke saath dobara try karein.';
              break;
            default:
              errorMessage = 'I\'m sorry, I encountered an issue while processing your request. Please try again with a different question.';
          }
          
          _messages.add(ChatMessage(
            id: 'ai-error-${DateTime.now().millisecondsSinceEpoch}',
            text: errorMessage,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
        
        // Scroll to bottom after error message
        _scrollToBottom();
      }
    }
  }

  Future<void> _sendMessageToAI(String messageText) async {
    // Add message to conversation history for AI context
    _conversationHistory.add({
      'role': 'user',
      'content': messageText
    });
     
    // Add a temporary "typing" indicator message
    final tempMessageId = 'typing-${DateTime.now().millisecondsSinceEpoch}';
    setState(() {
      _messages.add(ChatMessage(
        id: tempMessageId,
        text: '',
        isUser: false,
        timestamp: DateTime.now(),
        isTyping: true,
      ));
      _scrollToBottom();
    });
      
    try {
      // Use the AIService to generate a response
      final aiService = ref.read(aiServiceProvider);
        
      // Debug logging
      debugPrint("ChatPage: Sending message to AI: ${messageText.substring(0, math.min(messageText.length, 50))}...");
       
      // Send the message to the AI service with retry
      final response = await _getAIResponseWithRetry(aiService, messageText);
       
      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg.id == tempMessageId);
      });
        
      if (response != null) {
        // Add AI response message
        setState(() {
          _messages.add(ChatMessage(
            id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
            text: response,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
          
        // Add message to conversation history for AI context
        _conversationHistory.add({
          'role': 'assistant',
          'content': response
        });
      } else {
        // Add error message if response is null
        setState(() {
          String errorMessage;
          switch (_selectedLanguage) {
            case 'hindi':
              errorMessage = 'मुझे क्षमा करें, आपके प्रश्न का उत्तर देते समय मुझे एक समस्या का सामना करना पड़ा। कृपया एक अलग प्रश्न के साथ फिर से प्रयास करें।';
              break;
            case 'hinglish':
              errorMessage = 'Sorry, aapke question ka answer dete waqt mujhe ek problem hui. Kripya apna question dobara poochein ya thodi der baad try karein.';
              break;
            default:
              errorMessage = 'I apologize, but I encountered an error while processing your question. Could you please try again with a different question?';
          }
            
          _messages.add(ChatMessage(
            id: 'ai-error-${DateTime.now().millisecondsSinceEpoch}',
            text: errorMessage,
            isUser: false,
            timestamp: DateTime.now(),
          ));
        });
      }
        
      // Scroll to bottom after adding message
      _scrollToBottom();
        
    } catch (e) {
      // Remove typing indicator
      setState(() {
        _messages.removeWhere((msg) => msg.id == tempMessageId);
      });
        
      // Add error message
      setState(() {
        String errorMessage;
        switch (_selectedLanguage) {
          case 'hindi':
            errorMessage = 'मुझे क्षमा करें, आपके प्रश्न का उत्तर देते समय मुझे एक समस्या का सामना करना पड़ा। कृपया एक अलग प्रश्न के साथ फिर से प्रयास करें।';
            break;
          case 'hinglish':
            errorMessage = 'Sorry, aapke question ka answer dete waqt mujhe ek problem hui. Kripya apna question dobara poochein ya thodi der baad try karein.';
            break;
          default:
            errorMessage = 'I apologize, but I encountered an error while processing your question. Could you please try again with a different question?';
        }
          
        _messages.add(ChatMessage(
          id: 'ai-error-${DateTime.now().millisecondsSinceEpoch}',
          text: errorMessage,
          isUser: false,
          timestamp: DateTime.now(),
        ));
      });
        
      // Log the error
      debugPrint("ChatPage: Error processing message with AI: $e");
        
      // Scroll to bottom after adding error message
      _scrollToBottom();
    }
  }
 
  // Helper method to get AI response with retry mechanism
  Future<String?> _getAIResponseWithRetry(AIService aiService, String prompt) async {
    const maxRetries = 2;
    int retryCount = 0;
     
    while (retryCount <= maxRetries) {
      try {
        final response = await aiService.generateResponse(
          prompt: prompt,
          conversationHistory: _conversationHistory,
          language: _selectedLanguage,
        );
         
        // Check if response is valid and not an error message
        if (response.isNotEmpty && 
            !response.contains("I apologize, but I encountered an error") &&
            !response.contains("मुझे क्षमा करें") && // Hindi error start
            !response.contains("Sorry, aapke")) {  // Hinglish error start
          return response;
        } else {
          retryCount++;
          if (retryCount <= maxRetries) {
            debugPrint("ChatPage: Invalid response, retrying ($retryCount/$maxRetries)");
            await Future.delayed(Duration(milliseconds: 500 * retryCount));
          }
        }
      } catch (e) {
        retryCount++;
        if (retryCount <= maxRetries) {
          debugPrint("ChatPage: Error in AI response, retrying ($retryCount/$maxRetries): $e");
          await Future.delayed(Duration(milliseconds: 800 * retryCount));
        } else {
          debugPrint("ChatPage: Max retries reached, giving up: $e");
          return null;
        }
      }
    }
     
    return null; // Return null if all retries failed
  }
}

// Custom painter for audio waveform visualization
class AudioWaveformPainter extends CustomPainter {
  final Color waveColor;
  final bool isPlaying;
  final List<double> _waveform = List.generate(30, 
      (index) => 0.2 + 0.6 * math.sin(index / 3) * math.Random().nextDouble());

  AudioWaveformPainter({
    required this.waveColor,
    required this.isPlaying,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..color = waveColor
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    final width = size.width;
    final height = size.height;
    final barWidth = width / (_waveform.length * 2);

    for (int i = 0; i < _waveform.length; i++) {
      final barHeight = _waveform[i] * height;
      final x = i * barWidth * 2 + barWidth / 2;
      final y1 = height / 2 - barHeight / 2;
      final y2 = height / 2 + barHeight / 2;
      canvas.drawLine(Offset(x, y1), Offset(x, y2), paint);
    }
  }

  @override
  bool shouldRepaint(AudioWaveformPainter oldDelegate) {
    return isPlaying != oldDelegate.isPlaying || waveColor != oldDelegate.waveColor;
  }
} 