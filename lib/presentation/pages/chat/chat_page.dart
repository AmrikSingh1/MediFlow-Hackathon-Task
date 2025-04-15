import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/services/ai_service.dart';
import 'dart:math' as math;
import 'package:permission_handler/permission_handler.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:location/location.dart' as location_plugin;
import 'dart:io';

// AI Service provider
final aiServiceProvider = Provider<AIService>((ref) => AIService());

enum AttachmentType {
  none,
  image,
  document,
  location
}

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isRead;
  final String? attachmentUrl;
  final AttachmentType attachmentType;
  
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isRead = false,
    this.attachmentUrl,
    this.attachmentType = AttachmentType.none,
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
  String? _attachmentPath; // Track the path of the current attachment
  
  // Sample data - in a real app, this would come from a database
  late List<ChatMessage> _messages;
  late Map<String, dynamic> _chatInfo;
  
  // For AI conversation
  final List<Map<String, String>> _conversationHistory = [];
  
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
  
  @override
  void initState() {
    super.initState();
    _loadChatData();
    _testAIConnection();
    
    // Show language selection dialog for AI Assistant when first opened
    if (widget.chatId == '3') {
      Future.delayed(Duration.zero, () {
        _showLanguageSelectionDialog();
      });
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
    if (widget.chatId == '3') { // AI Assistant
      try {
        final aiService = ref.read(aiServiceProvider);
        final isConnected = await aiService.testConnection();
        
        if (!isConnected && mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                id: 'connection-${DateTime.now().millisecondsSinceEpoch}',
                text: 'I\'m having trouble connecting to my knowledge base. Some responses may be limited. Please let me know if you need any health information, and I\'ll do my best to assist you.',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          
          // Scroll to bottom after message is added
          _scrollToBottom();
        }
      } catch (e) {
        debugPrint('Error testing AI connection: $e');
      }
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    final newMessageId = 'msg-${DateTime.now().millisecondsSinceEpoch}';
    
    setState(() {
      _showSuggestions = false; // Hide suggestions after sending a message
      _messages.add(
        ChatMessage(
          id: newMessageId,
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _messageController.clear();
    });
    
    // Add to conversation history
    _conversationHistory.add({
      'role': 'user',
      'content': text
    });
    
    // Scroll to bottom after sending message
    _scrollToBottom();
    
    // Process with AI if it's the AI Assistant chat
    if (widget.chatId == '3') {
      // Show typing indicator
      setState(() {
        _isTyping = true;
      });
      
      try {
        // Use the AIService to generate a response with selected language
        final aiService = ref.read(aiServiceProvider);
        
        // Update the user's message with instructions about language preference
        String languageInstruction = "";
        switch (_selectedLanguage) {
          case 'hindi':
            languageInstruction = "The user is communicating in Hindi. Please respond in Hindi.";
            break;
          case 'hinglish':
            languageInstruction = "The user is communicating in Hinglish (mix of Hindi and English). Please respond in Hinglish.";
            break;
          default:
            languageInstruction = "The user is communicating in English. Please respond in English.";
        }
        
        final response = await aiService.generateResponse(
          prompt: "$languageInstruction\n\nUser message: $text",
          conversationHistory: _conversationHistory,
          language: _selectedLanguage,
        );
        
        if (mounted) {
          setState(() {
            _isTyping = false;
            _messages.add(
              ChatMessage(
                id: 'ai-${DateTime.now().millisecondsSinceEpoch}',
                text: response,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
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
        if (mounted) {
          setState(() {
            _isTyping = false;
            
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
            
            _messages.add(
              ChatMessage(
                id: 'ai-error-${DateTime.now().millisecondsSinceEpoch}',
                text: errorMessage,
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          
          // Scroll to bottom after error message
          _scrollToBottom();
        }
      }
    }
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
    setState(() {
      _isRecording = !_isRecording;
    });
    
    if (_isRecording) {
      // Start recording
      // TODO: Implement actual voice recording
      
      // Simulate recording and sending for demo
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) {
          setState(() {
            _isRecording = false;
            _messages.add(
              ChatMessage(
                id: 'new-${DateTime.now().millisecondsSinceEpoch}',
                text: '🎤 Voice Message (0:22)',
                isUser: true,
                timestamp: DateTime.now(),
              ),
            );
          });
          
          // Scroll to bottom after sending voice message
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
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
          IconButton(
            icon: const Icon(Icons.videocam),
            onPressed: () {
              // TODO: Implement video call
            },
          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
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
            ),
            
            if (_isAttaching) _buildAttachmentOptions(),
          ],
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
                // Show text content if present
                if (message.text.isNotEmpty)
                  Text(
                    message.text,
                    style: TextStyle(
                      color: message.isUser ? Colors.white : AppColors.textPrimary,
                      fontSize: 16,
                    ),
                  ),
                
                // Show attachment based on type
                if (message.attachmentUrl != null && message.attachmentType != AttachmentType.none) 
                  _buildAttachmentByType(message),
              ],
            ),
          ),
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
                debugPrint("Image error: $error for path: ${message.attachmentUrl}");
                return Container(
                  width: 200,
                  height: 150,
                  color: Colors.grey.shade300,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.broken_image,
                        size: 40,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Image could not be loaded',
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ],
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
      padding: const EdgeInsets.only(top: 16, bottom: 80),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.white.withOpacity(0.0),
            Colors.white.withOpacity(0.9),
            Colors.white,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16, bottom: 8),
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
            margin: const EdgeInsets.only(bottom: 12),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: exampleQuestions.map((question) => 
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ActionChip(
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
                  ),
                )
              ).toList(),
            ),
          ),
        ],
      ),
    );
  }
  
  // Show greeting in the selected language when language is changed
  void _showLanguageGreeting(String language) {
    String greeting;
    
    switch (language) {
      case 'hindi':
        greeting = 'नमस्ते! 👋 मैं मेडीकनेक्ट AI स्वास्थ्य सहायक हूँ। मैं स्वास्थ्य प्रश्नों के उत्तर दे सकता हूँ, चिकित्सा शब्दों को समझा सकता हूँ, लक्षणों पर चर्चा कर सकता हूँ, और सामान्य स्वास्थ्य जानकारी प्रदान कर सकता हूँ।\n\nकृपया मुझे अपनी स्वास्थ्य स्थिति के बारे में कुछ बताएं, जैसे:\n\n• क्या आप कोई लक्षण अनुभव कर रहे हैं?\n• क्या आप कोई दवाई ले रहे हैं?\n• क्या आपका कोई पुराना रोग है?\n\nयह जानकारी मुझे आपकी बेहतर सहायता करने में मदद करेगी।';
        break;
      case 'hinglish':
        greeting = 'Hello! 👋 Main MediConnect AI Health Assistant hoon. Main health questions ke jawab de sakta hoon, medical terms explain kar sakta hoon, symptoms discuss kar sakta hoon, aur general wellness information provide kar sakta hoon.\n\nPlease mujhe apne health condition ke bare mein kuch bataiye, jaise:\n\n• Kya aap koi symptoms experience kar rahe hain?\n• Kya aap koi medication le rahe hain?\n• Kya aapko koi chronic condition hai?\n\nYeh information mujhe aapki better help karne mein madad karegi.';
        break;
      default:
        greeting = 'Hello! 👋 I\'m the MediConnect AI Health Assistant. I can help with health questions, explain medical terms, discuss symptoms, and provide general wellness information.\n\nTo help me better assist you, please share a bit about your health condition, such as:\n\n• Are you experiencing any symptoms?\n• Are you taking any medications?\n• Do you have any chronic conditions?\n\nThis information will help me provide more relevant assistance.';
    }
    
    final greetingId = 'language-greeting-${DateTime.now().millisecondsSinceEpoch}';
    
    setState(() {
      _messages.add(
        ChatMessage(
          id: greetingId,
          text: greeting,
          isUser: false,
          timestamp: DateTime.now(),
        ),
      );
      
      // Add to conversation history
      _conversationHistory.add({
        'role': 'assistant',
        'content': greeting
      });
      
      // Update example questions based on language
      _showSuggestions = true;
    });
    
    // Scroll to bottom after sending greeting
    _scrollToBottom();
  }

  // Permission handling methods
  Future<bool> _requestPermission(Permission permission) async {
    var status = await permission.status;
    
    if (status.isDenied) {
      status = await permission.request();
    }
    
    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Please enable ${permission.toString()} permission from settings'),
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () => openAppSettings(),
          ),
        ),
      );
      return false;
    }
    
    return status.isGranted;
  }
  
  // Image picker method
  Future<void> _pickImage() async {
    bool hasPermission = await _requestPermission(Permission.photos);
    
    if (!hasPermission) return;
    
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      
      if (image != null) {
        setState(() {
          _attachmentPath = image.path;
        });
        _handleAttachment('image', image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error picking image: $e')),
      );
    }
  }
  
  // Camera method
  Future<void> _takePhoto() async {
    bool hasPermission = await _requestPermission(Permission.camera);
    
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
    bool hasPermission = await _requestPermission(Permission.location);
    
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
  
  // Handle the attachment
  void _handleAttachment(String type, String path) {
    // In a real app, you would upload the file to Firebase Storage
    // and then send a message with the attachment URL
    
    debugPrint("Handling attachment of type: $type, path: $path");
    
    setState(() {
      // Determine attachment type
      AttachmentType attachmentType = AttachmentType.none;
      String messageText = "";
      
      if (type == 'image' || type == 'photo') {
        attachmentType = AttachmentType.image;
        messageText = type == 'photo' ? "📷 Camera photo" : "🖼️ Image";
        
        // Verify file exists
        final file = File(path);
        if (!file.existsSync()) {
          debugPrint("File does not exist at path: $path");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error: Image file not found')),
          );
          return;
        }
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

  // Language selection dialog for pre-visit assessment
  void _showLanguageSelectionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(
          'Choose Your Preferred Language',
          style: AppTypography.titleMedium.copyWith(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Select the language you would like to use for your conversation with the MediConnect AI Health Assistant.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            _buildLanguageOption(
              title: 'English',
              description: 'Communicate in English',
              value: 'english',
            ),
            const SizedBox(height: 12),
            _buildLanguageOption(
              title: 'Hinglish',
              description: 'Mix of Hindi and English',
              value: 'hinglish',
            ),
            const SizedBox(height: 12),
            _buildLanguageOption(
              title: 'हिंदी (Hindi)',
              description: 'हिंदी में बातचीत करें',
              value: 'hindi',
            ),
          ],
        ),
      ),
    );
  }
  
  // Language option widget for the selection dialog
  Widget _buildLanguageOption({
    required String title,
    required String description,
    required String value,
  }) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        setState(() {
          _selectedLanguage = value;
        });
        _showLanguageGreeting(value);
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withOpacity(0.3),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.language,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.titleSmall.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    description,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppColors.textTertiary,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
} 