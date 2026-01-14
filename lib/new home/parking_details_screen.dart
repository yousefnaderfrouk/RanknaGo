import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'booking_screen.dart';
import 'directions_map_screen.dart';
import '../theme_provider.dart';
import '../language_provider.dart';

class ParkingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> parking;

  const ParkingDetailsScreen({super.key, required this.parking});

  @override
  State<ParkingDetailsScreen> createState() => _ParkingDetailsScreenState();

  // Helper method to ensure parking data has an ID
  static Map<String, dynamic> ensureId(Map<String, dynamic> parking) {
    if (!parking.containsKey('id') || parking['id'] == null) {
      // Try to get ID from other fields
      final id = parking['spotId'] ?? parking['_id'];
      if (id != null) {
        return {...parking, 'id': id.toString()};
      }
    }
    return parking;
  }
}

class _ParkingDetailsScreenState extends State<ParkingDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  bool _isBookmarked = false;
  Map<String, dynamic>? _parkingData;
  List<Map<String, dynamic>> _chargers = [];
  List<Map<String, dynamic>> _checkIns = [];
  List<Map<String, dynamic>> _reviews = [];
  bool _isLoading = true;
  String? _distance;
  String? _duration;
  bool _showBookmarkNotification = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);

    // Debug: Log incoming parking data
    print('🔍 === ParkingDetailsScreen initState ===');
    print('🔍 Incoming widget.parking keys: ${widget.parking.keys.toList()}');
    print('🔍 Incoming widget.parking id: ${widget.parking['id']}');
    print('🔍 Incoming widget.parking spotId: ${widget.parking['spotId']}');
    print('🔍 Incoming widget.parking _id: ${widget.parking['_id']}');

    _loadParkingData();
    _checkBookmarkStatus();
    _calculateDistance();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadParkingData() async {
    try {
      // Debug: Print all keys and data
      print('🔍 Parking data keys: ${widget.parking.keys.toList()}');

      // Try to get spotId from different possible fields
      String? spotId;

      // First, try 'id' field
      if (widget.parking.containsKey('id')) {
        final idValue = widget.parking['id'];
        if (idValue != null) {
          spotId = idValue.toString();
        }
      }

      // If not found, try 'spotId' field
      if ((spotId == null || spotId.isEmpty) &&
          widget.parking.containsKey('spotId')) {
        final spotIdValue = widget.parking['spotId'];
        if (spotIdValue != null) {
          spotId = spotIdValue.toString();
        }
      }

      // If still not found, try '_id' field
      if ((spotId == null || spotId.isEmpty) &&
          widget.parking.containsKey('_id')) {
        final idValue = widget.parking['_id'];
        if (idValue != null) {
          spotId = idValue.toString();
        }
      }

      if (spotId == null || spotId.isEmpty) {
        print('❌ Parking data keys: ${widget.parking.keys.toList()}');
        print(
          '❌ Parking data sample: ${widget.parking.toString().substring(0, widget.parking.toString().length > 300 ? 300 : widget.parking.toString().length)}',
        );
        if (mounted) {
          setState(() {
            _isLoading = false;
          });

          // Show error and go back
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Invalid parking spot: Missing ID'),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 3),
            ),
          );

          // Navigate back after showing error
          Future.delayed(const Duration(seconds: 1), () {
            if (mounted) {
              Navigator.pop(context);
            }
          });
        }
        return;
      }

      print('✅ Found spotId: $spotId');

      // Load parking spot data
      final spotDoc = await _firestore
          .collection('parking_spots')
          .doc(spotId)
          .get();

      if (spotDoc.exists) {
        final data = spotDoc.data()!;

        // IMPORTANT: Add 'id' field to data because Firestore doesn't include doc.id in data()
        final parkingDataWithId = {
          ...data,
          'id': spotId,
          'spotId': spotId, // Also add spotId for compatibility
          '_id': spotId, // Also add _id for compatibility
        };

        // Load chargers, check-ins, and reviews in parallel
        final results = await Future.wait([
          _loadChargers(spotId),
          _loadCheckIns(spotId),
          _loadReviews(spotId),
        ]);

        if (mounted) {
          setState(() {
            _parkingData = parkingDataWithId;
            _chargers = results[0];
            _checkIns = results[1];
            _reviews = results[2];
            _isLoading = false;
          });
        }

        print('✅ Saved _parkingData with id: $spotId');
        print('✅ _parkingData keys after save: ${_parkingData!.keys.toList()}');
        print('✅ _parkingData[\'id\']: ${_parkingData!['id']}');
      } else {
        print('❌ Parking spot not found in Firestore: $spotId');
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking spot not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      print('❌ Error loading parking data: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parking spot: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<List<Map<String, dynamic>>> _loadChargers(String spotId) async {
    try {
      final chargersSnapshot = await _firestore
          .collection('parking_spots')
          .doc(spotId)
          .collection('chargers')
          .orderBy('number')
          .get();

      return chargersSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'number': data['number'] ?? 0,
          'type': data['type'] ?? 'Type 2',
          'power': data['power'] ?? '22 kW',
          'available': data['available'] ?? true,
          'status': data['status'] ?? 'available',
        };
      }).toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadCheckIns(String spotId) async {
    try {
      final checkInsSnapshot = await _firestore
          .collection('parking_spots')
          .doc(spotId)
          .collection('check_ins')
          .orderBy('checkInTime', descending: true)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> checkIns = [];

      for (var doc in checkInsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId != null) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();

            final userData = userDoc.data();
            final checkInTime = data['checkInTime'] as Timestamp?;

            checkIns.add({
              'userId': userId,
              'userName': userData?['name'] ?? 'Unknown User',
              'userPhoto': userData?['photoURL'],
              'timeAgo': _formatTimeAgo(checkInTime),
            });
          } catch (e) {
            // Skip if user not found
          }
        }
      }

      return checkIns;
    } catch (e) {
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> _loadReviews(String spotId) async {
    try {
      final reviewsSnapshot = await _firestore
          .collection('parking_spots')
          .doc(spotId)
          .collection('reviews')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .get();

      final List<Map<String, dynamic>> reviews = [];

      for (var doc in reviewsSnapshot.docs) {
        final data = doc.data();
        final userId = data['userId'] as String?;

        if (userId != null) {
          try {
            final userDoc = await _firestore
                .collection('users')
                .doc(userId)
                .get();

            final userData = userDoc.data();
            final createdAt = data['createdAt'] as Timestamp?;

            reviews.add({
              'userId': userId,
              'userName': userData?['name'] ?? 'Unknown User',
              'userPhoto': userData?['photoURL'],
              'rating': (data['rating'] ?? 0).toDouble(),
              'comment': data['comment'] ?? '',
              'timeAgo': _formatTimeAgo(createdAt),
            });
          } catch (e) {
            // Skip if user not found
          }
        }
      }

      return reviews;
    } catch (e) {
      return [];
    }
  }

  String _formatTimeAgo(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown';

    final now = DateTime.now();
    final time = timestamp.toDate();
    final difference = now.difference(time);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  Future<void> _checkBookmarkStatus() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final spotId =
            widget.parking['id'] as String? ??
            widget.parking['spotId'] as String? ??
            widget.parking['_id'] as String?;

        if (spotId == null || spotId.isEmpty) return;

        final bookmarkDoc = await _firestore
            .collection('saved_spots')
            .doc('${user.uid}_$spotId')
            .get();

        if (mounted) {
          setState(() {
            _isBookmarked = bookmarkDoc.exists;
          });
        }
      }
    } catch (e) {
      // Error checking bookmark
    }
  }

  Future<void> _calculateDistance() async {
    try {
      final position = await Geolocator.getCurrentPosition();

      // Handle location as either LatLng or Map
      LatLng parkingLocation;
      if (widget.parking['location'] is LatLng) {
        parkingLocation = widget.parking['location'] as LatLng;
      } else if (widget.parking['location'] is Map) {
        final locationMap = widget.parking['location'] as Map<String, dynamic>;
        parkingLocation = LatLng(
          (locationMap['lat'] ?? locationMap['latitude'] ?? 0.0).toDouble(),
          (locationMap['lng'] ?? locationMap['longitude'] ?? 0.0).toDouble(),
        );
      } else {
        if (mounted) {
          setState(() {
            _distance = 'N/A';
          });
        }
        return;
      }

      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        parkingLocation.latitude,
        parkingLocation.longitude,
      );

      // Calculate duration based on distance (average speed: 50 km/h in city)
      final distanceInKm = distance / 1000;
      final durationInMinutes = (distanceInKm / 50 * 60).round();

      if (mounted) {
        setState(() {
          if (distance < 1000) {
            _distance = '${distance.toStringAsFixed(0)} m';
          } else {
            _distance = '${distanceInKm.toStringAsFixed(1)} km';
          }

          // Format duration
          if (durationInMinutes < 1) {
            _duration = '< 1 min';
          } else if (durationInMinutes < 60) {
            _duration = '$durationInMinutes mins';
          } else {
            final hours = durationInMinutes ~/ 60;
            final mins = durationInMinutes % 60;
            if (mins == 0) {
              _duration = '$hours ${hours == 1 ? 'hour' : 'hours'}';
            } else {
              _duration = '$hours h $mins mins';
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _distance = 'N/A';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final parking = _parkingData ?? widget.parking;
    final imageUrl = parking['imageUrl'] as String?;
    final rating = (parking['rating'] ?? 0.0).toDouble();
    final reviewCount = parking['reviewCount'] ?? 0;
    final address = parking['address'] ?? '';

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Content
          Column(
            children: [
              // Image Header
              _buildImageHeader(imageUrl),

              // Details Content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title and Info
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Title
                            Text(
                              parking['name'] ?? 'Unknown',
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 6),

                            // Address
                            Text(
                              address,
                              style: TextStyle(
                                fontSize: 14,
                                color: isDark
                                    ? Colors.grey[300]
                                    : Colors.grey[600],
                              ),
                            ),

                            const SizedBox(height: 12),
                            // Rating
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.grey[800]
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Row(
                                    children: List.generate(5, (index) {
                                      final starValue = rating - index;
                                      return Icon(
                                        starValue >= 1
                                            ? Icons.star_rounded
                                            : starValue > 0
                                            ? Icons.star_half_rounded
                                            : Icons.star_outline_rounded,
                                        color: Colors.orange,
                                        size: 18,
                                      );
                                    }),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    rating.toStringAsFixed(1),
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: isDark
                                          ? Colors.white
                                          : const Color(0xFF212121),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    '($reviewCount reviews)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.grey[300]
                                          : Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 16),

                            // Info Badges
                            Row(
                              children: [
                                _buildInfoBadge(
                                  Icons.location_on_outlined,
                                  _distance ?? 'N/A',
                                  Colors.orange,
                                ),
                                const SizedBox(width: 10),
                                _buildInfoBadge(
                                  Icons.access_time_rounded,
                                  _duration ?? 'Calculating...',
                                  Colors.blue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),

                            // Action Buttons
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton.icon(
                                onPressed: _showDirectionsDialog,
                                icon: Icon(
                                  Icons.navigation_rounded,
                                  size: 18,
                                  color: isDark
                                      ? const Color(0xFF64B5F6)
                                      : const Color(0xFF1E88E5),
                                ),
                                label: Text(
                                  'Get Direction',
                                  style: TextStyle(
                                    color: isDark
                                        ? const Color(0xFF64B5F6)
                                        : const Color(0xFF1E88E5),
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: isDark
                                      ? const Color(0xFF64B5F6)
                                      : const Color(0xFF1E88E5),
                                  side: BorderSide(
                                    color: isDark
                                        ? const Color(0xFF64B5F6)
                                        : const Color(0xFF1E88E5),
                                    width: 1.5,
                                  ),
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),

                      // Tabs
                      Builder(
                        builder: (context) {
                          final themeProvider = ThemeProvider.of(context);
                          final isDark = themeProvider?.isDarkMode ?? false;

                          return Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: isDark
                                      ? Colors.grey[700]!
                                      : Colors.grey[300]!,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              labelColor: const Color(0xFF1E88E5),
                              unselectedLabelColor: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                              labelStyle: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                              indicatorColor: const Color(0xFF1E88E5),
                              indicatorWeight: 2.5,
                              tabs: const [
                                Tab(text: 'Info'),
                                Tab(text: 'Chargers'),
                                Tab(text: 'Check-ins'),
                                Tab(text: 'Reviews'),
                              ],
                            ),
                          );
                        },
                      ),

                      // Tab Content
                      SizedBox(
                        height: 300,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                            _buildInfoTab(parking),
                            _buildChargersTab(),
                            _buildCheckInsTab(),
                            _buildReviewsTab(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Top Bar (Floating)
          _buildTopBar(),

          // Bookmark Notification
          if (_showBookmarkNotification) _buildBookmarkNotification(),
        ],
      ),
      // Bottom Book Button
      bottomNavigationBar: _buildBookButton(parking),
    );
  }

  Widget _buildImageHeader(String? imageUrl) {
    return SizedBox(
      height: 220,
      child: Stack(
        children: [
          // Image
          Container(
            height: 220,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              image: imageUrl != null && imageUrl.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(imageUrl),
                      fit: BoxFit.cover,
                      onError: (exception, stackTrace) {
                        // Handle error - will show placeholder
                      },
                    )
                  : null,
            ),
            child: imageUrl == null || imageUrl.isEmpty
                ? Center(
                    child: Icon(
                      Icons.image_not_supported_rounded,
                      size: 64,
                      color: Colors.grey[600],
                    ),
                  )
                : null,
          ),
          // Dark gradient overlay
          Container(
            height: 220,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.4),
                  Colors.transparent,
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBar() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            GestureDetector(
              onTap: () => Navigator.pop(context),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.grey[900]!.withOpacity(0.95)
                      : Colors.white.withOpacity(0.95),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Icon(
                  Icons.arrow_back,
                  color: isDark ? Colors.white : const Color(0xFF212121),
                  size: 20,
                ),
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: _shareParkingSpot,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[900]!.withOpacity(0.95)
                          : Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.share_outlined,
                      color: isDark ? Colors.white : const Color(0xFF212121),
                      size: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _toggleBookmark,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.grey[900]!.withOpacity(0.95)
                          : Colors.white.withOpacity(0.95),
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                      color: _isBookmarked
                          ? const Color(0xFF1E88E5)
                          : (isDark ? Colors.white : const Color(0xFF212121)),
                      size: 20,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBookmarkNotification() {
    return Positioned(
      top: 80,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5),
            borderRadius: BorderRadius.circular(25),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.white, size: 20),
              const SizedBox(width: 10),
              Text(
                _isBookmarked
                    ? 'Added to bookmarks!'
                    : 'Removed from bookmarks',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoBadge(IconData icon, String text, Color color) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: isDark ? Border.all(color: Colors.grey[700]!, width: 1) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: isDark
                ? (color == Colors.orange
                      ? Colors.orange
                      : const Color(0xFF64B5F6))
                : color,
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: isDark
                  ? (color == Colors.orange
                        ? Colors.orange
                        : const Color(0xFF64B5F6))
                  : color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoTab(Map<String, dynamic> parking) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final description = parking['description'] as String?;
    final amenities = parking['amenities'] as List<dynamic>? ?? [];
    final operatingHours = parking['operatingHours'] as Map<String, dynamic>?;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'About',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : const Color(0xFF212121),
            ),
          ),
          const SizedBox(height: 10),
          if (description != null && description.isNotEmpty)
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[300] : Colors.grey[700],
                height: 1.5,
              ),
            )
          else
            Text(
              'No description available.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
            ),
          if (amenities.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Features',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 10),
            ...amenities.map((amenity) {
              String label = '';
              IconData icon = Icons.check_circle;
              if (amenity == 'ev_charging') {
                label = 'EV Charging Available';
                icon = Icons.ev_station_rounded;
              } else if (amenity == 'security') {
                label = '24/7 Security';
                icon = Icons.security_rounded;
              } else if (amenity == 'covered') {
                label = 'Covered Parking';
                icon = Icons.roofing_rounded;
              } else if (amenity == 'accessible') {
                label = 'Wheelchair Accessible';
                icon = Icons.accessible_rounded;
              } else if (amenity == 'cctv') {
                label = 'CCTV Surveillance';
                icon = Icons.camera_alt_outlined;
              } else if (amenity == 'lighting') {
                label = 'Well Lit';
                icon = Icons.light_mode_rounded;
              } else if (amenity == 'restaurant') {
                label = 'Restaurant Nearby';
                icon = Icons.restaurant_rounded;
              } else if (amenity == 'shopping') {
                label = 'Shopping Nearby';
                icon = Icons.shopping_bag_rounded;
              } else if (amenity == 'wifi') {
                label = 'WiFi Available';
                icon = Icons.wifi_rounded;
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      color: isDark
                          ? const Color(0xFF64B5F6)
                          : const Color(0xFF1E88E5),
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[300] : Colors.grey[700],
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ],
          if (operatingHours != null && operatingHours.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Operating Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 10),
            if (operatingHours['mondayFriday'] != null)
              _buildOperatingHours(
                'Monday - Friday',
                operatingHours['mondayFriday'].toString(),
              ),
            if (operatingHours['saturday'] != null)
              _buildOperatingHours(
                'Saturday',
                operatingHours['saturday'].toString(),
              ),
            if (operatingHours['sunday'] != null)
              _buildOperatingHours(
                'Sunday',
                operatingHours['sunday'].toString(),
              ),
            if (operatingHours['monday'] != null)
              _buildOperatingHours(
                'Monday',
                operatingHours['monday'].toString(),
              ),
            if (operatingHours['tuesday'] != null)
              _buildOperatingHours(
                'Tuesday',
                operatingHours['tuesday'].toString(),
              ),
            if (operatingHours['wednesday'] != null)
              _buildOperatingHours(
                'Wednesday',
                operatingHours['wednesday'].toString(),
              ),
            if (operatingHours['thursday'] != null)
              _buildOperatingHours(
                'Thursday',
                operatingHours['thursday'].toString(),
              ),
            if (operatingHours['friday'] != null)
              _buildOperatingHours(
                'Friday',
                operatingHours['friday'].toString(),
              ),
          ] else ...[
            const SizedBox(height: 20),
            Text(
              'Operating Hours',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : const Color(0xFF212121),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Operating hours not specified.',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[500],
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildOperatingHours(String day, String hours) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
            ),
          ),
          Text(
            hours,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : const Color(0xFF212121),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChargersTab() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    if (_chargers.isEmpty) {
      return Center(
        child: Text(
          'No EV Chargers Available',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _chargers.length,
      itemBuilder: (context, index) {
        return _buildChargerCard(_chargers[index]);
      },
    );
  }

  Widget _buildChargerCard(Map<String, dynamic> charger) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    final bool isAvailable = charger['available'] ?? false;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isAvailable
                  ? const Color(0xFF1E88E5).withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.ev_station_rounded,
              color: isAvailable ? const Color(0xFF1E88E5) : Colors.red,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Charger #${charger['number']}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${charger['type']} • ${charger['power']}',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: isAvailable
                  ? const Color(0xFF1E88E5).withOpacity(0.1)
                  : Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              isAvailable
                  ? context.translate('Available')
                  : context.translate('In Use'),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isAvailable ? const Color(0xFF1E88E5) : Colors.red,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckInsTab() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    if (_checkIns.isEmpty) {
      return Center(
        child: Text(
          'No Recent Check-ins',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _checkIns.length,
      itemBuilder: (context, index) {
        return _buildCheckInCard(_checkIns[index]);
      },
    );
  }

  Widget _buildCheckInCard(Map<String, dynamic> checkIn) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 25,
            backgroundImage: checkIn['userPhoto'] != null
                ? NetworkImage(checkIn['userPhoto'])
                : null,
            onBackgroundImageError: (exception, stackTrace) {
              // Handle error
            },
            child: checkIn['userPhoto'] == null
                ? const Icon(Icons.person, color: Colors.grey)
                : null,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  checkIn['userName'],
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  checkIn['timeAgo'],
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: Color(0xFF1E88E5), size: 24),
        ],
      ),
    );
  }

  Widget _buildReviewsTab() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    if (_reviews.isEmpty) {
      return Center(
        child: Text(
          'No Reviews Yet',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[400] : Colors.grey,
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _reviews.length,
      itemBuilder: (context, index) {
        return _buildReviewCard(_reviews[index]);
      },
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[200]!,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundImage: review['userPhoto'] != null
                    ? NetworkImage(review['userPhoto'])
                    : null,
                onBackgroundImageError: (exception, stackTrace) {
                  // Handle error
                },
                child: review['userPhoto'] == null
                    ? const Icon(Icons.person, color: Colors.grey, size: 20)
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      review['userName'],
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF212121),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: List.generate(5, (i) {
                        return Icon(
                          i < review['rating']
                              ? Icons.star
                              : Icons.star_outline,
                          color: Colors.orange,
                          size: 16,
                        );
                      }),
                    ),
                  ],
                ),
              ),
              Text(
                review['timeAgo'],
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.grey[500] : Colors.grey[500],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            review['comment'],
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[300] : Colors.grey[700],
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookButton(Map<String, dynamic> parking) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    final isAvailable = (parking['availableSpots'] ?? 0) > 0;

    // Check if parking has a valid ID
    final hasValidId =
        parking['id'] != null ||
        parking['spotId'] != null ||
        parking['_id'] != null ||
        (_parkingData != null && _parkingData!['id'] != null);

    final canBook = isAvailable && hasValidId;
    String buttonText = context.translate('Book');
    if (!isAvailable) {
      buttonText = context.translate('Unavailable');
    } else if (!hasValidId) {
      buttonText = context.translate('Unavailable');
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      decoration: BoxDecoration(
        color: theme.cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: ElevatedButton(
            onPressed: canBook ? _showBookingDialog : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: canBook
                  ? const Color(0xFF1E88E5)
                  : Colors.grey[400],
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: Text(
              buttonText,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  // ==================== DIALOGS ====================

  Future<void> _toggleBookmark() async {
    try {
      final user = _auth.currentUser;
      if (user == null) return;

      final spotId =
          widget.parking['id'] as String? ??
          widget.parking['spotId'] as String? ??
          widget.parking['_id'] as String?;

      if (spotId == null || spotId.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot bookmark: Missing parking spot ID'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final bookmarkRef = _firestore
          .collection('saved_spots')
          .doc('${user.uid}_$spotId');

      if (_isBookmarked) {
        await bookmarkRef.delete();
        if (mounted) {
          setState(() {
            _isBookmarked = false;
          });
        }
      } else {
        await bookmarkRef.set({
          'userId': user.uid,
          'spotId': spotId,
          'createdAt': FieldValue.serverTimestamp(),
        });
        if (mounted) {
          setState(() {
            _isBookmarked = true;
          });
        }
      }

      // Show notification
      if (mounted) {
        setState(() {
          _showBookmarkNotification = true;
        });
      }

      // Hide notification after 2 seconds
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          setState(() {
            _showBookmarkNotification = false;
          });
        }
      });
    } catch (e) {
      // Error toggling bookmark
    }
  }

  Future<void> _shareParkingSpot() async {
    try {
      final parking = _parkingData ?? widget.parking;
      final name = parking['name'] ?? 'Parking Spot';
      final address = parking['address'] ?? '';
      final rating = (parking['rating'] ?? 0.0).toDouble();
      final reviewCount = parking['reviewCount'] ?? 0;

      // Handle location for Google Maps link
      String locationText = '';
      if (parking['location'] is LatLng) {
        final location = parking['location'] as LatLng;
        locationText = '${location.latitude},${location.longitude}';
      } else if (parking['location'] is Map) {
        final locationMap = parking['location'] as Map<String, dynamic>;
        final lat = locationMap['lat'] ?? locationMap['latitude'] ?? 0.0;
        final lng = locationMap['lng'] ?? locationMap['longitude'] ?? 0.0;
        locationText = '$lat,$lng';
      }

      // Build share text
      String shareText = 'Check out this parking spot on RaknaGo!\n\n';
      shareText += '📍 $name\n';
      if (address.isNotEmpty) {
        shareText += '📍 $address\n';
      }
      if (rating > 0) {
        shareText += '⭐ ${rating.toStringAsFixed(1)} ($reviewCount reviews)\n';
      }
      if (locationText.isNotEmpty) {
        shareText +=
            '\n📍 Location: https://www.google.com/maps/search/?api=1&query=$locationText';
      }
      shareText += '\n\nDownload RaknaGo to find and book parking spots!';

      // Share
      await Share.share(shareText, subject: 'Check out $name on RaknaGo');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(child: Text('Failed to share: ${e.toString()}')),
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
    }
  }

  Future<void> _showDirectionsDialog() async {
    // Handle location as either LatLng or Map
    LatLng location;
    if (widget.parking['location'] is LatLng) {
      location = widget.parking['location'] as LatLng;
    } else if (widget.parking['location'] is Map) {
      final locationMap = widget.parking['location'] as Map<String, dynamic>;
      location = LatLng(
        (locationMap['lat'] ?? locationMap['latitude'] ?? 0.0).toDouble(),
        (locationMap['lng'] ?? locationMap['longitude'] ?? 0.0).toDouble(),
      );
    } else {
      return;
    }

    final parking = _parkingData ?? widget.parking;
    final parkingName = parking['name'] ?? 'Parking Spot';

    try {
      // Get user's current location
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userLocation = LatLng(position.latitude, position.longitude);

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
              destination: location,
              userLocation: userLocation,
              parkingName: parkingName,
              userAvatarUrl: userAvatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      // If location access fails, show fallback dialog
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.navigation_rounded, color: Color(0xFF1E88E5)),
                SizedBox(width: 12),
                Text('Get Directions'),
              ],
            ),
            content: const Text('Open in Google Maps?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () async {
                  Navigator.pop(context);
                  final url =
                      'https://www.google.com/maps/search/?api=1&query=${location.latitude},${location.longitude}';
                  final uri = Uri.parse(url);
                  if (await canLaunchUrl(uri)) {
                    await launchUrl(uri, mode: LaunchMode.externalApplication);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Open'),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _showBookingDialog() async {
    print('🔍 === Booking Dialog Debug Start ===');
    print('🔍 _parkingData is null: ${_parkingData == null}');
    print('🔍 _parkingData keys: ${_parkingData?.keys.toList()}');
    print('🔍 _parkingData id: ${_parkingData?['id']}');
    print('🔍 widget.parking keys: ${widget.parking.keys.toList()}');
    print('🔍 widget.parking id: ${widget.parking['id']}');

    // Use _parkingData if available, otherwise use widget.parking
    // Make sure to include 'id' field
    Map<String, dynamic> parking = Map<String, dynamic>.from(
      _parkingData ?? widget.parking,
    );

    // Ensure parking has an ID
    if (!parking.containsKey('id') || parking['id'] == null) {
      print('⚠️ ID not found in parking, trying alternative fields...');
      // Try to get from other fields
      final id = parking['spotId'] ?? parking['_id'];
      if (id != null) {
        print('✅ Found ID in alternative field: $id');
        parking['id'] = id.toString();
      } else if (_parkingData != null && _parkingData!.containsKey('id')) {
        print('✅ Found ID in _parkingData: ${_parkingData!['id']}');
        parking['id'] = _parkingData!['id'];
      } else {
        print('❌ No ID found in any field');
      }
    } else {
      print('✅ ID found in parking: ${parking['id']}');
    }

    print('🔍 Final parking keys: ${parking.keys.toList()}');
    print('🔍 Final parking ID: ${parking['id']}');
    print('🔍 === Booking Dialog Debug End ===');

    final user = _auth.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please login to book'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Check wallet balance
    final walletDoc = await _firestore
        .collection('wallets')
        .doc(user.uid)
        .get();
    final currentBalance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();
    final pricePerHour = (parking['pricePerHour'] ?? 0.0).toDouble();
    final defaultDuration = 1; // Default 1 hour
    // Charge only for the first hour at booking time
    final totalPrice = pricePerHour * 1; // First hour only

    if (currentBalance < totalPrice) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            title: const Row(
              children: [
                Icon(Icons.warning_rounded, color: Colors.orange),
                SizedBox(width: 12),
                Text('Insufficient Balance'),
              ],
            ),
            content: Text(
              'Your balance is EGP ${currentBalance.toStringAsFixed(2)}, but you need EGP ${totalPrice.toStringAsFixed(2)} to book this parking spot.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Navigate to top up screen
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E88E5),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Top Up'),
              ),
            ],
          ),
        );
      }
      return;
    }

    if (mounted) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.check_circle_outline, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Confirm Booking'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                parking['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Price: EGP ${pricePerHour.toStringAsFixed(2)}/hour',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Duration: $defaultDuration hour',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              ),
              const SizedBox(height: 4),
              Text(
                'Total: EGP ${totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1E88E5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            StatefulBuilder(
              builder: (context, setDialogState) {
                return ElevatedButton(
                  onPressed: () async {
                    Navigator.pop(context);
                    await _createBooking(parking, defaultDuration, totalPrice);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Confirm'),
                );
              },
            ),
          ],
        ),
      );
    }
  }

  Future<void> _createBooking(
    Map<String, dynamic> parking,
    int duration,
    double totalPrice,
  ) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login to book'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check if user has completed profile (required by Firestore rules)
      final userDoc = await _firestore.collection('users').doc(user.uid).get();

      if (!userDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'User profile not found. Please complete your profile.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final userData = userDoc.data();
      final profileCompleted = userData?['profileCompleted'] ?? false;

      if (!profileCompleted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please complete your profile before booking.'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Try to get spotId from different possible fields (same logic as _loadParkingData)
      String? spotId;

      // First, try 'id' field
      if (parking.containsKey('id')) {
        final idValue = parking['id'];
        if (idValue != null) {
          spotId = idValue.toString();
        }
      }

      // If not found, try 'spotId' field
      if ((spotId == null || spotId.isEmpty) && parking.containsKey('spotId')) {
        final spotIdValue = parking['spotId'];
        if (spotIdValue != null) {
          spotId = spotIdValue.toString();
        }
      }

      // If still not found, try '_id' field
      if ((spotId == null || spotId.isEmpty) && parking.containsKey('_id')) {
        final idValue = parking['_id'];
        if (idValue != null) {
          spotId = idValue.toString();
        }
      }

      // Also check if we have spotId from _parkingData
      if ((spotId == null || spotId.isEmpty) && _parkingData != null) {
        if (_parkingData!.containsKey('id')) {
          final idValue = _parkingData!['id'];
          if (idValue != null) {
            spotId = idValue.toString();
          }
        }
      }

      if (spotId == null || spotId.isEmpty) {
        print('❌ Booking - Parking data keys: ${parking.keys.toList()}');
        print('❌ Booking - _parkingData keys: ${_parkingData?.keys.toList()}');
        print(
          '❌ Booking - widget.parking keys: ${widget.parking.keys.toList()}',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: const [
                  Icon(Icons.error_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Unable to book: Parking spot ID is missing. Please try again.',
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 3),
            ),
          );
        }
        return;
      }

      print('✅ Booking - Found spotId: $spotId');

      // Check available spots
      final spotDoc = await _firestore
          .collection('parking_spots')
          .doc(spotId)
          .get();

      if (!spotDoc.exists) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Parking spot not found'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      final spotData = spotDoc.data()!;
      final availableSpots = (spotData['availableSpots'] ?? 0) as int;

      if (availableSpots <= 0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No available spots'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Check wallet balance again
      final walletDoc = await _firestore
          .collection('wallets')
          .doc(user.uid)
          .get();
      final currentBalance = (walletDoc.data()?['balance'] ?? 0.0).toDouble();

      if (currentBalance < totalPrice) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Insufficient balance'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }

      // Create booking
      final now = DateTime.now();
      final startTime = now;
      final endTime = now.add(Duration(hours: duration));

      final bookingData = {
        'userId': user.uid,
        'spotId': spotId,
        'spotName': parking['name'] ?? 'Parking Spot',
        'spotAddress': parking['address'] ?? '',
        'startTime': Timestamp.fromDate(startTime),
        'endTime': Timestamp.fromDate(endTime),
        'duration': '$duration hour${duration > 1 ? 's' : ''}',
        'price': totalPrice,
        'totalPrice': totalPrice,
        'pricePerHour': parking['pricePerHour'] ?? 0.0,
        'status': 'active',
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Use batch to ensure atomicity
      final batch = _firestore.batch();

      // Add booking
      final bookingRef = _firestore.collection('reservations').doc();
      batch.set(bookingRef, bookingData);

      // Deduct from wallet
      final walletRef = _firestore.collection('wallets').doc(user.uid);
      batch.set(walletRef, {
        'balance': currentBalance - totalPrice,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Add transaction record
      final transactionRef = _firestore
          .collection('transactions')
          .doc(user.uid)
          .collection('user_transactions')
          .doc();
      batch.set(transactionRef, {
        'type': 'Booking',
        'amount': -totalPrice,
        'status': 'completed',
        'paymentMethod': 'Wallet',
        'bookingId': bookingRef.id,
        'description': 'Booking for ${parking['name']} - First hour',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Update available spots
      final spotRef = _firestore.collection('parking_spots').doc(spotId);
      batch.update(spotRef, {
        'availableSpots': FieldValue.increment(-1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Show loading indicator
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
            ),
          ),
        );
      }

      try {
        print('🔄 Committing batch...');
        await batch.commit();
        print('✅ Batch committed successfully');
        print('✅ Booking ID: ${bookingRef.id}');
        print('✅ Booking data: $bookingData');
        print('✅ Wallet balance before: $currentBalance');
        print('✅ Total price: $totalPrice');
        print('✅ Wallet balance after: ${currentBalance - totalPrice}');
        print('✅ Transaction added');

        // Wait a bit for Firestore to propagate
        await Future.delayed(const Duration(milliseconds: 500));

        // Verify the booking was created
        final bookingDoc = await bookingRef.get();
        if (!bookingDoc.exists) {
          print('❌ ERROR: Booking was not created in database!');
          throw Exception('Booking was not created in database');
        }
        print('✅ Verified booking exists in database');
        print('✅ Booking document data: ${bookingDoc.data()}');

        // Verify wallet balance was updated
        final updatedWalletDoc = await walletRef.get();
        final updatedBalance = (updatedWalletDoc.data()?['balance'] ?? 0.0)
            .toDouble();
        print(
          '✅ Verified wallet balance: $updatedBalance (was $currentBalance)',
        );

        if ((updatedBalance - (currentBalance - totalPrice)).abs() > 0.01) {
          print(
            '⚠️ WARNING: Wallet balance mismatch! Expected: ${currentBalance - totalPrice}, Got: $updatedBalance',
          );
        }

        // Close loading indicator
        if (mounted) {
          Navigator.pop(context);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(child: Text('Booking confirmed successfully!')),
                ],
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              duration: const Duration(seconds: 2),
            ),
          );

          // Wait a bit before navigating to show the success message
          await Future.delayed(const Duration(milliseconds: 500));

          // Navigate to booking screen (will reload automatically)
          if (mounted) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const BookingScreen()),
            );
          }
        }
      } catch (batchError) {
        // Close loading indicator if still open
        if (mounted) {
          try {
            Navigator.pop(context);
          } catch (_) {
            // Dialog might not be open
          }
        }

        print('❌ Batch commit error: $batchError');
        print('Error type: ${batchError.runtimeType}');
        if (batchError is FirebaseException) {
          print('Firebase error code: ${batchError.code}');
          print('Firebase error message: ${batchError.message}');
        }
        rethrow; // Re-throw to be caught by outer catch block
      }
    } catch (e) {
      // Close loading indicator if still open
      if (mounted) {
        try {
          Navigator.pop(context);
        } catch (_) {
          // Dialog might not be open
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Error creating booking: ${e.toString()}',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 4),
          ),
        );
      }

      // Print detailed error for debugging
      print('❌ Booking error: $e');
      print('Error type: ${e.runtimeType}');
      if (e is FirebaseException) {
        print('Firebase error code: ${e.code}');
        print('Firebase error message: ${e.message}');
      } else if (e is Exception) {
        print('Exception details: ${e.toString()}');
      }
    }
  }
}
