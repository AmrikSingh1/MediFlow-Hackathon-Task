import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/prescription_model.dart';

class PrescriptionDetailsPage extends ConsumerWidget {
  final PrescriptionModel prescription;
  
  const PrescriptionDetailsPage({
    Key? key,
    required this.prescription,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Format dates
    final dateFormatter = DateFormat('MMMM d, yyyy');
    final issuedDate = dateFormatter.format(prescription.issuedAt.toDate());
    final validUntil = prescription.validUntil != null
        ? dateFormatter.format(prescription.validUntil!.toDate())
        : 'Not specified';
    
    // Determine if prescription is expired
    final isExpired = prescription.validUntil != null && 
        prescription.validUntil!.toDate().isBefore(DateTime.now());
    
    // Get doctor information
    final doctorName = prescription.doctorDetails?['name'] ?? 'Your Doctor';
    final doctorSpecialty = prescription.doctorDetails?['specialty'] ?? '';
    final doctorPhone = prescription.doctorDetails?['phoneNumber'];
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Prescription Details'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          // Share button
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sharing functionality will be available soon'),
                ),
              );
            },
          ),
          // Print button
          IconButton(
            icon: const Icon(Icons.print),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Printing functionality will be available soon'),
                ),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Prescription ID and Status Card
            _buildStatusCard(isExpired, issuedDate, validUntil),
            const SizedBox(height: 24),
            
            // Doctor Information
            _buildSectionTitle('Prescribed by'),
            _buildDoctorInfoCard(doctorName, doctorSpecialty, doctorPhone, context),
            const SizedBox(height: 24),
            
            // Diagnosis
            if (prescription.diagnosis != null && prescription.diagnosis!.isNotEmpty) ...[
              _buildSectionTitle('Diagnosis'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  prescription.diagnosis!,
                  style: AppTypography.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Medications
            _buildSectionTitle('Medications'),
            ...prescription.medicines.map((medicine) => 
              _buildMedicineCard(medicine)
            ),
            const SizedBox(height: 24),
            
            // Patient Instructions
            if (prescription.instructions != null && prescription.instructions!.isNotEmpty) ...[
              _buildSectionTitle('Instructions'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  prescription.instructions!,
                  style: AppTypography.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Refill Information
            if (prescription.isRefillable) ...[
              _buildSectionTitle('Refill Information'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.refresh,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Refills Remaining: ${prescription.refillsRemaining}',
                          style: AppTypography.bodyMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Contact your pharmacy to request a refill. Have your prescription ID ready.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Additional Notes
            if (prescription.notes != null && prescription.notes!.isNotEmpty) ...[
              _buildSectionTitle('Additional Notes'),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.grey.shade200),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  prescription.notes!,
                  style: AppTypography.bodyMedium,
                ),
              ),
              const SizedBox(height: 24),
            ],
            
            // Prescription ID and QR Code
            _buildSectionTitle('Prescription ID'),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          prescription.id,
                          style: AppTypography.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: prescription.id));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Prescription ID copied to clipboard'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    width: 150,
                    height: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(
                      child: Text('QR Code\n(Coming Soon)', textAlign: TextAlign.center),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
  
  Widget _buildStatusCard(bool isExpired, String issuedDate, String validUntil) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isExpired 
              ? [Colors.grey.shade200, Colors.grey.shade300]
              : [AppColors.primary.withOpacity(0.7), AppColors.primary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: isExpired 
                ? Colors.grey.withOpacity(0.3)
                : AppColors.primary.withOpacity(0.3),
            blurRadius: 12,
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isExpired ? Icons.unpublished : Icons.check_circle,
                      size: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      isExpired ? 'Expired' : 'Active',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              const Icon(
                Icons.medication,
                color: Colors.white,
                size: 24,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Prescription',
            style: AppTypography.titleLarge.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Issued on $issuedDate',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Valid until: $validUntil',
            style: TextStyle(
              color: Colors.white.withOpacity(0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: AppTypography.titleMedium.copyWith(
          fontWeight: FontWeight.bold,
          color: AppColors.textPrimary,
        ),
      ),
    );
  }
  
  Widget _buildDoctorInfoCard(String name, String specialty, String? phone, BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Text(
                name.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                style: AppTypography.titleMedium.copyWith(
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
                  name,
                  style: AppTypography.bodyLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (specialty.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    specialty,
                    style: AppTypography.bodyMedium.copyWith(
                      color: Colors.grey[700],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (phone != null && phone.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.phone, color: AppColors.primary),
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Calling doctor at $phone'),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
  
  Widget _buildMedicineCard(PrescriptionMedicine medicine) {
    // Determine timing labels
    final List<String> timings = [];
    if (medicine.isMorning) timings.add('Morning');
    if (medicine.isAfternoon) timings.add('Afternoon');
    if (medicine.isEvening) timings.add('Evening');
    final timingString = timings.isEmpty ? 'As directed' : timings.join(', ');
    
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            medicine.name,
            style: AppTypography.bodyLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(Icons.medication, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Dosage: ${medicine.dosage}',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.repeat, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Frequency: ${medicine.frequency}',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.schedule, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                'Time: $timingString',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.restaurant, size: 16, color: Colors.grey),
              const SizedBox(width: 4),
              Text(
                medicine.isBeforeMeal ? 'Take before meals' : 'Take after meals',
                style: AppTypography.bodyMedium,
              ),
            ],
          ),
          if (medicine.duration != null && medicine.duration!.isNotEmpty) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                const Icon(Icons.date_range, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(
                  'Duration: ${medicine.duration}',
                  style: AppTypography.bodyMedium,
                ),
              ],
            ),
          ],
          if (medicine.instructions != null && medicine.instructions!.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Divider(),
            const SizedBox(height: 8),
            Text(
              'Special Instructions:',
              style: AppTypography.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              medicine.instructions!,
              style: AppTypography.bodyMedium.copyWith(
                color: Colors.grey[700],
              ),
            ),
          ],
        ],
      ),
    );
  }
} 