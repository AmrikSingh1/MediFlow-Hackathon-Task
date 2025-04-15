import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:medi_connect/core/config/routes.dart';
import 'package:medi_connect/core/constants/app_colors.dart';
import 'package:medi_connect/core/constants/app_typography.dart';
import 'package:medi_connect/core/models/user_model.dart';
import 'package:medi_connect/core/services/auth_service.dart';
import 'package:medi_connect/core/services/firebase_service.dart';

final userProvider = FutureProvider.autoDispose<UserModel?>((ref) async {
  final authService = AuthService();
  final firebaseService = FirebaseService();
  final user = await authService.getCurrentUser();
  if (user != null) {
    return await firebaseService.getUserById(user.uid);
  }
  return null;
});

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _refreshUserData();
    });
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _refreshUserData();
  }
  
  void _refreshUserData() {
    ref.refresh(userProvider);
  }
  
  @override
  Widget build(BuildContext context) {
    super.build(context);
    final userAsyncValue = ref.watch(userProvider);
    
    return userAsyncValue.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stackTrace) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Error loading profile: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _refreshUserData,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
      data: (user) {
        if (user == null) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('User not found'),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _refreshUserData,
                  child: const Text('Retry'),
                ),
              ],
            ),
          );
        }
        
        // Get medical info if available
        final medicalInfo = user.medicalInfo ?? {};
        
        return RefreshIndicator(
          onRefresh: () async {
            _refreshUserData();
          },
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Header
                _buildProfileHeader(user),
                const SizedBox(height: 32),
                
                // Personal Info
                _buildSection(
                  'Personal Information',
                  [
                    _buildInfoItem(
                      icon: Icons.person,
                      title: 'Full Name',
                      value: user.name,
                    ),
                    _buildInfoItem(
                      icon: Icons.calendar_today,
                      title: 'Date of Birth',
                      value: medicalInfo['dateOfBirth'] ?? 'Not set',
                    ),
                    _buildInfoItem(
                      icon: Icons.phone,
                      title: 'Phone Number',
                      value: user.phoneNumber ?? 'Not set',
                    ),
                    _buildInfoItem(
                      icon: Icons.email,
                      title: 'Email',
                      value: user.email,
                    ),
                    _buildInfoItem(
                      icon: Icons.home,
                      title: 'Address',
                      value: medicalInfo['address'] ?? 'Not set',
                    ),
                  ],
                  onEditPressed: () {
                    Navigator.of(context).pushNamed(Routes.patientProfile).then((_) {
                      _refreshUserData();
                    });
                  },
                ),
                const SizedBox(height: 24),
                
                // Medical Info
                _buildSection(
                  'Medical Information',
                  [
                    _buildInfoItem(
                      icon: Icons.height,
                      title: 'Height',
                      value: medicalInfo['height'] != null ? '${medicalInfo['height']} cm' : 'Not set',
                    ),
                    _buildInfoItem(
                      icon: Icons.monitor_weight,
                      title: 'Weight',
                      value: medicalInfo['weight'] != null ? '${medicalInfo['weight']} kg' : 'Not set',
                    ),
                    _buildInfoItem(
                      icon: Icons.bloodtype,
                      title: 'Blood Type',
                      value: medicalInfo['bloodType'] ?? 'Not set',
                    ),
                    _buildInfoItem(
                      icon: Icons.medication,
                      title: 'Allergies',
                      value: medicalInfo['allergies'] ?? 'None',
                    ),
                  ],
                  onEditPressed: () {
                    Navigator.of(context).pushNamed(Routes.patientProfile).then((_) {
                      _refreshUserData();
                    });
                  },
                ),
                const SizedBox(height: 24),
                
                // Settings
                _buildSection(
                  'Settings',
                  [
                    _buildSettingItem(
                      icon: Icons.notifications,
                      title: 'Notifications',
                      trailing: Switch(
                        value: true,
                        onChanged: (value) {
                          // TODO: Update notification settings
                        },
                        activeColor: AppColors.primary,
                      ),
                    ),
                    _buildSettingItem(
                      icon: Icons.lock,
                      title: 'Privacy & Security',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () {
                        // TODO: Navigate to privacy settings
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.language,
                      title: 'Language',
                      subtitle: 'English',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () {
                        // TODO: Navigate to language settings
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.help_outline,
                      title: 'Help & Support',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () {
                        // TODO: Navigate to help & support
                      },
                    ),
                    _buildSettingItem(
                      icon: Icons.info_outline,
                      title: 'About',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () {
                        // TODO: Navigate to about
                      },
                    ),
                  ],
                  showEditButton: false,
                ),
                const SizedBox(height: 24),
                
                // Developer Section
                _buildSection(
                  'Developer',
                  [
                    _buildSettingItem(
                      icon: Icons.health_and_safety,
                      title: 'Health Icons',
                      subtitle: 'View available health icons',
                      trailing: const Icon(
                        Icons.arrow_forward_ios,
                        size: 16,
                        color: AppColors.textTertiary,
                      ),
                      onTap: () {
                        Navigator.of(context).pushNamed(Routes.healthIcons);
                      },
                    ),
                  ],
                  showEditButton: false,
                ),
                const SizedBox(height: 24),
                
                // Logout Button
                Center(
                  child: TextButton.icon(
                    onPressed: () async {
                      await AuthService().signOut();
                      if (context.mounted) {
                        Navigator.of(context).pushReplacementNamed(Routes.login);
                      }
                    },
                    icon: const Icon(
                      Icons.logout,
                      color: AppColors.error,
                    ),
                    label: Text(
                      'Logout',
                      style: AppTypography.bodyLarge.copyWith(
                        color: AppColors.error,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                
                // App Version
                Center(
                  child: Text(
                    'MediConnect v1.0.0',
                    style: AppTypography.bodySmall.copyWith(
                      color: AppColors.textTertiary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildProfileHeader(UserModel user) {
    return Center(
      child: Column(
        children: [
          Stack(
            children: [
              user.profileImageUrl != null
                ? CircleAvatar(
                    radius: 60,
                    backgroundImage: NetworkImage(user.profileImageUrl!),
                  )
                : const CircleAvatar(
                    radius: 60,
                    backgroundColor: AppColors.surfaceMedium,
                    child: Icon(
                      Icons.person,
                      size: 80,
                      color: AppColors.primary,
                    ),
                  ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white,
                      width: 2,
                    ),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.camera_alt,
                      color: Colors.white,
                      size: 20,
                    ),
                    onPressed: () {
                      // TODO: Implement image picker
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            user.name,
            style: AppTypography.displaySmall,
          ),
          const SizedBox(height: 4),
          Text(
            'Patient ID: ${user.id.substring(0, 8)}',
            style: AppTypography.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(
    String title,
    List<Widget> children, {
    bool showEditButton = true,
    VoidCallback? onEditPressed,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTypography.headlineSmall,
            ),
            if (showEditButton)
              TextButton.icon(
                onPressed: onEditPressed,
                icon: const Icon(
                  Icons.edit,
                  size: 16,
                ),
                label: const Text('Edit'),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    );
  }

  Widget _buildInfoItem({
    required IconData icon,
    required String title,
    required String value,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.surfaceMedium,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTypography.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: AppTypography.bodyMedium.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem({
    required IconData icon,
    required String title,
    String? subtitle,
    required Widget trailing,
    VoidCallback? onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppColors.surfaceMedium,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTypography.bodyLarge,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTypography.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
} 