import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:local_auth/local_auth.dart';
import '../theme_provider.dart';
import '../language_provider.dart';

class SecurityScreen extends StatefulWidget {
  const SecurityScreen({super.key});

  @override
  State<SecurityScreen> createState() => _SecurityScreenState();
}

class _SecurityScreenState extends State<SecurityScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _rememberMe = true;
  bool _biometricID = false;
  bool _faceID = false;
  bool _twoFactorEnabled = false;
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _loadSecuritySettings();
    _checkBiometricAvailability();
  }

  Future<void> _checkBiometricAvailability() async {
    try {
      final isAvailable = await _localAuth.canCheckBiometrics;
      final isDeviceSupported = await _localAuth.isDeviceSupported();
      final availableBiometrics = await _localAuth.getAvailableBiometrics();

      setState(() {
        _isBiometricAvailable = isAvailable && isDeviceSupported;
        _availableBiometrics = availableBiometrics;
      });
    } catch (e) {
      setState(() {
        _isBiometricAvailable = false;
        _availableBiometrics = [];
      });
    }
  }

  Future<void> _loadSecuritySettings() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data();
          final prefs = await SharedPreferences.getInstance();
          setState(() {
            _rememberMe = prefs.getBool('rememberMe') ?? true;
            _biometricID = data?['biometricID'] ?? false;
            _faceID = data?['faceID'] ?? false;
            _twoFactorEnabled = data?['twoFactorEnabled'] ?? false;
          });
        }
      }
    } catch (e) {
      // Error loading settings
    }
  }

  Future<void> _saveSecuritySettings() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('rememberMe', _rememberMe);

        await _firestore.collection('users').doc(user.uid).update({
          'biometricID': _biometricID,
          'faceID': _faceID,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      // Error saving settings
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
        backgroundColor:
            theme.appBarTheme.backgroundColor ?? Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          context.translate('Security'),
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : const Color(0xFF212121),
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 8),

            // Security Options Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                children: [
                  _buildSwitchTile(
                    title: 'Remember me',
                    value: _rememberMe,
                    onChanged: (value) {
                      setState(() => _rememberMe = value);
                      _saveSecuritySettings();
                    },
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Biometric ID',
                    value: _biometricID,
                    onChanged: _isBiometricAvailable
                        ? (value) async {
                            if (value) {
                              final authenticated =
                                  await _authenticateWithBiometrics(
                                    reason:
                                        'Enable Biometric ID authentication',
                                  );
                              if (authenticated) {
                                setState(() {
                                  _biometricID = true;
                                });
                                await _saveSecuritySettings();
                                _showSuccessSnackBar(
                                  'Biometric ID enabled successfully!',
                                );
                              } else {
                                _showErrorSnackBar(
                                  'Biometric authentication failed',
                                );
                              }
                            } else {
                              setState(() {
                                _biometricID = false;
                              });
                              await _saveSecuritySettings();
                            }
                          }
                        : null,
                    subtitle: _isBiometricAvailable
                        ? null
                        : 'Biometric authentication not available on this device',
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Face ID',
                    value: _faceID,
                    onChanged:
                        (_isBiometricAvailable &&
                            _availableBiometrics.contains(BiometricType.face))
                        ? (value) async {
                            if (value) {
                              final authenticated =
                                  await _authenticateWithBiometrics(
                                    reason: 'Enable Face ID authentication',
                                    useErrorDialogs: true,
                                    stickyAuth: true,
                                  );
                              if (authenticated) {
                                setState(() {
                                  _faceID = true;
                                });
                                await _saveSecuritySettings();
                                _showSuccessSnackBar(
                                  'Face ID enabled successfully!',
                                );
                              } else {
                                _showErrorSnackBar(
                                  'Face ID authentication failed',
                                );
                              }
                            } else {
                              setState(() {
                                _faceID = false;
                              });
                              await _saveSecuritySettings();
                            }
                          }
                        : null,
                    subtitle:
                        (_isBiometricAvailable &&
                            _availableBiometrics.contains(BiometricType.face))
                        ? null
                        : 'Face ID not available on this device',
                  ),
                  _buildDivider(),
                  _buildSwitchTile(
                    title: 'Two-Factor Authentication',
                    value: _twoFactorEnabled,
                    onChanged: (value) {
                      _toggle2FA(value);
                    },
                  ),
                  _buildDivider(),
                  _buildNavigationTile(
                    title: 'Device Management',
                    onTap: () => _showDeviceManagementDialog(),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Change Password Button
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16),
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
                onPressed: _showChangePasswordDialog,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: const Text(
                  'Change Password',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Future<bool> _authenticateWithBiometrics({
    required String reason,
    bool useErrorDialogs = true,
    bool stickyAuth = false,
  }) async {
    try {
      return await _localAuth.authenticate(
        localizedReason: reason,
        options: AuthenticationOptions(
          useErrorDialogs: useErrorDialogs,
          stickyAuth: stickyAuth,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      return false;
    }
  }

  Widget _buildSwitchTile({
    required String title,
    required bool value,
    required ValueChanged<bool>? onChanged,
    String? subtitle,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: isDark ? Colors.white : const Color(0xFF212121),
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[500] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              CupertinoSwitch(
                value: value,
                onChanged: onChanged,
                activeColor: const Color(0xFF1E88E5),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNavigationTile({
    required String title,
    required VoidCallback onTap,
  }) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      title: Text(
        title,
        style: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF212121),
        ),
      ),
      trailing: Icon(
        Icons.arrow_forward_ios_rounded,
        size: 16,
        color: isDark ? Colors.grey[500] : Colors.grey[400],
      ),
    );
  }

  Widget _buildDivider() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Divider(
      height: 1,
      thickness: 1,
      indent: 16,
      endIndent: 16,
      color: isDark ? Colors.grey[700] : Colors.grey[200],
    );
  }

  // ==================== DIALOGS ====================

  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    bool _showCurrentPassword = false;
    bool _showNewPassword = false;
    bool _showConfirmPassword = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.lock_rounded, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Change Password'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: !_showCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showCurrentPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _showCurrentPassword = !_showCurrentPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: newPasswordController,
                  obscureText: !_showNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showNewPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _showNewPassword = !_showNewPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: confirmPasswordController,
                  obscureText: !_showConfirmPassword,
                  decoration: InputDecoration(
                    labelText: 'Confirm New Password',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _showConfirmPassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                      onPressed: () {
                        setDialogState(() {
                          _showConfirmPassword = !_showConfirmPassword;
                        });
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E88E5).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.info_outline,
                        color: Color(0xFF1E88E5),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Password must be at least 8 characters',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (currentPasswordController.text.isEmpty ||
                    newPasswordController.text.isEmpty ||
                    confirmPasswordController.text.isEmpty) {
                  _showErrorSnackBar('Please fill all fields');
                  return;
                }

                if (newPasswordController.text.length < 8) {
                  _showErrorSnackBar('Password must be at least 8 characters');
                  return;
                }

                if (newPasswordController.text !=
                    confirmPasswordController.text) {
                  _showErrorSnackBar('Passwords do not match');
                  return;
                }

                // Re-authenticate user
                try {
                  final user = _auth.currentUser;
                  if (user != null && user.email != null) {
                    final credential = EmailAuthProvider.credential(
                      email: user.email!,
                      password: currentPasswordController.text,
                    );
                    await user.reauthenticateWithCredential(credential);

                    // Update password
                    await user.updatePassword(newPasswordController.text);

                    if (mounted) {
                      Navigator.pop(context);
                      _showSuccessSnackBar('Password changed successfully!');
                    }
                  } else {
                    _showErrorSnackBar('User not found');
                  }
                } on FirebaseAuthException catch (e) {
                  if (e.code == 'wrong-password') {
                    _showErrorSnackBar('Current password is incorrect');
                  } else if (e.code == 'weak-password') {
                    _showErrorSnackBar('New password is too weak');
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
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('Change'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDeviceManagementDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) =>
            FutureBuilder<List<Map<String, dynamic>>>(
              future: _loadUserDevices(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return AlertDialog(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    title: const Row(
                      children: [
                        Icon(Icons.devices_rounded, color: Color(0xFF1E88E5)),
                        SizedBox(width: 12),
                        Text('Device Management'),
                      ],
                    ),
                    content: const Center(child: CircularProgressIndicator()),
                  );
                }

                final devices = snapshot.data ?? [];
                final currentDeviceId = _getCurrentDeviceId();

                return AlertDialog(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  title: const Row(
                    children: [
                      Icon(Icons.devices_rounded, color: Color(0xFF1E88E5)),
                      SizedBox(width: 12),
                      Text('Device Management'),
                    ],
                  ),
                  content: SizedBox(
                    width: double.maxFinite,
                    child: devices.isEmpty
                        ? Padding(
                            padding: const EdgeInsets.all(20),
                            child: Center(
                              child: Text(
                                'No devices found',
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                            ),
                          )
                        : ListView.builder(
                            shrinkWrap: true,
                            itemCount: devices.length,
                            itemBuilder: (context, index) {
                              final device = devices[index];
                              final isCurrent =
                                  device['deviceId'] == currentDeviceId;
                              return Padding(
                                padding: EdgeInsets.only(
                                  bottom: index < devices.length - 1 ? 12 : 0,
                                ),
                                child: _buildDeviceCard(
                                  device['deviceName'] ?? 'Unknown Device',
                                  isCurrent
                                      ? 'Current Device'
                                      : _formatLastActive(device['lastActive']),
                                  _getDeviceIcon(device['deviceType']),
                                  isCurrent,
                                  device['deviceId'],
                                  () {
                                    setDialogState(() {});
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                );
              },
            ),
      ),
    );
  }

  Future<String> _getCurrentDeviceId() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        return androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        return iosInfo.identifierForVendor ?? 'unknown';
      }
    } catch (e) {
      // Error getting device ID
    }
    return 'unknown';
  }

  Future<void> _saveCurrentDevice() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final deviceInfo = DeviceInfoPlugin();
      String deviceName = 'Unknown Device';
      String deviceType = 'unknown';
      String deviceId = 'unknown';

      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        deviceName = '${androidInfo.manufacturer} ${androidInfo.model}';
        deviceType = 'android';
        deviceId = androidInfo.id;
      } else if (Platform.isIOS) {
        final iosInfo = await deviceInfo.iosInfo;
        deviceName = '${iosInfo.name} (${iosInfo.model})';
        deviceType = 'ios';
        deviceId = iosInfo.identifierForVendor ?? 'unknown';
      }

      await _firestore
          .collection('devices')
          .doc(user.uid)
          .collection('user_devices')
          .doc(deviceId)
          .set({
            'deviceId': deviceId,
            'deviceName': deviceName,
            'deviceType': deviceType,
            'lastActive': FieldValue.serverTimestamp(),
            'createdAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
    } catch (e) {
      // Error saving device
    }
  }

  Future<List<Map<String, dynamic>>> _loadUserDevices() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return [];

      // Save current device first
      await _saveCurrentDevice();

      final devicesSnapshot = await _firestore
          .collection('devices')
          .doc(user.uid)
          .collection('user_devices')
          .orderBy('lastActive', descending: true)
          .get();

      return devicesSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'deviceId': doc.id,
          'deviceName': data['deviceName'] ?? 'Unknown Device',
          'deviceType': data['deviceType'] ?? 'unknown',
          'lastActive': data['lastActive'],
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  String _formatLastActive(dynamic timestamp) {
    if (timestamp == null) return 'Never';
    try {
      final date = (timestamp as Timestamp).toDate();
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inMinutes < 1) {
        return 'Active now';
      } else if (difference.inMinutes < 60) {
        return 'Last active: ${difference.inMinutes} minutes ago';
      } else if (difference.inHours < 24) {
        return 'Last active: ${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return 'Last active: ${difference.inDays} days ago';
      } else if (difference.inDays < 30) {
        final weeks = (difference.inDays / 7).floor();
        return 'Last active: $weeks ${weeks == 1 ? 'week' : 'weeks'} ago';
      } else {
        final months = (difference.inDays / 30).floor();
        return 'Last active: $months ${months == 1 ? 'month' : 'months'} ago';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  IconData _getDeviceIcon(String deviceType) {
    switch (deviceType.toLowerCase()) {
      case 'ios':
        return Icons.phone_iphone;
      case 'android':
        return Icons.phone_android;
      case 'tablet':
        return Icons.tablet;
      case 'desktop':
      case 'mac':
      case 'windows':
        return Icons.laptop_mac;
      default:
        return Icons.devices;
    }
  }

  Widget _buildDeviceCard(
    String name,
    String subtitle,
    IconData icon,
    bool isCurrent,
    String deviceId,
    VoidCallback onRemove,
  ) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isCurrent
            ? const Color(0xFF1E88E5).withOpacity(0.1)
            : (isDark ? Colors.grey[800] : Colors.grey[100]),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isCurrent
              ? const Color(0xFF1E88E5).withOpacity(0.3)
              : (isDark ? Colors.grey[700]! : Colors.grey[300]!),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isCurrent
                  ? const Color(0xFF1E88E5).withOpacity(0.2)
                  : (isDark ? Colors.grey[700] : Colors.grey[200]),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              color: isCurrent
                  ? const Color(0xFF1E88E5)
                  : (isDark ? Colors.grey[400] : Colors.grey[600]),
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isCurrent
                        ? const Color(0xFF1E88E5)
                        : (isDark ? Colors.white : Colors.grey[800]),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          if (!isCurrent)
            IconButton(
              icon: Icon(Icons.delete_outline, color: Colors.red[400]),
              onPressed: () {
                _showRemoveDeviceDialog(name, deviceId, onRemove);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showRemoveDeviceDialog(
    String deviceName,
    String deviceId,
    VoidCallback onRemove,
  ) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_rounded, color: Colors.orange),
            SizedBox(width: 12),
            Text('Remove Device'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove "$deviceName"? You will need to sign in again on this device.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                final user = _auth.currentUser;
                if (user != null) {
                  await _firestore
                      .collection('devices')
                      .doc(user.uid)
                      .collection('user_devices')
                      .doc(deviceId)
                      .delete();

                  if (mounted) {
                    Navigator.pop(context);
                    Navigator.pop(context);
                    _showSuccessSnackBar('Device removed successfully');
                    onRemove();
                  }
                }
              } catch (e) {
                if (mounted) {
                  Navigator.pop(context);
                  _showErrorSnackBar('Error removing device: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
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

  Future<void> _toggle2FA(bool value) async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        if (value) {
          // Enable 2FA
          // Check if user has email
          final email = user.email;
          if (email == null || email.isEmpty) {
            _showErrorSnackBar('Email is required for 2FA!');
            return;
          }

          // Enable 2FA
          await _firestore.collection('users').doc(user.uid).update({
            'twoFactorEnabled': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _twoFactorEnabled = true;
          });

          if (mounted) {
            _showSuccessSnackBar('2FA enabled successfully!');
          }
        } else {
          // Disable 2FA
          await _firestore.collection('users').doc(user.uid).update({
            'twoFactorEnabled': false,
            'updatedAt': FieldValue.serverTimestamp(),
          });

          setState(() {
            _twoFactorEnabled = false;
          });

          if (mounted) {
            _showSuccessSnackBar('2FA disabled successfully!');
          }
        }
      }
    } catch (e) {
      if (mounted) {
        _showErrorSnackBar('Error: $e');
      }
    }
  }
}
