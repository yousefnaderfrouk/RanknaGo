import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:io';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'theme_provider.dart';
import 'home_screen.dart';
import 'services/auth_service.dart';
import 'config/cloudinary_config.dart';
import '../admin/admin_dashboard_screen.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String email;

  const CompleteProfileScreen({super.key, required this.email});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _dateController = TextEditingController();
  final _authService = AuthService();
  final _firestore = FirebaseFirestore.instance;

  String? _selectedGender;
  String _selectedCountryCode = '+20'; // Default Egypt
  DateTime? _selectedDate;
  bool _isLoading = false;
  bool _isUploadingImage = false;
  File? _profileImage;
  String? _profileImageUrl;
  final ImagePicker _imagePicker = ImagePicker();
  final List<String> _genderOptions = ['Male', 'Female', 'Other'];

  final List<Map<String, String>> _countryCodes = [
    {'code': '+20', 'country': '🇪🇬 Egypt', 'flag': '🇪🇬'},
    {'code': '+966', 'country': '🇸🇦 Saudi Arabia', 'flag': '🇸🇦'},
    {'code': '+971', 'country': '🇦🇪 UAE', 'flag': '🇦🇪'},
    {'code': '+1', 'country': '🇺🇸 USA', 'flag': '🇺🇸'},
    {'code': '+44', 'country': '🇬🇧 UK', 'flag': '🇬🇧'},
  ];

  @override
  void initState() {
    super.initState();
    _emailController.text = widget.email;
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().subtract(const Duration(days: 365 * 20)),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF1E88E5),
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _dateController.text =
            '${picked.day.toString().padLeft(2, '0')}/${picked.month.toString().padLeft(2, '0')}/${picked.year}';
      });
    }
  }

  Future<void> _pickImage() async {
    try {
      // Show bottom sheet to choose source
      final source = await showModalBottomSheet<ImageSource>(
        context: context,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.camera_alt, color: Color(0xFF1E88E5)),
                title: const Text('Camera'),
                onTap: () => Navigator.pop(context, ImageSource.camera),
              ),
              ListTile(
                leading: const Icon(
                  Icons.photo_library,
                  color: Color(0xFF1E88E5),
                ),
                title: const Text('Gallery'),
                onTap: () => Navigator.pop(context, ImageSource.gallery),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      );

      if (source == null) return;

      // Pick image
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: source,
        imageQuality: 85,
        maxWidth: 800,
        maxHeight: 800,
      );

      if (pickedFile != null) {
        setState(() {
          _profileImage = File(pickedFile.path);
          _isUploadingImage = true;
        });

        // Upload image to Cloudinary
        await _uploadImageToCloudinary(pickedFile.path);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error picking image: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      setState(() {
        _isUploadingImage = false;
      });
    }
  }

  Future<void> _uploadImageToCloudinary(String imagePath) async {
    try {
      final user = _authService.currentUser;
      if (user == null) {
        throw 'User not found';
      }

      // إنشاء request
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      // إضافة الصورة
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      // إضافة المعاملات
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.fields['public_id'] = 'raknago/profiles/${user.uid}';
      request.fields['folder'] = 'raknago/profiles';

      // إرسال الطلب
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final downloadUrl = jsonData['secure_url'] as String;

        setState(() {
          _profileImageUrl = downloadUrl;
          _isUploadingImage = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text('Profile picture uploaded successfully!'),
                  ),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.all(Radius.circular(12)),
              ),
              duration: Duration(seconds: 2),
            ),
          );
        }
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['error']['message'] ?? 'Upload failed';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Error uploading image: ${e.toString()}')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
      setState(() {
        _isUploadingImage = false;
        _profileImageUrl = null;
      });
    }
  }

  Future<void> _handleContinue() async {
    if (_formKey.currentState!.validate()) {
      if (_selectedGender == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Please select your gender')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        return;
      }

      if (_selectedDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.error_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Please select your date of birth')),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );
        return;
      }

      setState(() {
        _isLoading = true;
      });

      try {
        final user = _authService.currentUser;
        if (user == null) {
          throw 'User not found';
        }

        // Update user profile in Firestore
        final updateData = {
          'name': _fullNameController.text.trim(),
          'phoneNumber': _phoneController.text.trim().isNotEmpty
              ? '$_selectedCountryCode ${_phoneController.text.trim()}'
              : null,
          'gender': _selectedGender,
          'dateOfBirth': _selectedDate?.toIso8601String(),
          'profileCompleted': true,
          'updatedAt': FieldValue.serverTimestamp(),
        };

        // Add photoURL if image was uploaded
        if (_profileImageUrl != null) {
          updateData['photoURL'] = _profileImageUrl;
        }

        await _firestore.collection('users').doc(user.uid).update(updateData);

        // Update photoURL in Firebase Auth if image was uploaded
        if (_profileImageUrl != null) {
          await user.updatePhotoURL(_profileImageUrl);
          await user.reload();
        }

        // Update display name in Firebase Auth
        await user.updateDisplayName(_fullNameController.text.trim());
        await user.reload();

        // Save profile completed status
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('profile_completed', true);
        await prefs.setBool('is_logged_in', true);

        if (!mounted) return;

        // Check user role
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        final role = userDoc.data()?['role'] ?? 'user';

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 12),
                Expanded(child: Text('Profile completed successfully!')),
              ],
            ),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(12)),
            ),
          ),
        );

        // Navigate based on role
        if (role == 'admin') {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => const AdminDashboardScreen(),
            ),
            (route) => false,
          );
        } else {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => const HomeScreen()),
            (route) => false,
          );
        }
      } catch (e) {
        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(e.toString())),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  // Title with emoji
                  Row(
                    children: [
                      Text(
                        'Complete your profile ',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: isDark ? Colors.white : const Color(0xFF212121),
                        ),
                      ),
                      const Text('📋', style: TextStyle(fontSize: 26)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  // Description
                  Text(
                    'Don\'t worry, only you can see your personal data. No one else will be able to see it.',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Profile Picture
                  _buildProfilePicture(),
                  const SizedBox(height: 32),
                  // Full Name Field
                  _buildTextField(
                    controller: _fullNameController,
                    label: 'Full Name',
                    hint: 'Enter your full name',
                    icon: Icons.person_outline,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your full name';
                      }
                      if (value.length < 3) {
                        return 'Name must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Email Field (Read-only)
                  _buildTextField(
                    controller: _emailController,
                    label: 'Email',
                    hint: 'Email',
                    icon: Icons.email_outlined,
                    readOnly: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Email is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Phone Number Field
                  _buildPhoneField(),
                  const SizedBox(height: 20),
                  // Gender Dropdown
                  _buildGenderDropdown(),
                  const SizedBox(height: 20),
                  // Date of Birth
                  _buildDateField(),
                  const SizedBox(height: 40),
                  // Continue Button
                  _buildContinueButton(),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    
    return Center(
      child: Stack(
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: isDark ? Colors.grey[800] : Colors.grey[200],
              shape: BoxShape.circle,
            ),
            child: _isUploadingImage
                ? const Center(
                    child: CircularProgressIndicator(color: Color(0xFF1E88E5)),
                  )
                : _profileImage != null
                ? ClipOval(child: Image.file(_profileImage!, fit: BoxFit.cover))
                : _profileImageUrl != null
                ? ClipOval(
                    child: Image.network(
                      _profileImageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Icon(
                          Icons.person,
                          size: 60,
                          color: isDark ? Colors.grey[600] : Colors.grey[400],
                        );
                      },
                    ),
                  )
                : Icon(
                    Icons.person,
                    size: 60,
                    color: isDark ? Colors.grey[600] : Colors.grey[400],
                  ),
          ),
          Positioned(
            bottom: 0,
            right: 0,
            child: GestureDetector(
              onTap: _isUploadingImage ? null : _pickImage,
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _isUploadingImage
                      ? Colors.grey
                      : const Color(0xFF1E88E5),
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
                child: _isUploadingImage
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(
                        Icons.camera_alt_rounded,
                        size: 18,
                        color: Colors.white,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    String? Function(String?)? validator,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: readOnly
                ? (isDark ? Colors.grey[900] : Colors.grey[50])
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: TextFormField(
            controller: controller,
            readOnly: readOnly,
            style: TextStyle(
              fontSize: 15,
              color: readOnly
                  ? (isDark ? Colors.grey[500] : Colors.grey[500])
                  : (isDark ? Colors.white : const Color(0xFF212121)),
            ),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
                fontSize: 15,
              ),
              prefixIcon: Icon(
                icon,
                color: readOnly
                    ? (isDark ? Colors.grey[500] : Colors.grey[400])
                    : const Color(0xFF1E88E5),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            validator: validator,
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Country Code Dropdown
              Container(
                padding: const EdgeInsets.only(left: 12),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _selectedCountryCode,
                    icon: Icon(
                      Icons.arrow_drop_down,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                    dropdownColor: theme.cardColor,
                    items: _countryCodes.map((country) {
                      return DropdownMenuItem<String>(
                        value: country['code'],
                        child: Row(
                          children: [
                            Text(
                              country['flag']!,
                              style: const TextStyle(fontSize: 20),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              country['code']!,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCountryCode = value!;
                      });
                    },
                  ),
                ),
              ),
              Container(
                width: 1,
                height: 40,
                color: isDark ? Colors.grey[700] : Colors.grey[300],
              ),
              // Phone Number Input
              Expanded(
                child: TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                    LengthLimitingTextInputFormatter(10),
                  ],
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                  decoration: InputDecoration(
                    hintText: '123 456 7890',
                    hintStyle: TextStyle(
                      color: isDark ? Colors.grey[500] : Colors.grey[400],
                      fontSize: 15,
                    ),
                    prefixIcon: const Icon(
                      Icons.phone_outlined,
                      color: Color(0xFF1E88E5),
                      size: 22,
                    ),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 16,
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please enter your phone number';
                    }
                    if (value.length < 9) {
                      return 'Phone number is too short';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Example: $_selectedCountryCode 123 456 7890',
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Gender',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              width: 1.5,
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedGender,
            decoration: InputDecoration(
              hintText: 'Select gender',
              hintStyle: TextStyle(
                color: isDark ? Colors.grey[500] : Colors.grey[400],
                fontSize: 15,
              ),
              prefixIcon: const Icon(
                Icons.wc_outlined,
                color: Color(0xFF1E88E5),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 16,
              ),
            ),
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
            ),
            dropdownColor: theme.cardColor,
            items: _genderOptions.map((String gender) {
              return DropdownMenuItem<String>(
                value: gender,
                child: Text(
                  gender,
                  style: TextStyle(
                    fontSize: 15,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                ),
              );
            }).toList(),
            onChanged: (String? newValue) {
              setState(() {
                _selectedGender = newValue;
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDateField() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Date of Birth',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: _selectDate,
          child: Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
                width: 1.5,
              ),
            ),
            child: AbsorbPointer(
              child: TextFormField(
                controller: _dateController,
                style: TextStyle(
                  fontSize: 15,
                  color: isDark ? Colors.white : const Color(0xFF212121),
                ),
                decoration: InputDecoration(
                  hintText: 'DD/MM/YYYY',
                  hintStyle: TextStyle(
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    fontSize: 15,
                  ),
                  prefixIcon: const Icon(
                    Icons.calendar_today_outlined,
                    color: Color(0xFF1E88E5),
                    size: 20,
                  ),
                  suffixIcon: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: isDark ? Colors.grey[500] : Colors.grey[400],
                    size: 16,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildContinueButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1E88E5).withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _handleContinue,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(28),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
                height: 24,
                width: 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              )
            : const Text(
                'Continue',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}
