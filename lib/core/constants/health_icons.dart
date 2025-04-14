import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

/// A utility class to easily access health icons in the app
class HealthIcons {
  // Device icons
  static Widget bloodPressure({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/devices/blood_pressure.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  static Widget stethoscope({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/devices/stethoscope.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  static Widget thermometer({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/devices/thermometer.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  static Widget syringe({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/devices/syringe.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  // Condition icons
  static Widget allergies({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/conditions/allergies.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  static Widget backPain({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/conditions/back_pain.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  static Widget fever({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/conditions/chills_fever.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  // Diagnostics icons
  static Widget microscope({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/diagnostics/malaria_microscope.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }

  // Medication icons
  static Widget pill({double? width, double? height, Color? color}) {
    return SvgPicture.asset(
      'assets/icons/health_icons/medications/pill_1.svg',
      width: width,
      height: height,
      colorFilter: color != null ? ColorFilter.mode(color, BlendMode.srcIn) : null,
    );
  }
} 