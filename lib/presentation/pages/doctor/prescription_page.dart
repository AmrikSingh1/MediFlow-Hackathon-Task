import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/prescription_model.dart';
import 'package:medi_connect/core/models/appointment_model.dart';
import 'package:medi_connect/core/services/firebase_service.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:uuid/uuid.dart';

// Add providers
final authServiceProvider = Provider<AuthService>((ref) => AuthService());
final firebaseServiceProvider = Provider<FirebaseService>((ref) => FirebaseService());

class PrescriptionPage extends ConsumerStatefulWidget {
  final AppointmentModel appointment;
  final PrescriptionModel? existingPrescription;

  const PrescriptionPage({
    Key? key,
    required this.appointment,
    this.existingPrescription,
  }) : super(key: key);

  @override
  ConsumerState<PrescriptionPage> createState() => _PrescriptionPageState();
}

class _PrescriptionPageState extends ConsumerState<PrescriptionPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  bool _isEditing = false;
  
  // Common prescription details
  final _diagnosisController = TextEditingController();
  final _instructionsController = TextEditingController();
  final _notesController = TextEditingController();

  // Prescription validity and refills
  DateTime _validUntil = DateTime.now().add(const Duration(days: 30));
  bool _isRefillable = false;
  int _refillsRemaining = 0;
  
  // Medicines list
  List<MedicineFormItem> _medicines = [];
  
  // Doctor ID (current user)
  String? _doctorId;
  
  @override
  void initState() {
    super.initState();
    _isEditing = widget.existingPrescription != null;
    _loadUserData();
    
    if (_isEditing) {
      _loadExistingPrescription();
    } else {
      _medicines.add(MedicineFormItem()); // Add one empty medicine by default
    }
  }
  
  Future<void> _loadUserData() async {
    final authService = ref.read(authServiceProvider);
    final currentUser = await authService.getCurrentUser();
    if (currentUser != null) {
      setState(() {
        _doctorId = currentUser.uid;
      });
    }
  }
  
  void _loadExistingPrescription() {
    final prescription = widget.existingPrescription!;
    
    // Set form values
    _diagnosisController.text = prescription.diagnosis ?? '';
    _instructionsController.text = prescription.instructions ?? '';
    _notesController.text = prescription.notes ?? '';
    
    // Set validity and refills
    if (prescription.validUntil != null) {
      _validUntil = prescription.validUntil!.toDate();
    }
    _isRefillable = prescription.isRefillable;
    _refillsRemaining = prescription.refillsRemaining;
    
    // Load medicines
    _medicines = prescription.medicines.map((med) {
      return MedicineFormItem(
        nameController: TextEditingController(text: med.name),
        dosageController: TextEditingController(text: med.dosage),
        frequencyController: TextEditingController(text: med.frequency),
        durationController: TextEditingController(text: med.duration ?? ''),
        instructionsController: TextEditingController(text: med.instructions ?? ''),
        isMorning: med.isMorning,
        isAfternoon: med.isAfternoon,
        isEvening: med.isEvening,
        isBeforeMeal: med.isBeforeMeal,
      );
    }).toList();
    
    if (_medicines.isEmpty) {
      _medicines.add(MedicineFormItem()); // Add one empty medicine by default
    }
  }
  
  @override
  void dispose() {
    _diagnosisController.dispose();
    _instructionsController.dispose();
    _notesController.dispose();
    for (var medicine in _medicines) {
      medicine.dispose();
    }
    super.dispose();
  }
  
  void _addMedicine() {
    setState(() {
      _medicines.add(MedicineFormItem());
    });
  }
  
  void _removeMedicine(int index) {
    if (_medicines.length > 1) {
      setState(() {
        _medicines[index].dispose();
        _medicines.removeAt(index);
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('At least one medicine is required'))
      );
    }
  }
  
  Future<void> _savePrescription() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    // Validate that at least one medicine has name, dosage, and frequency
    bool medicineValid = _medicines.any((medicine) => 
      medicine.nameController.text.isNotEmpty && 
      medicine.dosageController.text.isNotEmpty && 
      medicine.frequencyController.text.isNotEmpty
    );

    if (!medicineValid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one medicine with name, dosage, and frequency'))
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });
    
    try {
      final firebaseService = ref.read(firebaseServiceProvider);
      
      // Create medicines list
      final medicines = _medicines.map((medicine) => PrescriptionMedicine(
        name: medicine.nameController.text,
        dosage: medicine.dosageController.text,
        frequency: medicine.frequencyController.text,
        isMorning: medicine.isMorning,
        isAfternoon: medicine.isAfternoon,
        isEvening: medicine.isEvening,
        isBeforeMeal: medicine.isBeforeMeal,
        duration: medicine.durationController.text.isNotEmpty ? medicine.durationController.text : null,
        instructions: medicine.instructionsController.text.isNotEmpty ? medicine.instructionsController.text : null,
      )).toList();
      
      // Create or update prescription
      if (_isEditing) {
        // Update existing prescription
        final updatedPrescription = widget.existingPrescription!.copyWith(
          diagnosis: _diagnosisController.text.isNotEmpty ? _diagnosisController.text : null,
          medicines: medicines,
          instructions: _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
          isRefillable: _isRefillable,
          refillsRemaining: _refillsRemaining,
          validUntil: Timestamp.fromDate(_validUntil),
          updatedAt: Timestamp.now(),
        );
        
        await firebaseService.updatePrescription(updatedPrescription);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prescription updated successfully'))
          );
          Navigator.pop(context, true);
        }
      } else {
        // Create new prescription
        final prescription = PrescriptionModel(
          id: '',
          patientId: widget.appointment.patientId,
          doctorId: _doctorId ?? widget.appointment.doctorId,
          appointmentId: widget.appointment.id,
          diagnosis: _diagnosisController.text.isNotEmpty ? _diagnosisController.text : null,
          medicines: medicines,
          instructions: _instructionsController.text.isNotEmpty ? _instructionsController.text : null,
          notes: _notesController.text.isNotEmpty ? _notesController.text : null,
          isRefillable: _isRefillable,
          refillsRemaining: _refillsRemaining,
          issuedAt: Timestamp.now(),
          validUntil: Timestamp.fromDate(_validUntil),
          patientDetails: widget.appointment.patientDetails,
          doctorDetails: widget.appointment.doctorDetails,
          updatedAt: Timestamp.now(),
        );
        
        await firebaseService.createPrescription(prescription);
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Prescription created successfully'))
          );
          Navigator.pop(context, true);
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
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
              const Text('How to fill out the prescription form:'),
              const SizedBox(height: 16),
              Text('1. Diagnosis', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const Text('Enter the patient\'s diagnosis or reason for medication.'),
              const SizedBox(height: 12),
              
              Text('2. Medicines', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const Text('Add all medications the patient needs to take. For each medicine, specify:'),
              const Text('• Name: The medicine name'),
              const Text('• Dosage: Amount to take (e.g., 500mg, 1 tablet)'),
              const Text('• Frequency: How often to take (e.g., 3 times daily)'),
              const Text('• When to take: Morning, afternoon, evening'),
              const Text('• Before/after meals'),
              const Text('• Duration: How long to take the medicine for'),
              const SizedBox(height: 12),
              
              Text('3. Patient Instructions', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const Text('Add any general instructions for the patient to follow.'),
              const SizedBox(height: 12),
              
              Text('4. Validity Period', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const Text('Set how long the prescription is valid for.'),
              const SizedBox(height: 12),
              
              Text('5. Refills', style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.bold)),
              const Text('Enable refills and set how many times the patient can refill this prescription.'),
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
  
  @override
  Widget build(BuildContext context) {
    final patientName = widget.appointment.patientDetails?['name'] ?? 'Patient';
    
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Prescription' : 'New Prescription'),
        actions: [
          IconButton(
            icon: const Icon(Icons.help_outline),
            onPressed: _showHelpDialog,
            tooltip: 'Help',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Patient info card
                    Card(
                      margin: const EdgeInsets.only(bottom: 24),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Prescription for:',
                              style: AppTypography.labelMedium,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.1),
                                  radius: 24,
                                  child: Text(
                                    patientName.split(' ').map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase(),
                                    style: AppTypography.titleMedium.copyWith(
                                      color: AppColors.primary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      patientName,
                                      style: AppTypography.titleMedium,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Date: ${DateFormat('MMMM d, yyyy').format(DateTime.now())}',
                                      style: AppTypography.labelMedium,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    
                    // Diagnosis
                    Text(
                      'Diagnosis',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _diagnosisController,
                      decoration: InputDecoration(
                        hintText: 'Enter diagnosis or reason for medication',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    
                    // Medicines
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Medicines',
                          style: AppTypography.titleMedium,
                        ),
                        ElevatedButton.icon(
                          onPressed: _addMedicine,
                          icon: const Icon(Icons.add),
                          label: const Text('Add Medicine'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    
                    // Medicine list
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _medicines.length,
                      itemBuilder: (context, index) {
                        return _buildMedicineItem(index);
                      },
                    ),
                    
                    const SizedBox(height: 24),
                    
                    // Patient instructions
                    Text(
                      'Patient Instructions',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _instructionsController,
                      decoration: InputDecoration(
                        hintText: 'Enter instructions for the patient',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 3,
                    ),
                    const SizedBox(height: 24),
                    
                    // Notes
                    Text(
                      'Additional Notes (not visible to patient)',
                      style: AppTypography.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _notesController,
                      decoration: InputDecoration(
                        hintText: 'Enter additional notes (optional)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 24),
                    
                    // Validity and refills
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Validity period
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Valid Until',
                                style: AppTypography.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: _validUntil,
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime.now().add(const Duration(days: 365)),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _validUntil = picked;
                                    });
                                  }
                                },
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    border: Border.all(color: Colors.grey),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, size: 16),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('MMM d, yyyy').format(_validUntil),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        
                        // Refills
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Refills',
                                style: AppTypography.titleMedium,
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Switch(
                                    value: _isRefillable,
                                    onChanged: (value) {
                                      setState(() {
                                        _isRefillable = value;
                                        if (!value) {
                                          _refillsRemaining = 0;
                                        } else if (_refillsRemaining == 0) {
                                          _refillsRemaining = 1;
                                        }
                                      });
                                    },
                                    activeColor: AppColors.primary,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    _isRefillable ? 'Allowed' : 'Not allowed',
                                    style: AppTypography.bodyMedium,
                                  ),
                                ],
                              ),
                              if (_isRefillable) ...[
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'Number of refills:',
                                      style: AppTypography.bodyMedium,
                                    ),
                                    const SizedBox(width: 8),
                                    DropdownButton<int>(
                                      value: _refillsRemaining,
                                      items: List.generate(6, (index) => index)
                                          .map((value) => DropdownMenuItem<int>(
                                                value: value,
                                                child: Text(value.toString()),
                                              ))
                                          .toList(),
                                      onChanged: (value) {
                                        if (value != null) {
                                          setState(() {
                                            _refillsRemaining = value;
                                          });
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 32),
                    
                    // Save button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _savePrescription,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text(
                          _isEditing ? 'Update Prescription' : 'Save Prescription',
                          style: AppTypography.buttonText,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
    );
  }
  
  Widget _buildMedicineItem(int index) {
    final medicine = _medicines[index];
    
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Medicine ${index + 1}',
                  style: AppTypography.titleSmall,
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: () => _removeMedicine(index),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Medicine name
            TextFormField(
              controller: medicine.nameController,
              decoration: const InputDecoration(
                labelText: 'Medicine Name *',
                hintText: 'e.g., Amoxicillin',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter medicine name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            
            // Dosage and frequency
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: medicine.dosageController,
                    decoration: const InputDecoration(
                      labelText: 'Dosage *',
                      hintText: 'e.g., 500mg',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter dosage';
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextFormField(
                    controller: medicine.frequencyController,
                    decoration: const InputDecoration(
                      labelText: 'Frequency *',
                      hintText: 'e.g., Twice daily',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter frequency';
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // When to take
            Text(
              'When to take:',
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: FilterChip(
                    label: const Text('Morning'),
                    selected: medicine.isMorning,
                    onSelected: (selected) {
                      setState(() {
                        medicine.isMorning = selected;
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Afternoon'),
                    selected: medicine.isAfternoon,
                    onSelected: (selected) {
                      setState(() {
                        medicine.isAfternoon = selected;
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilterChip(
                    label: const Text('Evening'),
                    selected: medicine.isEvening,
                    onSelected: (selected) {
                      setState(() {
                        medicine.isEvening = selected;
                      });
                    },
                    selectedColor: AppColors.primary.withOpacity(0.2),
                    checkmarkColor: AppColors.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Before/after meals
            Text(
              'Relation to meals:',
              style: AppTypography.bodyMedium.copyWith(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Radio<bool>(
                  value: true,
                  groupValue: medicine.isBeforeMeal,
                  onChanged: (value) {
                    setState(() {
                      medicine.isBeforeMeal = value!;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                const Text('Before meals'),
                const SizedBox(width: 16),
                Radio<bool>(
                  value: false,
                  groupValue: medicine.isBeforeMeal,
                  onChanged: (value) {
                    setState(() {
                      medicine.isBeforeMeal = value!;
                    });
                  },
                  activeColor: AppColors.primary,
                ),
                const Text('After meals'),
              ],
            ),
            const SizedBox(height: 16),
            
            // Duration
            TextFormField(
              controller: medicine.durationController,
              decoration: const InputDecoration(
                labelText: 'Duration (optional)',
                hintText: 'e.g., 5 days, 2 weeks',
              ),
            ),
            const SizedBox(height: 16),
            
            // Special instructions
            TextFormField(
              controller: medicine.instructionsController,
              decoration: const InputDecoration(
                labelText: 'Special Instructions (optional)',
                hintText: 'e.g., Take with water, avoid dairy products',
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

class MedicineFormItem {
  final TextEditingController nameController;
  final TextEditingController dosageController;
  final TextEditingController frequencyController;
  final TextEditingController durationController;
  final TextEditingController instructionsController;
  bool isMorning;
  bool isAfternoon;
  bool isEvening;
  bool isBeforeMeal;
  
  MedicineFormItem({
    TextEditingController? nameController,
    TextEditingController? dosageController,
    TextEditingController? frequencyController,
    TextEditingController? durationController,
    TextEditingController? instructionsController,
    this.isMorning = false,
    this.isAfternoon = false,
    this.isEvening = false,
    this.isBeforeMeal = false,
  }) : 
    nameController = nameController ?? TextEditingController(),
    dosageController = dosageController ?? TextEditingController(),
    frequencyController = frequencyController ?? TextEditingController(),
    durationController = durationController ?? TextEditingController(),
    instructionsController = instructionsController ?? TextEditingController();
  
  void dispose() {
    nameController.dispose();
    dosageController.dispose();
    frequencyController.dispose();
    durationController.dispose();
    instructionsController.dispose();
  }
} 