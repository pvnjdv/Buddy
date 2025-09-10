import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../services/auth/user_service.dart';
import '../../config/settings/theme_config.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({super.key});

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  UserProfile? _userProfile;
  bool _loading = true;
  bool _updating = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      // Force fetch from API to get latest data
      final profile = await UserService.fetchUserProfileFromApi();
      if (profile != null) {
        setState(() {
          _userProfile = profile;
          _loading = false;
        });
      } else {
        // If API fails, try cached profile
        final cachedProfile = await UserService.getCurrentUserProfile();
        setState(() {
          _userProfile = cachedProfile;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _loading = false;
      });
      print('Error loading profile: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to load profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _updateProfilePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _updating = true;
      });

      try {
        final success = await UserService.updateUserProfile(
          name: _userProfile?.name,
          profileImage: File(pickedFile.path),
        );

        if (success) {
          await _loadProfile();
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Profile photo updated successfully!'),
              ),
            );
          }
        } else {
          throw Exception('Update failed');
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile photo')),
          );
        }
      } finally {
        setState(() {
          _updating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Profile',
          style: TextStyle(
            color: AppTheme.textPrimaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surfaceColor,
        foregroundColor: AppTheme.textPrimaryColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loading
                ? null
                : () {
                    setState(() {
                      _loading = true;
                    });
                    _loadProfile();
                  },
            tooltip: 'Refresh Profile',
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Color(0xFFF8FAFC), // Light blue-gray
              Color(0xFFE0E7FF), // Light indigo
              Color(0xFFDDD6FE), // Light purple
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: _loading
            ? const Center(
                child: CircularProgressIndicator(
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF4F46E5)),
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    // Profile Card
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF4F46E5).withOpacity(0.1),
                            blurRadius: 30,
                            offset: const Offset(0, 15),
                          ),
                        ],
                        border: Border.all(
                          color: const Color(0xFF4F46E5).withOpacity(0.1),
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Column(
                          children: [
                            // Profile Photo
                            Stack(
                              children: [
                                Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(
                                        0xFF4F46E5,
                                      ).withOpacity(0.2),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF4F46E5,
                                        ).withOpacity(0.2),
                                        blurRadius: 20,
                                        offset: const Offset(0, 8),
                                      ),
                                    ],
                                  ),
                                  child: ClipOval(
                                    child: _userProfile?.profilePhoto != null
                                        ? Image.network(
                                            _userProfile!.profilePhoto!,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder:
                                                (context, error, stackTrace) =>
                                                    _buildDefaultAvatar(),
                                          )
                                        : _buildDefaultAvatar(),
                                  ),
                                ),

                                // Camera Icon
                                Positioned(
                                  bottom: 0,
                                  right: 0,
                                  child: GestureDetector(
                                    onTap: _updating
                                        ? null
                                        : _updateProfilePhoto,
                                    child: Container(
                                      width: 36,
                                      height: 36,
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF4F46E5),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF4F46E5,
                                            ).withOpacity(0.3),
                                            blurRadius: 8,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: _updating
                                          ? const SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Icon(
                                              Icons.camera_alt,
                                              size: 18,
                                              color: Colors.white,
                                            ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 24),

                            // Name
                            Text(
                              (_userProfile?.name != null &&
                                      _userProfile!.name.trim().isNotEmpty)
                                  ? _userProfile!.name
                                  : 'Name not set',
                              style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color:
                                    (_userProfile?.name != null &&
                                        _userProfile!.name.trim().isNotEmpty)
                                    ? const Color(0xFF1E293B)
                                    : Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 8),

                            // Mobile Number
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFF4F46E5).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                (_userProfile?.mobileNumber != null &&
                                        _userProfile!.mobileNumber.isNotEmpty)
                                    ? _userProfile!.mobileNumber
                                    : 'Mobile not available',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF4F46E5),
                                ),
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Edit Profile Button
                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                onPressed: () {
                                  // Navigate to edit profile screen
                                  Navigator.pushNamed(
                                    context,
                                    '/profile_setup',
                                  );
                                },
                                icon: const Icon(Icons.edit),
                                label: const Text('Edit Profile'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: const Color(0xFF4F46E5),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Container(
      width: 120,
      height: 120,
      decoration: const BoxDecoration(
        color: Color(0xFF4F46E5),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.person, size: 60, color: Colors.white.withOpacity(0.8)),
    );
  }
}
