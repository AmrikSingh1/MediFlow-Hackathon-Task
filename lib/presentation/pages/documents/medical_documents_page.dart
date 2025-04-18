import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/models/medical_document_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'dart:math' as math;

// Provider for shared medical documents
final sharedDocumentsProvider = FutureProvider.autoDispose<List<MedicalDocumentModel>>((ref) async {
  final authService = AuthService();
  final firebaseService = FirebaseService();
  final user = authService.currentUser;
  
  if (user == null) {
    return [];
  }
  
  return await firebaseService.getSharedMedicalDocuments(user.uid);
});

class MedicalDocumentsPage extends ConsumerStatefulWidget {
  const MedicalDocumentsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<MedicalDocumentsPage> createState() => _MedicalDocumentsPageState();
}

class _MedicalDocumentsPageState extends ConsumerState<MedicalDocumentsPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isUploading = false;
  UserModel? _currentUser;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadCurrentUser();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _loadCurrentUser() async {
    final authService = AuthService();
    final user = authService.currentUser;
    
    if (user != null) {
      final firebaseService = FirebaseService();
      final userModel = await firebaseService.getUserById(user.uid);
      
      if (mounted) {
        setState(() {
          _currentUser = userModel;
        });
      }
    }
  }
  
  Future<void> _showShareDocumentDialog() async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('You must be logged in to share documents')),
      );
      return;
    }
    
    // Mock file selection and document sharing
    setState(() {
      _isUploading = true;
    });
    
    try {
      // This would be replaced with actual file picker logic in a real implementation
      await Future.delayed(const Duration(seconds: 2));
      
      // Mock document data
      final documentName = 'Medical_Report_${DateTime.now().millisecondsSinceEpoch}.pdf';
      final documentUrl = 'https://example.com/documents/$documentName';
      const documentType = 'application/pdf';
      
      // Show recipient selection dialog
      if (!mounted) return;
      
      final FirebaseService firebaseService = FirebaseService();
      List<UserModel> users = [];
      
      if (_currentUser!.role == UserRole.patient) {
        // If patient, show list of doctors
        users = await firebaseService.getDoctors();
      } else {
        // If doctor, show list of patients (this would need to be implemented in FirebaseService)
        // For now, we'll use an empty list
        users = [];
      }
      
      if (!mounted) return;
      
      final UserModel? selectedUser = await showDialog<UserModel>(
        context: context,
        builder: (context) => SelectRecipientDialog(users: users),
      );
      
      if (selectedUser != null) {
        final firebaseService = FirebaseService();
        await firebaseService.shareMedicalDocument(
          senderId: _currentUser!.id,
          recipientId: selectedUser.id,
          documentName: documentName,
          documentUrl: documentUrl,
          documentType: documentType,
          description: 'Medical report shared on ${DateFormat('MMM d, yyyy').format(DateTime.now())}',
        );
        
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Document shared with ${selectedUser.name}'),
            backgroundColor: Colors.green,
          ),
        );
        
        // Refresh documents list
        ref.refresh(sharedDocumentsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error sharing document: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Medical Documents'),
        backgroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: AppColors.textSecondary,
          indicatorColor: AppColors.primary,
          tabs: const [
            Tab(text: 'Received'),
            Tab(text: 'Shared'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Received documents tab
          _buildDocumentsTab(isReceived: true),
          
          // Shared documents tab
          _buildDocumentsTab(isReceived: false),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _isUploading ? null : _showShareDocumentDialog,
        backgroundColor: _isUploading ? Colors.grey : AppColors.primary,
        child: _isUploading
            ? const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : const Icon(Icons.upload_file),
      ),
    );
  }
  
  Widget _buildDocumentsTab({required bool isReceived}) {
    final documentsAsync = ref.watch(sharedDocumentsProvider);
    
    return documentsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, color: AppColors.error, size: 48),
            const SizedBox(height: 16),
            Text(
              'Error loading documents',
              style: AppTypography.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => ref.refresh(sharedDocumentsProvider),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (documents) {
        // Filter documents based on tab
        final filteredDocs = documents.where((doc) {
          final currentUserId = _currentUser?.id ?? '';
          return isReceived
              ? doc.recipientId == currentUserId
              : doc.senderId == currentUserId;
        }).toList();
        
        if (filteredDocs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  isReceived ? Icons.inbox : Icons.outbox,
                  size: 64,
                  color: AppColors.textSecondary.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  isReceived ? 'No received documents' : 'No shared documents',
                  style: AppTypography.titleMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  isReceived
                      ? 'Documents shared with you will appear here'
                      : 'Documents you share will appear here',
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                if (!isReceived)
                  GradientButton(
                    text: 'Share Document',
                    onPressed: _showShareDocumentDialog,
                    icon: const Icon(Icons.upload_file, color: Colors.white),
                    width: 200,
                  ),
              ],
            ),
          );
        }
        
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: filteredDocs.length,
          itemBuilder: (context, index) {
            final document = filteredDocs[index];
            return _buildDocumentCard(document, isReceived);
          },
        );
      },
    );
  }
  
  Widget _buildDocumentCard(MedicalDocumentModel document, bool isReceived) {
    // Format the date
    final formattedDate = DateFormat('MMM d, yyyy - h:mm a').format(document.sharedAt.toDate());
    
    // Determine file icon based on document type
    IconData fileIcon;
    Color iconColor;
    
    if (document.documentType.contains('pdf')) {
      fileIcon = Icons.picture_as_pdf;
      iconColor = Colors.red;
    } else if (document.documentType.contains('image')) {
      fileIcon = Icons.image;
      iconColor = Colors.blue;
    } else if (document.documentType.contains('word') || document.documentType.contains('doc')) {
      fileIcon = Icons.description;
      iconColor = Colors.blue;
    } else if (document.documentType.contains('sheet') || document.documentType.contains('excel')) {
      fileIcon = Icons.table_chart;
      iconColor = Colors.green;
    } else {
      fileIcon = Icons.insert_drive_file;
      iconColor = Colors.orange;
    }
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () {
          // This would open the document in a real implementation
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Document viewing will be available soon')),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Document icon
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: iconColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      fileIcon,
                      size: 28,
                      color: iconColor,
                    ),
                  ),
                  const SizedBox(width: 16),
                  
                  // Document details
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                document.documentName,
                                style: AppTypography.bodyLarge.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (!document.isRead && isReceived)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.primary,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Text(
                                  'NEW',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          formattedDate,
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isReceived ? Icons.download_done : Icons.upload,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isReceived ? 'Received' : 'Shared',
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
              
              if (document.description != null) ...[
                const SizedBox(height: 12),
                const Divider(),
                const SizedBox(height: 8),
                Text(
                  document.description!,
                  style: AppTypography.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    onPressed: () {
                      // This would download the document in a real implementation
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Download feature will be available soon')),
                      );
                    },
                    icon: const Icon(Icons.download, size: 18),
                    label: const Text('Download'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      // Show document details
                      showDialog(
                        context: context,
                        builder: (context) => DocumentDetailsDialog(document: document),
                      );
                    },
                    icon: const Icon(Icons.info_outline, size: 18),
                    label: const Text('Details'),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
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
}

class SelectRecipientDialog extends StatelessWidget {
  final List<UserModel> users;
  
  const SelectRecipientDialog({
    Key? key,
    required this.users,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return AlertDialog(
        title: const Text('Select Recipient'),
        content: SizedBox(
          height: 150,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.people_outline, size: 48, color: Colors.grey),
                const SizedBox(height: 16),
                const Text('No recipients available'),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
        ],
      );
    }
    
    return AlertDialog(
      title: const Text('Select Recipient'),
      content: SizedBox(
        width: double.maxFinite,
        height: 300,
        child: ListView.builder(
          itemCount: users.length,
          itemBuilder: (context, index) {
            final user = users[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Color((math.Random().nextDouble() * 0xFFFFFF).toInt()).withOpacity(0.2),
                child: Text(
                  user.name.isNotEmpty ? user.name[0].toUpperCase() : '?',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              title: Text(
                user.role == UserRole.doctor ? 'Dr. ${user.name}' : user.name,
              ),
              subtitle: Text(
                user.role == UserRole.doctor
                    ? (user.doctorInfo?['specialty'] ?? 'Doctor')
                    : 'Patient',
              ),
              onTap: () => Navigator.of(context).pop(user),
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }
}

class DocumentDetailsDialog extends StatelessWidget {
  final MedicalDocumentModel document;
  
  const DocumentDetailsDialog({
    Key? key,
    required this.document,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Document Details'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDetailRow('Name', document.documentName),
          _buildDetailRow('Type', document.documentType),
          _buildDetailRow('Size', '2.4 MB'), // This would be the actual size in a real implementation
          _buildDetailRow('Shared On', DateFormat('MMM d, yyyy - h:mm a').format(document.sharedAt.toDate())),
          if (document.readAt != null)
            _buildDetailRow('Read On', DateFormat('MMM d, yyyy - h:mm a').format(document.readAt!.toDate())),
          _buildDetailRow('Status', document.isRead ? 'Read' : 'Unread'),
          if (document.description != null)
            _buildDetailRow('Description', document.description!),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Close'),
        ),
      ],
    );
  }
  
  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
} 