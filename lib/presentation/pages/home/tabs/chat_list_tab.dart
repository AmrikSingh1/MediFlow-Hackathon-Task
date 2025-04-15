import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/chat_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';

// Providers
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final chatsProvider = FutureProvider.autoDispose<List<ChatModel>>((ref) async {
  try {
    final authService = ref.read(authServiceProvider);
    final firebaseService = ref.read(firebaseServiceProvider);
    final user = await authService.getCurrentUser();
    
    if (user == null) return [];
    
    debugPrint("Fetching chats for user ${user.uid}");
    final chats = await firebaseService.getChatsForUser(user.uid);
    debugPrint("Retrieved ${chats.length} chats");
    return chats;
  } catch (e) {
    debugPrint("Error fetching chats: $e");
    return [];
  }
});

class ChatListTab extends ConsumerStatefulWidget {
  const ChatListTab({super.key});

  @override
  ConsumerState<ChatListTab> createState() => _ChatListTabState();
}

class _ChatListTabState extends ConsumerState<ChatListTab> with AutomaticKeepAliveClientMixin {
  final TextEditingController _searchController = TextEditingController();
  String _activeFilter = 'All Chats';
  List<ChatModel> _filteredChats = [];
  bool _isLoading = true;
  
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshChats();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshChats();
  }
  
  void _refreshChats() {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
    });
    
    ref.refresh(chatsProvider);
    
    setState(() {
      _isLoading = false;
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  void _navigateToChat(String chatId) {
    Navigator.of(context).pushNamed('${Routes.chat.split('/:')[0]}/$chatId').then((_) {
      _refreshChats();
    });
  }
  
  List<ChatModel> _applyFilters(List<ChatModel> chats) {
    // First apply search filter
    List<ChatModel> result = _searchController.text.isEmpty 
        ? chats 
        : chats.where((chat) => 
            chat.participants.any((p) => 
              p.toLowerCase().contains(_searchController.text.toLowerCase())))
            .toList();
    
    // Then apply category filter
    switch (_activeFilter) {
      case 'Doctors':
        return result.where((chat) => 
          chat.participantDetails != null && 
          chat.participantDetails!['role'] == 'doctor').toList();
      case 'Assistants':
        return result.where((chat) => 
          chat.participantDetails != null && 
          chat.participantDetails!['role'] == 'assistant').toList();
      case 'Unread':
        return result.where((chat) => chat.unreadCount > 0).toList();
      case 'All Chats':
      default:
        return result;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final chatsAsync = ref.watch(chatsProvider);
    
    return Column(
      children: [
        // Search Bar
        Padding(
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _searchController,
            onChanged: (_) {
              setState(() {}); // Refresh to apply filters
            },
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
              _buildFilterChip('All Chats', _activeFilter == 'All Chats'),
              const SizedBox(width: 8),
              _buildFilterChip('Doctors', _activeFilter == 'Doctors'),
              const SizedBox(width: 8),
              _buildFilterChip('Assistants', _activeFilter == 'Assistants'),
              const SizedBox(width: 8),
              _buildFilterChip('Unread', _activeFilter == 'Unread'),
            ],
          ),
        ),
        const SizedBox(height: 8),
        
        // Chat List
        Expanded(
          child: chatsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (error, stackTrace) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Error loading chats: $error'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: _refreshChats,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
            data: (chats) {
              final filteredChats = _applyFilters(chats);
              
              if (filteredChats.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async => _refreshChats(),
                  child: ListView(
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.6,
                        child: _buildEmptyState(),
                      ),
                    ],
                  ),
                );
              }
              
              return RefreshIndicator(
                onRefresh: () async => _refreshChats(),
                child: ListView.builder(
                  itemCount: filteredChats.length,
                  itemBuilder: (context, index) {
                    final chat = filteredChats[index];
                    return _buildChatTile(chat);
                  },
                ),
              );
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
        setState(() {
          _activeFilter = selected ? label : 'All Chats';
        });
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
  
  Widget _buildChatTile(ChatModel chat) {
    final timeString = _formatTimestamp(chat.lastMessageTime.toDate());
    final hasUnread = chat.unreadCount > 0;
    final otherParticipantName = chat.participantDetails?['name'] ?? 'Unknown';
    final specialty = chat.participantDetails?['specialty'] ?? 'User';
    
    return InkWell(
      onTap: () => _navigateToChat(chat.id),
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
                        otherParticipantName,
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
                    specialty,
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          chat.lastMessage,
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
                            chat.unreadCount.toString(),
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
  
  Widget _buildAvatar(ChatModel chat) {
    final isOnline = chat.participantDetails?['isOnline'] as bool? ?? false;
    final hasCustomAvatar = chat.participantDetails?['avatarUrl'] != null;
    final name = chat.participantDetails?['name'] as String? ?? 'Unknown';
    
    return Stack(
      children: [
        hasCustomAvatar
            ? CircleAvatar(
                radius: 28,
                backgroundImage: NetworkImage(chat.participantDetails!['avatarUrl']),
              )
            : CircleAvatar(
                radius: 28,
                backgroundColor: AppColors.primary.withOpacity(0.1),
                child: Text(
                  name.isNotEmpty ? name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join() : '?',
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
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            child: Material(
              elevation: 4,
              shadowColor: AppColors.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(16),
              child: InkWell(
                onTap: _showCreateChatDialog,
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        AppColors.primary,
                        AppColors.primary.withBlue(255),
                      ],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  width: double.infinity,
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.add_circle_outline,
                        color: Colors.white,
                        size: 22,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Start a new conversation',
                        style: AppTypography.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Show dialog to create a new chat
  void _showCreateChatDialog() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Start a conversation',
                style: AppTypography.headlineSmall.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Choose who you want to chat with',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 24),
              
              // AI Assistant option
              _buildChatOption(
                title: 'AI Health Assistant',
                subtitle: 'Ask health questions and get instant responses',
                icon: Icons.smart_toy_outlined,
                onTap: () {
                  Navigator.pop(context);
                  // Navigate to AI Health Assistant chat
                  _navigateToChat('3'); // Assuming ID 3 is for AI Assistant
                },
              ),
              const SizedBox(height: 16),
              
              // Find Doctor option
              _buildChatOption(
                title: 'Find a Doctor',
                subtitle: 'Browse and connect with healthcare professionals',
                icon: Icons.person_search_outlined,
                onTap: () {
                  Navigator.pop(context);
                  // Show doctor selection
                  _showDoctorSelectionDialog();
                },
              ),
              
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChatOption({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.w600,
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
              const Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: AppColors.textSecondary,
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDoctorSelectionDialog() {
    showDialog(
      context: context,
      builder: (context) => const AlertDialog(
        title: Text('Coming Soon'),
        content: Text('Doctor selection and chat creation is coming soon!'),
      ),
    );
  }
} 