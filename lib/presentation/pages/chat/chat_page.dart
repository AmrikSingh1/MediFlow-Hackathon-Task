import 'package:flutter/material.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'dart:math' as math;

class ChatMessage {
  final String id;
  final String text;
  final bool isUser;
  final DateTime timestamp;
  final bool isRead;
  final String? attachmentUrl;
  
  ChatMessage({
    required this.id,
    required this.text,
    required this.isUser,
    required this.timestamp,
    this.isRead = false,
    this.attachmentUrl,
  });
}

class ChatPage extends StatefulWidget {
  final String chatId;
  
  const ChatPage({
    super.key,
    required this.chatId,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isAttaching = false;
  bool _isRecording = false;
  
  // Sample data - in a real app, this would come from a database
  late List<ChatMessage> _messages;
  late Map<String, dynamic> _chatInfo;
  
  @override
  void initState() {
    super.initState();
    _loadChatData();
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
    
    // Sample messages
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

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
  
  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    
    setState(() {
      _messages.add(
        ChatMessage(
          id: 'new-${DateTime.now().millisecondsSinceEpoch}',
          text: text,
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      _messageController.clear();
    });
    
    // Scroll to bottom after sending message
    Future.delayed(const Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
    
    // Simulate receiving a response after a delay
    if (widget.chatId == '3') { // AI Assistant
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          setState(() {
            _messages.add(
              ChatMessage(
                id: 'new-${DateTime.now().millisecondsSinceEpoch}',
                text: 'I\'ve received your message. Is there anything else I can help you with?',
                isUser: false,
                timestamp: DateTime.now(),
              ),
            );
          });
          
          // Scroll to bottom after receiving response
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
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            _buildAvatar(_chatInfo),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _chatInfo['name'],
                    style: AppTypography.bodyLarge.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _chatInfo['isOnline']
                              ? AppColors.online
                              : AppColors.offline,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        _chatInfo['isOnline']
                            ? 'Online'
                            : 'Offline',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.videocam_outlined),
            onPressed: () {
              // TODO: Implement video call
            },
          ),
          IconButton(
            icon: const Icon(Icons.more_vert),
            onPressed: () {
              // TODO: Show chat options
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Messages List
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 20,
              ),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final message = _messages[index];
                final showTimestamp = index == 0 ||
                    !_isSameDay(message.timestamp, _messages[index - 1].timestamp);
                
                return Column(
                  children: [
                    if (showTimestamp)
                      _buildDateDivider(message.timestamp),
                    _buildMessageItem(message),
                  ],
                );
              },
            ),
          ),
          
          // Attachment Options
          if (_isAttaching)
            Container(
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
                      // TODO: Implement image attachment
                      _toggleAttachments();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.camera_alt,
                    label: 'Camera',
                    color: Colors.green,
                    onTap: () {
                      // TODO: Implement camera attachment
                      _toggleAttachments();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.insert_drive_file,
                    label: 'Document',
                    color: Colors.orange,
                    onTap: () {
                      // TODO: Implement document attachment
                      _toggleAttachments();
                    },
                  ),
                  _buildAttachmentOption(
                    icon: Icons.location_on,
                    label: 'Location',
                    color: Colors.red,
                    onTap: () {
                      // TODO: Implement location sharing
                      _toggleAttachments();
                    },
                  ),
                ],
              ),
            ),
          
          // Input Area
          Container(
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
              children: [
                IconButton(
                  icon: Icon(
                    _isAttaching ? Icons.close : Icons.attach_file,
                    color: _isAttaching ? AppColors.error : AppColors.textSecondary,
                  ),
                  onPressed: _toggleAttachments,
                ),
                // Text input field
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: InputDecoration(
                      hintText: _isRecording
                          ? 'Recording...'
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
                      suffixIcon: _isRecording
                          ? Container(
                              margin: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AppColors.error,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.stop,
                                color: Colors.white,
                                size: 16,
                              ),
                            )
                          : null,
                    ),
                    readOnly: _isRecording,
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                // Mic/Send button
                IconButton(
                  icon: Icon(
                    _messageController.text.trim().isNotEmpty
                        ? Icons.send
                        : (_isRecording ? Icons.stop_circle : Icons.mic),
                    color: _isRecording
                        ? AppColors.error
                        : AppColors.primary,
                  ),
                  onPressed: _messageController.text.trim().isNotEmpty
                      ? _sendMessage
                      : _toggleRecording,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAvatar(Map<String, dynamic> chatInfo) {
    return chatInfo['avatar'] != null
        ? CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Icon(
              chatInfo['avatar'] as IconData,
              color: AppColors.primary,
              size: 24,
            ),
          )
        : CircleAvatar(
            radius: 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            child: Text(
              chatInfo['name'].toString().split(' ').map((e) => e[0]).join(),
              style: AppTypography.bodyLarge.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          );
  }
  
  Widget _buildMessageItem(ChatMessage message) {
    final timeString = _formatMessageTime(message.timestamp);
    
    return Align(
      alignment: message.isUser
          ? Alignment.centerRight
          : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isUser
              ? AppColors.primary
              : AppColors.surfaceMedium,
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: message.isUser ? const Radius.circular(0) : null,
            bottomLeft: !message.isUser ? const Radius.circular(0) : null,
          ),
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                color: message.isUser ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeString,
                  style: TextStyle(
                    fontSize: 10,
                    color: message.isUser
                        ? Colors.white.withOpacity(0.7)
                        : AppColors.textTertiary,
                  ),
                ),
                if (message.isUser) ...[
                  const SizedBox(width: 4),
                  Icon(
                    message.isRead ? Icons.done_all : Icons.done,
                    size: 12,
                    color: message.isRead
                        ? Colors.white.withOpacity(0.9)
                        : Colors.white.withOpacity(0.5),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildDateDivider(DateTime date) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          const Expanded(
            child: Divider(thickness: 1),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _formatDate(date),
              style: AppTypography.bodySmall.copyWith(
                color: AppColors.textTertiary,
              ),
            ),
          ),
          const Expanded(
            child: Divider(thickness: 1),
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
} 