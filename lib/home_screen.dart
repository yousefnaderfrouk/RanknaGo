import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:math';
import 'dart:ui' as ui;
import 'theme_provider.dart';
import 'language_provider.dart';
import 'new home/saved_screen.dart';
import 'new home/booking_screen.dart';
import 'new home/wallet_screen.dart';
import 'new home/account_screen.dart';
import 'new home/parking_details_screen.dart';
import 'new home/directions_map_screen.dart';
import 'new home/qr_scanner_screen.dart';
import 'widgets/custom_bottom_nav_bar.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  final MapController _mapController = MapController();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  LatLng _currentLocation = const LatLng(30.0444, 31.2357);
  List<Map<String, dynamic>> _parkingSpots = [];
  String? _userPhotoURL;
  bool _isLoadingSpots = true;

  // Filter states
  bool _filterAvailableOnly = false;
  bool _filterEVCharging = false;
  bool _filterNearMe = false;

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
    _loadParkingSpots();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final userDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          final data = userDoc.data();
          setState(() {
            _userPhotoURL = data?['photoURL'] ?? user.photoURL;
          });
        } else {
          setState(() {
            _userPhotoURL = user.photoURL;
          });
        }
      }
    } catch (e) {
      // Error loading user profile
    }
  }

  Future<void> _loadParkingSpots() async {
    try {
      final spotsSnapshot = await _firestore
          .collection('parking_spots')
          .where('isActive', isEqualTo: true)
          .get();

      final List<Map<String, dynamic>> spots = [];

      for (var doc in spotsSnapshot.docs) {
        final data = doc.data();
        final locationData = data['location'] as Map<String, dynamic>?;

        if (locationData != null) {
          final lat = (locationData['lat'] ?? 0.0) as double;
          final lng = (locationData['lng'] ?? 0.0) as double;

          spots.add({
            'id': doc.id,
            'name': data['name'] ?? 'Unknown',
            'location': LatLng(lat, lng),
            'available': (data['availableSpots'] ?? 0) > 0,
            'price': (data['pricePerHour'] ?? 0.0).toDouble(),
            'totalSpots': data['totalSpots'] ?? 0,
            'availableSpots': data['availableSpots'] ?? 0,
            'hasEVCharging': data['hasEVCharging'] ?? false,
            'address': data['address'] ?? '',
            'description': data['description'] ?? '',
            'rating': (data['rating'] ?? 0.0).toDouble(),
            'reviewCount': data['reviewCount'] ?? 0,
            'amenities': data['amenities'] ?? <String>[],
            'evChargerCount': data['evChargerCount'] ?? 0,
          });
        }
      }

      setState(() {
        _parkingSpots = spots;
        _isLoadingSpots = false;
      });
    } catch (e) {
      setState(() {
        _isLoadingSpots = false;
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return;
        }
      }

      Position position = await Geolocator.getCurrentPosition();
      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          try {
            _mapController.move(_currentLocation, 14.0);
          } catch (e) {
            // Retry after delay if map not ready
            Future.delayed(const Duration(milliseconds: 500), () {
              if (mounted) {
                try {
                  _mapController.move(_currentLocation, 14.0);
                } catch (e) {
                  // Ignore
                }
              }
            });
          }
        }
      });
    } catch (e) {
      // Location error handled
    }
  }

  void _centerOnUserLocation() {
    _mapController.move(_currentLocation, 15.0);
  }

  List<Map<String, dynamic>> get _filteredParkingSpots {
    List<Map<String, dynamic>> spots = List<Map<String, dynamic>>.from(
      _parkingSpots,
    );

    // Apply filters
    if (_filterAvailableOnly) {
      spots = spots.where((spot) => spot['available'] == true).toList();
    }

    if (_filterEVCharging) {
      spots = spots.where((spot) => spot['hasEVCharging'] == true).toList();
    }

    if (_filterNearMe) {
      // Filter spots within 5 km
      spots = spots.where((spot) {
        final spotLocation = spot['location'] as LatLng;
        final distance = _calculateDistance(
          _currentLocation.latitude,
          _currentLocation.longitude,
          spotLocation.latitude,
          spotLocation.longitude,
        );
        return distance <= 5.0; // 5 km
      }).toList();
    }

    return spots;
  }

  List<Map<String, dynamic>> get _sortedParkingSpots {
    final spots = List<Map<String, dynamic>>.from(_filteredParkingSpots);
    for (var spot in spots) {
      final spotLocation = spot['location'] as LatLng;
      final distance = _calculateDistance(
        _currentLocation.latitude,
        _currentLocation.longitude,
        spotLocation.latitude,
        spotLocation.longitude,
      );
      spot['calculatedDistance'] = distance;
      spot['distance'] = _formatDistance(distance);
    }
    spots.sort(
      (a, b) => (a['calculatedDistance'] as double).compareTo(
        b['calculatedDistance'] as double,
      ),
    );
    return spots;
  }

  double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const double earthRadius = 6371;
    final dLat = _toRadians(lat2 - lat1);
    final dLon = _toRadians(lon2 - lon1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
            cos(_toRadians(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  double _toRadians(double degrees) => degrees * pi / 180;

  String _formatDistance(double km) {
    if (km < 1) {
      return '${(km * 1000).toInt()} m';
    } else {
      return '${km.toStringAsFixed(1)} km';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: _currentIndex == 0 ? _buildHomeContent() : _buildOtherScreens(),
      bottomNavigationBar: CustomBottomNavBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
      ),
      floatingActionButton: Builder(
        builder: (context) {
          final themeProvider = ThemeProvider.of(context);
          final isDark = themeProvider?.isDarkMode ?? false;
          final theme = Theme.of(context);

          return FloatingActionButton(
            onPressed: () {
              setState(() {
                _currentIndex = 0;
              });
            },
            shape: const CircleBorder(),
            backgroundColor: _currentIndex == 0
                ? const Color(0xFF1E88E5)
                : (isDark ? theme.cardColor : Colors.white),
            elevation: 0,
            child: Icon(
              Icons.home,
              color: _currentIndex == 0
                  ? Colors.white
                  : const Color(0xFF1E88E5),
              size: 35,
            ),
          );
        },
      ),
      floatingActionButtonLocation: const CustomFabLocation(
        FloatingActionButtonLocation.centerDocked,
        offsetY: 15,
      ),
    );
  }

  Widget _buildHomeContent() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Stack(
      children: [
        // Map
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _currentLocation,
            initialZoom: 14.0,
            minZoom: 10.0,
            maxZoom: 18.0,
          ),
          children: [
            TileLayer(
              urlTemplate: isDark
                  ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                  : 'https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png',
              subdomains: const ['a', 'b', 'c', 'd'],
              userAgentPackageName: 'com.parkspot.app',
              retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
              // Suppress tile loading errors - they're normal when connections close during disposal
              maxNativeZoom: 18,
              maxZoom: 18,
            ),
            CircleLayer(
              circles: [
                CircleMarker(
                  point: _currentLocation,
                  radius: 100,
                  useRadiusInMeter: true,
                  color: const Color(0xFF1E88E5).withOpacity(0.15),
                  borderColor: const Color(0xFF1E88E5).withOpacity(0.3),
                  borderStrokeWidth: 2,
                ),
              ],
            ),
            MarkerLayer(
              markers: [
                Marker(
                  point: _currentLocation,
                  width: 70,
                  height: 70,
                  child: _buildUserMarker(),
                ),
                ..._filteredParkingSpots.map((spot) {
                  return Marker(
                    point: spot['location'],
                    width: 50,
                    height: 60,
                    child: _buildParkingMarker(spot),
                  );
                }).toList(),
              ],
            ),
          ],
        ),

        // Top Search Bar
        _buildTopSearchBar(),

        // Floating Buttons (Right Side)
        _buildFloatingButtons(),

        // Loading Indicator
        if (_isLoadingSpots)
          Container(
            color: Colors.black.withOpacity(0.3),
            child: const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF1E88E5)),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildUserMarker() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 4),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(
        child: _userPhotoURL != null && _userPhotoURL!.isNotEmpty
            ? Image.network(
                _userPhotoURL!,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    color: const Color(0xFF1E88E5),
                    child: const Icon(
                      Icons.person,
                      color: Colors.white,
                      size: 35,
                    ),
                  );
                },
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    color: const Color(0xFF1E88E5),
                    child: const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    ),
                  );
                },
              )
            : Container(
                color: const Color(0xFF1E88E5),
                child: const Icon(Icons.person, color: Colors.white, size: 35),
              ),
      ),
    );
  }

  Widget _buildParkingMarker(Map<String, dynamic> spot) {
    final isAvailable = spot['available'] as bool? ?? false;

    return GestureDetector(
      onTap: () => _showParkingDetails(spot),
      child: Column(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: isAvailable ? const Color(0xFF1E88E5) : Colors.red,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.white, width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Center(
              child: Icon(
                spot['hasEVCharging']
                    ? Icons.ev_station_rounded
                    : Icons.local_parking_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          CustomPaint(
            size: const Size(10, 10),
            painter: _TrianglePainter(
              color: isAvailable ? const Color(0xFF1E88E5) : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopSearchBar() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: _showSearchBottomSheet,
                child: Container(
                  height: 55,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Icon(
                          Icons.search,
                          color: isDark ? Colors.grey[400] : Colors.grey[400],
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          context.translate('Search'),
                          style: TextStyle(
                            color: isDark ? Colors.grey[300] : Colors.grey[400],
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 55,
              height: 55,
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: IconButton(
                icon: const Icon(Icons.tune_rounded, color: Color(0xFF1E88E5)),
                onPressed: _showFilterBottomSheet,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFloatingButtons() {
    return Positioned(
      right: 16,
      bottom: 30,
      child: Column(
        children: [
          FloatingActionButton(
            heroTag: 'qr',
            onPressed: _showQRScanner,
            backgroundColor: const Color(0xFF1E88E5),
            child: const Icon(
              Icons.qr_code_scanner_rounded,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 12),
          Builder(
            builder: (context) {
              final themeProvider = ThemeProvider.of(context);
              final isDark = themeProvider?.isDarkMode ?? false;
              final theme = Theme.of(context);
              return FloatingActionButton(
                heroTag: 'location',
                onPressed: _centerOnUserLocation,
                backgroundColor: theme.cardColor,
                child: Icon(
                  Icons.my_location_rounded,
                  color: isDark ? Colors.white : const Color(0xFF1E88E5),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildOtherScreens() {
    switch (_currentIndex) {
      case 1:
        return const SavedScreen();
      case 2:
        return const BookingScreen();
      case 3:
        return const WalletScreen();
      case 4:
        return const AccountScreen();
      default:
        return const SizedBox.shrink();
    }
  }

  void _showParkingDetails(Map<String, dynamic> spot) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey[700] : Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        spot['name'],
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Brooklyn, ${spot['address']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 48,
                  height: 48,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E88E5),
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.navigation_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                    onPressed: () async {
                      Navigator.pop(context);
                      await _openDirections(spot);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Builder(
                  builder: (context) {
                    final themeProvider = ThemeProvider.of(context);
                    final isDark = themeProvider?.isDarkMode ?? false;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.grey[800] : Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final themeProvider = ThemeProvider.of(context);
                              final isDark = themeProvider?.isDarkMode ?? false;
                              return Text(
                                (spot['rating'] ?? 0.0).toStringAsFixed(1),
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF212121),
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 6),
                          ...List.generate(
                            5,
                            (index) => Icon(
                              index <
                                      ((spot['rating'] ?? 0.0) as double)
                                          .round()
                                  ? Icons.star
                                  : Icons.star_border,
                              color: Colors.orange,
                              size: 16,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Builder(
                  builder: (context) {
                    final themeProvider = ThemeProvider.of(context);
                    final isDark = themeProvider?.isDarkMode ?? false;
                    return Text(
                      '(${spot['reviewCount'] ?? 0} reviews)',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.grey[400] : Colors.grey[600],
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: (spot['available'] as bool? ?? false)
                        ? const Color(0xFF1E88E5)
                        : Colors.red,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    (spot['available'] as bool? ?? false)
                        ? '${spot['availableSpots'] ?? 0} spots'
                        : 'Full',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                _buildInfoChip(
                  Icons.location_on_outlined,
                  spot['distance'] ?? '0 m',
                ),
                const SizedBox(width: 12),
                _buildInfoChip(Icons.access_time_rounded, '5 mins'),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    if ((spot['amenities'] as List<dynamic>?)?.contains(
                          'parking',
                        ) ??
                        true)
                      _buildAmenityIcon(Icons.local_parking_rounded),
                    if ((spot['amenities'] as List<dynamic>?)?.contains(
                          'parking',
                        ) ??
                        true)
                      const SizedBox(width: 12),
                    if (spot['hasEVCharging'] ?? false)
                      _buildAmenityIcon(Icons.ev_station_rounded),
                    if (spot['hasEVCharging'] ?? false)
                      const SizedBox(width: 12),
                    if ((spot['amenities'] as List<dynamic>?)?.contains(
                          'restaurant',
                        ) ??
                        false) ...[
                      _buildAmenityIcon(Icons.restaurant_rounded),
                      const SizedBox(width: 12),
                    ],
                    if ((spot['amenities'] as List<dynamic>?)?.contains(
                          'shopping',
                        ) ??
                        false) ...[
                      _buildAmenityIcon(Icons.shopping_cart_rounded),
                      const SizedBox(width: 12),
                    ],
                    if ((spot['amenities'] as List<dynamic>?)?.contains(
                          'wifi',
                        ) ??
                        false) ...[
                      _buildAmenityIcon(Icons.wifi_rounded),
                      const SizedBox(width: 12),
                    ],
                    if ((spot['amenities'] as List<dynamic>?)?.contains(
                          'accessible',
                        ) ??
                        false)
                      _buildAmenityIcon(Icons.accessible_rounded),
                  ],
                ),
                if (spot['hasEVCharging'] ?? false)
                  Builder(
                    builder: (context) {
                      final themeProvider = ThemeProvider.of(context);
                      final isDark = themeProvider?.isDarkMode ?? false;
                      return Row(
                        children: [
                          Text(
                            '${spot['evChargerCount'] ?? 0} chargers',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? const Color(0xFF64B5F6)
                                  : const Color(0xFF1E88E5),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: isDark
                                ? const Color(0xFF64B5F6)
                                : const Color(0xFF1E88E5),
                          ),
                        ],
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      color: isDark ? theme.cardColor : Colors.transparent,
                      border: Border.all(
                        color: const Color(0xFF1E88E5),
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(25),
                    ),
                    child: TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ParkingDetailsScreen(parking: spot),
                          ),
                        );
                      },
                      style: TextButton.styleFrom(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'View',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                      ),
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1E88E5).withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ParkingDetailsScreen(parking: spot),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(25),
                        ),
                      ),
                      child: const Text(
                        'Book',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Builder(
      builder: (context) {
        final themeProvider = ThemeProvider.of(context);
        final isDark = themeProvider?.isDarkMode ?? false;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[800] : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                size: 16,
                color: isDark ? Colors.grey[400] : Colors.grey[700],
              ),
              const SizedBox(width: 4),
              Text(
                text,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey[400] : Colors.grey[700],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildAmenityIcon(IconData icon) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;

    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: isDark ? Colors.grey[800] : Colors.grey[100],
        shape: BoxShape.circle,
      ),
      child: Icon(
        icon,
        size: 20,
        color: isDark ? Colors.grey[400] : Colors.grey[700],
      ),
    );
  }

  void _showSearchBottomSheet() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) {
          return Container(
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                  ),
                  child: Column(
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.grey[700] : Colors.grey[300],
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              height: 50,
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2A2F38)
                                    : Colors.grey[100],
                                borderRadius: BorderRadius.circular(25),
                              ),
                              child: TextField(
                                style: TextStyle(
                                  color: isDark
                                      ? Colors.white
                                      : const Color(0xFF212121),
                                ),
                                decoration: InputDecoration(
                                  hintText: 'Search station',
                                  hintStyle: TextStyle(
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[400],
                                    fontSize: 15,
                                  ),
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: isDark
                                        ? Colors.grey[500]
                                        : Colors.grey[400],
                                  ),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 15,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 50,
                            height: 50,
                            decoration: BoxDecoration(
                              color: isDark
                                  ? const Color(0xFF2A2F38)
                                  : Colors.grey[100],
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.tune_rounded,
                                color: Color(0xFF1E88E5),
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                _showFilterBottomSheet();
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nearby Stations',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF212121),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_sortedParkingSpots.length} stations found',
                        style: TextStyle(
                          fontSize: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _sortedParkingSpots.length,
                    itemBuilder: (context, index) {
                      final spot = _sortedParkingSpots[index];
                      return _buildSearchResultCard(spot);
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSearchResultCard(Map<String, dynamic> spot) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    final isAvailable = spot['available'] as bool? ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            Navigator.pop(context);
            _mapController.move(spot['location'], 16.0);
            Future.delayed(const Duration(milliseconds: 500), () {
              _showParkingDetails(spot);
            });
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: isAvailable ? const Color(0xFF1E88E5) : Colors.red,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color:
                            (isAvailable ? const Color(0xFF1E88E5) : Colors.red)
                                .withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Icon(
                      spot['hasEVCharging']
                          ? Icons.ev_station_rounded
                          : Icons.local_parking_rounded,
                      color: Colors.white,
                      size: 26,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Builder(
                        builder: (context) {
                          final themeProvider = ThemeProvider.of(context);
                          final isDark = themeProvider?.isDarkMode ?? false;
                          return Text(
                            spot['name'],
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF212121),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 6),
                      Builder(
                        builder: (context) {
                          final themeProvider = ThemeProvider.of(context);
                          final isDark = themeProvider?.isDarkMode ?? false;
                          return Text(
                            'Brooklyn, ${spot['address']}',
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark
                                  ? Colors.grey[400]
                                  : Colors.grey[600],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Builder(
                            builder: (context) {
                              final themeProvider = ThemeProvider.of(context);
                              final isDark = themeProvider?.isDarkMode ?? false;
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: isDark
                                      ? Colors.grey[800]
                                      : Colors.grey[100],
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.location_on_outlined,
                                      size: 14,
                                      color: isDark
                                          ? Colors.grey[400]
                                          : Colors.grey[700],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      spot['distance'],
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: isDark
                                            ? Colors.grey[300]
                                            : Colors.grey[700],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: isAvailable
                                  ? const Color(0xFF1E88E5).withOpacity(0.1)
                                  : Colors.red.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isAvailable
                                  ? '${spot['availableSpots']} spots'
                                  : 'Full',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isAvailable
                                    ? const Color(0xFF1E88E5)
                                    : Colors.red,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 16,
                  color: Colors.grey[400],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showFilterBottomSheet() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);
    bool filterAvailableOnly = _filterAvailableOnly;
    bool filterEVCharging = _filterEVCharging;
    bool filterNearMe = _filterNearMe;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => Container(
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Filter Options',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF212121),
                ),
              ),
              const SizedBox(height: 16),
              CheckboxListTile(
                title: Text(
                  'Available Only',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                ),
                value: filterAvailableOnly,
                onChanged: (value) {
                  setState(() {
                    filterAvailableOnly = value ?? false;
                  });
                },
                activeColor: const Color(0xFF1E88E5),
              ),
              CheckboxListTile(
                title: Text(
                  'EV Charging',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                ),
                value: filterEVCharging,
                onChanged: (value) {
                  setState(() {
                    filterEVCharging = value ?? false;
                  });
                },
                activeColor: const Color(0xFF1E88E5),
              ),
              CheckboxListTile(
                title: Text(
                  'Near Me',
                  style: TextStyle(
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                ),
                value: filterNearMe,
                onChanged: (value) {
                  setState(() {
                    filterNearMe = value ?? false;
                  });
                },
                activeColor: const Color(0xFF1E88E5),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() {
                      _filterAvailableOnly = filterAvailableOnly;
                      _filterEVCharging = filterEVCharging;
                      _filterNearMe = filterNearMe;
                    });
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Apply Filters',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQRScanner() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const QRScannerScreen()),
    );
  }

  Future<void> _openDirections(Map<String, dynamic> spot) async {
    // Handle location as either LatLng or Map
    LatLng location;
    if (spot['location'] is LatLng) {
      location = spot['location'] as LatLng;
    } else if (spot['location'] is Map) {
      final locationMap = spot['location'] as Map<String, dynamic>;
      location = LatLng(
        (locationMap['lat'] ?? locationMap['latitude'] ?? 0.0).toDouble(),
        (locationMap['lng'] ?? locationMap['longitude'] ?? 0.0).toDouble(),
      );
    } else {
      return;
    }

    final parkingName = spot['name'] ?? 'Parking Spot';

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
      // If location access fails, show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text('Unable to get your location: ${e.toString()}'),
                ),
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
}

class _TrianglePainter extends CustomPainter {
  final Color color;

  _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final path = ui.Path()
      ..moveTo(size.width / 2, size.height)
      ..lineTo(0, 0)
      ..lineTo(size.width, 0)
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
