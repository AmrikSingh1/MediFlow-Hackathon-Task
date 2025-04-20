import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/report_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:intl/intl.dart';

class ReportReviewPage extends ConsumerStatefulWidget {
  final String reportId;
  
  const ReportReviewPage({
    super.key,
    required this.reportId,
  });

  @override
  ConsumerState<ReportReviewPage> createState() => _ReportReviewPageState();
}

class _ReportReviewPageState extends ConsumerState<ReportReviewPage> {
  final FirebaseService _firebaseService = FirebaseService();
  final TextEditingController _correctedContentController = TextEditingController();
  
  bool _isLoading = true;
  bool _isSaving = false;
  ReportModel? _report;
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    _loadReport();
  }
  
  @override
  void dispose() {
    _correctedContentController.dispose();
    super.dispose();
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
          // Initialize the controller with existing corrected content or original content
          _correctedContentController.text = report.correctedContent ?? report.content;
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
  
  Future<void> _saveReview() async {
    if (_report == null) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // Save the corrected content
      await _firebaseService.reviewReport(_report!.id, _correctedContentController.text);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report review saved successfully')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving review: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  Future<void> _finalizeReport() async {
    if (_report == null) return;
    
    setState(() {
      _isSaving = true;
    });
    
    try {
      // First save any changes
      await _firebaseService.reviewReport(_report!.id, _correctedContentController.text);
      
      // Then finalize the report
      await _firebaseService.finalizeAndSendReport(_report!.id, null);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Report finalized and sent to patient')),
        );
        // Navigate back after successful finalization
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error finalizing report: $e')),
        );
      }
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Report'),
        actions: [
          if (_report != null && _report!.status != ReportStatus.finalized) ...[
            IconButton(
              onPressed: _isSaving ? null : _saveReview,
              icon: const Icon(Icons.save),
              tooltip: 'Save Review',
            ),
          ],
        ],
      ),
      body: _buildBody(),
      bottomNavigationBar: _buildBottomBar(),
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
    
    final formattedDate = DateFormat('MMMM d, yyyy').format(_report!.createdAt.toDate());
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Report header
          Card(
            margin: EdgeInsets.zero,
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
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C7FDF).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            _report!.patientName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                            style: AppTypography.titleLarge.copyWith(
                              color: const Color(0xFF6C7FDF),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      
                      // Patient details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _report!.patientName,
                              style: AppTypography.titleMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Report submitted on $formattedDate',
                              style: AppTypography.bodySmall.copyWith(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 16),
                  
                  // Status
                  Row(
                    children: [
                      const Text(
                        'Status: ',
                        style: AppTypography.bodyMedium,
                      ),
                      _buildStatusBadge(_report!.status),
                    ],
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Original content
          Text(
            'Original Report',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _report!.content,
                    style: AppTypography.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // Corrected content
          Text(
            'Edited Report',
            style: AppTypography.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_report!.status == ReportStatus.finalized)
                    Text(
                      _report!.correctedContent ?? _report!.content,
                      style: AppTypography.bodyMedium,
                    )
                  else
                    TextField(
                      controller: _correctedContentController,
                      maxLines: 15, // Allow multiple lines
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        hintText: 'Edit and correct the report content here',
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget? _buildBottomBar() {
    if (_report == null || _isLoading || _report!.status == ReportStatus.finalized) {
      return null;
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isSaving ? null : _saveReview,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Save as Draft'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: _isSaving ? null : _finalizeReport,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.success,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Finalize & Send to Patient'),
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
        text = 'Needs Review';
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
} 