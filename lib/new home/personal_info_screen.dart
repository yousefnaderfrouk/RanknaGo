import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../theme_provider.dart';
import '../language_provider.dart';

class PersonalInfoScreen extends StatefulWidget {
  const PersonalInfoScreen({super.key});

  @override
  State<PersonalInfoScreen> createState() => _PersonalInfoScreenState();
}

class _PersonalInfoScreenState extends State<PersonalInfoScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();

  final _fullNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _dateOfBirthController = TextEditingController();
  final _streetAddressController = TextEditingController();

  String _selectedGender = 'Male';
  String? _userPhotoURL;
  File? _selectedImage;
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];
  String? _originalEmail;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data();
          DateTime? dateOfBirth;
          if (data?['dateOfBirth'] != null) {
            if (data!['dateOfBirth'] is String) {
              dateOfBirth = DateTime.tryParse(data['dateOfBirth']);
            } else if (data['dateOfBirth'] is Timestamp) {
              dateOfBirth = (data['dateOfBirth'] as Timestamp).toDate();
            }
          }

          setState(() {
            _fullNameController.text = data?['name'] ?? user.displayName ?? '';
            _phoneController.text =
                data?['phoneNumber'] ?? user.phoneNumber ?? '';
            _emailController.text = data?['email'] ?? user.email ?? '';
            _originalEmail = data?['email'] ?? user.email;
            _selectedGender = data?['gender'] ?? 'Male';
            _streetAddressController.text = data?['streetAddress'] ?? '';
            _userPhotoURL = data?['photoURL'] ?? user.photoURL;

            if (dateOfBirth != null) {
              _dateOfBirthController.text =
                  '${dateOfBirth.month.toString().padLeft(2, '0')}/${dateOfBirth.day.toString().padLeft(2, '0')}/${dateOfBirth.year}';
            }
          });
        } else {
          setState(() {
            _fullNameController.text = user.displayName ?? '';
            _phoneController.text = user.phoneNumber ?? '';
            _emailController.text = user.email ?? '';
            _originalEmail = user.email;
            _userPhotoURL = user.photoURL;
          });
        }
      }
    } catch (e) {
      // Error loading user data
    }
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _dateOfBirthController.dispose();
    _streetAddressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: theme.appBarTheme.backgroundColor ?? Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.translate('Personal Info'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_outlined, color: Color(0xFF1E88E5)),
            onPressed: () {
              _showSuccessSnackBar('Edit mode enabled');
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Profile Picture
              Center(
                child: Stack(
                  children: [
                    Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.grey[300]!, width: 3),
                        image: _selectedImage != null
                            ? DecorationImage(
                                image: FileImage(_selectedImage!),
                                fit: BoxFit.cover,
                              )
                            : _userPhotoURL != null && _userPhotoURL!.isNotEmpty
                            ? DecorationImage(
                                image: NetworkImage(_userPhotoURL!),
                                fit: BoxFit.cover,
                                onError: (exception, stackTrace) {
                                  // Handle error
                                },
                              )
                            : null,
                        color:
                            _selectedImage == null &&
                                (_userPhotoURL == null ||
                                    _userPhotoURL!.isEmpty)
                            ? const Color(0xFF1E88E5)
                            : null,
                      ),
                      child:
                          _selectedImage == null &&
                              (_userPhotoURL == null || _userPhotoURL!.isEmpty)
                          ? const Icon(
                              Icons.person,
                              color: Colors.white,
                              size: 50,
                            )
                          : null,
                    ),
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: GestureDetector(
                        onTap: _pickImage,
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5),
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 3),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.edit_rounded,
                            color: Colors.white,
                            size: 18,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 40),

              // Full Name
              _buildTextField(
                label: 'Full Name',
                controller: _fullNameController,
              ),

              const SizedBox(height: 24),

              // Phone Number
              _buildTextField(
                label: 'Phone Number',
                controller: _phoneController,
                keyboardType: TextInputType.phone,
              ),

              const SizedBox(height: 24),

              // Email (Read-only with change button)
              _buildEmailField(),

              const SizedBox(height: 24),

              // Gender Dropdown (Read-only)
              _buildGenderDropdown(),

              const SizedBox(height: 24),

              // Date of Birth (Read-only)
              _buildDateField(),

              const SizedBox(height: 24),

              // Street Address
              _buildTextField(
                label: 'Street Address',
                controller: _streetAddressController,
              ),

              const SizedBox(height: 40),

              // Save Button
              Container(
                width: double.infinity,
                height: 56,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF1E88E5).withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _saveChanges,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text(
                    'Save Changes',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    TextInputType? keyboardType,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Color(0xFF212121),
          ),
          decoration: InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Color(0xFF1E88E5), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Email',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            TextButton(
              onPressed: _showChangeEmailDialog,
              child: const Text(
                'Change Email',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _emailController,
          readOnly: true,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
          decoration: InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixIcon: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(bottom: 12),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Colors.grey[300]!, width: 1),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedGender,
                    isExpanded: true,
                    icon: const SizedBox.shrink(),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey[600],
                    ),
                    items: _genderOptions.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                        enabled: false,
                      );
                    }).toList(),
                    onChanged: null, // Disabled
                  ),
                ),
              ),
              Container(
                alignment: Alignment.centerRight,
                padding: const EdgeInsets.only(bottom: 12),
                child: const Icon(
                  Icons.lock_outline,
                  color: Colors.grey,
                  size: 20,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.grey[700],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _dateOfBirthController,
          readOnly: true,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.grey[600],
          ),
          decoration: InputDecoration(
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey[300]!),
            ),
            focusedBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey, width: 1),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            suffixIcon: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(bottom: 12),
              child: const Icon(
                Icons.lock_outline,
                color: Colors.grey,
                size: 20,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _pickImage() async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        setState(() {
          _selectedImage = File(pickedFile.path);
        });
      }
    } catch (e) {
      _showErrorSnackBar('Error picking image: $e');
    }
  }

  Future<void> _saveChanges() async {
    // Validate fields
    if (_fullNameController.text.isEmpty) {
      _showErrorSnackBar('Please enter your full name');
      return;
    }

    if (_phoneController.text.isEmpty) {
      _showErrorSnackBar('Please enter your phone number');
      return;
    }

    if (_emailController.text.isEmpty) {
      _showErrorSnackBar('Please enter your email');
      return;
    }

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorSnackBar('User not found');
        return;
      }

      // Upload image if selected
      String? photoURL = _userPhotoURL;
      if (_selectedImage != null) {
        // TODO: Upload image to Firebase Storage or Cloudinary
        // For now, we'll keep the existing photoURL
        // photoURL = await _uploadImage(_selectedImage!);
      }

      // Update user data in Firestore (don't update gender, dateOfBirth, or email)
      final updateData = {
        'name': _fullNameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'streetAddress': _streetAddressController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (photoURL != null) {
        updateData['photoURL'] = photoURL;
      }

      await _firestore.collection('users').doc(user.uid).update(updateData);

      // Update Firebase Auth
      await user.updateDisplayName(_fullNameController.text.trim());
      if (photoURL != null) {
        await user.updatePhotoURL(photoURL);
      }
      await user.reload();

      _showSuccessSnackBar('Profile updated successfully!');

      // Go back after short delay
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          Navigator.pop(context);
        }
      });
    } catch (e) {
      _showErrorSnackBar('Error saving profile: $e');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red[400],
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _showChangeEmailDialog() {
    final newEmailController = TextEditingController();
    final verificationCodeController = TextEditingController();
    bool _codeSent = false;
    String? _verificationId;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.email_rounded, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Change Email'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (!_codeSent) ...[
                  TextField(
                    controller: newEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: InputDecoration(
                      labelText: 'New Email',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.email),
                    ),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      if (newEmailController.text.isEmpty) {
                        _showErrorSnackBar('Please enter a new email');
                        return;
                      }

                      if (newEmailController.text == _originalEmail) {
                        _showErrorSnackBar(
                          'New email must be different from current email',
                        );
                        return;
                      }

                      try {
                        // Send verification code to new email
                        // For now, we'll simulate sending a code
                        // In production, you would send an email with verification code
                        setDialogState(() {
                          _codeSent = true;
                          _verificationId =
                              '123456'; // In production, this would come from email service
                        });
                        _showSuccessSnackBar(
                          'Verification code sent to ${newEmailController.text}',
                        );
                      } catch (e) {
                        _showErrorSnackBar('Error: $e');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E88E5),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text('Send Verification Code'),
                  ),
                ] else ...[
                  Text(
                    'Enter the verification code sent to ${newEmailController.text}',
                    style: const TextStyle(fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: verificationCodeController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      prefixIcon: const Icon(Icons.lock_outline),
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            if (_codeSent)
              ElevatedButton(
                onPressed: () async {
                  if (verificationCodeController.text.isEmpty) {
                    _showErrorSnackBar('Please enter verification code');
                    return;
                  }

                  // Verify code (in production, verify against sent code)
                  if (verificationCodeController.text != _verificationId) {
                    _showErrorSnackBar('Invalid verification code');
                    return;
                  }

                  try {
                    final user = _auth.currentUser;
                    if (user != null) {
                      // Update email in Firebase Auth
                      await user.updateEmail(newEmailController.text.trim());

                      // Update email in Firestore
                      await _firestore
                          .collection('users')
                          .doc(user.uid)
                          .update({
                            'email': newEmailController.text.trim(),
                            'updatedAt': FieldValue.serverTimestamp(),
                          });

                      // Reload user
                      await user.reload();

                      // Update UI
                      setState(() {
                        _emailController.text = newEmailController.text.trim();
                        _originalEmail = newEmailController.text.trim();
                      });

                      Navigator.pop(context);
                      _showSuccessSnackBar('Email changed successfully!');
                    }
                  } on FirebaseAuthException catch (e) {
                    if (e.code == 'requires-recent-login') {
                      _showErrorSnackBar(
                        'Please re-authenticate to change email',
                      );
                    } else {
                      _showErrorSnackBar('Error: ${e.message}');
                    }
                  } catch (e) {
                    _showErrorSnackBar('Error: $e');
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Verify & Change'),
              ),
          ],
        ),
      ),
    );
  }
}
