# Health Icons

This directory contains SVG health icons for use in the MediConnect application. The icons are organized by category:

- `devices/`: Medical device icons like stethoscope, thermometer, etc.
- `conditions/`: Medical condition icons like allergies, back pain, etc.
- `diagnostics/`: Diagnostic tool icons like microscope.
- `medications/`: Medication-related icons like pills.

## Usage

The icons can be used in your Flutter application by using the `HealthIcons` utility class:

```dart
import 'package:medi_connect/core/constants/health_icons.dart';

// Use with default size and color
HealthIcons.stethoscope()

// Customize size and color
HealthIcons.bloodPressure(
  width: 24, 
  height: 24, 
  color: AppColors.primary
)
```

## Available Icons

### Medical Devices
- `HealthIcons.bloodPressure()`
- `HealthIcons.stethoscope()`
- `HealthIcons.thermometer()`
- `HealthIcons.syringe()`

### Medical Conditions
- `HealthIcons.allergies()`
- `HealthIcons.backPain()`
- `HealthIcons.fever()`

### Diagnostics
- `HealthIcons.microscope()`

### Medications
- `HealthIcons.pill()`

## Example

To see a showcase of all available icons, navigate to the `HealthIconShowcase` screen:

```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => const HealthIconShowcase()),
);
```

## Adding New Icons

To add more icons:

1. Add SVG files to the appropriate category directory
2. Update the `HealthIcons` class in `lib/core/constants/health_icons.dart`
3. Update this README to document the new icons 