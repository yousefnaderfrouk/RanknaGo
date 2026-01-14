import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class QRCodeScannerScreen extends StatefulWidget {
  const QRCodeScannerScreen({super.key});

  @override
  State<QRCodeScannerScreen> createState() => _QRCodeScannerScreenState();
}

class _QRCodeScannerScreenState extends State<QRCodeScannerScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final MobileScannerController _controller = MobileScannerController();
  bool _isProcessing = false;
  Map<String, dynamic>? _scannedSpot;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _handleQRCode(String qrCode) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      // Find parking spot by QR code
      final spotsSnapshot = await _firestore
          .collection('parking_spots')
          .where('qrCode', isEqualTo: qrCode)
          .limit(1)
          .get();

      // If not found by qrCode, try by document ID
      DocumentSnapshot? spotDoc;
      if (spotsSnapshot.docs.isEmpty) {
        try {
          spotDoc = await _firestore
              .collection('parking_spots')
              .doc(qrCode)
              .get();
        } catch (e) {
          // Document doesn't exist
        }
      } else {
        spotDoc = spotsSnapshot.docs.first;
      }

      if (spotDoc != null && spotDoc.exists) {
        final data = spotDoc.data() as Map<String, dynamic>;

        setState(() {
          _scannedSpot = {
            'id': spotDoc!.id,
            'name': data['name'] ?? 'Unknown',
            'address': data['address'] ?? '',
            'pricePerHour': (data['pricePerHour'] ?? 0.0).toDouble(),
            'availableSpots': data['availableSpots'] ?? 0,
            'totalSpots': data['totalSpots'] ?? 0,
            'isActive': data['isActive'] ?? true,
          };
        });

        // Stop scanner
        await _controller.stop();

        // Show result dialog
        _showSpotDetailsDialog();
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Parking spot not found')),
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
        setState(() => _isProcessing = false);
      }
    } catch (e) {
      setState(() => _isProcessing = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showSpotDetailsDialog() {
    if (_scannedSpot == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.local_parking_rounded, color: Color(0xFF1E88E5)),
            SizedBox(width: 12),
            Text('Parking Spot Found'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Spot Name
              Text(
                _scannedSpot!['name'],
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 8),
              // Address
              Row(
                children: [
                  Icon(Icons.location_on, size: 16, color: Colors.grey[600]),
                  const SizedBox(width: 4),
                  Expanded(
                    child: Text(
                      _scannedSpot!['address'],
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 16),
              // Price
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Price per hour:',
                    style: TextStyle(fontSize: 14, color: Color(0xFF212121)),
                  ),
                  Text(
                    'EGP ${_scannedSpot!['pricePerHour'].toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1E88E5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Availability
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Available spots:',
                    style: TextStyle(fontSize: 14, color: Color(0xFF212121)),
                  ),
                  Text(
                    '${_scannedSpot!['availableSpots']} / ${_scannedSpot!['totalSpots']}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: _scannedSpot!['availableSpots'] > 0
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Status
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Status:',
                    style: TextStyle(fontSize: 14, color: Color(0xFF212121)),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _scannedSpot!['isActive']
                          ? Colors.green[50]
                          : Colors.orange[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _scannedSpot!['isActive']
                            ? Colors.green[200]!
                            : Colors.orange[200]!,
                      ),
                    ),
                    child: Text(
                      _scannedSpot!['isActive'] ? 'Active' : 'Inactive',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _scannedSpot!['isActive']
                            ? Colors.green[700]
                            : Colors.orange[700],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              Navigator.pop(context); // Close scanner
            },
            child: const Text('Close'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close dialog
              // Restart scanner
              _controller.start();
              setState(() {
                _isProcessing = false;
                _scannedSpot = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: const Text('Scan Again'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Scan QR Code',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Stack(
        children: [
          // QR Scanner
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              final List<Barcode> barcodes = capture.barcodes;
              for (final barcode in barcodes) {
                if (barcode.rawValue != null) {
                  _handleQRCode(barcode.rawValue!);
                  break;
                }
              }
            },
          ),
          // Overlay
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.5),
                  Colors.transparent,
                  Colors.transparent,
                  Colors.black.withOpacity(0.5),
                ],
                stops: const [0.0, 0.3, 0.7, 1.0],
              ),
            ),
          ),
          // Instructions
          Positioned(
            bottom: 40,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.qr_code_scanner,
                    size: 48,
                    color: Color(0xFF1E88E5),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Position QR code within the frame',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF212121),
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'The system will automatically identify the parking spot',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  if (_isProcessing) ...[
                    const SizedBox(height: 16),
                    const CircularProgressIndicator(),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}














