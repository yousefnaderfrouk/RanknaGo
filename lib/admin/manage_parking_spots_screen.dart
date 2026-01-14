import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:latlong2/latlong.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../config/cloudinary_config.dart';
import 'map_picker_screen.dart';

class ManageParkingSpotsScreen extends StatefulWidget {
  const ManageParkingSpotsScreen({super.key});

  @override
  State<ManageParkingSpotsScreen> createState() =>
      _ManageParkingSpotsScreenState();
}

class _ManageParkingSpotsScreenState extends State<ManageParkingSpotsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final ImagePicker _imagePicker = ImagePicker();
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchQuery = '';
  String _filterStatus = 'All';
  bool _isLoading = true;
  List<Map<String, dynamic>> _parkingSpots = [];
  List<Map<String, dynamic>> _searchSuggestions = [];
  bool _showSuggestions = false;

  @override
  void initState() {
    super.initState();
    _loadParkingSpots();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    final query = _searchController.text;
    setState(() {
      _searchQuery = query;
      _showSuggestions = query.isNotEmpty;
    });
    if (query.isNotEmpty) {
      _getSearchSuggestions(query);
    } else {
      setState(() {
        _searchSuggestions = [];
      });
    }
  }

  Future<void> _getSearchSuggestions(String query) async {
    // Search only in existing parking spots
    _getLocalSuggestions(query);
  }

  List<Map<String, dynamic>> _getLocalSuggestionsList(String query) {
    return _parkingSpots
        .where(
          (spot) =>
              spot['name'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ) ||
              spot['address'].toString().toLowerCase().contains(
                query.toLowerCase(),
              ),
        )
        .take(5)
        .map(
          (spot) => {
            'description': '${spot['name']} - ${spot['address']}',
            'spotId': spot['id'],
          },
        )
        .toList();
  }

  void _getLocalSuggestions(String query) {
    final suggestions = _getLocalSuggestionsList(query);
    setState(() {
      _searchSuggestions = suggestions;
    });
  }

  void _selectSuggestion(Map<String, dynamic> suggestion) {
    // Select a parking spot from suggestions
    _searchController.text = suggestion['description'] ?? '';
    setState(() {
      _searchQuery = suggestion['description'] ?? '';
      _showSuggestions = false;
    });
    _searchFocusNode.unfocus();

    // The filtered list will automatically show the selected spot
    // because _searchQuery is updated and _filteredSpots uses it
  }

  Future<void> _loadParkingSpots() async {
    try {
      final spotsSnapshot = await _firestore.collection('parking_spots').get();
      final List<Map<String, dynamic>> spots = [];

      for (var doc in spotsSnapshot.docs) {
        final data = doc.data();
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate();

        // Generate QR code if not exists
        String qrCode = data['qrCode'] ?? doc.id;
        if (data['qrCode'] == null) {
          // Update spot with QR code if it doesn't exist
          await doc.reference.update({'qrCode': qrCode});
        }

        spots.add({
          'id': doc.id,
          'qrCode': qrCode,
          'name': data['name'] ?? 'Unknown',
          'description': data['description'] ?? '',
          'location': data['location'] ?? {'lat': 0.0, 'lng': 0.0},
          'address': data['address'] ?? '',
          'pricePerHour': (data['pricePerHour'] ?? 0.0).toDouble(),
          'hasEVCharging': data['hasEVCharging'] ?? false,
          'evChargingPrice': (data['evChargingPrice'] ?? 0.0).toDouble(),
          'evChargerCount': data['evChargerCount'] ?? 0,
          'totalSpots': data['totalSpots'] ?? 0,
          'availableSpots': data['availableSpots'] ?? 0,
          'rating': (data['rating'] ?? 0.0).toDouble(),
          'reviewCount': data['reviewCount'] ?? 0,
          'amenities': data['amenities'] ?? <String>[],
          'isActive': data['isActive'] ?? true,
          'createdAt': createdAt != null
              ? DateFormat('yyyy-MM-dd').format(createdAt)
              : 'N/A',
        });
      }

      setState(() {
        _parkingSpots = spots;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading parking spots: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  List<Map<String, dynamic>> get _filteredSpots {
    return _parkingSpots.where((spot) {
      final matchesSearch =
          spot['name'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          ) ||
          spot['address'].toString().toLowerCase().contains(
            _searchQuery.toLowerCase(),
          );

      final matchesStatus =
          _filterStatus == 'All' ||
          (_filterStatus == 'Active' && spot['isActive']) ||
          (_filterStatus == 'Inactive' && !spot['isActive']);

      return matchesSearch && matchesStatus;
    }).toList();
  }

  Future<String> _uploadImageToCloudinary(
    String imagePath,
    String publicId,
  ) async {
    try {
      // إنشاء request
      final uri = Uri.parse(CloudinaryConfig.uploadUrl);
      final request = http.MultipartRequest('POST', uri);

      // إضافة الصورة
      request.files.add(await http.MultipartFile.fromPath('file', imagePath));

      // إضافة المعاملات
      request.fields['upload_preset'] = CloudinaryConfig.uploadPreset;
      request.fields['public_id'] = publicId;
      request.fields['folder'] = 'raknago/parking_spots';

      // إرسال الطلب
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final jsonData = jsonDecode(response.body);
        final downloadUrl = jsonData['secure_url'] as String;
        return downloadUrl;
      } else {
        final errorData = jsonDecode(response.body);
        throw errorData['error']['message'] ?? 'Upload failed';
      }
    } catch (e) {
      throw 'Error uploading image: $e';
    }
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
          'Manage Parking Spots',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: Colors.white),
            onPressed: _showAddSpotDialog,
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
                // Enhanced Search Bar
                Stack(
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
                          hintText: 'ابحث عن ركنة موجودة...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Container(
                            margin: const EdgeInsets.all(8),
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E88E5).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(
                              Icons.search_rounded,
                              color: Color(0xFF1E88E5),
                              size: 20,
                            ),
                          ),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded),
                                  color: Colors.grey[600],
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchQuery = '';
                                      _showSuggestions = false;
                                    });
                                  },
                                )
                              : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 16,
                          ),
                        ),
                        onTap: () {
                          setState(() {
                            _showSuggestions =
                                _searchController.text.isNotEmpty;
                          });
                        },
                      ),
                    ),
                    // Search Suggestions
                    if (_showSuggestions && _searchSuggestions.isNotEmpty)
                      Positioned(
                        top: 60,
                        left: 0,
                        right: 0,
                        child: Container(
                          constraints: const BoxConstraints(maxHeight: 300),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ListView.builder(
                            shrinkWrap: true,
                            itemCount: _searchSuggestions.length,
                            itemBuilder: (context, index) {
                              final suggestion = _searchSuggestions[index];
                              return InkWell(
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
                                        width:
                                            index <
                                                _searchSuggestions.length - 1
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
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
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
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Active'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Inactive'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Spots List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredSpots.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_parking_rounded,
                          size: 80,
                          color: Colors.grey[300],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No parking spots found',
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
                    itemCount: _filteredSpots.length,
                    itemBuilder: (context, index) {
                      return _buildSpotCard(_filteredSpots[index]);
                    },
                  ),
          ),
        ],
      ),
      floatingActionButton: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFF1E88E5).withOpacity(0.4),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showAddSpotDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(Icons.add_rounded, size: 24),
          label: const Text(
            'Add Spot',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
                  colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                )
              : null,
          color: isSelected ? null : Colors.grey[100],
          borderRadius: BorderRadius.circular(25),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: const Color(0xFF1E88E5).withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isSelected) ...[
              const Icon(
                Icons.check_circle_rounded,
                size: 16,
                color: Colors.white,
              ),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isSelected ? Colors.white : Colors.grey[700],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSpotCard(Map<String, dynamic> spot) {
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
                Row(
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: spot['isActive']
                            ? const Color(0xFF1E88E5).withOpacity(0.1)
                            : Colors.grey[200],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.local_parking_rounded,
                        color: spot['isActive']
                            ? const Color(0xFF1E88E5)
                            : Colors.grey[500],
                        size: 28,
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
                                  spot['name'],
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
                                  color: spot['isActive']
                                      ? Colors.green.withOpacity(0.1)
                                      : Colors.red.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  spot['isActive'] ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: spot['isActive']
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            spot['address'],
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
                Text(
                  spot['description'],
                  style: TextStyle(fontSize: 14, color: Colors.grey[700]),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.location_on_rounded,
                        color: Color(0xFF1E88E5),
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Coordinates',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            Text(
                              'Lat: ${spot['location']['lat']}, Lng: ${spot['location']['lng']}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF212121),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _buildInfoItem(
                        'Price/Hour',
                        'EGP ${spot['pricePerHour']}',
                        Icons.attach_money_rounded,
                      ),
                    ),
                    Expanded(
                      child: _buildInfoItem(
                        'Availability',
                        '${spot['availableSpots']}/${spot['totalSpots']}',
                        Icons.check_circle_rounded,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (spot['hasEVCharging'])
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.ev_station_rounded,
                          color: Colors.green,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'EV Charging Available',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.green[700],
                            ),
                          ),
                        ),
                        Text(
                          'EGP ${spot['evChargingPrice']}/kWh',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.green[700],
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          Container(
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(16),
                bottomRight: Radius.circular(16),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Flexible(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF1E88E5).withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _showEditSpotDialog(spot),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: const [
                                Icon(
                                  Icons.edit_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    'Edit',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    width: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E88E5).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF1E88E5).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => _showQRCodeDialog(spot),
                        borderRadius: BorderRadius.circular(12),
                        child: const Padding(
                          padding: EdgeInsets.all(10),
                          child: Icon(
                            Icons.qr_code_rounded,
                            size: 18,
                            color: Color(0xFF1E88E5),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: spot['isActive']
                            ? Colors.orange[50]
                            : Colors.green[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: spot['isActive']
                              ? Colors.orange[200]!
                              : Colors.green[200]!,
                          width: 1,
                        ),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _toggleSpotStatus(spot),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  spot['isActive']
                                      ? Icons.visibility_off_rounded
                                      : Icons.visibility_rounded,
                                  size: 16,
                                  color: spot['isActive']
                                      ? Colors.orange[700]
                                      : Colors.green[700],
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: Text(
                                    spot['isActive']
                                        ? 'Deactivate'
                                        : 'Activate',
                                    style: TextStyle(
                                      color: spot['isActive']
                                          ? Colors.orange[700]
                                          : Colors.green[700],
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.red[200]!, width: 1),
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => _deleteSpot(spot),
                          borderRadius: BorderRadius.circular(12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.delete_outline_rounded,
                                  size: 16,
                                  color: Colors.red[700],
                                ),
                                const SizedBox(width: 4),
                                const Flexible(
                                  child: Text(
                                    'Delete',
                                    style: TextStyle(
                                      color: Colors.red,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
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
    );
  }

  Map<String, dynamic> _getAmenityData(String amenity) {
    final amenitiesMap = {
      'ev_charging': {
        'icon': Icons.ev_station_rounded,
        'label': 'EV Charging',
        'color': Colors.green[600]!,
      },
      'security': {
        'icon': Icons.security_rounded,
        'label': 'Security',
        'color': Colors.blue[600]!,
      },
      'covered': {
        'icon': Icons.roofing_rounded,
        'label': 'Covered',
        'color': Colors.orange[600]!,
      },
      'accessible': {
        'icon': Icons.accessible_rounded,
        'label': 'Accessible',
        'color': Colors.purple[600]!,
      },
      'cctv': {
        'icon': Icons.videocam_rounded,
        'label': 'CCTV',
        'color': Colors.red[600]!,
      },
      'lighting': {
        'icon': Icons.lightbulb_rounded,
        'label': 'Lighting',
        'color': Colors.amber[600]!,
      },
      'restaurant': {
        'icon': Icons.restaurant_rounded,
        'label': 'Restaurant',
        'color': Colors.brown[600]!,
      },
      'shopping': {
        'icon': Icons.shopping_bag_rounded,
        'label': 'Shopping',
        'color': Colors.pink[600]!,
      },
      'wifi': {
        'icon': Icons.wifi_rounded,
        'label': 'WiFi',
        'color': Colors.cyan[600]!,
      },
    };
    return amenitiesMap[amenity] ??
        {
          'icon': Icons.check_circle_rounded,
          'label': amenity.replaceAll('_', ' ').toUpperCase(),
          'color': Colors.grey[600]!,
        };
  }

  Widget _buildInfoItem(String label, String value, IconData icon) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
            Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Color(0xFF212121),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showAddSpotDialog() {
    final nameController = TextEditingController();
    final descController = TextEditingController();
    final addressController = TextEditingController();
    final latController = TextEditingController();
    final lngController = TextEditingController();
    final priceController = TextEditingController();
    final totalSpotsController = TextEditingController();
    final evPriceController = TextEditingController();
    final ratingController = TextEditingController(text: '0.0');
    final reviewCountController = TextEditingController(text: '0');
    final evChargerCountController = TextEditingController(text: '0');
    File? selectedImage;
    final mondayFridayController = TextEditingController(
      text: '6:00 AM - 11:00 PM',
    );
    final saturdayController = TextEditingController(
      text: '7:00 AM - 10:00 PM',
    );
    final sundayController = TextEditingController(text: '8:00 AM - 9:00 PM');
    bool hasEVCharging = false;
    List<String> selectedAmenities = [];

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_location_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Add Parking Spot',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Field
                        _buildEnhancedTextField(
                          controller: nameController,
                          label: 'Name',
                          hint: 'e.g., City Center Parking',
                          icon: Icons.label_rounded,
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        // Description Field
                        _buildEnhancedTextField(
                          controller: descController,
                          label: 'Description',
                          hint: 'Describe the parking location',
                          icon: Icons.description_rounded,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        // Address Field
                        _buildEnhancedTextField(
                          controller: addressController,
                          label: 'Address',
                          hint: 'Full address',
                          icon: Icons.location_on_rounded,
                        ),
                        const SizedBox(height: 16),
                        // Location picker button
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              LatLng? initialLocation;
                              if (latController.text.isNotEmpty &&
                                  lngController.text.isNotEmpty) {
                                try {
                                  initialLocation = LatLng(
                                    double.parse(latController.text),
                                    double.parse(lngController.text),
                                  );
                                } catch (e) {
                                  // Invalid coordinates
                                }
                              }

                              final selectedLocation =
                                  await Navigator.push<LatLng>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapPickerScreen(
                                        initialLocation: initialLocation,
                                      ),
                                    ),
                                  );

                              if (selectedLocation != null) {
                                setDialogState(() {
                                  latController.text = selectedLocation.latitude
                                      .toStringAsFixed(6);
                                  lngController.text = selectedLocation
                                      .longitude
                                      .toStringAsFixed(6);
                                });
                              }
                            },
                            icon: const Icon(Icons.map_rounded, size: 20),
                            label: const Text(
                              'Pick Location from Map',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Coordinates Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: latController,
                                label: 'Latitude',
                                icon: Icons.my_location_rounded,
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: lngController,
                                label: 'Longitude',
                                icon: Icons.my_location_rounded,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Price and Total Spots Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: priceController,
                                label: 'Price/Hour (EGP)',
                                hint: '0.0',
                                icon: Icons.currency_pound_rounded,
                                keyboardType: TextInputType.number,
                                isRequired: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: totalSpotsController,
                                label: 'Total Spots',
                                hint: '0',
                                icon: Icons.local_parking_rounded,
                                keyboardType: TextInputType.number,
                                isRequired: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Rating and Review Count Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: ratingController,
                                label: 'Rating (0.0 - 5.0)',
                                hint: '0.0',
                                icon: Icons.star_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: reviewCountController,
                                label: 'Review Count',
                                hint: '0',
                                icon: Icons.reviews_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Image Upload Field (Required)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: selectedImage == null
                                  ? Colors.red[300]!
                                  : Colors.grey[200]!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.image_rounded,
                                    color: selectedImage == null
                                        ? Colors.red[400]
                                        : const Color(0xFF1E88E5),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Parking Spot Image *',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF212121),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (selectedImage != null)
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: FileImage(selectedImage!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedImage = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No image selected',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final XFile? image = await _imagePicker
                                        .pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 85,
                                        );
                                    if (image != null) {
                                      setDialogState(() {
                                        selectedImage = File(image.path);
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.upload_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Select Image from Gallery',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        // EV Charging Checkbox
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: CheckboxListTile(
                            value: hasEVCharging,
                            onChanged: (value) {
                              setDialogState(() {
                                hasEVCharging = value!;
                              });
                            },
                            title: const Text(
                              'EV Charging Available',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            activeColor: const Color(0xFF1E88E5),
                            controlAffinity: ListTileControlAffinity.leading,
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                          ),
                        ),
                        if (hasEVCharging) ...[
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: _buildEnhancedTextField(
                                  controller: evPriceController,
                                  label: 'EV Price (EGP/kWh)',
                                  hint: '0.0',
                                  icon: Icons.ev_station_rounded,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: _buildEnhancedTextField(
                                  controller: evChargerCountController,
                                  label: 'Charger Count',
                                  hint: '0',
                                  icon: Icons.ev_station_rounded,
                                  keyboardType: TextInputType.number,
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),
                        // Operating Hours Section
                        GestureDetector(
                          onTap: () {
                            _showOperatingHoursDialog(
                              context,
                              setDialogState,
                              mondayFridayController,
                              saturdayController,
                              sundayController,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      color: Colors.blue[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Operating Hours',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.blue[700],
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildEnhancedTextField(
                                        controller: mondayFridayController,
                                        label: 'Mon-Fri',
                                        hint: '6:00 AM - 11:00 PM',
                                        icon: Icons.calendar_today_rounded,
                                        readOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildEnhancedTextField(
                                        controller: saturdayController,
                                        label: 'Saturday',
                                        hint: '7:00 AM - 10:00 PM',
                                        icon: Icons.calendar_today_rounded,
                                        readOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildEnhancedTextField(
                                        controller: sundayController,
                                        label: 'Sunday',
                                        hint: '8:00 AM - 9:00 PM',
                                        icon: Icons.calendar_today_rounded,
                                        readOnly: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Amenities Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.room_service_rounded,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Amenities',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF212121),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    [
                                      'ev_charging',
                                      'security',
                                      'covered',
                                      'accessible',
                                      'cctv',
                                      'lighting',
                                      'restaurant',
                                      'shopping',
                                      'wifi',
                                    ].map((amenity) {
                                      final isSelected = selectedAmenities
                                          .contains(amenity);
                                      final amenityData = _getAmenityData(
                                        amenity,
                                      );
                                      return InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            if (isSelected) {
                                              selectedAmenities.remove(amenity);
                                            } else {
                                              selectedAmenities.add(amenity);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF1E88E5),
                                                      Color(0xFF1976D2),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            color: isSelected
                                                ? null
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF1E88E5,
                                                      ).withOpacity(0.4),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        3,
                                                      ),
                                                      spreadRadius: 0,
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                amenityData['icon'],
                                                size: 18,
                                                color: isSelected
                                                    ? Colors.white
                                                    : amenityData['color'],
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                amenityData['label'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.grey[800],
                                                ),
                                              ),
                                              if (isSelected) ...[
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.check_circle,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              if (nameController.text.isEmpty ||
                                  priceController.text.isEmpty ||
                                  totalSpotsController.text.isEmpty ||
                                  selectedImage == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      selectedImage == null
                                          ? 'Please select an image'
                                          : 'Please fill all required fields',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              try {
                                // Upload image to Cloudinary
                                String? imageUrl;
                                if (selectedImage != null) {
                                  imageUrl = await _uploadImageToCloudinary(
                                    selectedImage!.path,
                                    'raknago/parking_spots/${DateTime.now().millisecondsSinceEpoch}_${nameController.text.replaceAll(' ', '_')}',
                                  );
                                }

                                final newSpotData = {
                                  'name': nameController.text,
                                  'description': descController.text,
                                  'address': addressController.text,
                                  'location': {
                                    'lat':
                                        double.tryParse(latController.text) ??
                                        30.0444,
                                    'lng':
                                        double.tryParse(lngController.text) ??
                                        31.2357,
                                  },
                                  'pricePerHour':
                                      double.tryParse(priceController.text) ??
                                      0.0,
                                  'totalSpots':
                                      int.tryParse(totalSpotsController.text) ??
                                      0,
                                  'availableSpots':
                                      int.tryParse(totalSpotsController.text) ??
                                      0,
                                  'hasEVCharging': hasEVCharging,
                                  'evChargingPrice':
                                      double.tryParse(evPriceController.text) ??
                                      0.0,
                                  'evChargerCount': hasEVCharging
                                      ? int.tryParse(
                                              evChargerCountController.text,
                                            ) ??
                                            0
                                      : 0,
                                  'rating':
                                      double.tryParse(ratingController.text) ??
                                      0.0,
                                  'reviewCount':
                                      int.tryParse(
                                        reviewCountController.text,
                                      ) ??
                                      0,
                                  'amenities': selectedAmenities,
                                  'imageUrl': imageUrl,
                                  'operatingHours': {
                                    'mondayFriday': mondayFridayController.text,
                                    'saturday': saturdayController.text,
                                    'sunday': sundayController.text,
                                  },
                                  'isActive': true,
                                  'createdAt': FieldValue.serverTimestamp(),
                                  'updatedAt': FieldValue.serverTimestamp(),
                                };

                                final docRef = await _firestore
                                    .collection('parking_spots')
                                    .add(newSpotData);

                                // Generate QR code data (using spot ID)
                                final qrCodeData = docRef.id;

                                // Update spot with QR code
                                await docRef.update({'qrCode': qrCodeData});

                                final newSpot = {
                                  'id': docRef.id,
                                  'qrCode': qrCodeData,
                                  ...newSpotData,
                                  'createdAt': DateFormat(
                                    'yyyy-MM-dd',
                                  ).format(DateTime.now()),
                                };

                                // Save context before closing dialog
                                final scaffoldContext = context;

                                setState(() {
                                  _parkingSpots.add(newSpot);
                                });

                                Navigator.pop(context);

                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    scaffoldContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: const Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle_outline,
                                            color: Colors.white,
                                          ),
                                          SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Parking spot added successfully!',
                                            ),
                                          ),
                                        ],
                                      ),
                                      backgroundColor: Colors.green[400],
                                      behavior: SnackBarBehavior.floating,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      duration: const Duration(seconds: 2),
                                    ),
                                  );
                                }
                              } catch (e) {
                                // Save context before closing dialog
                                final scaffoldContext = context;

                                // Close dialog if still open
                                try {
                                  Navigator.pop(context);
                                } catch (_) {
                                  // Dialog might already be closed
                                }

                                if (mounted) {
                                  ScaffoldMessenger.of(
                                    scaffoldContext,
                                  ).showSnackBar(
                                    SnackBar(
                                      content: Row(
                                        children: [
                                          const Icon(
                                            Icons.error_outline,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              'Error adding spot: ${e.toString()}',
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

                                print('Error adding parking spot: $e');
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.add_circle_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Add Spot',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    required IconData icon,
    TextInputType? keyboardType,
    int maxLines = 1,
    bool readOnly = false,
    bool isRequired = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          labelText: isRequired ? '$label *' : label,
          hintText: hint,
          prefixIcon: Container(
            margin: const EdgeInsets.all(12),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF1E88E5).withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: const Color(0xFF1E88E5), size: 20),
          ),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
          labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
          hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
        ),
        keyboardType: keyboardType,
        maxLines: maxLines,
        readOnly: readOnly,
        style: const TextStyle(fontSize: 14, color: Color(0xFF212121)),
      ),
    );
  }

  void _showEditSpotDialog(Map<String, dynamic> spot) {
    final nameController = TextEditingController(text: spot['name']);
    final descController = TextEditingController(text: spot['description']);
    final addressController = TextEditingController(text: spot['address']);
    final latController = TextEditingController(
      text: spot['location']['lat'].toString(),
    );
    final lngController = TextEditingController(
      text: spot['location']['lng'].toString(),
    );
    final priceController = TextEditingController(
      text: spot['pricePerHour'].toString(),
    );
    final totalSpotsController = TextEditingController(
      text: spot['totalSpots'].toString(),
    );
    final evPriceController = TextEditingController(
      text: spot['evChargingPrice'].toString(),
    );
    final ratingController = TextEditingController(
      text: (spot['rating'] ?? 0.0).toString(),
    );
    final reviewCountController = TextEditingController(
      text: (spot['reviewCount'] ?? 0).toString(),
    );
    final evChargerCountController = TextEditingController(
      text: (spot['evChargerCount'] ?? 0).toString(),
    );
    File? selectedImage;
    String? currentImageUrl = spot['imageUrl'];
    final operatingHours =
        spot['operatingHours'] as Map<String, dynamic>? ??
        {
          'mondayFriday': '6:00 AM - 11:00 PM',
          'saturday': '7:00 AM - 10:00 PM',
          'sunday': '8:00 AM - 9:00 PM',
        };
    final mondayFridayController = TextEditingController(
      text: operatingHours['mondayFriday'] ?? '6:00 AM - 11:00 PM',
    );
    final saturdayController = TextEditingController(
      text: operatingHours['saturday'] ?? '7:00 AM - 10:00 PM',
    );
    final sundayController = TextEditingController(
      text: operatingHours['sunday'] ?? '8:00 AM - 9:00 PM',
    );
    bool hasEVCharging = spot['hasEVCharging'];
    List<String> selectedAmenities = List<String>.from(spot['amenities'] ?? []);

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: Container(
            constraints: const BoxConstraints(maxHeight: 600),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.edit_location_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Edit Parking Spot',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(
                          Icons.close_rounded,
                          color: Colors.white,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                ),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Name Field
                        _buildEnhancedTextField(
                          controller: nameController,
                          label: 'Name',
                          hint: 'e.g., City Center Parking',
                          icon: Icons.label_rounded,
                          isRequired: true,
                        ),
                        const SizedBox(height: 16),
                        // Description Field
                        _buildEnhancedTextField(
                          controller: descController,
                          label: 'Description',
                          hint: 'Describe the parking location',
                          icon: Icons.description_rounded,
                          maxLines: 2,
                        ),
                        const SizedBox(height: 16),
                        // Address Field
                        _buildEnhancedTextField(
                          controller: addressController,
                          label: 'Address',
                          hint: 'Full address',
                          icon: Icons.location_on_rounded,
                        ),
                        const SizedBox(height: 16),
                        // Location picker button
                        Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              LatLng? initialLocation;
                              if (latController.text.isNotEmpty &&
                                  lngController.text.isNotEmpty) {
                                try {
                                  initialLocation = LatLng(
                                    double.parse(latController.text),
                                    double.parse(lngController.text),
                                  );
                                } catch (e) {
                                  // Invalid coordinates
                                }
                              }

                              final selectedLocation =
                                  await Navigator.push<LatLng>(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => MapPickerScreen(
                                        initialLocation: initialLocation,
                                      ),
                                    ),
                                  );

                              if (selectedLocation != null) {
                                setDialogState(() {
                                  latController.text = selectedLocation.latitude
                                      .toStringAsFixed(6);
                                  lngController.text = selectedLocation
                                      .longitude
                                      .toStringAsFixed(6);
                                });
                              }
                            },
                            icon: const Icon(Icons.map_rounded, size: 20),
                            label: const Text(
                              'Pick Location from Map',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        // Coordinates Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: latController,
                                label: 'Latitude',
                                icon: Icons.my_location_rounded,
                                readOnly: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: lngController,
                                label: 'Longitude',
                                icon: Icons.my_location_rounded,
                                readOnly: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Price and Total Spots Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: priceController,
                                label: 'Price/Hour (EGP)',
                                hint: '0.0',
                                icon: Icons.currency_pound_rounded,
                                keyboardType: TextInputType.number,
                                isRequired: true,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: totalSpotsController,
                                label: 'Total Spots',
                                hint: '0',
                                icon: Icons.local_parking_rounded,
                                keyboardType: TextInputType.number,
                                isRequired: true,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Rating and Review Count Row
                        Row(
                          children: [
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: ratingController,
                                label: 'Rating (0.0 - 5.0)',
                                hint: '0.0',
                                icon: Icons.star_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _buildEnhancedTextField(
                                controller: reviewCountController,
                                label: 'Review Count',
                                hint: '0',
                                icon: Icons.reviews_rounded,
                                keyboardType: TextInputType.number,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Image Upload Field (Required)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  selectedImage == null &&
                                      currentImageUrl == null
                                  ? Colors.red[300]!
                                  : Colors.grey[200]!,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.image_rounded,
                                    color:
                                        selectedImage == null &&
                                            currentImageUrl == null
                                        ? Colors.red[400]
                                        : const Color(0xFF1E88E5),
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Parking Spot Image *',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF212121),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (selectedImage != null)
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: FileImage(selectedImage!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setDialogState(() {
                                                selectedImage = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else if (currentImageUrl != null &&
                                  currentImageUrl!.isNotEmpty)
                                Container(
                                  height: 150,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    image: DecorationImage(
                                      image: NetworkImage(currentImageUrl!),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            shape: BoxShape.circle,
                                          ),
                                          child: IconButton(
                                            icon: const Icon(
                                              Icons.close,
                                              color: Colors.white,
                                              size: 20,
                                            ),
                                            onPressed: () {
                                              setDialogState(() {
                                                currentImageUrl = null;
                                              });
                                            },
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                      width: 1.5,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_rounded,
                                        size: 48,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'No image selected',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: () async {
                                    final XFile? image = await _imagePicker
                                        .pickImage(
                                          source: ImageSource.gallery,
                                          imageQuality: 85,
                                        );
                                    if (image != null) {
                                      setDialogState(() {
                                        selectedImage = File(image.path);
                                        currentImageUrl =
                                            null; // Clear old URL when new image is selected
                                      });
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.upload_rounded,
                                    size: 20,
                                  ),
                                  label: const Text(
                                    'Select Image from Gallery',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF1E88E5),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Operating Hours Section
                        GestureDetector(
                          onTap: () {
                            _showOperatingHoursDialog(
                              context,
                              setDialogState,
                              mondayFridayController,
                              saturdayController,
                              sundayController,
                            );
                          },
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.blue[100]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time_rounded,
                                      color: Colors.blue[700],
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Operating Hours',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[900],
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      Icons.arrow_forward_ios_rounded,
                                      color: Colors.blue[700],
                                      size: 16,
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildEnhancedTextField(
                                        controller: mondayFridayController,
                                        label: 'Mon-Fri',
                                        hint: '6:00 AM - 11:00 PM',
                                        icon: Icons.calendar_today_rounded,
                                        readOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildEnhancedTextField(
                                        controller: saturdayController,
                                        label: 'Saturday',
                                        hint: '7:00 AM - 10:00 PM',
                                        icon: Icons.calendar_today_rounded,
                                        readOnly: true,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildEnhancedTextField(
                                        controller: sundayController,
                                        label: 'Sunday',
                                        hint: '8:00 AM - 9:00 PM',
                                        icon: Icons.calendar_today_rounded,
                                        readOnly: true,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        // Amenities Section
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.room_service_rounded,
                                    color: Colors.grey[700],
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Amenities',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF212121),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Wrap(
                                spacing: 10,
                                runSpacing: 10,
                                children:
                                    [
                                      'ev_charging',
                                      'security',
                                      'covered',
                                      'accessible',
                                      'cctv',
                                      'lighting',
                                      'restaurant',
                                      'shopping',
                                      'wifi',
                                    ].map((amenity) {
                                      final isSelected = selectedAmenities
                                          .contains(amenity);
                                      final amenityData = _getAmenityData(
                                        amenity,
                                      );
                                      return InkWell(
                                        onTap: () {
                                          setDialogState(() {
                                            if (isSelected) {
                                              selectedAmenities.remove(amenity);
                                            } else {
                                              selectedAmenities.add(amenity);
                                            }
                                          });
                                        },
                                        borderRadius: BorderRadius.circular(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 10,
                                          ),
                                          decoration: BoxDecoration(
                                            gradient: isSelected
                                                ? const LinearGradient(
                                                    colors: [
                                                      Color(0xFF1E88E5),
                                                      Color(0xFF1976D2),
                                                    ],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  )
                                                : null,
                                            color: isSelected
                                                ? null
                                                : Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color: isSelected
                                                  ? Colors.transparent
                                                  : Colors.grey[300]!,
                                              width: 1.5,
                                            ),
                                            boxShadow: isSelected
                                                ? [
                                                    BoxShadow(
                                                      color: const Color(
                                                        0xFF1E88E5,
                                                      ).withOpacity(0.4),
                                                      blurRadius: 8,
                                                      offset: const Offset(
                                                        0,
                                                        3,
                                                      ),
                                                      spreadRadius: 0,
                                                    ),
                                                  ]
                                                : [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withOpacity(0.05),
                                                      blurRadius: 4,
                                                      offset: const Offset(
                                                        0,
                                                        2,
                                                      ),
                                                    ),
                                                  ],
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                amenityData['icon'],
                                                size: 18,
                                                color: isSelected
                                                    ? Colors.white
                                                    : amenityData['color'],
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                amenityData['label'],
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: isSelected
                                                      ? Colors.white
                                                      : Colors.grey[800],
                                                ),
                                              ),
                                              if (isSelected) ...[
                                                const SizedBox(width: 4),
                                                const Icon(
                                                  Icons.check_circle,
                                                  size: 16,
                                                  color: Colors.white,
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Actions
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(20),
                      bottomRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(context),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.grey[700],
                            side: BorderSide(
                              color: Colors.grey[300]!,
                              width: 1.5,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF1E88E5).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () async {
                              // Check if image is required
                              if (selectedImage == null &&
                                  currentImageUrl == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Please select an image'),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }

                              try {
                                // Upload new image if selected
                                String? imageUrl = currentImageUrl;
                                if (selectedImage != null) {
                                  imageUrl = await _uploadImageToCloudinary(
                                    selectedImage!.path,
                                    'raknago/parking_spots/${DateTime.now().millisecondsSinceEpoch}_${nameController.text.replaceAll(' ', '_')}',
                                  );
                                }

                                await _firestore
                                    .collection('parking_spots')
                                    .doc(spot['id'])
                                    .update({
                                      'name': nameController.text,
                                      'description': descController.text,
                                      'address': addressController.text,
                                      'location': {
                                        'lat':
                                            double.tryParse(
                                              latController.text,
                                            ) ??
                                            30.0444,
                                        'lng':
                                            double.tryParse(
                                              lngController.text,
                                            ) ??
                                            31.2357,
                                      },
                                      'pricePerHour':
                                          double.tryParse(
                                            priceController.text,
                                          ) ??
                                          0.0,
                                      'totalSpots':
                                          int.tryParse(
                                            totalSpotsController.text,
                                          ) ??
                                          0,
                                      'hasEVCharging': hasEVCharging,
                                      'evChargingPrice':
                                          double.tryParse(
                                            evPriceController.text,
                                          ) ??
                                          0.0,
                                      'evChargerCount': hasEVCharging
                                          ? int.tryParse(
                                                  evChargerCountController.text,
                                                ) ??
                                                0
                                          : 0,
                                      'rating':
                                          double.tryParse(
                                            ratingController.text,
                                          ) ??
                                          0.0,
                                      'reviewCount':
                                          int.tryParse(
                                            reviewCountController.text,
                                          ) ??
                                          0,
                                      'amenities': selectedAmenities,
                                      'imageUrl': imageUrl,
                                      'operatingHours': {
                                        'mondayFriday':
                                            mondayFridayController.text,
                                        'saturday': saturdayController.text,
                                        'sunday': sundayController.text,
                                      },
                                      'updatedAt': FieldValue.serverTimestamp(),
                                    });

                                setState(() {
                                  spot['name'] = nameController.text;
                                  spot['description'] = descController.text;
                                  spot['address'] = addressController.text;
                                  spot['location'] = {
                                    'lat':
                                        double.tryParse(latController.text) ??
                                        30.0444,
                                    'lng':
                                        double.tryParse(lngController.text) ??
                                        31.2357,
                                  };
                                  spot['pricePerHour'] =
                                      double.tryParse(priceController.text) ??
                                      0.0;
                                  spot['totalSpots'] =
                                      int.tryParse(totalSpotsController.text) ??
                                      0;
                                  spot['hasEVCharging'] = hasEVCharging;
                                  spot['evChargingPrice'] =
                                      double.tryParse(evPriceController.text) ??
                                      0.0;
                                  spot['evChargerCount'] = hasEVCharging
                                      ? int.tryParse(
                                              evChargerCountController.text,
                                            ) ??
                                            0
                                      : 0;
                                  spot['rating'] =
                                      double.tryParse(ratingController.text) ??
                                      0.0;
                                  spot['reviewCount'] =
                                      int.tryParse(
                                        reviewCountController.text,
                                      ) ??
                                      0;
                                  spot['amenities'] = selectedAmenities;
                                  spot['imageUrl'] = imageUrl;
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
                                            child: Text(
                                              'Parking spot updated successfully!',
                                            ),
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
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.save_rounded, size: 20),
                                SizedBox(width: 8),
                                Text(
                                  'Update Spot',
                                  style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSpotStatus(Map<String, dynamic> spot) async {
    try {
      final newStatus = !(spot['isActive'] ?? true);
      await _firestore.collection('parking_spots').doc(spot['id']).update({
        'isActive': newStatus,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      setState(() {
        spot['isActive'] = newStatus;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.info_outline, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    newStatus
                        ? 'Parking spot activated'
                        : 'Parking spot deactivated',
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF1E88E5),
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
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showQRCodeDialog(Map<String, dynamic> spot) {
    final qrCode = spot['qrCode'] ?? spot['id'];
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.qr_code_rounded,
                        color: Color(0xFF1E88E5),
                        size: 24,
                      ),
                      SizedBox(width: 12),
                      Text(
                        'QR Code',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF212121),
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              // Spot Name
              Text(
                spot['name'] ?? 'Unknown',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF212121),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                spot['address'] ?? '',
                style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              // QR Code
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey[300]!, width: 2),
                ),
                child: QrImageView(
                  data: qrCode,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
              ),
              const SizedBox(height: 24),
              // Info
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
                        'Users can scan this QR code to unlock the parking spot (requires active booking)',
                        style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1E88E5),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _deleteSpot(Map<String, dynamic> spot) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Delete Parking Spot'),
        content: Text(
          'Are you sure you want to delete "${spot['name']}"?  This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              // Save context before closing dialog
              final scaffoldContext = context;
              Navigator.pop(context);

              // Show loading indicator
              if (mounted) {
                showDialog(
                  context: scaffoldContext,
                  barrierDismissible: false,
                  builder: (context) => const Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(
                        Color(0xFF1E88E5),
                      ),
                    ),
                  ),
                );
              }

              try {
                // Delete related reservations first
                final reservationsSnapshot = await _firestore
                    .collection('reservations')
                    .where('spotId', isEqualTo: spot['id'])
                    .get();

                for (var doc in reservationsSnapshot.docs) {
                  await doc.reference.delete();
                }

                // Delete parking spot
                await _firestore
                    .collection('parking_spots')
                    .doc(spot['id'])
                    .delete();

                // Close loading indicator
                if (mounted) {
                  try {
                    Navigator.pop(scaffoldContext);
                  } catch (_) {
                    // Dialog might not be open
                  }
                }

                if (mounted) {
                  setState(() {
                    _parkingSpots.remove(spot);
                  });
                }

                if (mounted) {
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: const Row(
                        children: [
                          Icon(Icons.check_circle_outline, color: Colors.white),
                          SizedBox(width: 12),
                          Expanded(
                            child: Text('Parking spot deleted successfully'),
                          ),
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
                }
              } catch (e) {
                // Close loading indicator if still open
                if (mounted) {
                  try {
                    Navigator.pop(scaffoldContext);
                  } catch (_) {
                    // Dialog might not be open
                  }
                }

                if (mounted) {
                  ScaffoldMessenger.of(scaffoldContext).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Colors.white),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text('Error deleting spot: ${e.toString()}'),
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

                print('Error deleting parking spot: $e');
              }
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showOperatingHoursDialog(
    BuildContext context,
    StateSetter setDialogState,
    TextEditingController mondayFridayController,
    TextEditingController saturdayController,
    TextEditingController sundayController,
  ) {
    TimeOfDay mondayFridayStart = TimeOfDay(hour: 6, minute: 0);
    TimeOfDay mondayFridayEnd = TimeOfDay(hour: 23, minute: 0);
    TimeOfDay saturdayStart = TimeOfDay(hour: 7, minute: 0);
    TimeOfDay saturdayEnd = TimeOfDay(hour: 22, minute: 0);
    TimeOfDay sundayStart = TimeOfDay(hour: 8, minute: 0);
    TimeOfDay sundayEnd = TimeOfDay(hour: 21, minute: 0);

    // Parse existing values if available
    try {
      final mfText = mondayFridayController.text;
      if (mfText.isNotEmpty && mfText.contains(' - ')) {
        final parts = mfText.split(' - ');
        if (parts.length == 2) {
          mondayFridayStart = _parseTime(parts[0]);
          mondayFridayEnd = _parseTime(parts[1]);
        }
      }
    } catch (e) {
      // Use defaults
    }

    try {
      final satText = saturdayController.text;
      if (satText.isNotEmpty && satText.contains(' - ')) {
        final parts = satText.split(' - ');
        if (parts.length == 2) {
          saturdayStart = _parseTime(parts[0]);
          saturdayEnd = _parseTime(parts[1]);
        }
      }
    } catch (e) {
      // Use defaults
    }

    try {
      final sunText = sundayController.text;
      if (sunText.isNotEmpty && sunText.contains(' - ')) {
        final parts = sunText.split(' - ');
        if (parts.length == 2) {
          sundayStart = _parseTime(parts[0]);
          sundayEnd = _parseTime(parts[1]);
        }
      }
    } catch (e) {
      // Use defaults
    }

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Row(
            children: [
              Icon(Icons.access_time_rounded, color: Color(0xFF1E88E5)),
              SizedBox(width: 12),
              Text('Operating Hours'),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Monday-Friday
                _buildTimeRangeSelector(
                  context,
                  setState,
                  'Monday - Friday',
                  mondayFridayStart,
                  mondayFridayEnd,
                  (start, end) {
                    mondayFridayStart = start;
                    mondayFridayEnd = end;
                  },
                ),
                const SizedBox(height: 16),
                // Saturday
                _buildTimeRangeSelector(
                  context,
                  setState,
                  'Saturday',
                  saturdayStart,
                  saturdayEnd,
                  (start, end) {
                    saturdayStart = start;
                    saturdayEnd = end;
                  },
                ),
                const SizedBox(height: 16),
                // Sunday
                _buildTimeRangeSelector(
                  context,
                  setState,
                  'Sunday',
                  sundayStart,
                  sundayEnd,
                  (start, end) {
                    sundayStart = start;
                    sundayEnd = end;
                  },
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
              onPressed: () {
                mondayFridayController.text =
                    '${_formatTime(mondayFridayStart)} - ${_formatTime(mondayFridayEnd)}';
                saturdayController.text =
                    '${_formatTime(saturdayStart)} - ${_formatTime(saturdayEnd)}';
                sundayController.text =
                    '${_formatTime(sundayStart)} - ${_formatTime(sundayEnd)}';
                setDialogState(() {});
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1E88E5),
                foregroundColor: Colors.white,
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimeRangeSelector(
    BuildContext context,
    StateSetter setState,
    String label,
    TimeOfDay startTime,
    TimeOfDay endTime,
    Function(TimeOfDay, TimeOfDay) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFF212121),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: startTime,
                  );
                  if (time != null) {
                    setState(() {
                      onChanged(time, endTime);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(startTime),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text(
                'to',
                style: TextStyle(fontSize: 14, color: Colors.grey),
              ),
            ),
            Expanded(
              child: GestureDetector(
                onTap: () async {
                  final time = await showTimePicker(
                    context: context,
                    initialTime: endTime,
                  );
                  if (time != null) {
                    setState(() {
                      onChanged(startTime, time);
                    });
                  }
                },
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey[300]!),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.access_time_rounded,
                        size: 18,
                        color: Color(0xFF1E88E5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _formatTime(endTime),
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  TimeOfDay _parseTime(String timeStr) {
    try {
      final parts = timeStr.trim().split(' ');
      if (parts.length == 2) {
        final timePart = parts[0];
        final period = parts[1].toUpperCase();
        final timeParts = timePart.split(':');
        if (timeParts.length == 2) {
          int hour = int.parse(timeParts[0]);
          final minute = int.parse(timeParts[1]);
          if (period == 'PM' && hour != 12) {
            hour += 12;
          } else if (period == 'AM' && hour == 12) {
            hour = 0;
          }
          return TimeOfDay(hour: hour, minute: minute);
        }
      }
    } catch (e) {
      // Return default
    }
    return TimeOfDay(hour: 6, minute: 0);
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour == 0
        ? 12
        : time.hour > 12
        ? time.hour - 12
        : time.hour;
    final period = time.hour >= 12 ? 'PM' : 'AM';
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute $period';
  }
}
