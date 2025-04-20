import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/invitation_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/validation_service.dart';
import 'package:intl/intl.dart';

final invitationProvider = StreamProvider.autoDispose.family<List<InvitationModel>, String>((ref, doctorId) async* {
  final firebaseService = ref.read(firebaseServiceProvider);
  
  // Initial fetch
  yield await firebaseService.getSentInvitationsForDoctor(doctorId);
  
  // Refresh every minute for real-time updates
  while (true) {
    await Future.delayed(const Duration(minutes: 1));
    yield await firebaseService.getSentInvitationsForDoctor(doctorId);
  }
});

final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());
final validationServiceProvider = Provider<ValidationService>((ref) => ValidationService());

class InvitePatientPage extends ConsumerStatefulWidget {
  const InvitePatientPage({Key? key}) : super(key: key);

  @override
  ConsumerState<InvitePatientPage> createState() => _InvitePatientPageState();
}

class _InvitePatientPageState extends ConsumerState<InvitePatientPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _messageController = TextEditingController();
  
  bool _isLoading = false;
  String? _currentDoctorId;
  
  @override
  void initState() {
    super.initState();
    _loadDoctorData();
  }
  
  Future<void> _loadDoctorData() async {
    final authService = ref.read(authServiceProvider);
    final currentUser = await authService.getCurrentUserData();
    if (currentUser != null) {
      setState(() {
        _currentDoctorId = currentUser.id;
      });
    }
  }
  
  @override
  void dispose() {
    _emailController.dispose();
    _messageController.dispose();
    super.dispose();
  }
  
  Future<void> _sendInvitation() async {
    if (!_formKey.currentState!.validate() || _currentDoctorId == null) {
      return;
    }
    
    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.createPatientInvitation(
        _currentDoctorId!,
        _emailController.text.trim(),
        _messageController.text.trim(),
      );
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation sent successfully')),
        );
        
        // Clear form
        _emailController.clear();
        _messageController.clear();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send invitation: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _deleteInvitation(String invitationId) async {
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      await firebaseService.deleteInvitation(invitationId);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invitation deleted')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to delete invitation: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final invitations = _currentDoctorId != null
        ? ref.watch(invitationProvider(_currentDoctorId!))
        : AsyncValue.loading();
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Invite Patients'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Invitation form
            _buildInvitationForm(),
            
            const SizedBox(height: 32),
            
            // Sent invitations list
            Text(
              'Sent Invitations',
              style: AppTypography.headlineMedium,
            ),
            const SizedBox(height: 16),
            
            // Display invitations
            invitations.when(
              data: (data) {
                if (data.isEmpty) {
                  return _buildEmptyState();
                }
                return _buildInvitationsList(data);
              },
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.all(16.0),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (error, stack) => Center(
                child: Text('Error loading invitations: $error'),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildInvitationForm() {
    return Form(
      key: _formKey,
      child: Card(
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Invite a New Patient',
                style: AppTypography.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                'Enter your patient\'s email address to invite them to connect with you on MediConnect.',
                style: AppTypography.bodyMedium.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 16),
              
              // Email input
              TextFormField(
                controller: _emailController,
                decoration: InputDecoration(
                  labelText: 'Patient Email',
                  hintText: 'patient@example.com',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
                validator: (value) {
                  final validationService = ref.read(validationServiceProvider);
                  return validationService.validateEmail(value);
                },
              ),
              const SizedBox(height: 16),
              
              // Message input
              TextFormField(
                controller: _messageController,
                decoration: InputDecoration(
                  labelText: 'Personal Message (Optional)',
                  hintText: 'Invite your patient with a custom message',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  prefixIcon: const Icon(Icons.message_outlined),
                ),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              
              // Submit button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _sendInvitation,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send Invitation'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.mail_outline,
            size: 64,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 16),
          Text(
            'No invitations sent yet',
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Invite your patients using the form above.',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildInvitationsList(List<InvitationModel> invitations) {
    final dateFormat = DateFormat('MMM d, yyyy');
    
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: invitations.length,
      itemBuilder: (context, index) {
        final invitation = invitations[index];
        final isExpired = invitation.expiresAt.toDate().isBefore(DateTime.now());
        
        return Card(
          elevation: 1,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            invitation.patientEmail,
                            style: AppTypography.bodyLarge.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Sent on ${dateFormat.format(invitation.createdAt.toDate())}',
                            style: AppTypography.bodySmall.copyWith(
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    _buildStatusBadge(invitation.status, isExpired),
                  ],
                ),
                if (invitation.message != null && invitation.message!.isNotEmpty) ...[
                  const SizedBox(height: 12),
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
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      isExpired
                          ? 'Expired on ${dateFormat.format(invitation.expiresAt.toDate())}'
                          : 'Expires on ${dateFormat.format(invitation.expiresAt.toDate())}',
                      style: AppTypography.bodySmall.copyWith(
                        color: isExpired ? AppColors.error : AppColors.textTertiary,
                      ),
                    ),
                    const Spacer(),
                    if (invitation.status == 'pending' && !isExpired)
                      TextButton.icon(
                        onPressed: () => _deleteInvitation(invitation.id),
                        icon: Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                          size: 18,
                        ),
                        label: Text(
                          'Cancel',
                          style: AppTypography.bodySmall.copyWith(
                            color: AppColors.error,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildStatusBadge(String status, bool isExpired) {
    Color backgroundColor;
    Color textColor;
    String label;
    
    if (isExpired && status == 'pending') {
      backgroundColor = AppColors.surfaceMedium;
      textColor = AppColors.textTertiary;
      label = 'Expired';
    } else {
      switch (status) {
        case 'pending':
          backgroundColor = AppColors.warning.withOpacity(0.2);
          textColor = AppColors.warning;
          label = 'Pending';
          break;
        case 'accepted':
          backgroundColor = AppColors.success.withOpacity(0.2);
          textColor = AppColors.success;
          label = 'Accepted';
          break;
        case 'declined':
          backgroundColor = AppColors.error.withOpacity(0.2);
          textColor = AppColors.error;
          label = 'Declined';
          break;
        default:
          backgroundColor = AppColors.surfaceMedium;
          textColor = AppColors.textTertiary;
          label = 'Unknown';
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: 12,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: AppTypography.overline.copyWith(
          color: textColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
} 