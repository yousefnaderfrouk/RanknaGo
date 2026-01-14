import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:ui' as ui;

class MapPickerScreen extends StatefulWidget {
  final LatLng? initialLocation;

  const MapPickerScreen({super.key, this.initialLocation});

  @override
  State<MapPickerScreen> createState() => _MapPickerScreenState();
}

class _MapPickerScreenState extends State<MapPickerScreen> {
  final MapController _mapController = MapController();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  LatLng? _selectedLocation;
  LatLng? _currentLocation;
  bool _isLoadingLocation = true;
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _selectedLocation = widget.initialLocation;
    _getCurrentLocation();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim();
    setState(() {
      _showSuggestions = query.isNotEmpty;
    });
    if (query.isNotEmpty) {
      _getSearchSuggestions(query);
    } else {
      setState(() {
        _searchSuggestions = [];
        _isSearching = false;
      });
    }
  }

  Future<void> _getSearchSuggestions(String query) async {
    setState(() {
      _isSearching = true;
    });

    try {
      // Use Nominatim (OpenStreetMap) - Free, no API key needed
      // Restricted to Egypt only
      final url = Uri.parse(
        'https://nominatim.openstreetmap.org/search?'
        'q=${Uri.encodeComponent(query)}&'
        'countrycodes=eg&'
        'format=json&'
        'limit=5&'
        'addressdetails=1',
      );

      final response = await http.get(
        url,
        headers: {'User-Agent': 'RaknaGo App'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (mounted) {
          setState(() {
            _searchSuggestions = data
                .map(
                  (item) => {
                    'description': item['display_name'] ?? '',
                    'lat': double.tryParse(item['lat'] ?? '0') ?? 0.0,
                    'lng': double.tryParse(item['lon'] ?? '0') ?? 0.0,
                  },
                )
                .toList();
            _isSearching = false;
            _showSuggestions = _searchSuggestions.isNotEmpty;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isSearching = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSearching = false;
        });
      }
    }
  }

  Future<void> _selectSuggestion(Map<String, dynamic> suggestion) async {
    _searchController.text = suggestion['description'] ?? '';
    setState(() {
      _showSuggestions = false;
    });
    _searchFocusNode.unfocus();

    // If suggestion has coordinates, use them directly
    if (suggestion['lat'] != null && suggestion['lng'] != null) {
      final location = LatLng(
        suggestion['lat'] as double,
        suggestion['lng'] as double,
      );
      setState(() {
        _selectedLocation = location;
      });
      _mapController.move(location, 15.0);
    } else if (suggestion['placeId'] != null) {
      // If using Google Places, get coordinates from place_id
      // This requires Google Places API Details endpoint
      // For now, we'll skip this and use Nominatim which provides coordinates directly
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          setState(() {
            _isLoadingLocation = false;
          });
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        setState(() {
          _isLoadingLocation = false;
        });
        return;
      }

      Position position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      setState(() {
        _currentLocation = LatLng(position.latitude, position.longitude);
        if (_selectedLocation == null) {
          _selectedLocation = _currentLocation;
        }
        _isLoadingLocation = false;
      });

      // Move map to current location
      if (_selectedLocation != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _mapController.move(_selectedLocation!, 15.0);
        });
      }
    } catch (e) {
      setState(() {
        _isLoadingLocation = false;
        if (_selectedLocation == null) {
          _selectedLocation = const LatLng(
            30.0444,
            31.2357,
          ); // Default to Cairo
        }
      });
    }
  }

  void _onMapTap(TapPosition tapPosition, LatLng point) {
    setState(() {
      _selectedLocation = point;
    });
  }

  @override
  Widget build(BuildContext context) {
    final defaultLocation = _selectedLocation ?? const LatLng(30.0444, 31.2357);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E88E5),
        title: const Text(
          'Select Location',
          style: TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          if (_isLoadingLocation)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
        ],
      ),
      body: Stack(
        children: [
          // Map
          Padding(
            padding: const EdgeInsets.only(top: 90),
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: defaultLocation,
                initialZoom: 15.0,
                onTap: _onMapTap,
              ),
              children: [
                TileLayer(
                  // Use OpenStreetMap tiles for stable public tiles
                  urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                  subdomains: const ['a', 'b', 'c'],
                  userAgentPackageName: 'com.raknago.app',
                  retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
                ),
                // Current location marker
                if (_currentLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _currentLocation!,
                        width: 40,
                        height: 40,
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.blue.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.my_location,
                            color: Colors.blue,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                // Selected location marker
                if (_selectedLocation != null)
                  MarkerLayer(
                    markers: [
                      Marker(
                        point: _selectedLocation!,
                        width: 50,
                        height: 50,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E88E5),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.white,
                                  width: 3,
                                ),
                              ),
                            ),
                            Positioned(
                              bottom: 0,
                              child: CustomPaint(
                                size: const Size(20, 20),
                                painter: _TrianglePainter(
                                  color: const Color(0xFF1E88E5),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
          // Search Bar
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _searchFocusNode.hasFocus
                            ? const Color(0xFF1E88E5)
                            : Colors.grey[300]!,
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _searchFocusNode.hasFocus
                              ? const Color(0xFF1E88E5).withOpacity(0.1)
                              : Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      focusNode: _searchFocusNode,
                      decoration: InputDecoration(
                        hintText: 'ابحث عن موقع في مصر...',
                        hintStyle: TextStyle(color: Colors.grey[400]),
                        prefixIcon: Container(
                          margin: const EdgeInsets.all(8),
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1E88E5).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: _isSearching
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      Color(0xFF1E88E5),
                                    ),
                                  ),
                                )
                              : const Icon(
                                  Icons.search_rounded,
                                  color: Color(0xFF1E88E5),
                                  size: 20,
                                ),
                        ),
                        suffixIcon: ValueListenableBuilder<TextEditingValue>(
                          valueListenable: _searchController,
                          builder: (context, value, child) {
                            return value.text.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear_rounded),
                                    color: Colors.grey[600],
                                    onPressed: () {
                                      _searchController.clear();
                                      setState(() {
                                        _showSuggestions = false;
                                      });
                                    },
                                  )
                                : const SizedBox.shrink();
                          },
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                      ),
                      onTap: () {
                        setState(() {
                          _showSuggestions = _searchController.text.isNotEmpty;
                        });
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Search Suggestions (outside search bar container)
          if (_showSuggestions &&
              _searchSuggestions.isNotEmpty &&
              _searchController.text.trim().isNotEmpty)
            Positioned(
              top: 90,
              left: 16,
              right: 16,
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(16),
                color: Colors.transparent,
                child: Container(
                  constraints: const BoxConstraints(maxHeight: 300),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: ListView.builder(
                      shrinkWrap: true,
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: _searchSuggestions.length,
                      itemBuilder: (context, index) {
                        final suggestion = _searchSuggestions[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _selectSuggestion(suggestion),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200]!,
                                    width: index < _searchSuggestions.length - 1
                                        ? 1
                                        : 0,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF1E88E5,
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(
                                      Icons.location_on_rounded,
                                      color: Color(0xFF1E88E5),
                                      size: 20,
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      suggestion['description'] ?? '',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF212121),
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
            ),
          // Location info card
          Positioned(
            bottom: 20,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF1E88E5),
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Selected Location',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF212121),
                              ),
                            ),
                            const SizedBox(height: 4),
                            if (_selectedLocation != null)
                              Text(
                                'Lat: ${_selectedLocation!.latitude.toStringAsFixed(6)}\nLng: ${_selectedLocation!.longitude.toStringAsFixed(6)}',
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
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            if (_currentLocation != null) {
                              setState(() {
                                _selectedLocation = _currentLocation;
                              });
                              _mapController.move(_currentLocation!, 15.0);
                            }
                          },
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF1E88E5),
                            side: const BorderSide(color: Color(0xFF1E88E5)),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Use Current Location'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: _selectedLocation != null
                              ? () {
                                  Navigator.pop(context, _selectedLocation);
                                }
                              : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1E88E5),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                          child: const Text('Confirm'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
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

    final path = ui.Path();
    path.moveTo(size.width / 2, size.height);
    path.lineTo(0, 0);
    path.lineTo(size.width, 0);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
