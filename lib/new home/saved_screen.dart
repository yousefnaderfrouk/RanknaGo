import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'parking_details_screen.dart';
import 'directions_map_screen.dart';
import '../theme_provider.dart';
import '../language_provider.dart';

class SavedScreen extends StatefulWidget {
  const SavedScreen({super.key});

  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  List<Map<String, dynamic>> _savedParkings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSavedParkings();
  }

  Future<void> _loadSavedParkings() async {
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final savedSpotsSnapshot = await _firestore
            .collection('saved_spots')
            .where('userId', isEqualTo: user.uid)
            .get();

        final List<Map<String, dynamic>> savedParkings = [];

        for (var doc in savedSpotsSnapshot.docs) {
          final data = doc.data();
          final spotId = data['spotId'] as String?;

          if (spotId != null) {
            try {
              final spotDoc = await _firestore
                  .collection('parking_spots')
                  .doc(spotId)
                  .get();

              if (spotDoc.exists) {
                final spotData = spotDoc.data()!;

                // Calculate distance
                String? distance;
                String? duration;
                try {
                  final position = await Geolocator.getCurrentPosition();
                  final locationData =
                      spotData['location'] as Map<String, dynamic>?;

                  if (locationData != null) {
                    final lat = (locationData['lat'] ?? 0.0).toDouble();
                    final lng = (locationData['lng'] ?? 0.0).toDouble();
                    final parkingLocation = LatLng(lat, lng);

                    final distanceInMeters = Geolocator.distanceBetween(
                      position.latitude,
                      position.longitude,
                      parkingLocation.latitude,
                      parkingLocation.longitude,
                    );

                    if (distanceInMeters < 1000) {
                      distance = '${distanceInMeters.toStringAsFixed(0)} m';
                    } else {
                      distance =
                          '${(distanceInMeters / 1000).toStringAsFixed(1)} km';
                    }

                    // Calculate duration (average speed: 50 km/h in city)
                    final distanceInKm = distanceInMeters / 1000;
                    final durationInMinutes = (distanceInKm / 50 * 60).round();

                    if (durationInMinutes < 1) {
                      duration = '< 1 min';
                    } else if (durationInMinutes < 60) {
                      duration = '$durationInMinutes mins';
                    } else {
                      final hours = durationInMinutes ~/ 60;
                      final mins = durationInMinutes % 60;
                      if (mins == 0) {
                        duration = '$hours ${hours == 1 ? 'hour' : 'hours'}';
                      } else {
                        duration = '$hours h $mins mins';
                      }
                    }
                  }
                } catch (e) {
                  // Error calculating distance
                }

                savedParkings.add({
                  'id': spotId,
                  'name': spotData['name'] ?? 'Parking Spot',
                  'address': spotData['address'] ?? 'Unknown address',
                  'rating': (spotData['rating'] ?? 0.0).toDouble(),
                  'reviewCount': spotData['reviewCount'] ?? 0,
                  'distance': distance ?? 'N/A',
                  'duration': duration ?? 'N/A',
                  'available': (spotData['availableSpots'] ?? 0) > 0,
                  'chargers': spotData['evChargerCount'] ?? 0,
                  'amenities': spotData['amenities'] as List<dynamic>? ?? [],
                  'location': spotData['location'],
                  'pricePerHour': spotData['pricePerHour'] ?? 0.0,
                  'totalSpots': spotData['totalSpots'] ?? 0,
                  'availableSpots': spotData['availableSpots'] ?? 0,
                  'hasEVCharging': spotData['hasEVCharging'] ?? false,
                  'description': spotData['description'],
                  'imageUrl': spotData['imageUrl'],
                });
              }
            } catch (e) {
              // Error loading spot data
            }
          }
        }

        if (mounted) {
          setState(() {
            _savedParkings = savedParkings;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
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
                Icons.bookmark_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              context.translate('Saved'),
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
            onPressed: () {
              _showSearchDialog();
            },
          ),
        ],
      ),
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(color: const Color(0xFF1E88E5)),
            )
          : _savedParkings.isEmpty
          ? _buildEmptyState(isDark)
          : RefreshIndicator(
              onRefresh: _loadSavedParkings,
              color: const Color(0xFF1E88E5),
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _savedParkings.length,
                itemBuilder: (context, index) {
                  return _buildParkingCard(_savedParkings[index], isDark);
                },
              ),
            ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.bookmark_border_rounded,
            size: 80,
            color: isDark ? Colors.grey[700] : Colors.grey[300],
          ),
          const SizedBox(height: 16),
          Text(
            context.translate('No Saved Parkings'),
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.grey[300] : Colors.grey[600],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.translate(
              'Save your favorite parking spots\nfor quick access',
            ),
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? Colors.grey[500] : Colors.grey[500],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParkingCard(Map<String, dynamic> parking, bool isDark) {
    final name = parking['name'] ?? 'Parking Spot';
    final address = parking['address'] ?? 'Unknown address';
    final rating = (parking['rating'] ?? 0.0).toDouble();
    final reviewCount = parking['reviewCount'] ?? 0;
    final distance = parking['distance'] ?? 'N/A';
    final duration = parking['duration'] ?? 'N/A';
    final isAvailable = parking['available'] ?? true;
    final chargers = parking['chargers'] ?? 0;
    final amenities = parking['amenities'] as List<dynamic>? ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
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
          // Header (Name + Direction button)
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 16,
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
                  _showDirections(parking);
                },
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: const BoxDecoration(
                    color: Color(0xFF1E88E5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.navigation_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Rating
          Row(
            children: [
              Text(
                rating.toStringAsFixed(1),
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF212121),
                ),
              ),
              const SizedBox(width: 6),
              ...List.generate(5, (index) {
                if (index < rating.floor()) {
                  return const Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: Color(0xFFFDB913),
                  );
                } else if (index < rating) {
                  return const Icon(
                    Icons.star_half_rounded,
                    size: 16,
                    color: Color(0xFFFDB913),
                  );
                } else {
                  return Icon(
                    Icons.star_outline_rounded,
                    size: 16,
                    color: isDark ? Colors.grey[700] : Colors.grey[300],
                  );
                }
              }),
              const SizedBox(width: 6),
              Text(
                '($reviewCount ${context.translate('reviews')})',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[500] : Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Status with spots count, Distance, Duration
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isAvailable
                      ? const Color(0xFF1E88E5).withOpacity(0.1)
                      : Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isAvailable
                      ? '${parking['availableSpots'] ?? 0} ${context.translate('spots')}'
                      : context.translate('Full'),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: isAvailable ? const Color(0xFF1E88E5) : Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.location_on_outlined,
                size: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                distance,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
              const SizedBox(width: 12),
              Icon(
                Icons.access_time_rounded,
                size: 14,
                color: isDark ? Colors.grey[500] : Colors.grey[600],
              ),
              const SizedBox(width: 4),
              Text(
                duration,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Amenities + Chargers
          Row(
            children: [
              ...amenities.take(4).map((amenity) {
                return Padding(
                  padding: const EdgeInsets.only(right: 12),
                  child: Icon(
                    _getAmenityIcon(amenity),
                    size: 22,
                    color: isDark ? Colors.grey[500] : Colors.grey[600],
                  ),
                );
              }).toList(),
              const Spacer(),
              if (chargers > 0)
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ParkingDetailsScreen(parking: parking),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      Text(
                        '$chargers ${context.translate('chargers')}',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 12,
                        color: Color(0xFF1E88E5),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 16),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ParkingDetailsScreen(parking: parking),
                      ),
                    );
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
                    padding: const EdgeInsets.symmetric(vertical: 12),
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
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ParkingDetailsScreen(parking: parking),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Text(
                    context.translate('Book'),
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

  IconData _getAmenityIcon(String amenity) {
    switch (amenity.toLowerCase()) {
      case 'wifi':
        return Icons.wifi_rounded;
      case 'ev_charging':
      case 'ev':
        return Icons.ev_station_rounded;
      case 'cctv':
        return Icons.videocam_rounded;
      case 'covered':
        return Icons.roofing_rounded;
      case 'security':
        return Icons.security_rounded;
      case '24/7':
        return Icons.access_time_filled_rounded;
      case 'restaurant':
        return Icons.restaurant_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      case 'accessible':
        return Icons.accessible_rounded;
      default:
        return Icons.check_circle_outline_rounded;
    }
  }

  Future<void> _showDirections(Map<String, dynamic> parking) async {
    try {
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      final userLocation = LatLng(position.latitude, position.longitude);

      // Handle location as either LatLng or Map
      LatLng destination;
      if (parking['location'] is LatLng) {
        destination = parking['location'] as LatLng;
      } else if (parking['location'] is Map) {
        final locationMap = parking['location'] as Map<String, dynamic>;
        destination = LatLng(
          (locationMap['lat'] ?? locationMap['latitude'] ?? 0.0).toDouble(),
          (locationMap['lng'] ?? locationMap['longitude'] ?? 0.0).toDouble(),
        );
      } else {
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
              parkingName: parking['name'] ?? 'Parking Spot',
              userAvatarUrl: userAvatarUrl,
            ),
          ),
        );
      }
    } catch (e) {
      // Error getting location
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
              context.translate('Search Saved'),
              style: TextStyle(
                color: isDark ? Colors.white : const Color(0xFF212121),
              ),
            ),
          ],
        ),
        content: TextField(
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
          decoration: InputDecoration(
            hintText: context.translate('Search'),
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
