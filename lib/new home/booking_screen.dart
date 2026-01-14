import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'directions_map_screen.dart';
import 'parking_details_screen.dart';
import '../theme_provider.dart';
import '../language_provider.dart';

class BookingScreen extends StatefulWidget {
  const BookingScreen({super.key});

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _completedBookings = [];
  List<Map<String, dynamic>> _canceledBookings = [];
  bool _isLoading = true;
  StreamSubscription<QuerySnapshot>? _bookingsSubscription;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this, initialIndex: 0);
    _loadBookings();
    _setupListener();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _bookingsSubscription?.cancel();
    super.dispose();
  }

  void _setupListener() {
    final user = _auth.currentUser;
    if (user != null) {
      // Listen to reservations changes in real-time
      // Don't use orderBy in listener to avoid index requirement
      // We'll sort manually in _processBookings
      _bookingsSubscription = _firestore
          .collection('reservations')
          .where('userId', isEqualTo: user.uid)
          .snapshots()
          .listen(
            (snapshot) {
              print('🔄 Real-time update: ${snapshot.docs.length} bookings');
              // Sort manually since we can't use orderBy without index
              final docs = snapshot.docs.toList();
              docs.sort((a, b) {
                final aData = a.data() as Map<String, dynamic>?;
                final bData = b.data() as Map<String, dynamic>?;
                final aTime = (aData?['startTime'] as Timestamp?)?.toDate();
                final bTime = (bData?['startTime'] as Timestamp?)?.toDate();
                if (aTime == null && bTime == null) return 0;
                if (aTime == null) return 1;
                if (bTime == null) return -1;
                return bTime.compareTo(aTime); // descending
              });
              _processBookings(docs);
            },
            onError: (error) {
              print('❌ Error in real-time listener: $error');
              // Try to reload bookings manually on error
              _loadBookings();
            },
          );
    }
  }

  Future<void> _loadBookings() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
        return;
      }

      // Try to get bookings with orderBy, fallback to without if index is missing
      QuerySnapshot bookingsSnapshot;
      try {
        bookingsSnapshot = await _firestore
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .orderBy('startTime', descending: true)
            .get();
      } catch (e) {
        // If orderBy fails (missing index), try without orderBy
        print('⚠️ OrderBy failed, trying without orderBy: $e');
        bookingsSnapshot = await _firestore
            .collection('reservations')
            .where('userId', isEqualTo: user.uid)
            .get();

        // Sort manually
        final docs = bookingsSnapshot.docs.toList();
        docs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = (aData?['startTime'] as Timestamp?)?.toDate();
          final bTime = (bData?['startTime'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
        // Use sorted docs
        bookingsSnapshot = bookingsSnapshot;
      }

      // Get sorted docs list
      final sortedDocs = bookingsSnapshot.docs.toList();
      if (sortedDocs.length > 1) {
        sortedDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>?;
          final bData = b.data() as Map<String, dynamic>?;
          final aTime = (aData?['startTime'] as Timestamp?)?.toDate();
          final bTime = (bData?['startTime'] as Timestamp?)?.toDate();
          if (aTime == null && bTime == null) return 0;
          if (aTime == null) return 1;
          if (bTime == null) return -1;
          return bTime.compareTo(aTime);
        });
      }

      print('✅ Loaded ${sortedDocs.length} bookings');

      _processBookings(sortedDocs);
    } catch (e) {
      print('❌ Error loading bookings: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _processBookings(List<QueryDocumentSnapshot> sortedDocs) async {
    try {
      final now = DateTime.now();

      final List<Map<String, dynamic>> completedBookings = [];
      final List<Map<String, dynamic>> canceledBookings = [];

      for (var doc in sortedDocs) {
        final data = doc.data() as Map<String, dynamic>?;
        if (data == null) continue;

        final bookingId = doc.id;

        // Get parking spot details
        final spotId = data['spotId'] as String?;
        Map<String, dynamic>? spotData;
        if (spotId != null) {
          try {
            final spotDoc = await _firestore
                .collection('parking_spots')
                .doc(spotId)
                .get();
            spotData = spotDoc.data();
          } catch (e) {
            // Error loading spot
          }
        }

        final status = data['status'] as String? ?? 'active';
        final startTime = (data['startTime'] as Timestamp?)?.toDate();
        final endTime = (data['endTime'] as Timestamp?)?.toDate();

        // Debug: Log status for troubleshooting
        if (status == 'full' ||
            status == 'unavailable' ||
            status == 'cancelled' ||
            status == 'canceled') {
          print('📋 Booking status: $status (bookingId: $bookingId)');
        }

        final bookingData = {
          'id': bookingId,
          'userId': data['userId'], // Add userId for Firestore security rules
          'parkingName':
              spotData?['name'] ?? data['spotName'] ?? 'Parking Spot',
          'address':
              spotData?['address'] ?? data['spotAddress'] ?? 'Unknown address',
          'date': startTime ?? now,
          'startTime': startTime,
          'endTime': endTime,
          'duration': data['duration'] ?? '1 hour',
          'amount': ((data['price'] ?? data['totalPrice'] ?? 0.0) as num)
              .toDouble(),
          'totalPrice': ((data['totalPrice'] ?? data['price'] ?? 0.0) as num)
              .toDouble(),
          'pricePerHour':
              ((data['pricePerHour'] ?? spotData?['pricePerHour'] ?? 0.0)
                      as num)
                  .toDouble(),
          'status': status,
          'spotId': spotId,
          'location': spotData?['location'],
          'maxPower':
              spotData?['maxChargerPower'] ?? spotData?['evChargingPower'] ?? 0,
          'hasEVCharging': spotData?['hasEVCharging'] ?? false,
          // Add cancellation/completion data if available
          'hoursSpent': data['hoursSpent'] != null
              ? (data['hoursSpent'] as num).toDouble()
              : null,
          'chargeAmount': data['chargeAmount'] != null
              ? (data['chargeAmount'] as num).toDouble()
              : null,
          'additionalCharge': data['additionalCharge'] != null
              ? (data['additionalCharge'] as num).toDouble()
              : null,
        };

        // Categorize bookings based on status
        // Include 'full' status in canceled bookings (parking spots that are full/unavailable)
        if (status == 'cancelled' ||
            status == 'canceled' ||
            status == 'full' ||
            status == 'unavailable') {
          canceledBookings.add(bookingData);
        } else if (status == 'completed') {
          completedBookings.add(bookingData);
        } else {
          // All active bookings go to completed
          completedBookings.add(bookingData);
        }
      }

      if (mounted) {
        setState(() {
          _completedBookings = completedBookings;
          _canceledBookings = canceledBookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
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
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: const BoxDecoration(
                color: Color(0xFF1E88E5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.event_note_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.translate('My Booking'),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF212121),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.search_rounded,
              color: isDark ? Colors.white : const Color(0xFF212121),
              size: 26,
            ),
            onPressed: _showSearchDialog,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            color: theme.scaffoldBackgroundColor,
            child: TabBar(
              controller: _tabController,
              labelColor: const Color(0xFF1E88E5),
              unselectedLabelColor: isDark
                  ? Colors.grey[500]
                  : Colors.grey[500],
              labelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
              indicatorColor: const Color(0xFF1E88E5),
              indicatorWeight: 3,
              tabs: [
                Tab(text: context.translate('Completed')),
                Tab(text: context.translate('Canceled')),
              ],
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: const Color(0xFF1E88E5)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildBookingList(_completedBookings, 'completed', isDark),
                _buildBookingList(_canceledBookings, 'canceled', isDark),
              ],
            ),
    );
  }

  Widget _buildBookingList(
    List<Map<String, dynamic>> bookings,
    String type,
    bool isDark,
  ) {
    if (bookings.isEmpty) {
      return _buildEmptyState(type, isDark);
    }

    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: const Color(0xFF1E88E5),
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(bookings[index], type, isDark);
        },
      ),
    );
  }

  Widget _buildEmptyState(String type, bool isDark) {
    String message;
    IconData icon;
    switch (type) {
      case 'completed':
        message = context.translate('No completed bookings');
        icon = Icons.check_circle_outline_rounded;
        break;
      case 'canceled':
        message = context.translate('No canceled bookings');
        icon = Icons.cancel_outlined;
        break;
      default:
        message = context.translate('No bookings');
        icon = Icons.event_note_rounded;
    }

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingCard(
    Map<String, dynamic> booking,
    String type,
    bool isDark,
  ) {
    final parkingName = booking['parkingName'] ?? 'Parking Spot';
    final address = booking['address'] ?? 'Unknown address';
    final date = booking['date'] as DateTime? ?? DateTime.now();
    final startTime = booking['startTime'] as DateTime?;
    final endTime = booking['endTime'] as DateTime?;
    final maxPower = booking['maxPower'] ?? 0;

    // Calculate actual duration and amount based on booking type
    String durationText;
    double displayAmount;

    // Get hoursSpent for both completed and canceled bookings
    final hoursSpent = booking['hoursSpent'] as double?;

    if (type == 'completed' || type == 'canceled') {
      // For completed/canceled bookings, show actual time spent

      if (hoursSpent != null) {
        // Use the stored hoursSpent value
        if (hoursSpent < 1.0) {
          final minutes = (hoursSpent * 60).round();
          durationText = '$minutes min${minutes > 1 ? 's' : ''}';
        } else if (hoursSpent < 24.0) {
          final hours = hoursSpent.floor();
          final minutes = ((hoursSpent - hours) * 60).round();
          if (minutes == 0) {
            durationText = '$hours hour${hours > 1 ? 's' : ''}';
          } else {
            durationText = '$hours h $minutes min';
          }
        } else {
          final days = (hoursSpent / 24).floor();
          final remainingHours = (hoursSpent - (days * 24)).floor();
          durationText = '$days day${days > 1 ? 's' : ''} $remainingHours h';
        }
      } else if (startTime != null && endTime != null) {
        // Calculate from start and end times
        final difference = endTime.difference(startTime);
        final hours = difference.inHours;
        final minutes = difference.inMinutes % 60;

        if (hours == 0) {
          durationText = '$minutes min${minutes > 1 ? 's' : ''}';
        } else if (hours < 24) {
          if (minutes == 0) {
            durationText = '$hours hour${hours > 1 ? 's' : ''}';
          } else {
            durationText = '$hours h $minutes min';
          }
        } else {
          final days = hours ~/ 24;
          final remainingHours = hours % 24;
          durationText = '$days day${days > 1 ? 's' : ''} $remainingHours h';
        }
      } else if (startTime != null) {
        // If no endTime, calculate from startTime to now
        final difference = DateTime.now().difference(startTime);
        final hours = difference.inHours;
        final minutes = difference.inMinutes % 60;

        if (hours == 0) {
          durationText = '$minutes min${minutes > 1 ? 's' : ''}';
        } else if (hours < 24) {
          if (minutes == 0) {
            durationText = '$hours hour${hours > 1 ? 's' : ''}';
          } else {
            durationText = '$hours h $minutes min';
          }
        } else {
          final days = hours ~/ 24;
          final remainingHours = hours % 24;
          durationText = '$days day${days > 1 ? 's' : ''} $remainingHours h';
        }
      } else {
        // Fallback to stored duration
        final duration = booking['duration'] ?? '1 hour';
        durationText = duration;
      }

      // For canceled bookings, show charge amount
      if (type == 'canceled') {
        displayAmount = (booking['chargeAmount'] ?? booking['amount'] ?? 0.0)
            .toDouble();
      } else {
        // For completed bookings, calculate actual amount based on time spent
        if (hoursSpent != null) {
          final pricePerHour = (booking['pricePerHour'] ?? 0.0).toDouble();
          displayAmount = pricePerHour * hoursSpent;
        } else if (startTime != null && endTime != null) {
          final difference = endTime.difference(startTime);
          final hours = difference.inMinutes / 60.0;
          final pricePerHour = (booking['pricePerHour'] ?? 0.0).toDouble();
          displayAmount = pricePerHour * hours;
        } else if (startTime != null) {
          // Calculate from startTime to now
          final difference = DateTime.now().difference(startTime);
          final hours = difference.inMinutes / 60.0;
          final pricePerHour = (booking['pricePerHour'] ?? 0.0).toDouble();
          displayAmount = pricePerHour * hours;
        } else {
          // Fallback to stored amount
          displayAmount = (booking['totalPrice'] ?? booking['amount'] ?? 0.0)
              .toDouble();
        }
      }
    } else {
      // For active bookings, show original duration and price
      final duration = booking['duration'] ?? '1 hour';
      durationText = duration;
      displayAmount = (booking['amount'] ?? 0.0).toDouble();
    }

    final dateStr = DateFormat('MMM dd, yyyy').format(date);
    final timeStr = startTime != null
        ? DateFormat('HH:mm a').format(startTime)
        : 'N/A';

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[900] : Colors.white,
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date, Time and Reminder Toggle
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dateStr,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF212121),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    timeStr,
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.grey[400] : Colors.grey[600],
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor(type).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: _getStatusColor(type), width: 1.5),
                ),
                child: Text(
                  _getStatusText(type),
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _getStatusColor(type),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Parking Name and Navigation
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      parkingName,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  _showDirections(booking);
                },
                child: Container(
                  width: 42,
                  height: 42,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E88E5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 22,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Details Grid
          Row(
            children: [
              Expanded(
                child: _buildDetailColumn(
                  icon: Icons.ev_station_rounded,
                  label: context.translate('Tesla (Plug)'),
                  iconColor: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  icon: Icons.bolt_rounded,
                  label: context.translate('Max power'),
                  value: '$maxPower kW',
                  iconColor: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  icon: Icons.access_time_rounded,
                  label: type == 'completed' || type == 'canceled'
                      ? context.translate('Parked For')
                      : context.translate('Duration'),
                  value: durationText,
                  iconColor: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                ),
              ),
              Expanded(
                child: _buildDetailColumn(
                  icon: Icons.attach_money_rounded,
                  label: type == 'canceled'
                      ? context.translate('Total Paid')
                      : type == 'completed'
                      ? context.translate('Total Paid')
                      : context.translate('Amount'),
                  value: 'EGP ${displayAmount.toStringAsFixed(2)}',
                  iconColor: isDark ? Colors.grey[400]! : Colors.grey[700]!,
                ),
              ),
            ],
          ),
          // Show additional charge for canceled bookings (if any)
          if (type == 'canceled' &&
              booking['additionalCharge'] != null &&
              (booking['additionalCharge'] as num).toDouble() > 0) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.add_circle_outline,
                    color: Colors.orange,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${context.translate('Extra:')} EGP ${((booking['additionalCharge'] as num).toDouble()).toStringAsFixed(2)}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.orange.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 18),
          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    if (type == 'completed') {
                      _cancelBooking(booking);
                    } else {
                      _viewBookingDetails(booking);
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF1E88E5),
                    side: const BorderSide(
                      color: Color(0xFF1E88E5),
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    type == 'completed'
                        ? context.translate('Cancel')
                        : context.translate('View'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    _viewBookingDetails(booking);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    context.translate('View'),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailColumn({
    required IconData icon,
    required String label,
    String? value,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Icon(icon, size: 24, color: iconColor),
        const SizedBox(height: 6),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 10, color: Colors.grey[600]),
        ),
        if (value != null) ...[
          const SizedBox(height: 4),
          Text(
            value,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Color(0xFF212121),
            ),
          ),
        ],
      ],
    );
  }

  Color _getStatusColor(String type) {
    switch (type) {
      case 'completed':
        return Colors.green;
      case 'canceled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  String _getStatusText(String type) {
    switch (type) {
      case 'completed':
        return context.translate('Completed');
      case 'canceled':
        return context.translate('Canceled');
      default:
        return 'Unknown';
    }
  }

  Future<void> _showDirections(Map<String, dynamic> booking) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userLocation = LatLng(position.latitude, position.longitude);

      // Handle location as either LatLng or Map
      LatLng destination;
      if (booking['location'] is LatLng) {
        destination = booking['location'] as LatLng;
      } else if (booking['location'] is Map) {
        final locationMap = booking['location'] as Map<String, dynamic>;
        destination = LatLng(
          (locationMap['lat'] ?? locationMap['latitude'] ?? 0.0).toDouble(),
          (locationMap['lng'] ?? locationMap['longitude'] ?? 0.0).toDouble(),
        );
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.translate('Location not available')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Get user avatar if available
      final user = _auth.currentUser;
      String? userAvatarUrl;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        userAvatarUrl = userDoc.data()?['photoURL'];
      }

      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DirectionsMapScreen(
              destination: destination,
              userLocation: userLocation,
              parkingName: booking['parkingName'] ?? 'Parking Spot',
              userAvatarUrl: userAvatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _viewBookingDetails(Map<String, dynamic> booking) {
    final spotId = booking['spotId'] as String?;
    if (spotId != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ParkingDetailsScreen(
            parking: {
              'id': spotId,
              'name': booking['parkingName'],
              'address': booking['address'],
              'location': booking['location'],
            },
          ),
        ),
      );
    }
  }

  Future<void> _cancelBooking(Map<String, dynamic> booking) async {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final user = _auth.currentUser;

    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.translate('Please log in to cancel bookings'),
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final bookingId = booking['id'] as String?;
    if (bookingId == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.translate('Invalid booking: Missing ID')),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    // Always verify ownership from Firestore directly to ensure accuracy
    // This is especially important for completed bookings which may have stale local data
    try {
      final bookingDoc = await _firestore
          .collection('reservations')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.translate('Booking not found')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bookingData = bookingDoc.data();
      final firestoreUserId = bookingData?['userId'] as String?;

      print('🔍 ===== OWNERSHIP VERIFICATION =====');
      print('🔍 Booking ID: $bookingId');
      print('🔍 Firestore booking userId: $firestoreUserId');
      print('🔍 Current user uid: ${user.uid}');
      print('🔍 Booking status: ${bookingData?['status']}');
      print('🔍 All booking keys: ${bookingData?.keys.toList()}');

      // If userId exists in Firestore and doesn't match, deny access
      if (firestoreUserId != null &&
          firestoreUserId.isNotEmpty &&
          firestoreUserId != user.uid) {
        print('❌ ===== OWNERSHIP VERIFICATION FAILED =====');
        print('❌ User does not own this booking');
        print('❌ Firestore userId: "$firestoreUserId"');
        print('❌ Current user uid: "${user.uid}"');
        print('❌ Match: ${firestoreUserId == user.uid}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.translate('You can only cancel your own bookings'),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // If userId is missing or matches, allow cancellation
      if (firestoreUserId == null || firestoreUserId.isEmpty) {
        print(
          '⚠️ Booking has no userId in Firestore - will add current user ID',
        );
        print('⚠️ This is allowed by security rules');
      } else {
        print('✅ Booking userId matches current user');
        print('✅ Ownership verified - proceeding with cancellation dialog');
      }
      print('🔍 ===== OWNERSHIP VERIFICATION PASSED =====');
    } catch (e) {
      print('⚠️ Error verifying booking ownership from Firestore: $e');
      // If we can't verify, show error and don't proceed
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${context.translate('Error verifying booking:')} ${e.toString()}',
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
      return;
    }

    // Calculate time spent
    final startTime = booking['startTime'] as DateTime?;
    final endTime = booking['endTime'] as DateTime?;
    final now = DateTime.now();

    // For completed bookings, use endTime if available
    final endDateTime = endTime ?? now;

    double hoursSpent = 0.0;
    if (startTime != null) {
      final difference = endDateTime.difference(startTime);
      hoursSpent = difference.inMinutes / 60.0;
    }

    // First hour is ALWAYS charged (non-refundable)
    // Minimum charge is 1 hour
    if (hoursSpent < 1.0) {
      hoursSpent = 1.0;
    }

    final pricePerHour = (booking['pricePerHour'] ?? booking['amount'] ?? 0.0)
        .toDouble();
    final totalPrice = (booking['totalPrice'] ?? booking['amount'] ?? 0.0)
        .toDouble();
    final chargeAmount = pricePerHour * hoursSpent;

    // Calculate additional charge only (no refund for first hour)
    final additionalCharge = chargeAmount > totalPrice
        ? chargeAmount - totalPrice
        : 0.0;

    // Refund is always 0 because first hour is non-refundable
    final refundAmount = 0.0;

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: isDark ? Colors.grey[900] : Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.red),
              const SizedBox(width: 12),
              Text(
                context.translate('Cancel Booking'),
                style: TextStyle(
                  color: isDark ? Colors.white : const Color(0xFF212121),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                booking['status'] == 'completed'
                    ? context.translate(
                        'This booking is already completed. Are you sure you want to cancel it?',
                      )
                    : context.translate(
                        'Are you sure you want to cancel this booking?',
                      ),
                style: TextStyle(
                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[800] : Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Time spent
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.translate('Time spent:'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        Text(
                          '${hoursSpent.toStringAsFixed(2)} ${context.translate('hours')}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Prepaid amount (non-refundable)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.translate('1st hour (paid):'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        Text(
                          'EGP ${totalPrice.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Total charge
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          context.translate('Total charge:'),
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                        Text(
                          'EGP ${chargeAmount.toStringAsFixed(2)}',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark ? Colors.white : Colors.black,
                          ),
                        ),
                      ],
                    ),
                    // Additional charge (if any)
                    if (additionalCharge > 0) ...[
                      const Divider(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            context.translate('Extra charge:'),
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                          ),
                          Text(
                            'EGP ${additionalCharge.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '⚠️ ${context.translate('Will be deducted from wallet')}',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.red.shade700,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ] else ...[
                      const Divider(height: 20),
                      Text(
                        '✅ ${context.translate('No additional charge')}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        context.translate(
                          'First hour already paid (non-refundable)',
                        ),
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                context.translate('No'),
                style: TextStyle(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                await _processCancellation(
                  bookingId,
                  booking['spotId'] as String?,
                  chargeAmount,
                  refundAmount,
                  hoursSpent,
                  additionalCharge,
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: Text(context.translate('Yes, Cancel')),
            ),
          ],
        ),
      );
    }
  }

  Future<void> _processCancellation(
    String bookingId,
    String? spotId,
    double chargeAmount,
    double refundAmount,
    double hoursSpent,
    double additionalCharge,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      // First, verify the booking exists and belongs to the user
      final bookingDoc = await _firestore
          .collection('reservations')
          .doc(bookingId)
          .get();

      if (!bookingDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(context.translate('Booking not found')),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bookingData = bookingDoc.data();
      String? bookingUserId = bookingData?['userId'] as String?;

      print('🔍 Booking userId: $bookingUserId');
      print('🔍 Current user uid: ${user.uid}');
      print('🔍 Booking status: ${bookingData?['status']}');
      print('🔍 Booking data keys: ${bookingData?.keys.toList()}');

      // Verify ownership
      // If userId exists and doesn't match, deny access
      if (bookingUserId != null &&
          bookingUserId.isNotEmpty &&
          bookingUserId != user.uid) {
        print('❌ User does not own this booking');
        print('❌ Booking userId: $bookingUserId');
        print('❌ Current user uid: ${user.uid}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                context.translate('You can only cancel your own bookings'),
              ),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // If userId is missing or empty, we need to verify the booking belongs to current user
      // by checking if it appears in their bookings list (loaded via userId query)
      // Since the booking appears in the user's list, it should belong to them
      if (bookingUserId == null || bookingUserId.isEmpty) {
        print('⚠️ Booking has no userId - will add current user ID');
        print(
          '⚠️ This booking appears in user\'s list, so ownership is assumed',
        );
      } else {
        print('✅ Booking userId matches current user');
      }

      print('✅ Ownership verified - proceeding with cancellation');

      // If userId is missing, add it first in a separate update
      // This ensures security rules can properly validate ownership
      // Use set with merge:true instead of update to avoid permission issues
      if (bookingUserId == null || bookingUserId.isEmpty) {
        print('⚠️ Booking has no userId - adding it first');
        try {
          // Use set with merge:true to add userId without triggering update rules
          await _firestore.collection('reservations').doc(bookingId).set({
            'userId': user.uid,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
          print('✅ userId added successfully');
          // Re-fetch booking to get updated userId
          final updatedBookingDoc = await _firestore
              .collection('reservations')
              .doc(bookingId)
              .get();
          final updatedBookingData = updatedBookingDoc.data();
          bookingUserId = updatedBookingData?['userId'] as String?;
          print('✅ Re-fetched bookingUserId: $bookingUserId');
        } catch (e) {
          print('❌ Error adding userId: $e');
          print('❌ Error type: ${e.runtimeType}');
          if (e is FirebaseException) {
            print('❌ Firebase error code: ${e.code}');
            print('❌ Firebase error message: ${e.message}');
          }
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Error updating booking ownership: ${e.toString()}',
                ),
                backgroundColor: Colors.red,
                duration: const Duration(seconds: 4),
              ),
            );
          }
          return;
        }
      }

      // Double-check: if userId exists, it must match current user (verified earlier)
      if (bookingUserId != null &&
          bookingUserId.isNotEmpty &&
          bookingUserId != user.uid) {
        print('❌ CRITICAL: userId mismatch detected in _processCancellation!');
        print('❌ This should not happen - ownership was verified earlier');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Security check failed. Please try again.'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        return;
      }

      // Get current wallet balance
      final walletDoc = await _firestore
          .collection('wallets')
          .doc(user.uid)
          .get();
      final currentBalance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();

      print('💰 ===== WALLET BALANCE CHECK =====');
      print('💰 Current balance: EGP $currentBalance');
      print('💰 Hours spent: ${hoursSpent.toStringAsFixed(2)}h');
      print('💰 Charge amount: EGP ${chargeAmount.toStringAsFixed(2)}');
      print('💰 Additional charge: EGP ${additionalCharge.toStringAsFixed(2)}');
      print(
        '💰 New balance will be: EGP ${(currentBalance - additionalCharge).toStringAsFixed(2)}',
      );

      // Use batch to ensure atomicity
      final batch = _firestore.batch();

      // Update booking status
      final bookingRef = _firestore.collection('reservations').doc(bookingId);

      // Prepare update data
      // Note: Don't include userId in update if it already exists and matches
      // Security rules check resource.data.userId (existing) for Case 1
      final updateData = <String, dynamic>{
        'status': 'cancelled',
        'cancelledAt': FieldValue.serverTimestamp(),
        'hoursSpent': hoursSpent,
        'chargeAmount': chargeAmount,
        'additionalCharge': additionalCharge > 0 ? additionalCharge : 0.0,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // userId is now guaranteed to exist and match (added above if missing)
      // Security rules will check resource.data.userId == request.auth.uid
      print(
        '✅ userId exists and matches - proceeding with cancellation update',
      );

      print('📝 Update data keys: ${updateData.keys.toList()}');
      print('📝 Booking userId: $bookingUserId');
      print('📝 Current user uid: ${user.uid}');
      print('🔒 ===== LOCKING PARKING SPOT =====');
      print('🔒 Booking status changed to: cancelled');
      print('🔒 Parking spot will be locked - QR unlock will be denied');

      // Use update (not set) to match security rules
      // Security rules are written for 'update' operation, not 'set'
      batch.update(bookingRef, updateData);

      // Update wallet balance - only deduct additional charge if any
      final walletRef = _firestore.collection('wallets').doc(user.uid);

      if (additionalCharge > 0) {
        print('💸 ===== DEDUCTING FROM WALLET =====');
        print(
          '💸 Deducting EGP ${additionalCharge.toStringAsFixed(2)} from wallet',
        );
        print('💸 Old balance: EGP ${currentBalance.toStringAsFixed(2)}');
        print(
          '💸 New balance: EGP ${(currentBalance - additionalCharge).toStringAsFixed(2)}',
        );

        // Deduct additional charge from wallet
        batch.set(walletRef, {
          'balance': currentBalance - additionalCharge,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));

        print('✅ Wallet update added to batch');
      } else {
        print(
          'ℹ️ No additional charge - wallet remains at EGP ${currentBalance.toStringAsFixed(2)}',
        );
        print('ℹ️ (First hour already paid, no extra time used)');
      }
      // If no additional charge, wallet remains the same (first hour already paid)

      // Add transaction only if there's additional charge
      if (additionalCharge > 0) {
        print('📝 ===== CREATING TRANSACTION RECORD =====');

        // Additional charge transaction
        final transactionRef = _firestore
            .collection('transactions')
            .doc(user.uid)
            .collection('user_transactions')
            .doc();
        batch.set(transactionRef, {
          'type': 'Additional Charge',
          'amount': -additionalCharge,
          'bookingId': bookingId,
          'description':
              'Extra charge for cancelled booking (${hoursSpent.toStringAsFixed(2)}h used, 1h prepaid)',
          'createdAt': FieldValue.serverTimestamp(),
        });

        print('✅ Transaction record added to batch');
        print(
          '📝 Transaction amount: -EGP ${additionalCharge.toStringAsFixed(2)}',
        );
      }

      // Add cancellation note transaction
      final noteTransactionRef = _firestore
          .collection('transactions')
          .doc(user.uid)
          .collection('user_transactions')
          .doc();
      batch.set(noteTransactionRef, {
        'type': 'Booking Cancelled',
        'amount': 0,
        'bookingId': bookingId,
        'description':
            'Cancelled booking: ${hoursSpent.toStringAsFixed(2)}h total (1h prepaid, ${additionalCharge > 0 ? '${(hoursSpent - 1.0).toStringAsFixed(2)}h extra' : 'no extra charge'})',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update available spots
      if (spotId != null) {
        final spotRef = _firestore.collection('parking_spots').doc(spotId);
        batch.update(spotRef, {
          'availableSpots': FieldValue.increment(1),
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }

      print('✅ Batch operations prepared, committing...');
      print('📦 Batch contains:');
      print('   - Booking update (status: cancelled)');
      if (additionalCharge > 0) {
        print('   - Wallet update (deduct: $additionalCharge)');
        print('   - Transaction creation');
      }
      print('   - Cancellation note transaction');
      if (spotId != null) {
        print('   - Parking spot update');
      }

      try {
        await batch.commit();
        print('✅ Batch committed successfully');
        print('🔒 ✅ ✅ ✅ PARKING SPOT LOCKED ✅ ✅ ✅');
        print('🔒 Booking cancelled - QR unlock access revoked');

        // Verify wallet balance was updated (only if there was an additional charge)
        if (additionalCharge > 0) {
          print('🔍 ===== VERIFYING WALLET UPDATE =====');
          final updatedWalletDoc = await _firestore
              .collection('wallets')
              .doc(user.uid)
              .get();
          final updatedBalance = (updatedWalletDoc.data()?['balance'] ?? 0.0)
              .toDouble();
          print(
            '🔍 Wallet balance after commit: EGP ${updatedBalance.toStringAsFixed(2)}',
          );
          print(
            '🔍 Expected balance: EGP ${(currentBalance - additionalCharge).toStringAsFixed(2)}',
          );

          if ((updatedBalance - (currentBalance - additionalCharge)).abs() <
              0.01) {
            print('✅ ✅ ✅ WALLET DEDUCTION CONFIRMED! ✅ ✅ ✅');
            print(
              '✅ EGP ${additionalCharge.toStringAsFixed(2)} was successfully deducted',
            );
          } else {
            print('⚠️ WARNING: Wallet balance mismatch!');
            print(
              '⚠️ Expected: ${(currentBalance - additionalCharge).toStringAsFixed(2)}, Got: ${updatedBalance.toStringAsFixed(2)}',
            );
          }
        }
      } catch (batchError) {
        print('❌ Batch commit failed: $batchError');
        print('❌ Batch error type: ${batchError.runtimeType}');
        rethrow; // Re-throw to be caught by outer catch block
      }

      // Reload bookings
      await _loadBookings();

      if (mounted) {
        // Switch to Canceled tab (index 1) after cancellation
        _tabController.animateTo(1);

        String message;
        Color backgroundColor;

        if (additionalCharge > 0) {
          message =
              'Booking cancelled. EGP ${additionalCharge.toStringAsFixed(2)} extra charge deducted from wallet.';
          backgroundColor = Colors.orange;
        } else {
          message = 'Booking cancelled successfully. (1st hour already paid)';
          backgroundColor = Colors.green;
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text(message)),
              ],
            ),
            backgroundColor: backgroundColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (e) {
      print('❌ Error in _processCancellation: $e');
      print('❌ Error type: ${e.runtimeType}');
      print('❌ Error toString: ${e.toString()}');

      if (mounted) {
        String errorMessage = 'Error cancelling booking';

        // Check for specific error types
        if (e is FirebaseException) {
          if (e.code == 'permission-denied') {
            errorMessage =
                'Permission denied. This booking may belong to another user. Please contact support if this is your booking.';
          } else if (e.code == 'not-found') {
            errorMessage = 'Booking not found. It may have been deleted.';
          } else {
            errorMessage =
                'Error cancelling booking: ${e.message ?? e.toString()}';
          }
        } else if (e.toString().contains('permission-denied') ||
            e.toString().contains('PERMISSION_DENIED')) {
          errorMessage =
              'Permission denied. This booking may belong to another user. Please contact support if this is your booking.';
        } else if (e.toString().contains('not-found') ||
            e.toString().contains('NOT_FOUND')) {
          errorMessage = 'Booking not found. It may have been deleted.';
        } else {
          errorMessage = 'Error cancelling booking: ${e.toString()}';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
          ),
        );
      }
    }
  }

  void _showSearchDialog() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: isDark ? Colors.grey[900] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.search_rounded, color: Color(0xFF1E88E5)),
            const SizedBox(width: 12),
            Text(
              context.translate('Search Bookings'),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF212121),
              ),
            ),
          ],
        ),
        content: TextField(
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: 'Search...',
            hintStyle: TextStyle(
              color: isDark ? Colors.grey[500] : Colors.grey[400],
            ),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Color(0xFF1E88E5), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(
                color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              context.translate('Cancel'),
              style: TextStyle(
                color: isDark ? Colors.grey[400] : Colors.grey[600],
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
            ),
            child: Text(context.translate('Search')),
          ),
        ],
      ),
    );
  }
}
