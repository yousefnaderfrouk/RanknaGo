import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../language_provider.dart';

/// QR Scanner Screen - User Parking Unlock System
///
/// This screen allows users to unlock parking spots by scanning QR codes.
/// QR codes are generated in the Admin panel (manage_parking_spots_screen.dart)
/// and printed/placed at parking spot entrances.
///
/// Security: Users can ONLY unlock spots they have active bookings for.
/// See QR_SYSTEM_INTEGRATION.md for full documentation.
class QRScannerScreen extends StatefulWidget {
  const QRScannerScreen({super.key});

  @override
  State<QRScannerScreen> createState() => _QRScannerScreenState();
}

class _QRScannerScreenState extends State<QRScannerScreen> {
  final MobileScannerController controller = MobileScannerController(
    detectionSpeed: DetectionSpeed.noDuplicates,
  );
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  bool _isProcessing = false;
  String? _scannedCode;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1E232C),
      body: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          // QR Scanner View
          MobileScanner(
            controller: controller,
            onDetect: (capture) {
              if (!_isProcessing) {
                final List<Barcode> barcodes = capture.barcodes;
                if (barcodes.isNotEmpty && barcodes.first.rawValue != null) {
                  final String code = barcodes.first.rawValue!;
                  if (_scannedCode != code) {
                    _scannedCode = code;
                    log('📱 QR Code scanned: $code');
                    // Auto-process when QR code is detected
                    _processQRCode(code);
                  }
                }
              }
            },
          ),

          // Scan area overlay
          Container(
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(color: Colors.transparent),
            ),
            child: Stack(
              children: [
                // Dark overlay with cutout
                ColorFiltered(
                  colorFilter: ColorFilter.mode(
                    const Color(0xFF1E232C).withOpacity(0.8),
                    BlendMode.srcOut,
                  ),
                  child: Stack(
                    children: [
                      Container(
                        decoration: const BoxDecoration(
                          color: Color(0xFF1E232C),
                          backgroundBlendMode: BlendMode.dstOut,
                        ),
                      ),
                      Align(
                        alignment: Alignment.center,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            color: Colors.red,
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Border overlay with corners
                Center(
                  child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Stack(
                      children: [
                        // Top-left corner
                        Positioned(
                          top: 0,
                          left: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.blue, width: 10),
                                left: BorderSide(color: Colors.blue, width: 10),
                              ),
                              borderRadius: BorderRadius.only(
                                topLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        // Top-right corner
                        Positioned(
                          top: 0,
                          right: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              border: Border(
                                top: BorderSide(color: Colors.blue, width: 10),
                                right: BorderSide(
                                  color: Colors.blue,
                                  width: 10,
                                ),
                              ),
                              borderRadius: BorderRadius.only(
                                topRight: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        // Bottom-left corner
                        Positioned(
                          bottom: 0,
                          left: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.blue,
                                  width: 10,
                                ),
                                left: BorderSide(color: Colors.blue, width: 10),
                              ),
                              borderRadius: BorderRadius.only(
                                bottomLeft: Radius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        // Bottom-right corner
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 40,
                            height: 40,
                            decoration: const BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.blue,
                                  width: 10,
                                ),
                                right: BorderSide(
                                  color: Colors.blue,
                                  width: 10,
                                ),
                              ),
                              borderRadius: BorderRadius.only(
                                bottomRight: Radius.circular(12),
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

          // Back button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),

          // Title and subtitle
          Positioned(
            top: 100,
            child: Column(
              children: [
                Text(
                  context.translate('Scan QR Code'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  context.translate('Please point the camera at the QR Code'),
                  style: const TextStyle(color: Colors.white70, fontSize: 16),
                ),
              ],
            ),
          ),

          // Bottom scanner button
          Positioned(
            bottom: 50,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(width: 40),
                GestureDetector(
                  onTap: () {
                    if (_scannedCode != null && !_isProcessing) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '${context.translate('QR Code:')} $_scannedCode',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } else if (_isProcessing) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            context.translate('Processing, please wait...'),
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('No QR Code scanned yet'),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _isProcessing ? Colors.orange : Colors.blue,
                        width: 3,
                      ),
                    ),
                    child: CircleAvatar(
                      radius: 30,
                      backgroundColor: Colors.transparent,
                      child: _isProcessing
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                color: Colors.orange,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(
                              Icons.qr_code_scanner,
                              color: Colors.blue,
                              size: 30,
                            ),
                    ),
                  ),
                ),
                const SizedBox(width: 40),
              ],
            ),
          ),

          // Processing overlay
          if (_isProcessing)
            Container(
              color: Colors.black54,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.blue),
                    SizedBox(height: 16),
                    Text(
                      'Verifying booking...',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _processQRCode(String? qrCode) async {
    if (qrCode == null || qrCode.isEmpty) {
      _showErrorDialog('Invalid QR Code', 'The QR code is empty or invalid.');
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    // Stop scanner while processing
    await controller.stop();

    log('🔍 ===== PROCESSING QR CODE =====');
    log('🔍 QR Code content: $qrCode');

    try {
      final user = _auth.currentUser;
      if (user == null) {
        _showErrorDialog(
          'Not Logged In',
          'Please log in to unlock parking spots.',
        );
        return;
      }

      log('✅ User authenticated: ${user.uid}');

      // Parse QR code - expecting format: "spotId" or "parking_spot_id:spotId"
      String spotId = qrCode;
      if (qrCode.contains(':')) {
        spotId = qrCode.split(':').last;
      }

      log('🅿️ Parking Spot ID: $spotId');

      // 1. Check if parking spot exists
      log('🔍 Checking if parking spot exists...');
      final spotDoc = await _firestore
          .collection('parking_spots')
          .doc(spotId)
          .get();

      if (!spotDoc.exists) {
        log('❌ Parking spot not found');
        _showErrorDialog(
          'Invalid QR Code',
          'This parking spot does not exist in our system.',
        );
        return;
      }

      final spotData = spotDoc.data();
      final spotName = spotData?['name'] ?? 'Unknown Parking';
      log('✅ Parking spot found: $spotName');

      // 2. Check if user has an active booking for this spot
      log('🔍 Checking for active booking...');

      // First, check if user has ANY booking for this spot (to provide better error message)
      final allBookingsQuery = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .where('spotId', isEqualTo: spotId)
          .get();

      // Check for active booking specifically
      final activeBookingsQuery = await _firestore
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .where('spotId', isEqualTo: spotId)
          .where('status', isEqualTo: 'active')
          .get();

      if (activeBookingsQuery.docs.isEmpty) {
        log('❌ No active booking found for this parking spot');

        // Check if there's a cancelled booking to provide specific message
        if (allBookingsQuery.docs.isNotEmpty) {
          final anyBooking = allBookingsQuery.docs.first.data();
          final bookingStatus = anyBooking['status'] as String?;

          if (bookingStatus == 'cancelled') {
            log('⚠️ Booking was cancelled - access denied');
            _showErrorDialog(
              'Booking Cancelled',
              'Your booking for "$spotName" has been cancelled.\n\nThe parking spot is now locked and cannot be unlocked.\n\nPlease create a new booking to access this parking spot.',
            );
          } else if (bookingStatus == 'completed') {
            log('⚠️ Booking was completed - access denied');
            _showErrorDialog(
              'Booking Completed',
              'Your booking for "$spotName" has been completed.\n\nThe parking spot is now locked.\n\nPlease create a new booking to access this parking spot.',
            );
          } else {
            _showErrorDialog(
              'No Active Booking',
              'You don\'t have an active booking for "$spotName".\n\nThe parking spot is locked.\n\nPlease book this parking spot before trying to unlock it.',
            );
          }
        } else {
          _showErrorDialog(
            'No Booking Found',
            'You don\'t have an active booking for "$spotName".\n\nThe parking spot is locked.\n\nPlease book this parking spot before trying to unlock it.',
          );
        }
        return;
      }

      final booking = activeBookingsQuery.docs.first.data();
      final bookingId = activeBookingsQuery.docs.first.id;
      log('✅ Active booking found: $bookingId');
      log('📝 Booking details:');
      log('   - Parking: $spotName');
      log('   - Start time: ${booking['startTime']}');
      log('   - Total price: ${booking['totalPrice']}');

      // 3. Success - User has valid booking
      log('✅ ✅ ✅ BOOKING VERIFIED - UNLOCKING PARKING SPOT ✅ ✅ ✅');

      // Update booking with unlock timestamp
      await _firestore.collection('reservations').doc(bookingId).update({
        'lastUnlocked': FieldValue.serverTimestamp(),
        'unlockCount': FieldValue.increment(1),
      });

      log('✅ Unlock logged successfully');

      if (mounted) {
        // Show success dialog
        await _showSuccessDialog(spotName, booking);

        // Return to previous screen
        if (mounted) {
          Navigator.of(context).pop();
        }
      }
    } catch (e) {
      log('❌ Error processing QR code: $e');
      _showErrorDialog(
        'Error',
        'An error occurred while processing the QR code:\n${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
          _scannedCode = null;
        });
        // Resume scanner
        await controller.start();
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 28),
            const SizedBox(width: 12),
            Expanded(child: Text(title)),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              // Reset scanned code to allow rescanning
              _scannedCode = null;
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSuccessDialog(
    String spotName,
    Map<String, dynamic> booking,
  ) async {
    if (!mounted) return;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 12),
            const Text('Success!'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Parking spot unlocked successfully!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.local_parking,
                        color: Colors.blue,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          spotName,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(
                        Icons.access_time,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Started: ${_formatTimestamp(booking['startTime'])}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.attach_money,
                        color: Colors.grey,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Total: EGP ${(booking['totalPrice'] ?? 0.0).toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  String _formatTimestamp(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';

    try {
      DateTime dateTime;
      if (timestamp is Timestamp) {
        dateTime = timestamp.toDate();
      } else if (timestamp is String) {
        dateTime = DateTime.parse(timestamp);
      } else {
        return 'Unknown';
      }

      final now = DateTime.now();
      final difference = now.difference(dateTime);

      if (difference.inMinutes < 60) {
        return '${difference.inMinutes} min ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } catch (e) {
      return 'Unknown';
    }
  }

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}
