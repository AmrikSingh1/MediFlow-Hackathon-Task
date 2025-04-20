import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/invitation_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

final invitationsProvider = FutureProvider.autoDispose<List<InvitationModel>>((ref) async {
  final authService = ref.read(authServiceProvider);
  final firebaseService = ref.read(firebaseServiceProvider);
  
  final currentUser = await authService.getCurrentUserData();
  if (currentUser == null || currentUser.email.isEmpty) {
    return [];
  }
  
  return await firebaseService.getPendingInvitationsForPatient(currentUser.email);
});

class ViewInvitationsPage extends ConsumerStatefulWidget {
  const ViewInvitationsPage({Key? key}) : super(key: key);

  @override
  ConsumerState<ViewInvitationsPage> createState() => _ViewInvitationsPageState();
}

class _ViewInvitationsPageState extends ConsumerState<ViewInvitationsPage> {
  bool _isProcessing = false;
  
  Future<void> _respondToInvitation(InvitationModel invitation, bool accept) async {
    if (_isProcessing) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final authService = ref.read(authServiceProvider);
      final firebaseService = ref.read(firebaseServiceProvider);
      
      final currentUser = await authService.getCurrentUserData();
      if (currentUser == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('You must be logged in to respond to invitations')),
          );
        }
        return;
      }
      
      final status = accept ? 'accepted' : 'declined';
      await firebaseService.updateInvitationStatus(
        invitation.id, 
        status,
        patientId: accept ? currentUser.id : null,
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invitation ${accept ? 'accepted' : 'declined'}'),
            backgroundColor: accept ? AppColors.success : AppColors.textTertiary,
          ),
        );
        
        // Refresh the invitations list
        ref.refresh(invitationsProvider);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final invitationsAsync = ref.watch(invitationsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Doctor Invitations'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.refresh(invitationsProvider);
        },
        child: invitationsAsync.when(
          data: (invitations) {
            if (invitations.isEmpty) {
              return _buildEmptyState();
            }
            return _buildInvitationsList(invitations);
          },
          loading: () => const Center(
            child: CircularProgressIndicator(),
          ),
          error: (error, stackTrace) => Center(
            child: Text('Error: $error'),
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.mail_outline,
              size: 72,
              color: AppColors.textTertiary,
            ),
            const SizedBox(height: 16),
            Text(
              'No Invitations',
              style: AppTypography.headlineSmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'You don\'t have any pending invitations from doctors at this time.',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            TextButton.icon(
              onPressed: () {
                ref.refresh(invitationsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh'),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInvitationsList(List<InvitationModel> invitations) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: invitations.length,
      itemBuilder: (context, index) {
        final invitation = invitations[index];
        final expirationDate = invitation.expiresAt.toDate();
        final isExpired = expirationDate.isBefore(DateTime.now());
        
        if (isExpired) {
          return const SizedBox.shrink(); // Skip expired invitations
        }
        
        return Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Doctor info
                Row(
                  children: [
                    CircleAvatar(
                      backgroundImage: invitation.doctorDetails?['profileImageUrl'] != null
                          ? NetworkImage(invitation.doctorDetails!['profileImageUrl'])
                          : null,
                      backgroundColor: AppColors.primary.withOpacity(0.1),
                      child: invitation.doctorDetails?['profileImageUrl'] == null
                          ? Icon(
                              Icons.person,
                              color: AppColors.primary,
                            )
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dr. ${invitation.doctorName}',
                            style: AppTypography.titleMedium,
                          ),
                          if (invitation.doctorDetails?['specialty'] != null) ...[
                            const SizedBox(height: 4),
                            Text(
                              invitation.doctorDetails!['specialty'],
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),
                
                // Invitation info
                Row(
                  children: [
                    Icon(
                      Icons.event_note_outlined,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Invitation sent on ${dateFormat.format(invitation.createdAt.toDate())}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Row(
                  children: [
                    Icon(
                      Icons.schedule,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Expires on ${dateFormat.format(expirationDate)}',
                      style: AppTypography.bodySmall,
                    ),
                  ],
                ),
                
                if (invitation.message != null && invitation.message!.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLight,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.surfaceMedium,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Message:',
                          style: AppTypography.bodySmall.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          invitation.message!,
                          style: AppTypography.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ],
                
                const SizedBox(height: 24),
                
                // Action buttons
                if (invitation.status == 'pending' && !isExpired) ...[
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _isProcessing
                              ? null
                              : () => _respondToInvitation(invitation, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.textPrimary,
                            side: BorderSide(color: AppColors.surfaceMedium),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Decline'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _isProcessing
                              ? null
                              : () => _respondToInvitation(invitation, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isProcessing
                              ? const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Text('Accept'),
                        ),
                      ),
                    ],
                  ),
                ] else if (invitation.status == 'accepted') ...[
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        'Accepted',
                        style: AppTypography.bodySmall.copyWith(
                          color: AppColors.success,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
} 