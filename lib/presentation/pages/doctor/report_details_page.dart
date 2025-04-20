import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/report_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:intl/intl.dart';

class ReportDetailsPage extends ConsumerStatefulWidget {
  final String reportId;
  
  const ReportDetailsPage({
    super.key,
    required this.reportId,
  });

  @override
  ConsumerState<ReportDetailsPage> createState() => _ReportDetailsPageState();
}

class _ReportDetailsPageState extends ConsumerState<ReportDetailsPage> {
  final FirebaseService _firebaseService = FirebaseService();
  
  bool _isLoading = true;
  ReportModel? _report;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadReport();
  }
  
  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      final report = await _firebaseService.getReportById(widget.reportId);
      if (report != null) {
        setState(() {
          _report = report;
        });
      } else {
        setState(() {
          _errorMessage = 'Report not found';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Error loading report: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _shareReport() async {
    // Implementation for sharing report (e.g., via email, PDF, etc.)
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Share functionality coming soon')),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Details'),
        actions: [
          if (_report != null) ...[
            IconButton(
              onPressed: _shareReport,
              icon: const Icon(Icons.share),
              tooltip: 'Share Report',
            ),
          ],
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: AppColors.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Error',
              style: AppTypography.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _errorMessage!,
              style: AppTypography.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _loadReport,
              child: const Text('Try Again'),
            ),
          ],
        ),
      );
    }
    
    if (_report == null) {
      return const Center(child: Text('Report not found'));
    }
    
    final formattedCreatedDate = DateFormat('MMMM d, yyyy').format(_report!.createdAt.toDate());
    final formattedUpdatedDate = DateFormat('MMMM d, yyyy').format(_report!.updatedAt.toDate());
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report status card
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      // Patient avatar
                      Container(
                        width: 60,
                        height: 60,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C7FDF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _report!.patientName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                            style: AppTypography.headlineMedium.copyWith(
                              color: const Color(0xFF6C7FDF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Report details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _report!.patientName,
                              style: AppTypography.titleLarge.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Created on $formattedCreatedDate',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (_report!.updatedAt != _report!.createdAt) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Last updated on $formattedUpdatedDate',
                                style: AppTypography.bodySmall.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      
                      // Status badge
                      _buildStatusBadge(_report!.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Report metadata
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Report Information',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  
                  _buildInfoRow('Report ID', _report!.id),
                  _buildInfoRow('Patient ID', _report!.patientId),
                  _buildInfoRow('Doctor ID', _report!.doctorId),
                  if (_report!.appointmentId != null)
                    _buildInfoRow('Appointment ID', _report!.appointmentId!),
                  _buildInfoRow('Status', _getStatusText(_report!.status)),
                  _buildInfoRow('Saved to Profile', _report!.isSavedToProfile ? 'Yes' : 'No'),
                  _buildInfoRow('Sent to Patient', _report!.isSentToPatient ? 'Yes' : 'No'),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Original content
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Original Report',
                    style: AppTypography.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 16),
                  Text(
                    _report!.content,
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          
          if (_report!.correctedContent != null) ...[
            const SizedBox(height: 24),
            
            // Corrected content
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Final Report',
                      style: AppTypography.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Divider(height: 1),
                    const SizedBox(height: 16),
                    Text(
                      _report!.correctedContent!,
                      style: AppTypography.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
          
          const SizedBox(height: 24),
          
          // PDF download button if available
          if (_report!.pdfUrl != null)
            ElevatedButton.icon(
              onPressed: () {
                // Implement PDF download/viewing
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('PDF viewing will be available soon')),
                );
              },
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('View PDF Report'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: AppTypography.bodyMedium.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: AppTypography.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatusBadge(ReportStatus status) {
    Color color;
    String text;
    
    switch (status) {
      case ReportStatus.draft:
        color = AppColors.warning;
        text = 'Draft';
        break;
      case ReportStatus.reviewed:
        color = AppColors.info;
        text = 'Reviewed';
        break;
      case ReportStatus.finalized:
        color = AppColors.success;
        text = 'Finalized';
        break;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Text(
        text,
        style: AppTypography.bodySmall.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
  
  String _getStatusText(ReportStatus status) {
    switch (status) {
      case ReportStatus.draft:
        return 'Draft';
      case ReportStatus.reviewed:
        return 'Reviewed';
      case ReportStatus.finalized:
        return 'Finalized';
    }
  }
} 