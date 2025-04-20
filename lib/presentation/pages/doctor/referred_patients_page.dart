import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/config/routes.dart';

class ReferredPatientsPage extends ConsumerStatefulWidget {
  final UserModel doctor;
  
  const ReferredPatientsPage({
    Key? key,
    required this.doctor,
  }) : super(key: key);
  
  @override
  ConsumerState<ReferredPatientsPage> createState() => _ReferredPatientsPageState();
}

class _ReferredPatientsPageState extends ConsumerState<ReferredPatientsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  List<Map<String, dynamic>> _referredPatients = [];
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadReferredPatients();
  }
  
  Future<void> _loadReferredPatients() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final patients = await _firebaseService.getReferredPatients(widget.doctor.id);
      setState(() {
        _referredPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading referred patients: $e');
      setState(() {
        _isLoading = false;
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load referred patients: $e')),
        );
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Referred Patients', style: TextStyle(color: Colors.white)),
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
                    'Your Referred Patients',
                    style: AppTypography.headlineMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Patients who joined MediConnect using your referral codes.',
                    style: AppTypography.bodyLarge.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    '${_referredPatients.length} ${_referredPatients.length == 1 ? 'Patient' : 'Patients'} Referred',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Expanded(
                    child: _referredPatients.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.people_outline_rounded,
                                  size: 64,
                                  color: AppColors.textTertiary,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'No referred patients yet',
                                  style: AppTypography.titleMedium.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Share your referral code with patients to connect',
                                  style: AppTypography.bodyMedium.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton.icon(
                                  onPressed: () {
                                    Navigator.pop(context);
                                  },
                                  icon: const Icon(Icons.qr_code_rounded),
                                  label: const Text('Generate Referral Code'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.primary,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.separated(
                            itemCount: _referredPatients.length,
                            separatorBuilder: (context, index) => const SizedBox(height: 16),
                            itemBuilder: (context, index) {
                              final patient = _referredPatients[index];
                              final patientName = patient['patientName'] as String? ?? 'Unknown Patient';
                              final referralCode = patient['referralCode'] as String? ?? '';
                              final referredAt = patient['referredAt'] as DateTime? ?? DateTime.now();
                              final patientId = patient['patientId'] as String? ?? '';
                              
                              final referredDate = DateFormat('MMM d, yyyy').format(referredAt);
                              final initials = patientName.split(' ').take(2).map((e) => e.isNotEmpty ? e[0] : '').join();
                              
                              return InkWell(
                                onTap: () {
                                  if (patientId.isNotEmpty) {
                                    Navigator.pushNamed(
                                      context,
                                      Routes.patientDetail.replaceAll(':id', patientId),
                                    );
                                  }
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.05),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 50,
                                        height: 50,
                                        decoration: BoxDecoration(
                                          color: AppColors.primary.withOpacity(0.1),
                                          shape: BoxShape.circle,
                                        ),
                                        child: Center(
                                          child: Text(
                                            initials.toUpperCase(),
                                            style: AppTypography.titleLarge.copyWith(
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              patientName,
                                              style: AppTypography.titleMedium.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.calendar_today_rounded,
                                                  size: 14,
                                                  color: AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Joined: $referredDate',
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                                const SizedBox(width: 16),
                                                Icon(
                                                  Icons.qr_code_rounded,
                                                  size: 14,
                                                  color: AppColors.textSecondary,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  'Code: $referralCode',
                                                  style: AppTypography.bodySmall.copyWith(
                                                    color: AppColors.textSecondary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textSecondary,
                                      ),
                                    ],
                                  ),
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