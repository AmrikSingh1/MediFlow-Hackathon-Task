import 'package:flutter/material.dart';
import 'package:medi_connect/core/constants/app_typography.dart';

class SelectionCard extends StatefulWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? selectedColor;
  final Color? unselectedColor;

  const SelectionCard({
    Key? key,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
    this.selectedColor,
    this.unselectedColor,
  }) : super(key: key);

  @override
  State<SelectionCard> createState() => _SelectionCardState();
}

class _SelectionCardState extends State<SelectionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final selectedColor = widget.selectedColor ?? const Color(0xFF8A70D6);
    final unselectedColor = widget.unselectedColor ?? Colors.white;
    
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeInOut,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: widget.isSelected
                ? selectedColor.withOpacity(0.08)
                : unselectedColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.isSelected
                  ? selectedColor
                  : _isHovered
                      ? selectedColor.withOpacity(0.3)
                      : const Color(0xFFE6E8F0),
              width: widget.isSelected ? 2 : 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: widget.isSelected || _isHovered
                    ? selectedColor.withOpacity(0.1)
                    : Colors.black.withOpacity(0.03),
                blurRadius: widget.isSelected || _isHovered ? 10 : 5,
                spreadRadius: widget.isSelected || _isHovered ? 1 : 0,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon Container
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: widget.isSelected
                      ? selectedColor.withOpacity(0.1)
                      : const Color(0xFFF7F8FA),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 32,
                  color: widget.isSelected
                      ? selectedColor
                      : const Color(0xFF9AA1B4),
                ),
              ),
              const SizedBox(height: 16),
              
              // Title
              Text(
                widget.title,
                style: AppTypography.titleMedium.copyWith(
                  color: widget.isSelected
                      ? selectedColor
                      : const Color(0xFF2D3748),
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              
              // Description
              Text(
                widget.description,
                style: AppTypography.bodySmall.copyWith(
                  color: const Color(0xFF718096),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
} 