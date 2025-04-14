import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';

class ChatListTab extends StatefulWidget {
  const ChatListTab({super.key});

  @override
  State<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends State<ChatListTab> {
  final TextEditingController _searchController = TextEditingController();
  
  final List<Map<String, dynamic>> _chatList = [
    {
      'id': '1',
      'name': 'Dr. Sarah Johnson',
      'specialty': 'Cardiologist',
      'avatar': null,
      'lastMessage': 'Please let me know if you have any questions about your medication.',
      'timestamp': DateTime.now().subtract(const Duration(minutes: 30)),
      'unreadCount': 2,
      'isOnline': true,
    },
    {
      'id': '2',
      'name': 'Dr. Michael Chen',
      'specialty': 'Dermatologist',
      'avatar': null,
      'lastMessage': 'Your test results look good. We\'ll discuss more at your next appointment.',
      'timestamp': DateTime.now().subtract(const Duration(hours: 2)),
      'unreadCount': 0,
      'isOnline': false,
    },
    {
      'id': '3',
      'name': 'MediConnect Assistant',
      'specialty': 'AI Health Assistant',
      'avatar': Icons.smart_toy,
      'lastMessage': 'I\'ve sent your symptom report to Dr. Johnson ahead of your appointment.',
      'timestamp': DateTime.now().subtract(const Duration(days: 1)),
      'unreadCount': 0,
      'isOnline': true,
    },
    {
      'id': '4',
      'name': 'Dr. Emily Rodriguez',
      'specialty': 'Nutritionist',
      'avatar': null,
      'lastMessage': 'Here\'s the meal plan we discussed. Let me know how it works for you.',
      'timestamp': DateTime.now().subtract(const Duration(days: 3)),
      'unreadCount': 0,
      'isOnline': false,
    },
  ];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _navigateToChat(String chatId) {
    Navigator.of(context).pushNamed('${Routes.chat.split('/:')[0]}/$chatId');
  }
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search conversations',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: AppColors.surfaceMedium,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                vertical: 12,
                horizontal: 16,
              ),
            ),
          ),
        ),
        
        // Chat Filters
        Container(
          height: 40,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _buildFilterChip('All Chats', true),
              const SizedBox(width: 8),
              _buildFilterChip('Doctors', false),
              const SizedBox(width: 8),
              _buildFilterChip('Assistants', false),
              const SizedBox(width: 8),
              _buildFilterChip('Unread', false),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Chat List
        Expanded(
          child: _chatList.isEmpty
              ? _buildEmptyState()
              : ListView.builder(
                  itemCount: _chatList.length,
                  itemBuilder: (context, index) {
                    final chat = _chatList[index];
                    return _buildChatTile(chat);
                  },
                ),
        ),
      ],
    );
  }
  
  Widget _buildFilterChip(String label, bool isSelected) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        // TODO: Implement filter logic
      },
      backgroundColor: AppColors.surfaceMedium,
      selectedColor: AppColors.primary.withOpacity(0.1),
      checkmarkColor: AppColors.primary,
      labelStyle: AppTypography.bodyMedium.copyWith(
        color: isSelected ? AppColors.primary : AppColors.textSecondary,
        fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? AppColors.primary : Colors.transparent,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
    );
  }
  
  Widget _buildChatTile(Map<String, dynamic> chat) {
    final timeString = _formatTimestamp(chat['timestamp'] as DateTime);
    final hasUnread = (chat['unreadCount'] as int) > 0;
    
    return InkWell(
      onTap: () => _navigateToChat(chat['id'] as String),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        decoration: BoxDecoration(
          color: hasUnread ? AppColors.primary.withOpacity(0.05) : Colors.transparent,
          border: Border(
            bottom: BorderSide(
              color: AppColors.surfaceDark,
              width: 1,
            ),
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(chat),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        chat['name'] as String,
                        style: AppTypography.bodyLarge.copyWith(
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                      Text(
                        timeString,
                        style: AppTypography.bodySmall.copyWith(
                          color: hasUnread
                              ? AppColors.primary
                              : AppColors.textTertiary,
                          fontWeight: hasUnread ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    chat['specialty'] as String,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat['lastMessage'] as String,
                          style: AppTypography.bodyMedium.copyWith(
                            color: hasUnread
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: hasUnread ? FontWeight.w500 : FontWeight.normal,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hasUnread)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            chat['unreadCount'].toString(),
                            style: AppTypography.bodySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
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
  
  Widget _buildAvatar(Map<String, dynamic> chat) {
    final isOnline = chat['isOnline'] as bool;
    
    return Stack(
      children: [
        chat['avatar'] != null
            ? CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Icon(
                  chat['avatar'] as IconData,
                  color: AppColors.primary,
                  size: 32,
                ),
              )
            : CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  chat['name'].toString().split(' ').map((e) => e[0]).join(),
                  style: AppTypography.headlineSmall.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
        if (isOnline)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.online,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }
  
  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final messageDate = DateTime(timestamp.year, timestamp.month, timestamp.day);
    
    if (messageDate == today) {
      return '${timestamp.hour}:${timestamp.minute.toString().padLeft(2, '0')}';
    } else if (messageDate == yesterday) {
      return 'Yesterday';
    } else if (now.difference(timestamp).inDays < 7) {
      final weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
      return weekdays[timestamp.weekday - 1];
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.chat_bubble_outline,
            size: 80,
            color: AppColors.surfaceDark,
          ),
          const SizedBox(height: 24),
          Text(
            'No conversations yet',
            style: AppTypography.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(
            'Start a conversation with your doctor or use the AI assistant for help',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              // TODO: Navigate to new chat
            },
            icon: const Icon(Icons.add),
            label: const Text('Start a new conversation'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 