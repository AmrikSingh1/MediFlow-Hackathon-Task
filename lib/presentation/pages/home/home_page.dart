import 'package:flutter/material.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/presentation/widgets/gradient_button.dart';
import 'package:medi_connect/presentation/pages/home/tabs/dashboard_tab.dart';
import 'package:medi_connect/presentation/pages/home/tabs/appointments_tab.dart';
import 'package:medi_connect/presentation/pages/home/tabs/chat_list_tab.dart';
import 'package:medi_connect/presentation/pages/home/tabs/profile_tab.dart';
import 'package:medi_connect/presentation/pages/patient/doctor_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  bool _showReportTooltip = true;  // State to track if tooltip should be shown
  
  final List<Widget> _tabs = [
    const DashboardTab(),
    const AppointmentsTab(),
    const ChatListTab(),
    const ProfileTab(),
    const SizedBox(), // Placeholder for Reports tab - will navigate directly
  ];
  
  final List<String> _tabTitles = [
    'Dashboard',
    'Appointments',
    'Messages',
    'Profile',
    'Reports',
  ];

  // Animation controller for the bottom navigation bar
  late AnimationController _animationController;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    
    // Auto-hide the tooltip after 10 seconds
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        setState(() {
          _showReportTooltip = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_tabTitles[_currentIndex]),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              // TODO: Navigate to notifications
            },
          ),
        ],
        leading: _currentIndex != 3 ? IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () {
            setState(() {
              _currentIndex = 3; // Navigate to profile tab
              _animationController.reset();
              _animationController.forward();
            });
          },
        ) : null,
      ),
      body: Stack(
        children: [
          _tabs[_currentIndex],
          // Show tooltip only on dashboard tab and if it's not dismissed
          if (_currentIndex == 0 && _showReportTooltip)
            Positioned(
              bottom: 100, // Position above bottom nav bar
              right: 20,
              child: _buildReportTooltip(),
            ),
        ],
      ),
      bottomNavigationBar: _buildCustomBottomNavigationBar(),
      floatingActionButton: _currentIndex == 0
              ? FloatingActionButton.extended(
                  onPressed: () {
                    Navigator.of(context).pushNamed(Routes.preAnamnesis);
                  },
                  backgroundColor: AppColors.primary,
                  icon: const Icon(Icons.health_and_safety, color: Colors.white),
                  label: const Text('Check Symptoms'),
                )
              : null,
    );
  }

  Widget _buildCustomBottomNavigationBar() {
    return Container(
      height: 60,
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.dashboard_outlined, Icons.dashboard),
            _buildNavItem(1, Icons.calendar_month_outlined, Icons.calendar_month),
            _buildNavItem(4, Icons.description_outlined, Icons.description),
            _buildNavItem(2, Icons.chat_outlined, Icons.chat),
            _buildNavItem(3, Icons.person_outline, Icons.person),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, IconData activeIcon) {
    final isSelected = _currentIndex == index;
    
    return InkWell(
      onTap: () {
        // If Reports tab is clicked, navigate to pre-anamnesis page
        if (index == 4) {
          Navigator.of(context).pushNamed(Routes.preAnamnesis);
          return;
        }
        
        setState(() {
          _currentIndex = index;
          _animationController.reset();
          _animationController.forward();
        });
      },
      customBorder: const CircleBorder(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(25),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: isSelected ? AppColors.primary : AppColors.textTertiary,
              size: 24,
            ),
            if (isSelected)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Container(
                      width: 16 + 8 * _animationController.value,
                      height: 3,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: AppColors.primaryGradient,
                        ),
                        borderRadius: BorderRadius.circular(1.5),
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

  void _onItemTapped(int index) {
    if (index != _currentIndex) {
      setState(() {
        _currentIndex = index;
        _animationController.reset();
        _animationController.forward();
      });
    }
  }
  
  void _onActionSelected(String action) {
    // Handle the action button taps
    if (action == 'find_doctor') {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => DoctorListPage(specialty: 'Specialist')),
      );
    } else if (action == 'lab_test') {
      // Navigate to lab test page
    } else if (action == 'medicines') {
      // Navigate to medicines page
    } else if (action == 'appointment') {
      // Navigate to book appointment page directly
    }
  }

  Widget _buildReportTooltip() {
    return Container(
      width: 180,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(
          color: AppColors.primary.withOpacity(0.2),
          width: 1.5,
        ),
      ),
      child: Stack(
        children: [
          // Tooltip content
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.description,
                      color: AppColors.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Try AI Reports!',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Generate AI health reports to check your symptoms',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Close button
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              icon: Icon(
                Icons.close,
                size: 16,
                color: AppColors.textTertiary,
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                setState(() {
                  _showReportTooltip = false;
                });
              },
            ),
          ),
          
          // Arrow pointing to reports tab
          Positioned(
            bottom: -8,
            right: 80,
            child: CustomPaint(
              size: const Size(16, 8),
              painter: ArrowPainter(),
            ),
          ),
        ],
      ),
    );
  }
}

// Custom painter for drawing the arrow pointing to the Reports tab
class ArrowPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
      
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width / 2, size.height)
      ..close();
      
    canvas.drawPath(path, paint);
    
    // Draw the border
    final borderPaint = Paint()
      ..color = AppColors.primary.withOpacity(0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
      
    canvas.drawPath(path, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
} 