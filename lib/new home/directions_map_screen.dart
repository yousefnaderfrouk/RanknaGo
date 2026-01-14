import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import '../theme_provider.dart';

class DirectionsMapScreen extends StatefulWidget {
  final LatLng destination;
  final LatLng userLocation;
  final String parkingName;
  final String? userAvatarUrl;

  const DirectionsMapScreen({
    super.key,
    required this.destination,
    required this.userLocation,
    required this.parkingName,
    this.userAvatarUrl,
  });

  @override
  State<DirectionsMapScreen> createState() => _DirectionsMapScreenState();
}

class _DirectionsMapScreenState extends State<DirectionsMapScreen> {
  late final MapController _mapController;
  bool _navigating = false;
  List<LatLng> _route = [];
  List<LatLng> _remainingRoute = []; // المسار المتبقي فقط
  int _carIndex = 0;
  Timer? _animationTimer;
  double _distance = 0;
  int _duration = 0;
  double _totalDistance = 0; // المسافة الكلية من API
  int _totalDuration = 0; // الوقت الكلي من API
  LatLng _currentUserLocation = const LatLng(30.0444, 31.2357);
  LatLng _carPositionOnRoute = const LatLng(
    30.0444,
    31.2357,
  ); // موقع السيارة على المسار
  StreamSubscription<Position>? _positionStream;
  bool _isLoadingRoute = true;
  List<Map<String, dynamic>> _instructions = [];
  int _currentInstructionIndex = 0;
  String _currentDirectionText = ''; // نص الاتجاه الحالي
  bool _is2DMode = true; // وضع الخريطة (2D أو 3D)

  @override
  void initState() {
    super.initState();
    _mapController = MapController();
    _currentUserLocation = widget.userLocation;
    _fetchRealRoute();
    _startLocationTracking();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_route.isNotEmpty) {
        _fitBounds();
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _positionStream?.cancel();
    _mapController.dispose();
    super.dispose();
  }

  Future<void> _fetchRealRoute() async {
    setState(() {
      _isLoadingRoute = true;
    });

    try {
      // استخدام OpenRouteService API للحصول على مسار حقيقي
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car'
          '?api_key=eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjYzNmY5YTc5ODFjYzRkMWFiZmM2MTdiMDFiYjcxYzkwIiwiaCI6Im11cm11cjY0In0='
          '&start=${widget.userLocation.longitude},${widget.userLocation.latitude}'
          '&end=${widget.destination.longitude},${widget.destination.latitude}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['features'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;

        // تحويل الإحداثيات من [lon, lat] إلى LatLng
        // التأكد من أن المسار يتبع الشوارع الحقيقية من API
        _route = coordinates.map((coord) {
          return LatLng(coord[1] as double, coord[0] as double);
        }).toList();

        // التأكد من أن المسار يحتوي على نقاط كافية (على الأقل 2 نقطة)
        if (_route.length < 2) {
          throw Exception('المسار غير صالح - نقاط غير كافية');
        }

        // تحديث المسار المتبقي
        _remainingRoute = List.from(_route);

        // حساب المسافة والوقت من API
        final properties = data['features'][0]['properties'];
        final summary = properties['summary'];

        // حساب المسافة والوقت يدوياً أولاً للتحقق
        final Distance distanceCalculator = Distance();
        final directDistance = distanceCalculator.as(
          LengthUnit.Kilometer,
          widget.userLocation,
          widget.destination,
        );

        // المسافة تكون بالمتر في API
        final distanceInMeters = summary['distance'] as num? ?? 0;
        final apiDistance = distanceInMeters / 1000; // تحويل من متر إلى كيلومتر

        // الوقت يكون بالثواني في API
        final durationInSeconds = summary['duration'] as num? ?? 0;
        final apiDuration = (durationInSeconds / 60)
            .round(); // تحويل من ثانية إلى دقيقة

        // حفظ القيم الكلية من API
        if (apiDistance > 0 &&
            apiDistance <= directDistance * 10 &&
            apiDuration > 0 &&
            apiDuration <= 10000) {
          _totalDistance = apiDistance;
          _totalDuration = apiDuration;
          // تحديث المسافة والوقت المتبقيين
          _distance = apiDistance;
          _duration = apiDuration;
        } else {
          // استخدام المسافة المباشرة مع حساب الوقت التقريبي
          _totalDistance = directDistance;
          _totalDuration = (directDistance / 40 * 60).round();
          _distance = directDistance;
          _duration = _totalDuration;
        }

        // استخراج تعليمات التنقل الحقيقية
        final segments = properties['segments'] as List;
        _instructions = [];
        for (var segment in segments) {
          final steps = segment['steps'] as List;
          for (var step in steps) {
            final instruction = step['instruction'] as String;
            final distance = (step['distance'] as num) / 1000;
            final duration = (step['duration'] as num) / 60; // بالدقائق
            final type = step['type'] as int? ?? 0; // نوع المنعطف

            // تحسين نص التعليمات
            String improvedInstruction = instruction;
            if (instruction.contains('Turn left')) {
              improvedInstruction = '↰ انعطف يساراً';
            } else if (instruction.contains('Turn right')) {
              improvedInstruction = '↱ انعطف يميناً';
            } else if (instruction.contains('Go straight')) {
              improvedInstruction = '↑ استمر للأمام';
            } else if (instruction.contains('Continue')) {
              improvedInstruction = '→ استمر';
            } else if (instruction.contains('Destination')) {
              improvedInstruction = '✓ وصلت إلى الوجهة';
            }

            _instructions.add({
              'instruction': improvedInstruction,
              'originalInstruction': instruction,
              'distance': distance,
              'duration': duration,
              'type': type,
            });
          }
        }

        setState(() {
          _isLoadingRoute = false;
        });

        if (mounted) {
          _fitBounds();
        }
      } else {
        // إذا فشل API، نعرض رسالة خطأ بدلاً من مسار بسيط
        print('API Error: ${response.statusCode} - ${response.body}');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'فشل في الحصول على المسار. يرجى المحاولة مرة أخرى.',
              ),
              backgroundColor: Colors.red,
            ),
          );
        }
        setState(() {
          _isLoadingRoute = false;
        });
      }
    } catch (e) {
      // في حالة الخطأ، نعرض رسالة بدلاً من مسار بسيط
      print('Route Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطأ في الاتصال: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      setState(() {
        _isLoadingRoute = false;
      });
    }
  }

  void _startLocationTracking() {
    _positionStream =
        Geolocator.getPositionStream(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 10,
          ),
        ).listen((Position position) {
          if (mounted) {
            setState(() {
              _currentUserLocation = LatLng(
                position.latitude,
                position.longitude,
              );
            });

            // تحديث المسار أثناء التنقل (كل 200 متر فقط لتوفير API calls)
            if (_navigating) {
              // تحديث المسار فقط إذا تحرك المستخدم مسافة كبيرة
              final Distance distanceCalculator = Distance();
              final lastRoutePoint =
                  _route.isNotEmpty && _carIndex < _route.length
                  ? _route[_carIndex]
                  : _currentUserLocation;
              final distanceFromLastUpdate = distanceCalculator.as(
                LengthUnit.Meter,
                _currentUserLocation,
                lastRoutePoint,
              );

              // تحديث المسار كل 200 متر لتقليل استهلاك API
              if (distanceFromLastUpdate > 200) {
                _updateRouteFromCurrentPosition();
              }
            }

            // تتبع السيارة على المسار أثناء التنقل - تحريك الخريطة لتتبع السيارة تلقائياً
            if (_navigating && mounted) {
              // استخدام zoom بناءً على وضع 2D/3D
              final zoomLevel = _is2DMode ? 16.5 : 18.0;
              _mapController.move(_carPositionOnRoute, zoomLevel);
            }
          }
        });
  }

  Future<void> _updateRouteFromCurrentPosition() async {
    try {
      final response = await http.get(
        Uri.parse(
          'https://api.openrouteservice.org/v2/directions/driving-car'
          '?api_key=eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjYzNmY5YTc5ODFjYzRkMWFiZmM2MTdiMDFiYjcxYzkwIiwiaCI6Im11cm11cjY0In0='
          '&start=${_currentUserLocation.longitude},${_currentUserLocation.latitude}'
          '&end=${widget.destination.longitude},${widget.destination.latitude}',
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final geometry = data['features'][0]['geometry'];
        final coordinates = geometry['coordinates'] as List;

        // تحديث المسار - التأكد من أن المسار يتبع الشوارع الحقيقية من API
        final newRoute = coordinates.map((coord) {
          return LatLng(coord[1] as double, coord[0] as double);
        }).toList();

        final properties = data['features'][0]['properties'];
        final summary = properties['summary'];

        // المسافة تكون بالمتر في API
        final distanceInMeters = summary['distance'] as num? ?? 0;
        final apiDistance = distanceInMeters / 1000; // تحويل من متر إلى كيلومتر

        // الوقت يكون بالثواني في API
        final durationInSeconds = summary['duration'] as num? ?? 0;
        final apiDuration = (durationInSeconds / 60)
            .round(); // تحويل من ثانية إلى دقيقة

        if (mounted && newRoute.isNotEmpty && newRoute.length >= 2) {
          setState(() {
            _route = newRoute;
            // تحديث المسار المتبقي أيضاً باستخدام نقاط API الحقيقية التي تتبع الشوارع
            _remainingRoute = [];
            _remainingRoute.add(_currentUserLocation);
            for (int i = 0; i < _route.length; i++) {
              _remainingRoute.add(_route[i]);
            }
            // إضافة الوجهة فقط إذا كانت بعيدة عن آخر نقطة
            final Distance distanceCalculator = Distance();
            final lastRoutePoint = _route.last;
            final distanceToDestination = distanceCalculator.as(
              LengthUnit.Meter,
              lastRoutePoint,
              widget.destination,
            );
            if (distanceToDestination > 10) {
              _remainingRoute.add(widget.destination);
            }

            // حفظ القيم الكلية من API
            if (apiDistance > 0 && apiDuration > 0) {
              _totalDistance = apiDistance;
              _totalDuration = apiDuration;
              // تحديث المسافة والوقت المتبقيين
              _updateRemainingDistanceAndTime();
            }

            // إعادة حساب موقع السيارة على المسار الجديد
            _updateCarPositionOnRoute();
          });

          // إعادة zoom على السيارة على المسار بعد إعادة التوجيه (مثل Google Maps)
          if (mounted) {
            final zoomLevel = _is2DMode ? 16.5 : 18.0;
            _mapController.move(_carPositionOnRoute, zoomLevel);
          }
        }
      }
    } catch (e) {
      // Ignore errors during navigation
    }
  }

  void _fitBounds() {
    if (_route.isEmpty) return;

    final latitudes = _route.map((p) => p.latitude).toList();
    final longitudes = _route.map((p) => p.longitude).toList();

    final north = latitudes.reduce((a, b) => a > b ? a : b);
    final south = latitudes.reduce((a, b) => a < b ? a : b);
    final east = longitudes.reduce((a, b) => a > b ? a : b);
    final west = longitudes.reduce((a, b) => a < b ? a : b);

    final bounds = LatLngBounds(LatLng(south, west), LatLng(north, east));

    _mapController.fitBounds(
      bounds,
      options: const FitBoundsOptions(padding: EdgeInsets.all(80)),
    );
  }

  void _startNavigation() {
    if (_route.isEmpty) return;

    setState(() {
      _navigating = true;
      _carIndex = 0;
      _currentInstructionIndex = 0;
      _currentDirectionText = '';
      _remainingRoute = List.from(_route); // بدء المسار المتبقي بالمسار الكامل
      // التبديل التلقائي إلى وضع 2D عند بدء الرحلة (مثل Google Maps)
      _is2DMode = true;
    });

    // البحث عن أقرب نقطة في المسار للموقع الحالي
    _updateCarPositionOnRoute();

    // عمل zoom على السيارة على المسار مع animation (مثل Google Maps)
    if (mounted) {
      // استخدام zoom أعلى لتتبع السيارة بشكل أفضل
      final zoomLevel = 16.5; // دائماً 2D عند البدء

      // Animation سلس للتبديل إلى 2D
      Future.delayed(const Duration(milliseconds: 100), () {
        if (mounted) {
          _mapController.move(_carPositionOnRoute, zoomLevel);
        }
      });
    }

    // بدء التتبع الحقيقي للموقع
    // لا نستخدم timer للحركة، بل نعتمد على تحديث الموقع الحقيقي
    // فقط نستخدم timer لتحديث التعليمات والواجهة
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(milliseconds: 500), (t) {
      if (!mounted || !_navigating) return;

      // تحديث موقع السيارة بناءً على الموقع الحقيقي
      _updateCarPositionOnRoute();

      // تحديث المسافة والوقت المتبقي أولاً
      _updateRemainingDistanceAndTime();

      // تحديث التعليمات
      _updateCurrentInstruction();

      // التحقق من الوصول - فقط إذا كانت المسافة المتبقية أقل من 50 متر
      // والتأكد من أن المستخدم قريب فعلياً من الوجهة
      if (_distance < 0.05 && _distance > 0) {
        final Distance distanceCalculator = Distance();
        final actualDistance = distanceCalculator.as(
          LengthUnit.Meter,
          _currentUserLocation,
          widget.destination,
        );

        // التحقق من أن المستخدم قريب فعلياً من الوجهة (أقل من 50 متر)
        if (actualDistance < 50) {
          _animationTimer?.cancel();
          _showArrivalDialog();
        }
      }
    });
  }

  void _updateCarPositionOnRoute() {
    if (_route.isEmpty) return;

    // البحث عن أقرب نقطة في المسار للموقع الحالي
    double minDistance = double.infinity;
    int closestIndex = 0;
    final Distance distanceCalculator = Distance();

    for (int i = 0; i < _route.length; i++) {
      final dist = distanceCalculator.as(
        LengthUnit.Meter,
        _currentUserLocation,
        _route[i],
      );
      if (dist < minDistance) {
        minDistance = dist;
        closestIndex = i;
      }
    }

    // تحديث موقع السيارة على المسار (استخدام نقطة المسار بدلاً من الموقع الحقيقي)
    LatLng newCarPosition = _route[closestIndex];

    // إذا كان هناك نقطة تالية في المسار، نحسب موقعاً بينهما بناءً على المسافة
    if (closestIndex < _route.length - 1) {
      final nextPoint = _route[closestIndex + 1];
      final distanceToNext = distanceCalculator.as(
        LengthUnit.Meter,
        _currentUserLocation,
        nextPoint,
      );
      final distanceBetweenPoints = distanceCalculator.as(
        LengthUnit.Meter,
        _route[closestIndex],
        nextPoint,
      );

      // إذا كان المستخدم أقرب للنقطة التالية، نستخدم موقعاً بين النقطتين
      if (distanceToNext < distanceBetweenPoints && distanceBetweenPoints > 0) {
        final ratio = distanceToNext / distanceBetweenPoints;
        newCarPosition = LatLng(
          _route[closestIndex].latitude +
              (nextPoint.latitude - _route[closestIndex].latitude) *
                  (1 - ratio),
          _route[closestIndex].longitude +
              (nextPoint.longitude - _route[closestIndex].longitude) *
                  (1 - ratio),
        );
      }
    }

    // تحديث موقع السيارة والمسار المتبقي
    if (closestIndex != _carIndex ||
        _remainingRoute.isEmpty ||
        (newCarPosition.latitude != _carPositionOnRoute.latitude ||
            newCarPosition.longitude != _carPositionOnRoute.longitude)) {
      setState(() {
        _carIndex = closestIndex;
        _carPositionOnRoute = newCarPosition;

        // تحديث المسار المتبقي (من موقع السيارة على المسار إلى الوجهة)
        _remainingRoute = [];
        _remainingRoute.add(_carPositionOnRoute);

        // إضافة باقي نقاط المسار من أقرب نقطة (هذه النقاط تتبع الشوارع من API)
        for (int i = closestIndex; i < _route.length; i++) {
          _remainingRoute.add(_route[i]);
        }

        // إضافة الوجهة فقط إذا كانت بعيدة عن آخر نقطة في المسار
        final lastRoutePoint = _route.isNotEmpty
            ? _route.last
            : _carPositionOnRoute;
        final distanceToDestination = distanceCalculator.as(
          LengthUnit.Meter,
          lastRoutePoint,
          widget.destination,
        );

        // إضافة الوجهة فقط إذا كانت بعيدة عن آخر نقطة في المسار (أكثر من 10 متر)
        if (distanceToDestination > 10) {
          _remainingRoute.add(widget.destination);
        }
      });

      // تحريك الخريطة لتتبع السيارة على المسار مع zoom بناءً على وضع 2D/3D
      if (mounted) {
        final zoomLevel = _is2DMode ? 16.5 : 18.0;
        _mapController.move(_carPositionOnRoute, zoomLevel);
      }
    }
  }

  void _updateRemainingDistanceAndTime() {
    if (_route.isEmpty) return;

    // حساب المسافة المتبقية على طول المسار الحقيقي من API
    final Distance distanceCalculator = Distance();
    double remainingDistance = 0;

    // إذا كان المسار المتبقي موجوداً، استخدمه
    if (_remainingRoute.isNotEmpty && _remainingRoute.length > 1) {
      // حساب المسافة على طول المسار المتبقي (من API)
      for (int i = 0; i < _remainingRoute.length - 1; i++) {
        remainingDistance += distanceCalculator.as(
          LengthUnit.Kilometer,
          _remainingRoute[i],
          _remainingRoute[i + 1],
        );
      }

      // حساب المسافة من آخر نقطة في المسار المتبقي إلى الوجهة
      final lastPoint = _remainingRoute.last;
      final distanceToDestination = distanceCalculator.as(
        LengthUnit.Kilometer,
        lastPoint,
        widget.destination,
      );
      remainingDistance += distanceToDestination;
    } else {
      // إذا لم يكن المسار المتبقي موجوداً، استخدم المسافة المباشرة من الموقع الحالي
      remainingDistance = distanceCalculator.as(
        LengthUnit.Kilometer,
        _currentUserLocation,
        widget.destination,
      );
    }

    // حساب الوقت المتبقي بناءً على المسافة المتبقية
    // استخدام متوسط السرعة من API (المسافة الكلية / الوقت الكلي)
    double averageSpeed = 0; // كم/ساعة

    // استخدام متوسط السرعة من القيم الكلية المحفوظة من API
    if (_totalDistance > 0 && _totalDuration > 0) {
      // حساب متوسط السرعة من المسافة والوقت الكليين من API
      averageSpeed =
          _totalDistance / (_totalDuration / 60.0); // تحويل الدقائق إلى ساعات
    } else if (_distance > 0 && _duration > 0) {
      // إذا لم تكن القيم الكلية متوفرة، استخدم القيم الحالية
      averageSpeed = _distance / (_duration / 60.0);
    } else {
      // افتراضي: 40 كم/ساعة في المدينة
      averageSpeed = 40;
    }

    // حساب الوقت المتبقي بناءً على المسافة المتبقية والسرعة المتوسطة
    int remainingDuration = 0;
    if (remainingDistance > 0 && averageSpeed > 0) {
      remainingDuration = (remainingDistance / averageSpeed * 60).round();
      if (remainingDuration < 1 && remainingDistance > 0) {
        remainingDuration = 1; // على الأقل دقيقة واحدة
      }
    }

    // تحديث المسافة والوقت المتبقي
    setState(() {
      _distance = remainingDistance;
      _duration = remainingDuration;
    });
  }

  void _updateCurrentInstruction() {
    if (_instructions.isEmpty) return;

    // حساب المسافة المتبقية من الموقع الحالي إلى الوجهة
    final Distance distanceCalculator = Distance();
    double remainingDistance = 0;

    // المسافة من الموقع الحالي إلى أقرب نقطة في المسار
    if (_carIndex < _route.length) {
      remainingDistance += distanceCalculator.as(
        LengthUnit.Kilometer,
        _currentUserLocation,
        _route[_carIndex],
      );
    }

    // المسافة من نقطة المسار الحالية إلى الوجهة
    for (int i = _carIndex; i < _route.length - 1; i++) {
      remainingDistance += distanceCalculator.as(
        LengthUnit.Kilometer,
        _route[i],
        _route[i + 1],
      );
    }

    // المسافة من آخر نقطة في المسار إلى الوجهة
    if (_route.isNotEmpty) {
      remainingDistance += distanceCalculator.as(
        LengthUnit.Kilometer,
        _route.last,
        widget.destination,
      );
    }

    // العثور على التعليمة المناسبة بناءً على المسافة المتبقية
    double accumulatedDistance = 0;
    int newInstructionIndex = _currentInstructionIndex;

    for (int i = 0; i < _instructions.length; i++) {
      accumulatedDistance += _instructions[i]['distance'] as double;
      if (remainingDistance <= accumulatedDistance ||
          i == _instructions.length - 1) {
        newInstructionIndex = i;
        break;
      }
    }

    // تحديث التعليمة والاتجاه
    if (newInstructionIndex != _currentInstructionIndex ||
        _currentDirectionText.isEmpty) {
      String directionText = '';
      if (newInstructionIndex < _instructions.length) {
        final instruction =
            _instructions[newInstructionIndex]['instruction'] as String;
        final originalInstruction =
            _instructions[newInstructionIndex]['originalInstruction']
                as String? ??
            '';

        // تحويل التعليمات إلى اتجاهات عربية
        if (originalInstruction.toLowerCase().contains('turn left') ||
            originalInstruction.toLowerCase().contains('left') ||
            instruction.contains('يسار')) {
          directionText = '↰ احود يسار';
        } else if (originalInstruction.toLowerCase().contains('turn right') ||
            originalInstruction.toLowerCase().contains('right') ||
            instruction.contains('يمين')) {
          directionText = '↱ احود يمين';
        } else if (originalInstruction.toLowerCase().contains('go straight') ||
            originalInstruction.toLowerCase().contains('head') ||
            originalInstruction.toLowerCase().contains('continue straight') ||
            instruction.contains('أمام')) {
          directionText = '↑ استمر للأمام';
        } else if (originalInstruction.toLowerCase().contains('continue')) {
          directionText = '→ استمر';
        } else if (originalInstruction.toLowerCase().contains('destination') ||
            originalInstruction.toLowerCase().contains('arrive')) {
          directionText = '✓ وصلت';
        } else {
          directionText = instruction;
        }
      }

      setState(() {
        _currentInstructionIndex = newInstructionIndex;
        _currentDirectionText = directionText;
      });
    }
  }

  void _stopNavigation() {
    _animationTimer?.cancel();
    setState(() {
      _navigating = false;
      _carIndex = 0;
    });
    _fitBounds();
  }

  void _showArrivalDialog() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: theme.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.check, color: Colors.white, size: 28),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'You\'ve arrived!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
        content: Text(
          'You have arrived at ${widget.parkingName}',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? Colors.grey[300] : Colors.grey[700],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E88E5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    // استخدام الموقع الحقيقي للمستخدم أثناء التنقل

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Map - نفس Home Screen بالضبط
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _currentUserLocation,
              initialZoom: 14.0,
              minZoom: 10.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                // Use OpenStreetMap tiles (reliable public tiles) instead of Carto
                urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'com.parkspot.app',
                retinaMode: MediaQuery.of(context).devicePixelRatio > 1.0,
                maxNativeZoom: 18,
                maxZoom: 18,
              ),

              // Circle Layer for user location (like Google Maps)
              if (!_navigating)
                CircleLayer(
                  circles: [
                    CircleMarker(
                      point: _currentUserLocation,
                      radius: 100,
                      useRadiusInMeter: true,
                      color: const Color(0xFF1E88E5).withOpacity(0.15),
                      borderColor: const Color(0xFF1E88E5).withOpacity(0.3),
                      borderStrokeWidth: 2,
                    ),
                  ],
                ),

              // Route Polyline (BLUE) - مسار حقيقي من API
              // أثناء التنقل: نعرض فقط المسار المتبقي (مثل Google Maps)
              // قبل التنقل: نعرض المسار الكامل
              if ((_navigating ? _remainingRoute : _route).isNotEmpty)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _navigating ? _remainingRoute : _route,
                      strokeWidth: 6.0,
                      color: const Color(0xFF1E88E5),
                      borderStrokeWidth: 2.0,
                      borderColor: Colors.white,
                    ),
                  ],
                ),

              // Markers
              MarkerLayer(
                markers: [
                  // Destination Marker (Parking)
                  Marker(
                    point: widget.destination,
                    width: 50,
                    height: 50,
                    child: _buildDestinationMarker(),
                  ),

                  // User Start Marker - يظهر فقط قبل بدء التنقل
                  if (!_navigating)
                    Marker(
                      point: _currentUserLocation,
                      width: 70,
                      height: 70,
                      child: _buildUserMarker(),
                    ),

                  // Moving Car Marker - يظهر فقط أثناء التنقل (بدلاً من User Marker)
                  // السيارة تتحرك على المسار وليس على الموقع الحقيقي
                  if (_navigating)
                    Marker(
                      point: _carPositionOnRoute,
                      width: 56,
                      height: 56,
                      child: _buildCarMarker(),
                    ),
                ],
              ),
            ],
          ),

          // Loading Indicator
          if (_isLoadingRoute)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          Color(0xFF1E88E5),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Calculating route...',
                        style: TextStyle(
                          color: isDark
                              ? Colors.white
                              : const Color(0xFF212121),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // Top UI - مثل Google Maps
          SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 12),

                // Back button and Distance badge
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Back Button
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: theme.cardColor,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_back,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF212121),
                            size: 20,
                          ),
                        ),
                      ),

                      // Distance Badge (only when not navigating)
                      if (!_navigating && !_isLoadingRoute)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.directions_car_rounded,
                                color: Color(0xFF1E88E5),
                                size: 18,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '${_distance.toStringAsFixed(1)} km',
                                style: const TextStyle(
                                  color: Color(0xFF212121),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                width: 1,
                                height: 16,
                                color: Colors.grey[300],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '$_duration min',
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
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

          // Navigation Instructions (مثل Google Maps) - تعليمات في الأعلى
          if (_navigating && _currentDirectionText.isNotEmpty)
            Positioned(
              top: 80,
              left: 16,
              right: 16,
              child: SafeArea(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // أيقونة الاتجاه
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.navigation_rounded,
                          color: Color(0xFF1E88E5),
                          size: 28,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // نص الاتجاه
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _currentDirectionText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF212121),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (_currentInstructionIndex <
                                _instructions.length) ...[
                              const SizedBox(height: 4),
                              Text(
                                '${(_instructions[_currentInstructionIndex]['distance'] as double).toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      // المسافة المتبقية
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E88E5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${_distance.toStringAsFixed(1)}',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1E88E5),
                              ),
                            ),
                            const Text(
                              'km',
                              style: TextStyle(
                                fontSize: 10,
                                color: Color(0xFF1E88E5),
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

          // My Location Button - لتوسيط الخريطة على موقعك
          Positioned(
            right: 16,
            bottom: _navigating ? 180 : 92,
            child: GestureDetector(
              onTap: () {
                if (mounted) {
                  // عمل zoom على السيارة على المسار بناءً على وضع 2D/3D
                  final zoomLevel = _is2DMode ? 16.5 : 18.0;
                  final positionToMove = _navigating
                      ? _carPositionOnRoute
                      : _currentUserLocation;
                  _mapController.move(positionToMove, zoomLevel);
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.my_location,
                  color: Color(0xFF1E88E5),
                  size: 22,
                ),
              ),
            ),
          ),

          // Re-route Button - زر إعادة التوجيه (يظهر فقط أثناء التنقل)
          if (_navigating)
            Positioned(
              right: 16,
              bottom: 120,
              child: GestureDetector(
                onTap: () {
                  // إعادة حساب المسار من الموقع الحالي
                  _updateRouteFromCurrentPosition();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.refresh, color: Colors.white),
                            SizedBox(width: 8),
                            Text('جاري إعادة حساب المسار...'),
                          ],
                        ),
                        backgroundColor: Color(0xFF1E88E5),
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                },
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: theme.cardColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.refresh,
                    color: Color(0xFF1E88E5),
                    size: 22,
                  ),
                ),
              ),
            ),

          // 2D/3D Toggle Button - زر تبديل وضع الخريطة (دائماً ظاهر)
          Positioned(
            right: 16,
            bottom: _navigating ? 60 : 152,
            child: GestureDetector(
              onTap: () {
                setState(() {
                  _is2DMode = !_is2DMode;
                });
                // عند التبديل بين 2D و 3D، نحدث zoom مع animation سلس
                if (mounted) {
                  final positionToMove = _navigating
                      ? _carPositionOnRoute
                      : _currentUserLocation;

                  // Animation سلس للتبديل بين الأوضاع
                  final targetZoom = !_is2DMode ? 18.0 : 16.5;

                  // استخدام animation تدريجي للتبديل
                  _animateZoomChange(positionToMove, targetZoom);
                }
              },
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.cardColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Icon(
                  _is2DMode ? Icons.layers : Icons.layers_outlined,
                  color: _is2DMode ? const Color(0xFF1E88E5) : Colors.grey[600],
                  size: 22,
                ),
              ),
            ),
          ),

          // Bottom Controls
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child: SafeArea(
              child: !_navigating
                  ? (_isLoadingRoute
                        ? const SizedBox.shrink()
                        : _buildStartButton())
                  : _buildNavControls(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStartButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _route.isEmpty ? null : _startNavigation,
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              gradient: _route.isEmpty
                  ? null
                  : const LinearGradient(
                      colors: [Color(0xFF1E88E5), Color(0xFF1976D2)],
                    ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Center(
              child: _route.isEmpty
                  ? const Text(
                      'No route available',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey,
                      ),
                    )
                  : const Text(
                      'Start',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ),
      ),
      );
  }

  Widget _buildNavControls() {
    final themeProvider = ThemeProvider.of(context);
    final isDark = themeProvider?.isDarkMode ?? false;
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Stop button
          GestureDetector(
            onTap: _stopNavigation,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.close, color: Colors.red[600], size: 20),
            ),
          ),
          const SizedBox(width: 12),
          // Navigation info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Navigating to ${widget.parkingName}',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF212121),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                // استخدام Flexible و Wrap لتجنب overflow
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.access_time,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$_duration min',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.grey[300] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.straighten,
                          size: 14,
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            '${_distance.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark
                                  ? Colors.grey[300]
                                  : Colors.grey[700],
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // On route badge
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, size: 16, color: Colors.green[700]),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      'On route',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Colors.green[700],
                      ),
                      overflow: TextOverflow.ellipsis,
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

  Widget _buildDestinationMarker() {
    return Stack(
      alignment: Alignment.center,
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5).withOpacity(0.2),
            shape: BoxShape.circle,
          ),
        ),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFF1E88E5),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF1E88E5).withOpacity(0.4),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: const Icon(
            Icons.local_parking_rounded,
            color: Colors.white,
            size: 22,
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
        child: widget.userAvatarUrl != null && widget.userAvatarUrl!.isNotEmpty
            ? Image.network(
                widget.userAvatarUrl!,
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

  Widget _buildCarMarker() {
    return Transform.rotate(
      angle: _calculateBearing(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Shadow/Glow effect
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFF1E88E5).withOpacity(0.4),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
          // Car container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFF1E88E5), width: 3),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.15),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [const Color(0xFF1E88E5), const Color(0xFF1976D2)],
                ),
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }

  double _calculateBearing() {
    // حساب الاتجاه بناءً على موقع السيارة على المسار والنقطة التالية
    if (_route.isEmpty) return 0.0;

    LatLng next;
    if (_navigating && _carIndex < _route.length - 1) {
      // أثناء التنقل، استخدم النقطة التالية في المسار
      next = _route[_carIndex + 1];
    } else if (_carIndex < _route.length - 1) {
      next = _route[_carIndex + 1];
    } else {
      // إذا كنا في نهاية المسار، استخدم الوجهة
      next = widget.destination;
    }

    // استخدام موقع السيارة على المسار بدلاً من الموقع الحقيقي
    final current = _carPositionOnRoute;
    final lat1 = current.latitude * 3.14159 / 180;
    final lat2 = next.latitude * 3.14159 / 180;
    final dLon = (next.longitude - current.longitude) * 3.14159 / 180;

    final y = sin(dLon) * cos(lat2);
    final x = cos(lat1) * sin(lat2) - sin(lat1) * cos(lat2) * cos(dLon);

    final bearing = atan2(y, x);
    return bearing;
  }

  // Animation سلس للتبديل بين zoom levels (مثل Google Maps)
  void _animateZoomChange(LatLng position, double targetZoom) {
    if (!mounted) return;

    final currentZoom = _mapController.camera.zoom;
    final steps = 10; // عدد الخطوات للanimation
    final duration = const Duration(milliseconds: 300); // مدة الanimation
    final stepDuration = duration.inMilliseconds / steps;
    final zoomStep = (targetZoom - currentZoom) / steps;

    int currentStep = 0;

    Timer.periodic(Duration(milliseconds: stepDuration.round()), (timer) {
      if (!mounted || currentStep >= steps) {
        timer.cancel();
        // التأكد من الوصول للقيمة النهائية
        if (mounted) {
          _mapController.move(position, targetZoom);
        }
        return;
      }

      currentStep++;
      final newZoom = currentZoom + (zoomStep * currentStep);
      if (mounted) {
        _mapController.move(position, newZoom);
      }
    });
  }
}
