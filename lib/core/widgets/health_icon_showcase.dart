import 'package:flutter/material.dart';
import 'package:medi_connect/core/constants/health_icons.dart';
import 'package:medi_connect/core/constants/app_colors.dart';

/// A widget that showcases all available health icons
class HealthIconShowcase extends StatelessWidget {
  const HealthIconShowcase({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Health Icons'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Medical Devices',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildIconsGrid([
              _IconItem(
                icon: HealthIcons.bloodPressure(width: 40, height: 40, color: AppColors.primary),
                label: 'Blood Pressure',
              ),
              _IconItem(
                icon: HealthIcons.stethoscope(width: 40, height: 40, color: AppColors.primary),
                label: 'Stethoscope',
              ),
              _IconItem(
                icon: HealthIcons.thermometer(width: 40, height: 40, color: AppColors.primary),
                label: 'Thermometer',
              ),
              _IconItem(
                icon: HealthIcons.syringe(width: 40, height: 40, color: AppColors.primary),
                label: 'Syringe',
              ),
            ]),
            
            const SizedBox(height: 32),
            const Text(
              'Medical Conditions',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildIconsGrid([
              _IconItem(
                icon: HealthIcons.allergies(width: 40, height: 40, color: AppColors.error),
                label: 'Allergies',
              ),
              _IconItem(
                icon: HealthIcons.backPain(width: 40, height: 40, color: AppColors.error),
                label: 'Back Pain',
              ),
              _IconItem(
                icon: HealthIcons.fever(width: 40, height: 40, color: AppColors.error),
                label: 'Fever',
              ),
            ]),
            
            const SizedBox(height: 32),
            const Text(
              'Diagnostics',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildIconsGrid([
              _IconItem(
                icon: HealthIcons.microscope(width: 40, height: 40, color: AppColors.secondary),
                label: 'Microscope',
              ),
            ]),
            
            const SizedBox(height: 32),
            const Text(
              'Medications',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            _buildIconsGrid([
              _IconItem(
                icon: HealthIcons.pill(width: 40, height: 40, color: AppColors.accent),
                label: 'Pill',
              ),
            ]),
          ],
        ),
      ),
    );
  }

  Widget _buildIconsGrid(List<_IconItem> items) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 4,
        childAspectRatio: 0.8,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: item.icon,
            ),
            const SizedBox(height: 8),
            Text(
              item.label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12),
            ),
          ],
        );
      },
    );
  }
}

class _IconItem {
  final Widget icon;
  final String label;

  _IconItem({
    required this.icon,
    required this.label,
  });
} 