import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/referral_code_model.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:intl/intl.dart';

class DoctorReferralCodePage extends ConsumerStatefulWidget {
  final UserModel doctor;
  
  const DoctorReferralCodePage({
    Key? key,
    required this.doctor,
  }) : super(key: key);
  
  @override
  ConsumerState<DoctorReferralCodePage> createState() => _DoctorReferralCodePageState();
}

class _DoctorReferralCodePageState extends ConsumerState<DoctorReferralCodePage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<ReferralCodeModel> _referralCodes = [];
  bool _isLoading = true;
  bool _isGenerating = false;
  
  @override
  void initState() {
    super.initState();
    _loadReferralCodes();
  }
  
  Future<void> _loadReferralCodes() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final codes = await _firebaseService.getDoctorReferralCodes(widget.doctor.id);
      setState(() {
        _referralCodes = codes;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading referral codes: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load referral codes: $e')),
        );
      }
    }
  }
  
  Future<void> _generateReferralCode() async {
    setState(() {
      _isGenerating = true;
    });
    
    try {
      final newCode = await _firebaseService.generateReferralCode(widget.doctor.id);
      setState(() {
        _referralCodes = [newCode, ..._referralCodes];
        _isGenerating = false;
      });
      
      if (mounted) {
        _showReferralCodeDialog(newCode);
      }
    } catch (e) {
      debugPrint('Error generating referral code: $e');
      setState(() {
        _isGenerating = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to generate referral code: $e')),
        );
      }
    }
  }
  
  void _shareReferralCode(ReferralCodeModel code) {
    final text = '''
Dr. ${widget.doctor.name} has invited you to join MediConnect!

Use this referral code to connect: ${code.code}

This code is valid until ${DateFormat('MMM d, yyyy').format(code.expiresAt.toDate())}.

Download the MediConnect app and enter this code when creating your account.
''';
    
    Share.share(text, subject: 'Join MediConnect with Referral Code');
  }
  
  void _copyReferralCode(ReferralCodeModel code) {
    Clipboard.setData(ClipboardData(text: code.code));
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Referral code copied to clipboard')),
    );
  }
  
  void _showReferralCodeDialog(ReferralCodeModel code) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Referral Code Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Share this code with your patients:'),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.surfaceDark),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    code.code,
                    style: AppTypography.headlineSmall.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: code.code));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Valid until: ${DateFormat('MMM d, yyyy').format(code.expiresAt.toDate())}',
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
          ElevatedButton.icon(
            onPressed: () {
              Navigator.pop(context);
              _shareReferralCode(code);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referral Codes', style: TextStyle(color: Colors.white)),
        backgroundColor: AppColors.primaryDark,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Invite Patients',
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Generate referral codes to invite patients to connect with you on MediConnect.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: _isGenerating ? null : _generateReferralCode,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryDark],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.add_circle_outline,
                                  color: Colors.white,
                                  size: 28,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Generate New Referral Code',
                                      style: AppTypography.titleLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Share with your patients to connect',
                                      style: AppTypography.bodyMedium.copyWith(
                                        color: Colors.white.withOpacity(0.8),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isGenerating)
                                const CircularProgressIndicator(color: Colors.white)
                              else
                                const Icon(
                                  Icons.arrow_forward_ios,
                                  color: Colors.white,
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Your Referral Codes',
                    style: AppTypography.titleLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _referralCodes.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.code_rounded,
                                  size: 64,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No referral codes yet',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Generate a code to invite patients',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _referralCodes.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final code = _referralCodes[index];
                              final isExpired = code.isExpired();
                              final isValid = code.isValid();
                              
                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isValid
                                        ? AppColors.surfaceDark
                                        : isExpired
                                            ? AppColors.error.withOpacity(0.5)
                                            : AppColors.success.withOpacity(0.5),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 8,
                                      offset: const Offset(0, 2),
                                    ),
                                  ],
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            code.code,
                                            style: AppTypography.titleLarge.copyWith(
                                              fontWeight: FontWeight.bold,
                                              letterSpacing: 1.5,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        if (isValid)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'ACTIVE',
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        else if (isExpired)
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.error.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'EXPIRED',
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.error,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          )
                                        else
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              color: AppColors.success.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              'USED',
                                              style: AppTypography.bodySmall.copyWith(
                                                color: AppColors.success,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.calendar_today_rounded,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Created: ${DateFormat('MMM d, yyyy').format(code.createdAt.toDate())}',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: AppColors.textSecondary,
                                          ),
                                        ),
                                        const SizedBox(width: 16),
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Expires: ${DateFormat('MMM d, yyyy').format(code.expiresAt.toDate())}',
                                          style: AppTypography.bodySmall.copyWith(
                                            color: isExpired ? AppColors.error : AppColors.textSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    if (code.isUsed && code.usedByPatientName != null)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 12),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.person_outline_rounded,
                                              size: 14,
                                              color: AppColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Used by: ${code.usedByPatientName}',
                                              style: AppTypography.bodyMedium.copyWith(
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    const SizedBox(height: 16),
                                    if (isValid)
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _copyReferralCode(code),
                                            icon: const Icon(Icons.copy),
                                            label: const Text('Copy'),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: AppColors.primary,
                                              side: const BorderSide(color: AppColors.primary),
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          ElevatedButton.icon(
                                            onPressed: () => _shareReferralCode(code),
                                            icon: const Icon(Icons.share),
                                            label: const Text('Share'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: AppColors.primary,
                                              foregroundColor: Colors.white,
                                            ),
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
} 