import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/prescription_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/presentation/pages/patient/prescription_details_page.dart';

// Add provider definitions
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

// Provider for fetching patient prescriptions
final patientPrescriptionsProvider = FutureProvider<List<PrescriptionModel>>((ref) async {
  final authService = ref.watch(authServiceProvider);
  final firebaseService = ref.watch(firebaseServiceProvider);
  
  final currentUser = await authService.getCurrentUser();
  if (currentUser == null) return [];
  
  return await firebaseService.getPrescriptionsForPatient(currentUser.uid);
});

class PrescriptionListPage extends ConsumerStatefulWidget {
  const PrescriptionListPage({Key? key}) : super(key: key);

  @override
  ConsumerState<PrescriptionListPage> createState() => _PrescriptionListPageState();
}

class _PrescriptionListPageState extends ConsumerState<PrescriptionListPage> {
  String _searchQuery = '';
  bool _showOnlyActive = false;
  
  @override
  Widget build(BuildContext context) {
    final prescriptionsAsync = ref.watch(patientPrescriptionsProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Prescriptions'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    hintText: 'Search prescriptions',
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() {
                      _searchQuery = value.toLowerCase();
                    });
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Switch(
                      value: _showOnlyActive,
                      onChanged: (value) {
                        setState(() {
                          _showOnlyActive = value;
                        });
                      },
                      activeColor: AppColors.primary,
                    ),
                    const Text('Show only active prescriptions'),
                  ],
                ),
              ],
            ),
          ),
          
          // Prescriptions list
          Expanded(
            child: prescriptionsAsync.when(
              data: (prescriptions) {
                if (prescriptions.isEmpty) {
                  return const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.medication_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'No prescriptions found',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Your prescriptions will appear here',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                // Filter prescriptions based on search query and active filter
                final filteredPrescriptions = prescriptions.where((prescription) {
                  // Apply active filter
                  if (_showOnlyActive && prescription.validUntil != null) {
                    final now = DateTime.now();
                    if (prescription.validUntil!.toDate().isBefore(now)) {
                      return false;
                    }
                  }
                  
                  // Apply search filter
                  if (_searchQuery.isEmpty) return true;
                  
                  // Search in diagnosis
                  if (prescription.diagnosis != null && 
                      prescription.diagnosis!.toLowerCase().contains(_searchQuery)) {
                    return true;
                  }
                  
                  // Search in doctor name
                  final doctorName = prescription.doctorDetails?['name'] ?? '';
                  if (doctorName.toLowerCase().contains(_searchQuery)) {
                    return true;
                  }
                  
                  // Search in medicines
                  for (final medicine in prescription.medicines) {
                    if (medicine.name.toLowerCase().contains(_searchQuery)) {
                      return true;
                    }
                  }
                  
                  return false;
                }).toList();
                
                if (filteredPrescriptions.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          _showOnlyActive ? Icons.event_busy : Icons.search_off, 
                          size: 64, 
                          color: Colors.grey
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _showOnlyActive 
                              ? 'No active prescriptions found' 
                              : 'No prescriptions match your search',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _showOnlyActive
                              ? 'Try unchecking the "Show only active" filter'
                              : 'Try a different search term',
                          style: const TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filteredPrescriptions.length,
                  itemBuilder: (context, index) {
                    final prescription = filteredPrescriptions[index];
                    return _buildPrescriptionCard(prescription);
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, stackTrace) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 64, color: Colors.red),
                    const SizedBox(height: 16),
                    const Text(
                      'Error loading prescriptions',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      error.toString(),
                      style: const TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPrescriptionCard(PrescriptionModel prescription) {
    final dateFormatter = DateFormat('MMMM d, yyyy');
    final issuedDate = dateFormatter.format(prescription.issuedAt.toDate());
    
    // Determine if prescription is expired
    bool isExpired = false;
    if (prescription.validUntil != null) {
      isExpired = prescription.validUntil!.toDate().isBefore(DateTime.now());
    }
    
    // Get the doctor name
    final doctorName = prescription.doctorDetails?['name'] ?? 'Your Doctor';
    final doctorSpecialty = prescription.doctorDetails?['specialty'] ?? '';
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isExpired ? Colors.grey.shade300 : AppColors.primary.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      elevation: 2,
      child: InkWell(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PrescriptionDetailsPage(
                prescription: prescription,
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Status and date
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpired 
                          ? Colors.grey.shade200 
                          : AppColors.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isExpired ? Icons.unpublished : Icons.check_circle,
                          size: 14,
                          color: isExpired ? Colors.grey : AppColors.primary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          isExpired ? 'Expired' : 'Active',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: isExpired ? Colors.grey : AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'Issued: $issuedDate',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              
              // Doctor info
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    radius: 20,
                    child: Text(
                      doctorName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          doctorName,
                          style: AppTypography.titleSmall,
                        ),
                        if (doctorSpecialty.isNotEmpty)
                          Text(
                            doctorSpecialty,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Diagnosis if available
              if (prescription.diagnosis != null && prescription.diagnosis!.isNotEmpty) ...[
                Text(
                  'Diagnosis:',
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prescription.diagnosis!,
                  style: AppTypography.bodyMedium,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),
              ],
              
              // Medications
              Text(
                'Medications:',
                style: AppTypography.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: prescription.medicines.take(3).map((medicine) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.medication, size: 14, color: Colors.grey),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '${medicine.name} (${medicine.dosage})',
                            style: AppTypography.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
              
              if (prescription.medicines.length > 3)
                Text(
                  '+ ${prescription.medicines.length - 3} more medications',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              
              const SizedBox(height: 16),
              
              // Validity and refills
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  if (prescription.validUntil != null)
                    Text(
                      'Valid until: ${dateFormatter.format(prescription.validUntil!.toDate())}',
                      style: const TextStyle(fontSize: 12),
                    )
                  else
                    const Text(
                      'No expiration date specified',
                      style: TextStyle(fontSize: 12),
                    ),
                  
                  if (prescription.isRefillable)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Refills: ${prescription.refillsRemaining}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.green,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(height: 8),
              const Divider(),
              const SizedBox(height: 8),
              
              // View details button
              Center(
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PrescriptionDetailsPage(
                          prescription: prescription,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('View Details'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showHelpDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Prescription Help'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('About Your Prescriptions', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('View and manage all your prescriptions in one place.'),
              const SizedBox(height: 16),
              
              Text('Search & Filter', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• Use the search bar to find medications by name'),
              const Text('• Toggle "Show only active" to hide expired prescriptions'),
              const SizedBox(height: 16),
              
              Text('Understanding Status', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('• Active: Prescription is current and can be filled'),
              const Text('• Expired: Prescription is no longer valid'),
              const SizedBox(height: 16),
              
              Text('Refills', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('If your prescription shows refills available, you can request refills through your pharmacy.'),
              const SizedBox(height: 16),
              
              Text('Need Help?', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              const Text('Contact your doctor if you have questions about your prescriptions or need a refill for an expired prescription.'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
} 