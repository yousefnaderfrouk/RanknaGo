import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ManageBookingsScreen extends StatefulWidget {
  const ManageBookingsScreen({super.key});

  @override
  State<ManageBookingsScreen> createState() => _ManageBookingsScreenState();
}

class _ManageBookingsScreenState extends State<ManageBookingsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  String _searchQuery = '';
  String _filterStatus = 'All'; // All, Active, Completed, Cancelled
  bool _isLoading = true;
  List<Map<String, dynamic>> _bookings = [];
  List<Map<String, dynamic>> _availableSpots = [];
  List<Map<String, dynamic>> _availableUsers = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      // Load bookings
      final bookingsSnapshot = await _firestore
          .collection('reservations')
          .get();
      final List<Map<String, dynamic>> bookings = [];

      // Collect unique user IDs and spot IDs for batch loading
      final Set<String> userIds = {};
      final Set<String> spotIds = {};

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();
        if (data['userId'] != null) {
          userIds.add(data['userId']);
        }
        if (data['spotId'] != null) {
          spotIds.add(data['spotId']);
        }
      }

      // Batch load users
      final Map<String, Map<String, dynamic>> usersMap = {};
      for (var userId in userIds) {
        try {
          final userDoc = await _firestore
              .collection('users')
              .doc(userId)
              .get();
          if (userDoc.exists) {
            usersMap[userId] = userDoc.data() ?? {};
          }
        } catch (e) {
          // Skip if user can't be read
        }
      }

      // Batch load spots
      final Map<String, Map<String, dynamic>> spotsMap = {};
      for (var spotId in spotIds) {
        try {
          final spotDoc = await _firestore
              .collection('parking_spots')
              .doc(spotId)
              .get();
          if (spotDoc.exists) {
            spotsMap[spotId] = spotDoc.data() ?? {};
          }
        } catch (e) {
          // Skip if spot can't be read
        }
      }

      for (var doc in bookingsSnapshot.docs) {
        final data = doc.data();

        // Get user info from map
        final userData = usersMap[data['userId']] ?? {};

        // Get spot info from map
        final spotData = spotsMap[data['spotId']] ?? {};

        final startTime = (data['startTime'] as Timestamp?)?.toDate();
        final endTime = (data['endTime'] as Timestamp?)?.toDate();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        bookings.add({
          'id': doc.id,
          'userId': data['userId'],
          'spotId': data['spotId'],
          'userName': userData['name'] ?? userData['displayName'] ?? 'Unknown',
          'userEmail': userData['email'] ?? '',
          'spotName': spotData['name'] ?? 'Unknown',
          'spotAddress': spotData['address'] ?? '',
          'date': startTime != null
              ? DateFormat('yyyy-MM-dd').format(startTime)
              : 'N/A',
          'startTime': startTime != null
              ? DateFormat('hh:mm a').format(startTime)
              : 'N/A',
          'endTime': endTime != null
              ? DateFormat('hh:mm a').format(endTime)
              : 'N/A',
          'duration': data['duration'] ?? 'N/A',
          'price': (data['price'] ?? 0.0).toDouble(),
          'status': data['status'] ?? 'active',
          'createdAt': createdAt != null
              ? DateFormat('yyyy-MM-dd HH:mm').format(createdAt)
              : 'N/A',
        });
      }

      // Load all parking spots (not just active ones)
      final spotsSnapshot = await _firestore.collection('parking_spots').get();
      _availableSpots = spotsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'name': data['name'] ?? '',
          'address': data['address'] ?? '',
          'pricePerHour': (data['pricePerHour'] ?? 0.0).toDouble(),
          'availableSpots': data['availableSpots'] ?? 0,
        };
      }).toList();

      // Load all users (with limit for admin access)
      // Note: Firestore rules allow list with limit <= 1 for non-admins, but admins can list all
      // We'll try to get all users, and if it fails, we'll collect unique user IDs from bookings
      try {
        final usersSnapshot = await _firestore.collection('users').get();
        _availableUsers = usersSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': doc.id,
            'name': data['name'] ?? data['displayName'] ?? 'Unknown',
            'email': data['email'] ?? '',
          };
        }).toList();
      } catch (e) {
        // If listing all users fails, collect unique user IDs from bookings
        final Set<String> userIds = {};
        for (var booking in bookings) {
          if (booking['userId'] != null) {
            userIds.add(booking['userId']);
          }
        }

        // Load users individually
        _availableUsers = [];
        for (var userId in userIds) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();
            if (userDoc.exists) {
              final data = userDoc.data();
              _availableUsers.add({
                'id': userDoc.id,
                'name': data?['name'] ?? data?['displayName'] ?? 'Unknown',
                'email': data?['email'] ?? '',
              });
            }
          } catch (e) {
            // Skip if user doc can't be read
          }
        }
      }

      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading bookings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    return _bookings.where((booking) {
      final matchesSearch =
          booking['userName'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          booking['spotName'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          booking['id'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesStatus =
          _filterStatus == 'All' ||
          booking['status'].toString().toLowerCase() ==
              _filterStatus.toLowerCase();

      return matchesSearch && matchesStatus;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Manage Bookings',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: _showCreateBookingDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search and Filter
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Column(
              children: [
                // Search Bar
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: const InputDecoration(
                      hintText: 'Search bookings...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF1E88E5)),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Filter Chips
                Row(
                  children: [
                    _buildFilterChip('All'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Active'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed'),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled'),
                  ],
                ),
              ],
            ),
          ),

          // Bookings List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredBookings.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.book_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No bookings found',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: _filteredBookings.length,
                    itemBuilder: (context, index) {
                      return _buildBookingCard(_filteredBookings[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showCreateBookingDialog,
        backgroundColor: const Color(0xFF1E88E5),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Booking'),
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    final isSelected = _filterStatus == label;
    return GestureDetector(
      onTap: () {
        setState(() {
          _filterStatus = label;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF1E88E5) : Colors.grey[200],
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: isSelected ? Colors.white : Colors.grey[700],
          ),
        ),
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final statusColor = booking['status'] == 'active'
        ? Colors.green
        : booking['status'] == 'completed'
        ? Colors.blue
        : Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF1E88E5),
                            const Color(0xFF1976D2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Center(
                        child: Text(
                          booking['userName'].toString()[0].toUpperCase(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  booking['id'],
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF212121),
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  booking['status'].toString().toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: statusColor[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            booking['userName'],
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 16),

                // Parking Details
                Row(
                  children: [
                    const Icon(
                      Icons.local_parking_rounded,
                      size: 18,
                      color: Color(0xFF1E88E5),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            booking['spotName'],
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF212121),
                            ),
                          ),
                          Text(
                            booking['spotAddress'],
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Time & Duration
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.calendar_today_rounded,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  booking['date'],
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(
                                  Icons.access_time_rounded,
                                  size: 14,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${booking['startTime']} - ${booking['endTime']}',
                                  style: const TextStyle(fontSize: 12),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          children: [
                            const Text(
                              'Price',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'EGP ${booking['price']}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showCreateBookingDialog() {
    Map<String, dynamic>? selectedUser;
    Map<String, dynamic>? selectedSpot;
    DateTime selectedDate = DateTime.now();
    TimeOfDay startTime = TimeOfDay.now();
    int duration = 2;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              const Icon(Icons.add_circle_rounded, color: Color(0xFF1E88E5)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Create Manual Booking',
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Select User
                  const Text(
                    'Select User',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedUser,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Choose user',
                        prefixIcon: Icon(Icons.person_search_rounded),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return _availableUsers.map<Widget>((user) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              user['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList();
                      },
                      items: _availableUsers.map((user) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: user,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                user['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (user['email'] != null &&
                                  user['email'].toString().isNotEmpty)
                                Text(
                                  user['email'],
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: Colors.grey[600],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedUser = value;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Select Parking Spot
                  const Text(
                    'Select Parking Spot',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey[300]!),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonFormField<Map<String, dynamic>>(
                      value: selectedSpot,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        hintText: 'Choose parking spot',
                        prefixIcon: Icon(Icons.local_parking_rounded),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      selectedItemBuilder: (BuildContext context) {
                        return _availableSpots.map<Widget>((spot) {
                          return Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              spot['name'] ?? 'Unknown',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList();
                      },
                      items: _availableSpots.map((spot) {
                        return DropdownMenuItem<Map<String, dynamic>>(
                          value: spot,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                spot['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${spot['address'] ?? ''} - EGP ${spot['pricePerHour']?.toStringAsFixed(0) ?? '0'}/hr',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey[600],
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (value) {
                        setDialogState(() {
                          selectedSpot = value;
                        });
                      },
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Date Selection
                  const Text(
                    'Booking Date',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: selectedDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(const Duration(days: 30)),
                      );
                      if (date != null) {
                        setDialogState(() {
                          selectedDate = date;
                        });
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.calendar_today_rounded,
                            color: Color(0xFF1E88E5),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                            style: const TextStyle(fontSize: 15),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Duration Selection
                  const Text(
                    'Duration (hours)',
                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [1, 2, 3, 4, 6, 8].map((hour) {
                      final isSelected = duration == hour;
                      return GestureDetector(
                        onTap: () {
                          setDialogState(() {
                            duration = hour;
                          });
                        },
                        child: Container(
                          width: 50,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? const Color(0xFF1E88E5)
                                : Colors.grey[200],
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '$hour',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey[700],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Price Preview
                  if (selectedSpot != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E88E5).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Flexible(
                            child: Text(
                              'Total Price:',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              'EGP ${(selectedSpot!['pricePerHour'] * duration).toStringAsFixed(0)}',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E88E5),
                              ),
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.end,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (selectedUser == null || selectedSpot == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Please select user and parking spot'),
                      backgroundColor: Colors.red,
                    ),
                  );
                  return;
                }

                try {
                  final startDateTime = DateTime(
                    selectedDate.year,
                    selectedDate.month,
                    selectedDate.day,
                    startTime.hour,
                    startTime.minute,
                  );
                  final endDateTime = startDateTime.add(
                    Duration(hours: duration),
                  );

                  final totalPrice = selectedSpot!['pricePerHour'] * duration;

                  final bookingData = {
                    'userId': selectedUser!['id'],
                    'spotId': selectedSpot!['id'],
                    'spotName': selectedSpot!['name'],
                    'startTime': Timestamp.fromDate(startDateTime),
                    'endTime': Timestamp.fromDate(endDateTime),
                    'duration': '$duration hours',
                    'price': totalPrice,
                    'totalPrice': totalPrice,
                    'status': 'active',
                    'createdBy': 'admin',
                    'createdAt': FieldValue.serverTimestamp(),
                    'updatedAt': FieldValue.serverTimestamp(),
                  };

                  final docRef = await _firestore
                      .collection('reservations')
                      .add(bookingData);

                  // Update available spots
                  await _firestore
                      .collection('parking_spots')
                      .doc(selectedSpot!['id'])
                      .update({
                        'availableSpots': FieldValue.increment(-1),
                        'updatedAt': FieldValue.serverTimestamp(),
                      });

                  final newBooking = {
                    'id': docRef.id,
                    'userId': selectedUser!['id'],
                    'spotId': selectedSpot!['id'],
                    'userName': selectedUser!['name'],
                    'userEmail': selectedUser!['email'],
                    'spotName': selectedSpot!['name'],
                    'spotAddress': selectedSpot!['address'],
                    'date': DateFormat('yyyy-MM-dd').format(startDateTime),
                    'startTime': DateFormat('hh:mm a').format(startDateTime),
                    'endTime': DateFormat('hh:mm a').format(endDateTime),
                    'duration': '$duration hours',
                    'price': selectedSpot!['pricePerHour'] * duration,
                    'status': 'active',
                    'createdAt': DateFormat(
                      'yyyy-MM-dd HH:mm',
                    ).format(DateTime.now()),
                  };

                  setState(() {
                    _bookings.insert(0, newBooking);
                  });

                  Navigator.pop(context);

                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Row(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              color: Colors.white,
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Text('Booking created successfully!'),
                            ),
                          ],
                        ),
                        backgroundColor: Colors.green[400],
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Create Booking'),
            ),
          ],
        ),
      ),
    );
  }
}
