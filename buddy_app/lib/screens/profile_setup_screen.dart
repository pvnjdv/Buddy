import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../services/auth/user_service.dart';
import '../services/auth/auth_service.dart';
import '../services/app_mode_service.dart';
import '../models/college_models.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _nameController = TextEditingController();
  File? _profileImage;
  bool _loading = false;
  bool _initialLoading = true;
  String? _error;
  String? _mobileNumber;
  UserRole _selectedProfession = UserRole.normal;
  bool _isExistingUser = false;
  UserProfile? _existingProfile;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      print('ProfileSetup: Loading user data...');

      // Get mobile number
      final mobile = await AuthService.getMobileNumber();
      print('ProfileSetup: Mobile number: $mobile');

      // Try to get existing user profile
      final existingProfile = await UserService.getCurrentUserProfile();
      print('ProfileSetup: Existing profile: $existingProfile');

      setState(() {
        _mobileNumber = mobile;
        if (existingProfile != null && existingProfile.name.trim().isNotEmpty) {
          print(
            'ProfileSetup: Found existing user with name: ${existingProfile.name}',
          );
          _isExistingUser = true;
          _existingProfile = existingProfile;
          _nameController.text = existingProfile.name;

          // Set profession based on existing data
          if (existingProfile.profession != null &&
              existingProfile.profession!.trim().isNotEmpty) {
            try {
              _selectedProfession = UserRole.values.firstWhere(
                (role) =>
                    role.toString().split('.').last ==
                    existingProfile.profession,
                orElse: () => UserRole.normal,
              );
              print('ProfileSetup: Set profession to: $_selectedProfession');
            } catch (e) {
              print('ProfileSetup: Error setting profession: $e');
              _selectedProfession = UserRole.normal;
            }
          }
        } else {
          print('ProfileSetup: New user or empty profile');
          _isExistingUser = false;
        }
        _initialLoading = false;
      });
    } catch (e) {
      print('ProfileSetup: Error loading user data: $e');
      setState(() {
        _initialLoading = false;
        _error = 'Failed to load user data';
      });
    }
  }

  Future<void> _logout() async {
    // Clear cached profile data
    await UserService.clearCachedProfile();
    await AuthService.logout();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _profileImage = File(pickedFile.path);
      });
    }
  }

  Future<void> _saveProfile() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() {
        _error = 'Please enter your name';
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // Use the updateUserProfile method which makes actual API calls
      final success = await UserService.updateUserProfile(
        name: _nameController.text.trim(),
        profileImage: _profileImage,
        profession: _selectedProfession.toString().split('.').last,
      );

      if (success && mounted) {
        // Update app mode based on selected profession
        final appModeService = AppModeService();
        await appModeService.updateModeBasedOnProfession(
          _selectedProfession.toString().split('.').last,
        );

        Navigator.pushReplacementNamed(context, '/home');
      } else {
        setState(() {
          _error = 'Failed to save profile. Please try again.';
        });
      }
    } catch (e) {
      setState(() {
        _error = 'Failed to save profile. Please try again.';
      });
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_initialLoading) {
      return Scaffold(
        backgroundColor: const Color(0xFF0D1B2A),
        body: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF667EEA)),
          ),
        ),
      );
    }

    return PopScope(
      canPop: false, // Prevent back button
      child: Scaffold(
        backgroundColor: const Color(0xFF0D1B2A), // Deep dark blue
        body: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Color(0xFF0D1B2A), // Deep dark blue
                Color(0xFF1B263B), // Dark slate
                Color(0xFF2D3748), // Darker gray
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: SafeArea(
            child: Column(
              children: [
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      // Back/Logout Button
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A202C).withOpacity(0.8),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFF4A5568).withOpacity(0.3),
                          ),
                        ),
                        child: IconButton(
                          onPressed: () {
                            showDialog(
                              context: context,
                              builder: (BuildContext context) {
                                return AlertDialog(
                                  backgroundColor: const Color(0xFF1A202C),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  title: const Text(
                                    'Logout',
                                    style: TextStyle(color: Colors.white),
                                  ),
                                  content: const Text(
                                    'Are you sure you want to logout? You will need to login again.',
                                    style: TextStyle(color: Colors.grey),
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text(
                                        'Cancel',
                                        style: TextStyle(
                                          color: Color(0xFF667EEA),
                                        ),
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _logout,
                                      child: const Text(
                                        'Logout',
                                        style: TextStyle(color: Colors.red),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          },
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          tooltip: 'Logout',
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Title
                      Expanded(
                        child: Text(
                          _isExistingUser ? 'Edit Profile' : 'Complete Profile',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Main Content
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 400),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A202C).withOpacity(0.9),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: const Color(0xFF4A5568).withOpacity(0.3),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Icon with gradient
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFF667EEA),
                                      Color(0xFF764BA2),
                                    ],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  boxShadow: [
                                    BoxShadow(
                                      color: const Color(
                                        0xFF667EEA,
                                      ).withOpacity(0.3),
                                      blurRadius: 15,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.person_add,
                                  size: 48,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Title
                              Text(
                                _isExistingUser
                                    ? 'Edit Your Profile'
                                    : 'Complete Your Profile',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                  letterSpacing: 0.5,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),

                              // Subtitle
                              Text(
                                _isExistingUser
                                    ? 'Update your information and continue'
                                    : 'Please provide your details to get started',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[400],
                                  fontWeight: FontWeight.w300,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              // Mobile Number Display
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF10B981,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(
                                      0xFF10B981,
                                    ).withOpacity(0.3),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.phone,
                                      color: Color(0xFF10B981),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        'Mobile: ${_mobileNumber ?? 'Loading...'}',
                                        style: const TextStyle(
                                          color: Color(0xFF10B981),
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Profile Photo Section
                              GestureDetector(
                                onTap: _pickImage,
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: const Color(0xFF2D3748),
                                    border: Border.all(
                                      color: const Color(0xFF4A5568),
                                      width: 3,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF667EEA,
                                        ).withOpacity(0.2),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: _profileImage != null
                                      ? ClipOval(
                                          child: Image.file(
                                            _profileImage!,
                                            fit: BoxFit.cover,
                                            width: 120,
                                            height: 120,
                                          ),
                                        )
                                      : (_existingProfile?.profilePhoto != null)
                                      ? ClipOval(
                                          child: Image.network(
                                            _existingProfile!.profilePhoto!,
                                            fit: BoxFit.cover,
                                            width: 120,
                                            height: 120,
                                            errorBuilder:
                                                (context, error, stackTrace) {
                                                  return const Icon(
                                                    Icons.add_a_photo,
                                                    size: 40,
                                                    color: Color(0xFF667EEA),
                                                  );
                                                },
                                          ),
                                        )
                                      : const Icon(
                                          Icons.add_a_photo,
                                          size: 40,
                                          color: Color(0xFF667EEA),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 12),

                              TextButton(
                                onPressed: _pickImage,
                                child: Text(
                                  _profileImage != null ||
                                          (_existingProfile?.profilePhoto !=
                                              null)
                                      ? 'Change Photo'
                                      : 'Add Photo',
                                  style: const TextStyle(
                                    color: Color(0xFF667EEA),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Name Input
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D3748),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF4A5568),
                                    width: 1,
                                  ),
                                ),
                                child: TextField(
                                  controller: _nameController,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Full Name',
                                    labelStyle: TextStyle(
                                      color: Colors.grey[400],
                                      fontSize: 14,
                                    ),
                                    hintText: 'Enter your full name',
                                    hintStyle: TextStyle(
                                      color: Colors.grey[600],
                                    ),
                                    prefixIcon: Icon(
                                      Icons.person_outline,
                                      color: Colors.grey[400],
                                    ),
                                    border: InputBorder.none,
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 20,
                                    ),
                                  ),
                                  textCapitalization: TextCapitalization.words,
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Profession Selection
                              Container(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF2D3748),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: const Color(0xFF4A5568),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 4,
                                  ),
                                  child: DropdownButtonHideUnderline(
                                    child: DropdownButton<UserRole>(
                                      value: _selectedProfession,
                                      isExpanded: true,
                                      dropdownColor: const Color(0xFF2D3748),
                                      icon: Icon(
                                        Icons.arrow_drop_down,
                                        color: Colors.grey[400],
                                      ),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 16,
                                      ),
                                      items: UserRole.values.map((
                                        UserRole role,
                                      ) {
                                        return DropdownMenuItem<UserRole>(
                                          value: role,
                                          child: Row(
                                            children: [
                                              Icon(
                                                _getRoleIcon(role),
                                                color: const Color(0xFF667EEA),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 12),
                                              Text(
                                                _getRoleDisplayName(role),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ],
                                          ),
                                        );
                                      }).toList(),
                                      onChanged: (UserRole? newValue) {
                                        if (newValue != null) {
                                          setState(() {
                                            _selectedProfession = newValue;
                                          });
                                        }
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),

                              Text(
                                'Select your profession to enable relevant features',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey[500],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 32),

                              // Action Button
                              SizedBox(
                                width: double.infinity,
                                child: Container(
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFF667EEA),
                                        Color(0xFF764BA2),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(
                                          0xFF667EEA,
                                        ).withOpacity(0.4),
                                        blurRadius: 15,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: _loading ? null : _saveProfile,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 18,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                    ),
                                    child: _loading
                                        ? const SizedBox(
                                            width: 24,
                                            height: 24,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    Colors.white,
                                                  ),
                                            ),
                                          )
                                        : Text(
                                            _isExistingUser
                                                ? 'Update Profile'
                                                : 'Complete Setup',
                                            style: const TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.white,
                                              letterSpacing: 0.5,
                                            ),
                                          ),
                                  ),
                                ),
                              ),

                              // Continue to Home button for existing users
                              if (_isExistingUser) ...[
                                const SizedBox(height: 16),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.pushReplacementNamed(
                                        context,
                                        '/home',
                                      );
                                    },
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: const Color(
                                            0xFF667EEA,
                                          ).withOpacity(0.3),
                                        ),
                                      ),
                                    ),
                                    child: const Text(
                                      'Continue to Home',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF667EEA),
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ], // Error message
                              if (_error != null) ...[
                                const SizedBox(height: 24),
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFFE53E3E,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: const Color(
                                        0xFFE53E3E,
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.error_outline,
                                        color: Color(0xFFE53E3E),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          _error!,
                                          style: const TextStyle(
                                            color: Color(0xFFE53E3E),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getRoleDisplayName(UserRole role) {
    switch (role) {
      case UserRole.normal:
        return 'General User';
      case UserRole.student:
        return 'Student';
      case UserRole.teacher:
        return 'Teacher/Faculty';
      case UserRole.hod:
        return 'Head of Department';
      case UserRole.principal:
        return 'Principal/Director';
    }
  }

  IconData _getRoleIcon(UserRole role) {
    switch (role) {
      case UserRole.normal:
        return Icons.person;
      case UserRole.student:
        return Icons.school;
      case UserRole.teacher:
        return Icons.psychology;
      case UserRole.hod:
        return Icons.supervisor_account;
      case UserRole.principal:
        return Icons.admin_panel_settings;
    }
  }
}
